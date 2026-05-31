import uuid as _uuid
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import Recipe, Ingredient, GroceryListItem, AlbumRecipe
from app.api.dependencies import get_current_user
from app.services.inventory import find_missing

router = APIRouter()


# ── Response models ────────────────────────────────────────────────────────────

class IngredientOut(BaseModel):
    id: str
    raw_text: str
    canonical_name: str
    quantity: str | None
    unit: str | None
    notes: str | None
    category: str


class RecipeOut(BaseModel):
    id: str
    dish_name: str
    creator_name: str | None
    source_url: str
    thumbnail_url: str | None
    embed_html: str | None
    platform: str
    confidence: float
    created_at: str
    steps: list[str] = []
    ingredients: list[IngredientOut] = []
    servings: int | None = None
    effort: str | None = None
    time_minutes: int | None = None
    is_batch_prep: bool = False
    protein_level: str | None = None
    calorie_level: str | None = None
    protein_source: str | None = None
    is_favorited: bool = False


class RecipeListItem(BaseModel):
    id: str
    dish_name: str
    creator_name: str | None
    source_url: str
    thumbnail_url: str | None
    platform: str
    ingredient_count: int
    created_at: str
    servings: int | None = None
    effort: str | None = None
    time_minutes: int | None = None
    is_batch_prep: bool = False
    protein_level: str | None = None
    calorie_level: str | None = None
    protein_source: str | None = None
    is_favorited: bool = False


class CookabilityItem(BaseModel):
    id: str
    dish_name: str
    creator_name: str | None
    source_url: str
    thumbnail_url: str | None
    platform: str
    ingredient_count: int
    created_at: str
    servings: int | None = None
    effort: str | None = None
    time_minutes: int | None = None
    is_batch_prep: bool = False
    protein_level: str | None = None
    calorie_level: str | None = None
    protein_source: str | None = None
    is_favorited: bool = False
    missing_count: int = 0
    missing_ingredients: list[str] = []


class FavoriteRequest(BaseModel):
    is_favorited: bool


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[RecipeListItem])
def list_recipes(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    recipes = session.exec(
        select(Recipe).where(Recipe.user_id == user_id).order_by(Recipe.created_at.desc())
    ).all()
    result = []
    for r in recipes:
        count = len(session.exec(select(Ingredient).where(Ingredient.recipe_id == r.id)).all())
        result.append(_list_item(r, count))
    return result


@router.get("/cookability", response_model=list[CookabilityItem])
def get_cookability(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    """All recipes sorted by ascending missing-ingredient count."""
    recipes = session.exec(
        select(Recipe).where(Recipe.user_id == user_id).order_by(Recipe.created_at.desc())
    ).all()

    result = []
    for r in recipes:
        ingredients = session.exec(
            select(Ingredient).where(Ingredient.recipe_id == r.id)
        ).all()
        missing = find_missing([i.canonical_name for i in ingredients], session, user_id)
        result.append(CookabilityItem(
            id=str(r.id),
            dish_name=r.dish_name,
            creator_name=r.creator_name,
            source_url=r.source_url,
            thumbnail_url=r.thumbnail_url,
            platform=r.platform,
            ingredient_count=len(ingredients),
            created_at=r.created_at.isoformat(),
            servings=r.servings,
            effort=r.effort,
            time_minutes=r.time_minutes,
            is_batch_prep=r.is_batch_prep or False,
            protein_level=r.protein_level,
            calorie_level=r.calorie_level,
            protein_source=r.protein_source,
            is_favorited=r.is_favorited or False,
            missing_count=len(missing),
            missing_ingredients=missing,
        ))

    result.sort(key=lambda x: x.missing_count)
    return result


@router.get("/{recipe_id}", response_model=RecipeOut)
def get_recipe(
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

    ingredients = session.exec(select(Ingredient).where(Ingredient.recipe_id == uid)).all()

    return RecipeOut(
        id=str(recipe.id),
        dish_name=recipe.dish_name,
        creator_name=recipe.creator_name,
        source_url=recipe.source_url,
        thumbnail_url=recipe.thumbnail_url,
        embed_html=recipe.embed_html,
        platform=recipe.platform,
        confidence=recipe.confidence,
        created_at=recipe.created_at.isoformat(),
        steps=recipe.steps or [],
        ingredients=[
            IngredientOut(
                id=str(i.id), raw_text=i.raw_text, canonical_name=i.canonical_name,
                quantity=i.quantity, unit=i.unit, notes=i.notes, category=i.category,
            )
            for i in ingredients
        ],
        servings=recipe.servings,
        effort=recipe.effort,
        time_minutes=recipe.time_minutes,
        is_batch_prep=recipe.is_batch_prep or False,
        protein_level=recipe.protein_level,
        calorie_level=recipe.calorie_level,
        protein_source=recipe.protein_source,
        is_favorited=recipe.is_favorited or False,
    )


@router.patch("/{recipe_id}/favorite", status_code=204)
def set_favorite(
    recipe_id: str,
    body: FavoriteRequest,
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

    recipe.is_favorited = body.is_favorited
    session.add(recipe)
    session.commit()


@router.delete("/{recipe_id}", status_code=204)
def delete_recipe(
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

    for ar in session.exec(select(AlbumRecipe).where(AlbumRecipe.recipe_id == uid)).all():
        session.delete(ar)
    for item in session.exec(select(GroceryListItem).where(GroceryListItem.recipe_id == uid)).all():
        session.delete(item)
    for ing in session.exec(select(Ingredient).where(Ingredient.recipe_id == uid)).all():
        session.delete(ing)
    session.delete(recipe)
    session.commit()


# ── Helper ─────────────────────────────────────────────────────────────────────

def _list_item(r: Recipe, ingredient_count: int) -> RecipeListItem:
    return RecipeListItem(
        id=str(r.id), dish_name=r.dish_name, creator_name=r.creator_name,
        source_url=r.source_url, thumbnail_url=r.thumbnail_url,
        platform=r.platform, ingredient_count=ingredient_count,
        created_at=r.created_at.isoformat(),
        servings=r.servings, effort=r.effort, time_minutes=r.time_minutes,
        is_batch_prep=r.is_batch_prep or False, protein_level=r.protein_level,
        calorie_level=r.calorie_level, protein_source=r.protein_source,
        is_favorited=r.is_favorited or False,
    )
