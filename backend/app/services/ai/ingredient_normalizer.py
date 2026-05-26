"""
Normalizes raw ingredient text to canonical English ingredient names.

Strategy:
1. Check a small fast lookup dictionary first (covers most common items)
2. Fall back to LLM normalization for unknown or foreign-language items

Always returns both raw_text and canonical_name.
"""
import json
from pydantic import BaseModel

from app.config import settings


class NormalizedIngredient(BaseModel):
    raw_text: str
    canonical_name: str
    category: str = "other"


# Fast lookup for the most common ingredients.
# Extend this before using LLM to keep costs low.
INGREDIENT_DICTIONARY: dict[str, tuple[str, str]] = {
    # raw fragment → (canonical_name, category)
    "peanut butter": ("peanut butter", "pantry"),
    "garlic": ("garlic", "produce"),
    "ginger": ("ginger", "produce"),
    "spring onion": ("spring onion", "produce"),
    "green onion": ("spring onion", "produce"),
    "scallion": ("spring onion", "produce"),
    "shallot": ("shallot", "produce"),
    "chilli crisp": ("chilli crisp", "pantry"),
    "chili crisp": ("chilli crisp", "pantry"),
    "sesame seed": ("sesame seed", "spice"),
    "soy sauce": ("soy sauce", "pantry"),
    "rice wine vinegar": ("rice wine vinegar", "pantry"),
    "sunflower oil": ("sunflower oil", "pantry"),
    "noodle": ("noodle", "grain"),
    "pasta": ("pasta", "grain"),
    "red chilli": ("red chilli", "produce"),
    "red chili": ("red chilli", "produce"),
    "olive oil": ("olive oil", "pantry"),
    "salt": ("salt", "spice"),
    "pepper": ("black pepper", "spice"),
    "egg": ("egg", "dairy"),
    "butter": ("butter", "dairy"),
    "milk": ("milk", "dairy"),
    "mozzarella": ("mozzarella", "dairy"),
    "muçarela": ("mozzarella", "dairy"),
    "potato": ("potato", "produce"),
    "batata": ("potato", "produce"),
    "chive": ("chive", "produce"),
    "cebolinha": ("chive", "produce"),
    "bacon": ("bacon", "meat"),
    "chicken": ("chicken", "meat"),
    "azeite": ("olive oil", "pantry"),
}


def _dict_lookup(raw_text: str) -> NormalizedIngredient | None:
    """Fast dictionary lookup. Returns None if not found."""
    lower = raw_text.lower()
    for key, (canonical, category) in INGREDIENT_DICTIONARY.items():
        if key in lower:
            return NormalizedIngredient(
                raw_text=raw_text,
                canonical_name=canonical,
                category=category,
            )
    return None


async def normalize_ingredients(
    raw_texts: list[str],
) -> list[NormalizedIngredient]:
    """
    Normalizes a list of raw ingredient strings.
    Uses dictionary lookup first, LLM fallback for unknowns.
    """
    results: list[NormalizedIngredient] = []
    llm_needed: list[str] = []

    for raw in raw_texts:
        hit = _dict_lookup(raw)
        if hit:
            results.append(hit)
        else:
            llm_needed.append(raw)

    if llm_needed:
        llm_results = await _llm_normalize(llm_needed)
        results.extend(llm_results)

    return results


async def _llm_normalize(raw_texts: list[str]) -> list[NormalizedIngredient]:
    """Falls back to Claude for ingredient normalization."""
    if not settings.anthropic_api_key:
        # Dev fallback
        return [
            NormalizedIngredient(raw_text=t, canonical_name=t.lower().split()[0], category="other")
            for t in raw_texts
        ]

    import anthropic

    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    system = """You are an ingredient normalization assistant. Map ingredient descriptions to canonical English ingredient names.
Return ONLY valid JSON array. No explanation.
canonical_name: lowercase, English, singular form of the base ingredient (remove brands, descriptors, prep methods).
category must be one of: produce, dairy, meat, pantry, spice, grain, frozen, other."""

    user = f"""Normalize these ingredients. Return a JSON array:
[
  {{
    "raw_text": "original text",
    "canonical_name": "normalized english name",
    "category": "category"
  }}
]

Ingredients:
{json.dumps(raw_texts, ensure_ascii=False)}"""

    try:
        message = await client.messages.create(
            model="claude-sonnet-4-5",
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        data = json.loads(message.content[0].text.strip())
        return [NormalizedIngredient.model_validate(item) for item in data]
    except Exception as e:
        print(f"[ingredient_normalizer] LLM error: {e}")
        return [
            NormalizedIngredient(raw_text=t, canonical_name=t, category="other")
            for t in raw_texts
        ]
