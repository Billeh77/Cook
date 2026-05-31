from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select, func

from app.db import get_session
from app.models import CookingLog, PlannedMeal, Recipe, InventoryItem
from app.api.dependencies import get_current_user

router = APIRouter()


class KitchenStatsOut(BaseModel):
    # This week
    recipes_cooked_this_week: int
    servings_this_week: int
    # Planner
    planned_count: int
    # Library
    saved_recipes: int
    # Pantry
    pantry_items: int
    # All time
    total_cooked_all_time: int


@router.get("", response_model=KitchenStatsOut)
def get_stats(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    # Logs this week
    weekly_logs = session.exec(
        select(CookingLog).where(
            CookingLog.user_id == user_id,
            CookingLog.cooked_at >= week_ago,
        )
    ).all()

    recipes_cooked_this_week = len(weekly_logs)
    servings_this_week = sum(l.servings for l in weekly_logs)

    # All-time logs
    total_cooked_all_time = session.exec(
        select(func.count(CookingLog.id)).where(CookingLog.user_id == user_id)
    ).one()

    # Planner
    planned_count = session.exec(
        select(func.count(PlannedMeal.id)).where(PlannedMeal.user_id == user_id)
    ).one()

    # Saved recipes
    saved_recipes = session.exec(
        select(func.count(Recipe.id)).where(Recipe.user_id == user_id)
    ).one()

    # Pantry items (not out of stock)
    pantry_items = session.exec(
        select(func.count(InventoryItem.id)).where(
            InventoryItem.user_id == user_id,
            InventoryItem.status != "out_of_stock",
        )
    ).one()

    return KitchenStatsOut(
        recipes_cooked_this_week=recipes_cooked_this_week,
        servings_this_week=servings_this_week,
        planned_count=planned_count,
        saved_recipes=saved_recipes,
        pantry_items=pantry_items,
        total_cooked_all_time=total_cooked_all_time,
    )
