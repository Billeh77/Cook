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

_CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "produce": ["apple", "banana", "lemon", "lime", "tomato", "lettuce", "spinach",
                "kale", "carrot", "celery", "onion", "garlic", "potato", "pepper",
                "zucchini", "cucumber", "avocado", "strawberry", "blueberry", "mango",
                "mushroom", "ginger", "cilantro", "parsley", "basil", "mint",
                "scallion", "shallot", "leek", "eggplant", "asparagus", "arugula",
                "broccoli", "cauliflower", "beet", "fennel", "corn", "pea", "herb",
                "orange", "grape", "pineapple", "pear", "peach", "plum", "cherry",
                "radish", "turnip", "artichoke", "bok choy", "cabbage", "romaine"],
    "dairy":   ["milk", "cream", "butter", "cheese", "yogurt", "sour cream",
                "mozzarella", "parmesan", "cheddar", "ricotta", "feta", "brie",
                "half and half", "mascarpone", "kefir", "ghee", "gouda", "provolone"],
    "meat":    ["chicken", "beef", "pork", "turkey", "lamb", "salmon", "tuna",
                "shrimp", "bacon", "sausage", "steak", "fish", "seafood", "crab",
                "lobster", "scallop", "prosciutto", "pancetta", "salami", "ham",
                "duck", "veal", "anchovy", "sardine", "tilapia", "cod", "halibut",
                "ground beef", "ground turkey", "ground pork", "mahi", "clam", "oyster"],
    "grain":   ["flour", "rice", "pasta", "bread", "oat", "quinoa", "barley",
                "tortilla", "noodle", "spaghetti", "penne", "breadcrumb", "panko",
                "cracker", "couscous", "polenta", "rye", "wheat", "cereal", "cornmeal"],
    "spice":   ["salt", "pepper", "cumin", "coriander", "paprika", "cayenne",
                "turmeric", "cinnamon", "nutmeg", "clove", "oregano", "thyme",
                "rosemary", "bay leaf", "chili powder", "curry", "garam masala",
                "garlic powder", "onion powder", "red pepper flake", "saffron",
                "seasoning", "spice", "allspice", "cardamom", "dried"],
    "pantry":  ["oil", "vinegar", "soy sauce", "fish sauce", "oyster sauce",
                "hot sauce", "ketchup", "mustard", "mayonnaise", "honey", "maple",
                "sugar", "baking powder", "baking soda", "vanilla", "chocolate",
                "cocoa", "coconut milk", "broth", "stock", "tomato paste",
                "canned", "beans", "lentil", "chickpea", "tahini", "peanut butter",
                "almond butter", "jam", "wine", "miso", "worcestershire", "sauce",
                "olive oil", "sesame oil", "coconut oil", "molasses", "syrup"],
}


def _classify_category(name: str) -> str:
    lower = name.lower()
    for category, keywords in _CATEGORY_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            return category
    return "other"


class InventoryItemCreate(BaseModel):
    canonical_name: str
    status: str = "in_stock"


class InventoryItemUpdate(BaseModel):
    status: str


class InventoryItemOut(BaseModel):
    id: str
    canonical_name: str
    status: str
    category: str
    updated_at: str


@router.get("", response_model=list[InventoryItemOut])
def list_inventory(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    items = session.exec(
        select(InventoryItem)
        .where(InventoryItem.user_id == user_id)
        .order_by(InventoryItem.category, InventoryItem.canonical_name)
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
        category=_classify_category(item.canonical_name),
        updated_at=item.updated_at.isoformat(),
    )
