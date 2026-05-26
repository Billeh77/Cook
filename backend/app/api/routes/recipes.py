from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import Recipe, Ingredient

router = APIRouter()


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
    missing_count: int = 0


class RecipeListItem(BaseModel):
    id: str
    dish_name: str
    creator_name: str | None
    source_url: str
    thumbnail_url: str | None
    platform: str
    ingredient_count: int
    created_at: str


@router.get("", response_model=list[RecipeListItem])
def list_recipes(session: Session = Depends(get_session)):
    recipes = session.exec(select(Recipe).order_by(Recipe.created_at.desc())).all()
    result = []
    for r in recipes:
        count = session.exec(
            select(Ingredient).where(Ingredient.recipe_id == r.id)
        ).all()
        result.append(RecipeListItem(
            id=str(r.id),
            dish_name=r.dish_name,
            creator_name=r.creator_name,
            source_url=r.source_url,
            thumbnail_url=r.thumbnail_url,
            platform=r.platform,
            ingredient_count=len(count),
            created_at=r.created_at.isoformat(),
        ))
    return result


@router.get("/{recipe_id}", response_model=RecipeOut)
def get_recipe(recipe_id: str, session: Session = Depends(get_session)):
    import uuid
    try:
        uid = uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid recipe ID")

    recipe = session.get(Recipe, uid)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    ingredients = session.exec(
        select(Ingredient).where(Ingredient.recipe_id == uid)
    ).all()

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
                id=str(i.id),
                raw_text=i.raw_text,
                canonical_name=i.canonical_name,
                quantity=i.quantity,
                unit=i.unit,
                notes=i.notes,
                category=i.category,
            )
            for i in ingredients
        ],
    )


@router.delete("/{recipe_id}", status_code=204)
def delete_recipe(recipe_id: str, session: Session = Depends(get_session)):
    import uuid
    try:
        uid = uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid recipe ID")

    recipe = session.get(Recipe, uid)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    # Delete ingredients first
    ingredients = session.exec(
        select(Ingredient).where(Ingredient.recipe_id == uid)
    ).all()
    for ing in ingredients:
        session.delete(ing)

    session.delete(recipe)
    session.commit()
