"""
Inventory matching — compares recipe ingredients against the user's pantry.
"""
from sqlmodel import Session, select
from app.models import InventoryItem

# Statuses that count as "available" — won't be added to the grocery list
AVAILABLE_STATUSES = {"in_stock", "low", "always_have"}


def get_available_canonical_names(session: Session) -> set[str]:
    """Returns the set of canonical ingredient names that are currently available."""
    items = session.exec(
        select(InventoryItem).where(InventoryItem.status.in_(AVAILABLE_STATUSES))
    ).all()
    return {item.canonical_name.lower() for item in items}


def find_missing(ingredient_names: list[str], session: Session) -> list[str]:
    """
    Given a list of canonical ingredient names needed for a recipe,
    returns the subset that are missing from inventory.
    """
    available = get_available_canonical_names(session)
    return [name for name in ingredient_names if name.lower() not in available]
