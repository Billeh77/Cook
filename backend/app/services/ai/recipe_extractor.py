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
    steps: list[str] = []       # cooking instructions if present; empty list if not
    confidence: float = 0.0
    # Tags — inferred from recipe content
    meal_type: str | None = None           # "breakfast" | "lunch" | "dinner" | "dessert"
    servings: int | None = None             # number of servings the recipe makes
    effort: str | None = None              # "easy" | "medium" | "hard"
    time_minutes: int | None = None        # total estimated time in minutes
    is_batch_prep: bool = False            # true if recipe is a weekly batch / meal-prep
    protein_level: str | None = None      # "high" | "medium" | "low"
    calorie_level: str | None = None      # "low" | "medium" | "high" — per serving
    protein_source: str | None = None    # "chicken" | "beef" | "pork" | "fish" | "seafood" | "eggs" | "lamb" | "turkey" | "vegan" | "vegetarian"
    cuisine: str | None = None           # e.g. "italian" | "mexican" | "chinese" | "japanese" | "thai" | "indian" | "mediterranean" | "middle eastern" | "french" | "american" | "korean" | "greek" | "spanish" | "vietnamese" | "moroccan"


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

TAGS — infer these from the recipe content:
- meal_type: "breakfast" | "lunch" | "dinner" | "dessert" — the primary occasion this meal is \
  intended for. Use "breakfast" for morning foods (eggs, pancakes, oats, smoothies, etc.), \
  "lunch" for lighter midday meals (salads, sandwiches, wraps, soups), "dinner" for main evening \
  meals (pasta, steak, roasts, curries, stir-fries), and "dessert" for sweets (cakes, cookies, \
  ice cream, puddings). When ambiguous (e.g. a salad could be lunch or dinner), pick the most \
  likely context. Return null only if genuinely impossible to determine.
- servings: integer — how many people / portions the recipe makes (e.g. 1, 2, 4, 6). \
  Clues: "serves 4", "for 2", large quantities of protein, "whole tray", "weekly prep"
- effort: "easy" | "medium" | "hard" — based on technique complexity and number of steps
- time_minutes: integer — total estimated time including prep and cook (rough estimate is fine)
- is_batch_prep: true if the recipe is clearly intended for weekly meal prep or makes \
  large quantities meant to last several days (e.g. big batch of sauce, full tray of protein)
- protein_level: "high" if main protein is prominent (large cuts of meat, many eggs, legumes \
  as main); "low" if mostly vegetables, grains, or light dishes; "medium" otherwise
- calorie_level: "low" | "medium" | "high" — estimated calories PER SINGLE SERVING. \
  Always divide the total recipe calories by the servings count before deciding. \
  A batch of 8 chicken thighs might be "medium" per serving even if the total is large. \
  low = under 400 kcal/serving, medium = 400–700 kcal/serving, high = over 700 kcal/serving
- protein_source: the primary protein source as a single lowercase label. \
  Use exactly one of: "chicken" | "beef" | "pork" | "fish" | "seafood" | "eggs" | \
  "lamb" | "turkey" | "vegan" | "vegetarian". \
  Use "vegan" if the recipe contains no animal products at all. \
  Use "vegetarian" if it uses dairy or eggs but no meat or fish. \
  Use null if the protein source is unclear or genuinely mixed.
- cuisine: the primary cuisine of the dish, if clearly identifiable. \
  Use exactly one of: "italian" | "mexican" | "chinese" | "japanese" | "thai" | \
  "indian" | "mediterranean" | "middle eastern" | "french" | "american" | "korean" | \
  "greek" | "spanish" | "vietnamese" | "moroccan" | "caribbean" | "latin american" | \
  "turkish" | "persian". \
  Return null for generic, fusion, or unclear dishes — null is the correct answer for \
  things like a basic smoothie, a generic salad, mac and cheese, or any dish that does \
  not clearly belong to one cuisine. Only assign a cuisine when it is obvious and unambiguous.

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
  "meal_type": "breakfast|lunch|dinner|dessert or null",
  "servings": null,
  "effort": "easy|medium|hard or null",
  "time_minutes": null,
  "is_batch_prep": false,
  "protein_level": "high|medium|low or null",
  "calorie_level": "low|medium|high or null",
  "protein_source": "chicken|beef|pork|fish|seafood|eggs|lamb|turkey|vegan|vegetarian or null",
  "cuisine": "italian|mexican|chinese|japanese|thai|indian|mediterranean|middle eastern|french|american|korean|greek|spanish|vietnamese|moroccan|caribbean|latin american|turkish|persian or null",
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
            max_tokens=4096,
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
