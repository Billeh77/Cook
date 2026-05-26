import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import GroceryListItem, Ingredient, InventoryItem
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
    update_inventory: bool = True  # mark as in_stock when checked off


@router.get("", response_model=list[GroceryListItemOut])
def get_grocery_list(session: Session = Depends(get_session)):
    items = session.exec(
        select(GroceryListItem).order_by(GroceryListItem.category, GroceryListItem.canonical_name)
    ).all()
    return [
        GroceryListItemOut(
            id=str(i.id),
            canonical_name=i.canonical_name,
            category=i.category,
            checked=i.checked,
            recipe_id=str(i.recipe_id) if i.recipe_id else None,
        )
        for i in items
    ]


@router.post("/generate", response_model=list[GroceryListItemOut], status_code=201)
def generate_grocery_list(body: GenerateRequest, session: Session = Depends(get_session)):
    """
    Takes a list of recipe IDs, diffs each recipe's ingredients against inventory,
    and adds missing items to the grocery list (deduplicating by canonical_name).
    """
    if not body.recipe_ids:
        raise HTTPException(status_code=400, detail="Provide at least one recipe_id")

    # Collect all ingredients for requested recipes
    all_ingredients: list[Ingredient] = []
    for rid in body.recipe_ids:
        try:
            uid = uuid.UUID(rid)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Invalid recipe ID: {rid}")
        ings = session.exec(select(Ingredient).where(Ingredient.recipe_id == uid)).all()
        all_ingredients.extend(ings)

    if not all_ingredients:
        return []

    # Find which are missing from inventory
    canonical_names = [i.canonical_name for i in all_ingredients]
    missing_names = set(find_missing(canonical_names, session))

    # Build a map: canonical_name → ingredient (for category lookup)
    name_to_ing: dict[str, Ingredient] = {}
    for ing in all_ingredients:
        if ing.canonical_name in missing_names:
            name_to_ing[ing.canonical_name] = ing

    # Remove items already on the list
    existing = session.exec(select(GroceryListItem)).all()
    already_listed = {i.canonical_name for i in existing}

    new_items: list[GroceryListItem] = []
    for name, ing in name_to_ing.items():
        if name not in already_listed:
            item = GroceryListItem(
                canonical_name=name,
                category=ing.category,
                recipe_id=ing.recipe_id,
            )
            session.add(item)
            new_items.append(item)

    session.commit()

    # Return the full current list
    all_items = session.exec(
        select(GroceryListItem).order_by(GroceryListItem.category, GroceryListItem.canonical_name)
    ).all()
    return [
        GroceryListItemOut(
            id=str(i.id),
            canonical_name=i.canonical_name,
            category=i.category,
            checked=i.checked,
            recipe_id=str(i.recipe_id) if i.recipe_id else None,
        )
        for i in all_items
    ]


@router.patch("/items/{item_id}/check", response_model=GroceryListItemOut)
def check_grocery_item(item_id: str, body: CheckRequest, session: Session = Depends(get_session)):
    try:
        uid = uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(GroceryListItem, uid)
    if not item:
        raise HTTPException(status_code=404, detail="Grocery list item not found")

    item.checked = body.checked

    # Optionally update inventory when checking off
    if body.checked and body.update_inventory:
        existing = session.exec(
            select(InventoryItem).where(InventoryItem.canonical_name == item.canonical_name)
        ).first()
        if existing:
            existing.status = "in_stock"
            existing.updated_at = datetime.now(timezone.utc)
            session.add(existing)
        else:
            inv_item = InventoryItem(
                canonical_name=item.canonical_name,
                status="in_stock",
            )
            session.add(inv_item)

    session.add(item)
    session.commit()
    session.refresh(item)

    return GroceryListItemOut(
        id=str(item.id),
        canonical_name=item.canonical_name,
        category=item.category,
        checked=item.checked,
        recipe_id=str(item.recipe_id) if item.recipe_id else None,
    )


@router.delete("/items/{item_id}", status_code=204)
def delete_grocery_item(item_id: str, session: Session = Depends(get_session)):
    try:
        uid = uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(GroceryListItem, uid)
    if not item:
        raise HTTPException(status_code=404, detail="Grocery list item not found")

    session.delete(item)
    session.commit()


@router.delete("", status_code=204)
def clear_checked_items(session: Session = Depends(get_session)):
    """Remove all checked-off items after a shopping trip."""
    checked = session.exec(select(GroceryListItem).where(GroceryListItem.checked == True)).all()  # noqa: E712
    for item in checked:
        session.delete(item)
    session.commit()
