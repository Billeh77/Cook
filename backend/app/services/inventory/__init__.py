"""
Inventory matching — compares recipe ingredients against the user's pantry.
"""
from sqlmodel import Session, select
from app.models import InventoryItem

# Statuses that count as "available" — won't be added to the grocery list
AVAILABLE_STATUSES = {"in_stock", "low", "always_have"}


def get_available_canonical_names(session: Session, user_id: str) -> set[str]:
    """Returns the set of canonical ingredient names that are currently available for a user."""
    items = session.exec(
        select(InventoryItem).where(
            InventoryItem.user_id == user_id,
            InventoryItem.status.in_(AVAILABLE_STATUSES),
        )
    ).all()
    return {item.canonical_name.lower() for item in items}


def find_missing(ingredient_names: list[str], session: Session, user_id: str) -> list[str]:
    """
    Given a list of canonical ingredient names needed for a recipe,
    returns the subset that are missing from the user's inventory.
    """
    available = get_available_canonical_names(session, user_id)
    return [name for name in ingredient_names if name.lower() not in available]
