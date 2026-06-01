import uuid as _uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import GroceryListItem, Ingredient, InventoryItem
from app.api.dependencies import get_current_user
from app.services.inventory import find_missing

router = APIRouter()


class GroceryListItemOut(BaseModel):
    id: str
    canonical_name: str
    category: str
    checked: bool
    recipe_id: str | None


class GenerateRequest(BaseModel):
    recipe_ids: list[str]


class CheckRequest(BaseModel):
    checked: bool
    update_inventory: bool = False


class ManualAddRequest(BaseModel):
    canonical_name: str
    category: str = "other"


@router.get("", response_model=list[GroceryListItemOut])
def get_grocery_list(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    items = session.exec(
        select(GroceryListItem)
        .where(GroceryListItem.user_id == user_id)
        .order_by(GroceryListItem.category, GroceryListItem.canonical_name)
    ).all()
    return [_out(i) for i in items]


@router.post("/generate", response_model=list[GroceryListItemOut], status_code=201)
def generate_grocery_list(
    body: GenerateRequest,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    if not body.recipe_ids:
        raise HTTPException(status_code=400, detail="Provide at least one recipe_id")

    all_ingredients: list[Ingredient] = []
    for rid in body.recipe_ids:
        try:
            uid = _uuid.UUID(rid)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid recipe ID: {rid}")
        all_ingredients.extend(
            session.exec(select(Ingredient).where(Ingredient.recipe_id == uid)).all()
        )

    if not all_ingredients:
        return []

    missing_names = set(find_missing([i.canonical_name for i in all_ingredients], session, user_id))
    name_to_ing = {i.canonical_name: i for i in all_ingredients if i.canonical_name in missing_names}

    # Only skip items that are already on the list and not yet checked
    existing_unchecked = {
        i.canonical_name
        for i in session.exec(
            select(GroceryListItem).where(
                GroceryListItem.user_id == user_id,
                GroceryListItem.checked == False,  # noqa: E712
            )
        ).all()
    }

    for name, ing in name_to_ing.items():
        if name not in existing_unchecked:
            session.add(GroceryListItem(
                user_id=user_id,
                canonical_name=name,
                category=ing.category,
                recipe_id=ing.recipe_id,
            ))

    session.commit()

    all_items = session.exec(
        select(GroceryListItem)
        .where(GroceryListItem.user_id == user_id)
        .order_by(GroceryListItem.category, GroceryListItem.canonical_name)
    ).all()
    return [_out(i) for i in all_items]


@router.post("/items", response_model=GroceryListItemOut, status_code=201)
def add_grocery_item(
    body: ManualAddRequest,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    """Manually add a single ingredient to the grocery list."""
    name = body.canonical_name.strip().lower()
    if not name:
        raise HTTPException(status_code=400, detail="canonical_name is required")

    # Don't duplicate unchecked items
    existing = session.exec(
        select(GroceryListItem).where(
            GroceryListItem.user_id == user_id,
            GroceryListItem.canonical_name == name,
            GroceryListItem.checked == False,  # noqa: E712
        )
    ).first()
    if existing:
        return _out(existing)

    item = GroceryListItem(
        user_id=user_id,
        canonical_name=name,
        category=body.category,
    )
    session.add(item)
    session.commit()
    session.refresh(item)
    return _out(item)


@router.post("/add-to-pantry", status_code=204)
def add_checked_to_pantry(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    """Move all checked grocery items into the pantry (inventory) then delete them."""
    checked_items = session.exec(
        select(GroceryListItem).where(
            GroceryListItem.user_id == user_id,
            GroceryListItem.checked == True,  # noqa: E712
        )
    ).all()

    for item in checked_items:
        existing = session.exec(
            select(InventoryItem).where(
                InventoryItem.user_id == user_id,
                InventoryItem.canonical_name == item.canonical_name,
            )
        ).first()
        if existing:
            existing.status = "in_stock"
            existing.updated_at = datetime.now(timezone.utc)
            session.add(existing)
        else:
            session.add(InventoryItem(
                user_id=user_id,
                canonical_name=item.canonical_name,
                status="in_stock",
            ))
        session.delete(item)

    session.commit()


@router.patch("/items/{item_id}/check", response_model=GroceryListItemOut)
def check_grocery_item(
    item_id: str,
    body: CheckRequest,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(GroceryListItem, uid)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="Item not found")

    item.checked = body.checked

    if body.checked and body.update_inventory:
        existing = session.exec(
            select(InventoryItem)
            .where(InventoryItem.user_id == user_id, InventoryItem.canonical_name == item.canonical_name)
        ).first()
        if existing:
            existing.status = "in_stock"
            existing.updated_at = datetime.now(timezone.utc)
            session.add(existing)
        else:
            session.add(InventoryItem(
                user_id=user_id,
                canonical_name=item.canonical_name,
                status="in_stock",
            ))

    session.add(item)
    session.commit()
    session.refresh(item)
    return _out(item)


@router.delete("/items/{item_id}", status_code=204)
def delete_grocery_item(
    item_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")
    item = session.get(GroceryListItem, uid)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="Item not found")
    session.delete(item)
    session.commit()


@router.delete("", status_code=204)
def clear_checked_items(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    for item in session.exec(
        select(GroceryListItem)
        .where(GroceryListItem.user_id == user_id, GroceryListItem.checked == True)  # noqa: E712
    ).all():
        session.delete(item)
    session.commit()


def _out(item: GroceryListItem) -> GroceryListItemOut:
    return GroceryListItemOut(
        id=str(item.id),
        canonical_name=item.canonical_name,
        category=item.category,
        checked=item.checked,
        recipe_id=str(item.recipe_id) if item.recipe_id else None,
    )
