import uuid as _uuid
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import PlannedMeal, Recipe, Ingredient
from app.api.dependencies import get_current_user
from app.services.inventory import find_missing

router = APIRouter()


# ── Response models ────────────────────────────────────────────────────────────

class PlannedMealOut(BaseModel):
    id: str
    recipe_id: str
    dish_name: str
    thumbnail_url: str | None
    platform: str
    added_at: str
    missing_count: int
    missing_ingredients: list[str]   # up to 3 canonical names


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[PlannedMealOut])
def list_planned_meals(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    meals = session.exec(
        select(PlannedMeal)
        .where(PlannedMeal.user_id == user_id)
        .order_by(PlannedMeal.added_at.desc())
    ).all()
    result = []
    for m in meals:
        recipe = session.get(Recipe, m.recipe_id)
        if not recipe:
            continue
        ingredients = session.exec(
            select(Ingredient).where(Ingredient.recipe_id == m.recipe_id)
        ).all()
        missing = find_missing([i.canonical_name for i in ingredients], session, user_id)
        result.append(PlannedMealOut(
            id=str(m.id),
            recipe_id=str(m.recipe_id),
            dish_name=recipe.dish_name,
            thumbnail_url=recipe.thumbnail_url,
            platform=recipe.platform,
            added_at=m.added_at.isoformat(),
            missing_count=len(missing),
            missing_ingredients=missing[:3],
        ))
    return result


@router.post("/{recipe_id}", status_code=204)
def add_to_planner(
    recipe_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid recipe ID")
    recipe = session.get(Recipe, uid)
    if not recipe or recipe.user_id != user_id:
        raise HTTPException(status_code=404, detail="Recipe not found")

    existing = session.exec(
        select(PlannedMeal).where(
            PlannedMeal.user_id == user_id,
            PlannedMeal.recipe_id == uid,
        )
    ).first()
    if not existing:
        session.add(PlannedMeal(user_id=user_id, recipe_id=uid))
        session.commit()


@router.delete("/{recipe_id}", status_code=204)
def remove_from_planner(
    recipe_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid recipe ID")
    meal = session.exec(
        select(PlannedMeal).where(
            PlannedMeal.user_id == user_id,
            PlannedMeal.recipe_id == uid,
        )
    ).first()
    if meal:
        session.delete(meal)
        session.commit()
