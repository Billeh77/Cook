import json
import os
from pydantic import BaseModel

from app.config import settings


class IngredientDraft(BaseModel):
    raw_text: str
    quantity: str | None = None
    unit: str | None = None
    notes: str | None = None


class RecipeDraft(BaseModel):
    dish_name: str | None = None
    ingredients: list[IngredientDraft] = []
    steps: list[str] = []
    confidence: float = 0.0


SYSTEM_PROMPT = """You are a recipe extraction assistant. Your job is to extract structured recipe data from social media cooking video captions.

Rules:
- Return ONLY valid JSON. No explanation, no markdown, no code fences.
- If the caption does not contain a recipe, return {"dish_name": null, "ingredients": [], "steps": [], "confidence": 0.0}
- confidence: 1.0 = full recipe with quantities, 0.5 = partial recipe, 0.0 = no recipe detected
- Preserve original quantities and units exactly as written in the caption
- Include all ingredients mentioned, even if quantities are missing
- Steps should be clean sentences derived from the caption instructions"""

USER_PROMPT_TEMPLATE = """Extract the recipe from this cooking video caption. Return JSON matching this exact schema:

{{
  "dish_name": "string or null",
  "ingredients": [
    {{
      "raw_text": "exact text from caption",
      "quantity": "number as string or null",
      "unit": "unit string or null",
      "notes": "descriptors like crunchy, fresh, minced or null"
    }}
  ],
  "steps": ["step 1", "step 2"],
  "confidence": 0.0
}}

Caption:
{caption_text}"""


async def extract_recipe(caption_text: str) -> RecipeDraft:
    """
    Sends caption text to Claude and returns a structured RecipeDraft.
    Falls back to empty RecipeDraft with confidence 0.0 on any error.
    """
    if not settings.anthropic_api_key:
        # Development fallback: return a fake recipe so the pipeline can be tested
        return _fake_extract(caption_text)

    try:
        import anthropic

        client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        message = await client.messages.create(
            model="claude-3-5-haiku-20241022",
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": USER_PROMPT_TEMPLATE.format(caption_text=caption_text),
                }
            ],
        )

        raw_json = message.content[0].text.strip()
        data = json.loads(raw_json)
        return RecipeDraft.model_validate(data)

    except json.JSONDecodeError as e:
        print(f"[recipe_extractor] JSON parse error: {e}")
        return RecipeDraft(confidence=0.0)
    except Exception as e:
        # Re-raise so the route returns a 500 — a misconfigured API key or bad model ID
        # should be loud, not silently collapsed into needs_manual_review.
        print(f"[recipe_extractor] error: {type(e).__name__}: {e}")
        raise


def _fake_extract(caption_text: str) -> RecipeDraft:
    """
    Deterministic fake extractor for development/testing when no API key is set.
    Detects a few keywords to return a plausible stub.
    """
    text_lower = caption_text.lower()
    if "noodle" in text_lower or "pasta" in text_lower:
        return RecipeDraft(
            dish_name="Noodle Dish (fake extraction)",
            ingredients=[
                IngredientDraft(raw_text="noodles", quantity="2", unit="portions"),
                IngredientDraft(raw_text="peanut butter", quantity="2", unit="tbsp"),
            ],
            steps=["Cook noodles", "Mix sauce", "Combine"],
            confidence=0.5,
        )
    if caption_text.strip():
        return RecipeDraft(
            dish_name="Unknown Dish (fake extraction)",
            ingredients=[],
            steps=[],
            confidence=0.2,
        )
    return RecipeDraft(confidence=0.0)
