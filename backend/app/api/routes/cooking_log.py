import uuid as _uuid
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import CookingLog, PlannedMeal, Recipe
from app.api.dependencies import get_current_user

router = APIRouter()


# ── Request / response models ──────────────────────────────────────────────────

class CookBody(BaseModel):
    servings: int = 1
    remove_from_planner: bool = True


class CookingLogOut(BaseModel):
    id: str
    recipe_id: str
    dish_name: str
    cooked_at: str
    servings: int
    thumbnail_url: str | None = None


class CookingHistoryPage(BaseModel):
    entries: list[CookingLogOut]
    has_more: bool


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=CookingHistoryPage)
def get_cooking_history(
    days: int = Query(7, ge=1, description="Return entries from the last N days"),
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    logs = session.exec(
        select(CookingLog)
        .where(CookingLog.user_id == user_id)
        .where(CookingLog.cooked_at >= cutoff)
        .order_by(CookingLog.cooked_at.desc())
    ).all()

    # Check whether any entries exist before the current window
    has_more = session.exec(
        select(CookingLog)
        .where(CookingLog.user_id == user_id)
        .where(CookingLog.cooked_at < cutoff)
    ).first() is not None

    result = []
    for l in logs:
        recipe = session.get(Recipe, l.recipe_id)
        result.append(CookingLogOut(
            id=str(l.id),
            recipe_id=str(l.recipe_id),
            dish_name=l.dish_name,
            cooked_at=l.cooked_at.isoformat(),
            servings=l.servings,
            thumbnail_url=recipe.thumbnail_url if recipe else None,
        ))

    return CookingHistoryPage(entries=result, has_more=has_more)


@router.post("/{recipe_id}", response_model=CookingLogOut, status_code=201)
def log_cooked(
    recipe_id: str,
    body: CookBody,
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

    log = CookingLog(
        user_id=user_id,
        recipe_id=uid,
        dish_name=recipe.dish_name,
        servings=max(1, body.servings),
    )
    session.add(log)

    if body.remove_from_planner:
        planned = session.exec(
            select(PlannedMeal).where(
                PlannedMeal.user_id == user_id,
                PlannedMeal.recipe_id == uid,
            )
        ).first()
        if planned:
            session.delete(planned)

    session.commit()
    session.refresh(log)
    return CookingLogOut(
        id=str(log.id),
        recipe_id=str(log.recipe_id),
        dish_name=log.dish_name,
        cooked_at=log.cooked_at.isoformat(),
        servings=log.servings,
        thumbnail_url=recipe.thumbnail_url,
    )
