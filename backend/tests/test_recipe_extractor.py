"""
Tests for recipe_extractor.py.

When no API key is set, the fake extractor runs — that is what we test here.
Real LLM integration tests belong in tests/integration/ (not run in CI).
"""
import pytest
from app.services.ai.recipe_extractor import extract_recipe, RecipeDraft

NOODLE_CAPTION = """10 MINUTE PEANUT BUTTER + CHILLI CRISP NOODLES 🤤
2 tbsp crunchy peanut butter
1 tbsp minced garlic
2 portions noodles of choice
get all your ingredients in a frying pan, then heat your oil."""

EMPTY_CAPTION = ""

HASHTAG_ONLY = "#fyp #food #cooking"


@pytest.mark.asyncio
async def test_extract_noodle_recipe_returns_draft(monkeypatch):
    monkeypatch.setattr("app.services.ai.recipe_extractor.settings.anthropic_api_key", "")
    result = await extract_recipe(NOODLE_CAPTION)
    assert isinstance(result, RecipeDraft)
    assert result.confidence > 0.0
    assert result.dish_name is not None


@pytest.mark.asyncio
async def test_extract_empty_caption_returns_low_confidence(monkeypatch):
    monkeypatch.setattr("app.services.ai.recipe_extractor.settings.anthropic_api_key", "")
    result = await extract_recipe(EMPTY_CAPTION)
    assert result.confidence == 0.0


@pytest.mark.asyncio
async def test_extract_hashtag_only_returns_draft(monkeypatch):
    monkeypatch.setattr("app.services.ai.recipe_extractor.settings.anthropic_api_key", "")
    result = await extract_recipe(HASHTAG_ONLY)
    assert isinstance(result, RecipeDraft)
