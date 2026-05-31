from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select, func
from sqlalchemy import distinct

from app.db import get_session
from app.models import CookingLog, PlannedMeal, Recipe, InventoryItem, Ingredient
from app.api.dependencies import get_current_user

router = APIRouter()


class KitchenStatsOut(BaseModel):
    # ── This week ──────────────────────────────────────────────────────────────
    meals_cooked_this_week: int         # total servings this week
    recipes_cooked_this_week: int       # distinct cooking sessions this week
    planned_count: int                  # meals currently in planner
    ingredients_used_this_week: int     # sum of ingredient counts for this week's cooks
    money_spent_this_week: float        # placeholder — always 0.0 until receipt tracking

    # ── Your kitchen ───────────────────────────────────────────────────────────
    pantry_items: int                   # inventory items that are in_stock / low / always_have
    unique_recipes_cooked: int          # distinct recipes ever cooked
    total_cooked_all_time: int          # total cooking sessions (including repeats)
    saved_recipes: int                  # all saved recipes


@router.get("", response_model=KitchenStatsOut)
def get_stats(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    # ── This week ──────────────────────────────────────────────────────────────
    weekly_logs = session.exec(
        select(CookingLog).where(
            CookingLog.user_id == user_id,
            CookingLog.cooked_at >= week_ago,
        )
    ).all()

    recipes_cooked_this_week = len(weekly_logs)
    meals_cooked_this_week = sum(log.servings for log in weekly_logs)

    # Ingredients used = sum of each recipe's ingredient count for every cook this week
    ingredients_used_this_week = 0
    for log in weekly_logs:
        count = session.exec(
            select(func.count(Ingredient.id)).where(Ingredient.recipe_id == log.recipe_id)
        ).one()
        ingredients_used_this_week += count

    # ── Planner ────────────────────────────────────────────────────────────────
    planned_count = session.exec(
        select(func.count(PlannedMeal.id)).where(PlannedMeal.user_id == user_id)
    ).one()

    # ── Your kitchen ───────────────────────────────────────────────────────────
    pantry_items = session.exec(
        select(func.count(InventoryItem.id)).where(
            InventoryItem.user_id == user_id,
            InventoryItem.status != "out_of_stock",
        )
    ).one()

    unique_recipes_cooked = session.exec(
        select(func.count(distinct(CookingLog.recipe_id))).where(
            CookingLog.user_id == user_id
        )
    ).one()

    total_cooked_all_time = session.exec(
        select(func.count(CookingLog.id)).where(CookingLog.user_id == user_id)
    ).one()

    saved_recipes = session.exec(
        select(func.count(Recipe.id)).where(Recipe.user_id == user_id)
    ).one()

    return KitchenStatsOut(
        meals_cooked_this_week=meals_cooked_this_week,
        recipes_cooked_this_week=recipes_cooked_this_week,
        planned_count=planned_count,
        ingredients_used_this_week=ingredients_used_this_week,
        money_spent_this_week=0.0,
        pantry_items=pantry_items,
        unique_recipes_cooked=unique_recipes_cooked,
        total_cooked_all_time=total_cooked_all_time,
        saved_recipes=saved_recipes,
    )
