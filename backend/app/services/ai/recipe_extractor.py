"""
Single-pass recipe extraction, normalization, and instruction parsing.

One LLM call returns everything: dish name, ingredients (raw + normalized),
categories, quantities, and cooking steps if present in the caption.

Cook is a grocery and inventory management app. The canonical_name field is
the key used to match ingredients against a user's pantry inventory and to
build grocery lists. Consistency in canonical_name is critical.
"""
import json
from pydantic import BaseModel
from app.config import settings


# ── Output models ─────────────────────────────────────────────────────────────

class ExtractedIngredient(BaseModel):
    raw_text: str           # exact text from caption, including quantity and descriptors
    canonical_name: str     # normalized: lowercase, English, singular base ingredient only
    quantity: str | None    # numeric portion only, e.g. "2", "½", "100"
    unit: str | None        # "g", "tbsp", "cups", "cloves", "sprigs", etc. — null if unitless
    category: str           # produce | dairy | meat | pantry | spice | grain | other
    notes: str | None       # preparation descriptors only, e.g. "thinly sliced", "freshly cracked"


class RecipeExtraction(BaseModel):
    dish_name: str | None = None
    ingredients: list[ExtractedIngredient] = []
    steps: list[str] = []   # cooking instructions if present in caption; empty list if not
    confidence: float = 0.0


# ── Prompt ────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are the recipe extraction engine for Cook, a personal grocery and pantry \
management app. Users share TikTok and Instagram cooking videos with the app. \
Your job is to extract structured recipe data from the video caption.

The data you produce powers three features:
1. Saved recipe cards — dish name, creator, ingredient list, optional steps
2. Inventory matching — canonical_name is matched against the user's pantry \
   (e.g. "pecorino romano" in pantry → not needed on grocery list)
3. Grocery list generation — missing canonical_names become shopping items

Because canonical_name drives inventory and grocery logic, consistency is \
critical. Follow these normalization rules exactly:

CANONICAL_NAME rules:
- Lowercase English, singular form of the base ingredient only
- Strip all quantities, units, brands, preparation methods, and descriptors
- Translate non-English ingredient names to their standard English equivalent
- Use the most recognizable common name (prefer "mozzarella" over "fresh \
  mozzarella cheese")
- Keep compound names when meaningful as a unit \
  ("olive oil" not "oil", "soy sauce" not "sauce")

Examples:
  "100g guanciale"               → "guanciale"
  "Pecorino Romano 4 spoonfuls"  → "pecorino romano"
  "½ red onion, thinly sliced"   → "red onion"
  "Black pepper, freshly cracked"→ "black pepper"
  "80g of your fav pasta"        → "pasta"
  "Pasta water"                  → "pasta water"
  "fio de azeite de oliva"       → "olive oil"
  "muçarela ralada"              → "mozzarella"
  "cebolinha"                    → "chives"
  "a touch of Parmigiano Reggiano" → "parmigiano reggiano"

STEPS rules:
- Only include steps if the caption actually contains cooking instructions
- Extract them as clean, concise sentences
- Preserve the original order
- If the caption has no instructions, return an empty array []

CONFIDENCE:
- 1.0 = full recipe with quantities and most ingredients clearly listed
- 0.7 = recipe found but some ingredients vague or quantities missing
- 0.4 = only a partial ingredient list
- 0.0 = caption contains no recipe

Return ONLY valid JSON. No explanation, no markdown, no code fences.\
"""

SCHEMA = """\
{
  "dish_name": "string or null",
  "confidence": 0.0,
  "ingredients": [
    {
      "raw_text": "exact text from caption including quantity and descriptors",
      "canonical_name": "normalized lowercase english base ingredient",
      "quantity": "numeric string or null",
      "unit": "unit string or null",
      "category": "produce|dairy|meat|pantry|spice|grain|other",
      "notes": "prep descriptors only, or null"
    }
  ],
  "steps": ["step 1", "step 2"]
}\
"""


# ── Main function ─────────────────────────────────────────────────────────────

async def extract_recipe(caption_text: str) -> RecipeExtraction:
    """
    Extracts, normalizes, and structures a full recipe from a caption in one
    LLM call. Falls back to a deterministic stub when no API key is configured.
    """
    if not settings.anthropic_api_key:
        return _fake_extract(caption_text)

    import anthropic
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    user_prompt = (
        f"Extract the recipe from this cooking video caption.\n\n"
        f"Return JSON matching this schema:\n{SCHEMA}\n\n"
        f"Caption:\n{caption_text}"
    )

    try:
        message = await client.messages.create(
            model="claude-opus-4-5",
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )

        raw = message.content[0].text.strip()

        # Strip markdown code fences if the model wrapped the JSON
        if raw.startswith("```"):
            raw = raw.split("```", 2)[1]
            if raw.startswith("json"):
                raw = raw[4:]
            raw = raw.strip()
        if raw.endswith("```"):
            raw = raw[:-3].strip()

        data = json.loads(raw)
        return RecipeExtraction.model_validate(data)

    except json.JSONDecodeError as e:
        print(f"[recipe_extractor] JSON parse error: {e}")
        return RecipeExtraction(confidence=0.0)
    except Exception as e:
        print(f"[recipe_extractor] error: {type(e).__name__}: {e}")
        raise


# ── Dev fallback ──────────────────────────────────────────────────────────────

def _fake_extract(caption_text: str) -> RecipeExtraction:
    """Deterministic stub used when ANTHROPIC_API_KEY is not set."""
    text_lower = caption_text.lower()
    if "noodle" in text_lower or "pasta" in text_lower:
        return RecipeExtraction(
            dish_name="Noodle Dish (no API key)",
            ingredients=[
                ExtractedIngredient(raw_text="noodles", canonical_name="noodle",
                                    quantity="2", unit="portions", category="grain", notes=None),
                ExtractedIngredient(raw_text="peanut butter", canonical_name="peanut butter",
                                    quantity="2", unit="tbsp", category="pantry", notes=None),
            ],
            steps=["Cook noodles per packet instructions.", "Mix sauce.", "Combine and serve."],
            confidence=0.5,
        )
    if caption_text.strip():
        return RecipeExtraction(dish_name="Unknown dish (no API key)", confidence=0.2)
    return RecipeExtraction(confidence=0.0)
