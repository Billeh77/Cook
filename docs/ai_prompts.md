# AI Prompts — Grocery List

These are the canonical prompt templates used by the backend AI services.
Update this file when prompts change so Claude Code stays aligned.

---

## 1. Recipe Extraction

**File**: `backend/app/services/ai/recipe_extractor.py`
**Model**: `claude-haiku-4-5-20251101` (fast, cheap, good at structured extraction)
**Output**: JSON only, validated against `RecipeDraft` Pydantic model

### System prompt
```
You are a recipe extraction assistant. Your job is to extract structured recipe data from social media cooking video captions.

Rules:
- Return ONLY valid JSON. No explanation, no markdown, no code fences.
- If the caption does not contain a recipe, return {"dish_name": null, "ingredients": [], "steps": [], "confidence": 0.0}
- confidence: 1.0 = full recipe with quantities, 0.5 = partial, 0.0 = no recipe
- Preserve original quantities and units exactly as written
- Include all ingredients mentioned, even if quantities are missing
- Steps should be clean sentences, not raw caption text
```

### User prompt
```
Extract the recipe from this cooking video caption. Return JSON matching this exact schema:

{
  "dish_name": "string or null",
  "ingredients": [
    {
      "raw_text": "exact text from caption",
      "quantity": "number as string or null",
      "unit": "unit string or null",
      "notes": "descriptors like 'crunchy', 'fresh', 'minced' or null"
    }
  ],
  "steps": ["step 1", "step 2"],
  "confidence": 0.0
}

Caption:
{caption_text}
```

### Example input
```
10 MINUTE PEANUT BUTTER + CHILLI CRISP NOODLES 🤤 ...
2 tbsp crunchy peanut butter
1 tbsp minced garlic
1 tbsp minced ginger
2 tbsp finely sliced spring onion
...
```

### Example output
```json
{
  "dish_name": "10 Minute Peanut Butter Chilli Crisp Noodles",
  "ingredients": [
    {"raw_text": "2 tbsp crunchy peanut butter", "quantity": "2", "unit": "tbsp", "notes": "crunchy"},
    {"raw_text": "1 tbsp minced garlic", "quantity": "1", "unit": "tbsp", "notes": "minced"},
    {"raw_text": "1 tbsp minced ginger", "quantity": "1", "unit": "tbsp", "notes": "minced"},
    {"raw_text": "2 tbsp finely sliced spring onion", "quantity": "2", "unit": "tbsp", "notes": "finely sliced"},
    {"raw_text": "2 tbsp finely diced shallot", "quantity": "2", "unit": "tbsp", "notes": "finely diced"},
    {"raw_text": "2 tsp chilli crisp", "quantity": "2", "unit": "tsp", "notes": null},
    {"raw_text": "toasted sesame seeds", "quantity": null, "unit": null, "notes": "toasted"},
    {"raw_text": "2 tbsp soy sauce", "quantity": "2", "unit": "tbsp", "notes": null},
    {"raw_text": "2 tbsp rice wine vinegar", "quantity": "2", "unit": "tbsp", "notes": null},
    {"raw_text": "80ml hot neutral oil", "quantity": "80", "unit": "ml", "notes": "hot, neutral"},
    {"raw_text": "2 portions noodles of choice", "quantity": "2", "unit": "portions", "notes": "of choice"},
    {"raw_text": "1 small red chilli, sliced", "quantity": "1", "unit": null, "notes": "small, sliced"}
  ],
  "steps": [
    "Get all your ingredients in a frying pan.",
    "Heat your oil until hot and starting to smoke.",
    "Pour over the aromatics, whisking well to combine.",
    "Cook your noodles according to packet instructions, reserving some cooking liquid.",
    "Toss the noodles through the sauce, loosening with cooking liquid if required.",
    "Garnish with more spring onion, red chilli, and sesame seeds."
  ],
  "confidence": 0.97
}
```

---

## 2. Ingredient Normalization

**File**: `backend/app/services/ai/ingredient_normalizer.py`
**Model**: `claude-haiku-4-5-20251101`
**Output**: JSON only

### System prompt
```
You are an ingredient normalization assistant. Your job is to map ingredient descriptions (which may be in any language or include brand names and descriptors) to a canonical English ingredient name.

Rules:
- Return ONLY valid JSON. No explanation.
- canonical_name: lowercase, English, singular form of the base ingredient
- Remove brand names, descriptors, preparation methods
- category must be one of: produce, dairy, meat, pantry, spice, grain, frozen, other
- Examples:
  - "2 tbsp crunchy peanut butter (I like @manilife_ deep roast)" → "peanut butter", category: "pantry"
  - "cebolinha" (Portuguese) → "chive", category: "produce"
  - "muçarela ralada" → "mozzarella", category: "dairy"
  - "azeite de oliva" → "olive oil", category: "pantry"
  - "fio de azeite" → "olive oil", category: "pantry"
  - "1 small red chilli, sliced" → "red chilli", category: "produce"
```

### User prompt
```
Normalize these ingredients. Return a JSON array:

[
  {
    "raw_text": "original text",
    "canonical_name": "normalized english name",
    "category": "category"
  }
]

Ingredients:
{ingredients_json}
```

---

## 3. Grocery List Optimization (future v2)

**File**: `backend/app/services/ai/grocery_optimizer.py`
**Model**: `claude-3-5-sonnet` (reasoning needed)
**Purpose**: "Which 5 items should I buy to unlock the most recipes?"

This is a v2 feature. Implement inventory matching logic first (pure Python, no LLM).

---

## Implementation notes

- Always use `response_format` or explicit JSON instruction — never parse free text
- If JSON is malformed, retry once with a stricter prompt, then return `confidence: 0.0`
- Log raw LLM response before parsing for debugging
- Use `instructor` library or manual `.model_validate_json()` for validation
- Haiku is fast enough for the share extension flow (< 3s typical)
