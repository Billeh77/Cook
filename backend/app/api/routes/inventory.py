from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import InventoryItem

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
def list_inventory(session: Session = Depends(get_session)):
    items = session.exec(select(InventoryItem).order_by(InventoryItem.canonical_name)).all()
    return [
        InventoryItemOut(
            id=str(i.id),
            canonical_name=i.canonical_name,
            status=i.status,
            updated_at=i.updated_at.isoformat(),
        )
        for i in items
    ]


@router.post("", response_model=InventoryItemOut, status_code=201)
def add_inventory_item(body: InventoryItemCreate, session: Session = Depends(get_session)):
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"Invalid status. Choose from: {VALID_STATUSES}")

    # Upsert by canonical_name
    existing = session.exec(
        select(InventoryItem).where(InventoryItem.canonical_name == body.canonical_name.lower())
    ).first()

    if existing:
        existing.status = body.status
        from datetime import datetime, timezone
        existing.updated_at = datetime.now(timezone.utc)
        session.add(existing)
        session.commit()
        session.refresh(existing)
        item = existing
    else:
        item = InventoryItem(canonical_name=body.canonical_name.lower(), status=body.status)
        session.add(item)
        session.commit()
        session.refresh(item)

    return InventoryItemOut(
        id=str(item.id),
        canonical_name=item.canonical_name,
        status=item.status,
        updated_at=item.updated_at.isoformat(),
    )


@router.patch("/{item_id}", response_model=InventoryItemOut)
def update_inventory_item(item_id: str, body: InventoryItemUpdate, session: Session = Depends(get_session)):
    import uuid
    if body.status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail=f"Invalid status. Choose from: {VALID_STATUSES}")
    try:
        uid = uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(InventoryItem, uid)
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    item.status = body.status
    from datetime import datetime, timezone
    item.updated_at = datetime.now(timezone.utc)
    session.add(item)
    session.commit()
    session.refresh(item)

    return InventoryItemOut(
        id=str(item.id),
        canonical_name=item.canonical_name,
        status=item.status,
        updated_at=item.updated_at.isoformat(),
    )


@router.delete("/{item_id}", status_code=204)
def delete_inventory_item(item_id: str, session: Session = Depends(get_session)):
    import uuid
    try:
        uid = uuid.UUID(item_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid item ID")

    item = session.get(InventoryItem, uid)
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found")

    session.delete(item)
    session.commit()
