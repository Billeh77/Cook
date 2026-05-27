from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session

from app.db import get_session
from app.models import Recipe, Ingredient
from app.api.dependencies import get_current_user
from app.services.ingestion.platform_detector import detect_platform, UnsupportedPlatformError
from app.services.ingestion.tiktok_oembed import fetch_tiktok_oembed
from app.services.ai.recipe_extractor import extract_recipe

router = APIRouter()


class IngestLinkRequest(BaseModel):
    url: str


class IngredientResponse(BaseModel):
    id: str
    raw_text: str
    canonical_name: str
    quantity: str | None = None
    unit: str | None = None
    notes: str | None = None
    category: str = "other"


class IngestLinkResponse(BaseModel):
    id: str | None = None
    status: str
    platform: str | None = None
    dish_name: str | None = None
    creator_name: str | None = None
    source_url: str | None = None
    thumbnail_url: str | None = None
    confidence: float = 0.0
    raw_caption: str | None = None
    ingredients: list[IngredientResponse] = []


@router.post("/link", response_model=IngestLinkResponse)
async def ingest_link(
    request: IngestLinkRequest,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    # 1. Detect platform
    try:
        platform = detect_platform(request.url)
    except UnsupportedPlatformError as e:
        raise HTTPException(status_code=422, detail=str(e))

    # 2. Fetch raw caption
    if platform == "tiktok":
        raw = await fetch_tiktok_oembed(request.url)
    else:
        raise HTTPException(status_code=422, detail=f"Platform '{platform}' not yet supported")

    if not raw.caption_text:
        return IngestLinkResponse(
            status="needs_manual_review",
            platform=platform,
            source_url=request.url,
        )

    # 3. Single LLM call — extract + normalize in one shot
    extraction = await extract_recipe(raw.caption_text)

    if extraction.confidence < 0.3:
        return IngestLinkResponse(
            status="needs_manual_review",
            platform=platform,
            source_url=request.url,
            raw_caption=raw.caption_text,
            confidence=extraction.confidence,
        )

    # 4. Save recipe
    db_recipe = Recipe(
        user_id=user_id,
        dish_name=extraction.dish_name or "Unknown Dish",
        creator_name=raw.creator_name,
        source_url=request.url,
        thumbnail_url=raw.thumbnail_url,
        embed_html=raw.embed_html,
        platform=platform,
        raw_caption=raw.caption_text,
        steps=extraction.steps or [],
        confidence=extraction.confidence,
        servings=extraction.servings,
        effort=extraction.effort,
        time_minutes=extraction.time_minutes,
        is_batch_prep=extraction.is_batch_prep,
        protein_level=extraction.protein_level,
        calorie_level=extraction.calorie_level,
        protein_source=extraction.protein_source,
    )
    session.add(db_recipe)
    session.flush()

    # 5. Save ingredients
    db_ingredients: list[Ingredient] = []
    for ing in extraction.ingredients:
        db_ing = Ingredient(
            recipe_id=db_recipe.id,
            raw_text=ing.raw_text,
            canonical_name=ing.canonical_name,
            quantity=ing.quantity,
            unit=ing.unit,
            notes=ing.notes,
            category=ing.category,
        )
        session.add(db_ing)
        db_ingredients.append(db_ing)

    session.commit()
    session.refresh(db_recipe)

    return IngestLinkResponse(
        id=str(db_recipe.id),
        status="success",
        platform=platform,
        dish_name=db_recipe.dish_name,
        creator_name=db_recipe.creator_name,
        source_url=db_recipe.source_url,
        thumbnail_url=db_recipe.thumbnail_url,
        confidence=db_recipe.confidence,
        raw_caption=db_recipe.raw_caption,
        ingredients=[
            IngredientResponse(
                id=str(i.id),
                raw_text=i.raw_text,
                canonical_name=i.canonical_name,
                quantity=i.quantity,
                unit=i.unit,
                notes=i.notes,
                category=i.category,
            )
            for i in db_ingredients
        ],
    )
