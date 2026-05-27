import uuid as _uuid
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import InventoryItem
from app.api.dependencies import get_current_user

router = APIRouter()

VALID_STATUSES = {"in_stock", "low", "out_of_stock", "always_have"}


class InventoryItemCreate(BaseModel):
    canonical_name: str
    status: str = "in_stock"


class InventoryItemUpdate(BaseModel):
    status: str


class InventoryItemOut(BaseModel):
    id: str
    canonical_name: str
    status: str
    updated_at: str


@router.get("", response_model=list[InventoryItemOut])
def list_inventory(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    items = session.exec(
        select(InventoryItem)
        .where(InventoryItem.user_id == user_id)
        .order_by(InventoryItem.canonical_name)
    ).all()
    return [_out(i) for i in items]


@router.post("", response_model=InventoryItemOut, status_code=201)
def add_inventory_item(
    body: InventoryItemCreate,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"Invalid status. Choose: {VALID_STATUSES}")

    name = body.canonical_name.lower().strip()
    existing = session.exec(
        select(InventoryItem)
        .where(InventoryItem.user_id == user_id, InventoryItem.canonical_name == name)
    ).first()

    if existing:
        existing.status = body.status
        existing.updated_at = datetime.now(timezone.utc)
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return _out(existing)

    item = InventoryItem(user_id=user_id, canonical_name=name, status=body.status)
    session.add(item)
    session.commit()
    session.refresh(item)
    return _out(item)


@router.patch("/{item_id}", response_model=InventoryItemOut)
def update_inventory_item(
    item_id: str,
    body: InventoryItemUpdate,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"Invalid status. Choose: {VALID_STATUSES}")
    try:
        uid = _uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(InventoryItem, uid)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="Item not found")

    item.status = body.status
    item.updated_at = datetime.now(timezone.utc)
    session.add(item)
    session.commit()
    session.refresh(item)
    return _out(item)


@router.delete("/{item_id}", status_code=204)
def delete_inventory_item(
    item_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(InventoryItem, uid)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="Item not found")

    session.delete(item)
    session.commit()


def _out(item: InventoryItem) -> InventoryItemOut:
    return InventoryItemOut(
        id=str(item.id),
        canonical_name=item.canonical_name,
        status=item.status,
        updated_at=item.updated_at.isoformat(),
    )
