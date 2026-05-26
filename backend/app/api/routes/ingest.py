from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.ingestion.platform_detector import detect_platform, UnsupportedPlatformError
from app.services.ingestion.tiktok_oembed import fetch_tiktok_oembed
from app.services.ai.recipe_extractor import extract_recipe

router = APIRouter()


class IngestLinkRequest(BaseModel):
    url: str


class IngestLinkResponse(BaseModel):
    status: str
    platform: str | None = None
    dish_name: str | None = None
    creator_name: str | None = None
    source_url: str | None = None
    thumbnail_url: str | None = None
    ingredient_count: int = 0
    confidence: float = 0.0
    raw_caption: str | None = None


@router.post("/link", response_model=IngestLinkResponse)
async def ingest_link(request: IngestLinkRequest):
    try:
        platform = detect_platform(request.url)
    except UnsupportedPlatformError as e:
        raise HTTPException(status_code=422, detail=str(e))

    if platform == "tiktok":
        raw = await fetch_tiktok_oembed(request.url)
    else:
        raise HTTPException(status_code=422, detail=f"Platform '{platform}' not yet supported")

    if not raw.caption_text:
        return IngestLinkResponse(
            status="needs_manual_review",
            platform=platform,
            source_url=request.url,
            confidence=0.0,
        )

    recipe = await extract_recipe(raw.caption_text)

    if recipe.confidence < 0.3:
        return IngestLinkResponse(
            status="needs_manual_review",
            platform=platform,
            source_url=request.url,
            raw_caption=raw.caption_text,
            confidence=recipe.confidence,
        )

    return IngestLinkResponse(
        status="success",
        platform=platform,
        dish_name=recipe.dish_name,
        creator_name=raw.creator_name,
        source_url=request.url,
        thumbnail_url=raw.thumbnail_url,
        ingredient_count=len(recipe.ingredients),
        confidence=recipe.confidence,
    )
