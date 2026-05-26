# Architecture — Grocery List

## System overview

```
┌─────────────────────────────────────────────┐
│                  iOS App                    │
│                                             │
│  ┌──────────────┐   ┌─────────────────────┐ │
│  │ Share        │   │ Main App (SwiftUI)  │ │
│  │ Extension    │   │                     │ │
│  │              │   │ - Saved Recipes     │ │
│  │ Captures URL │   │ - Inventory         │ │
│  │ → POST /link │   │ - Grocery List      │ │
│  └──────┬───────┘   │ - Can Cook          │ │
│         │           └──────────┬──────────┘ │
└─────────┼──────────────────────┼────────────┘
          │                      │
          ▼                      ▼
┌─────────────────────────────────────────────┐
│              FastAPI Backend                │
│                                             │
│  POST /ingest/link                          │
│    → PlatformDetector                       │
│    → TikTokOEmbedService                    │
│    → RecipeExtractor (Claude API)           │
│    → IngredientNormalizer                   │
│    → store Recipe + Ingredients             │
│                                             │
│  GET  /recipes                              │
│  GET  /recipes/{id}/cookability             │
│  POST /inventory                            │
│  GET  /inventory                            │
│  POST /grocery-list/generate                │
│  PATCH /grocery-list/{id}/check-off         │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│              PostgreSQL                     │
│   recipes | ingredients | inventory         │
│   grocery_lists | grocery_list_items        │
└─────────────────────────────────────────────┘
```

---

## Backend service map

### Ingestion layer

```
services/ingestion/
  platform_detector.py      detects TikTok vs Instagram from URL
  tiktok_oembed.py          calls TikTok oEmbed API, returns RawVideoData
  instagram_playwright.py   renders page with Playwright, returns RawVideoData
```

Both services return the same `RawVideoData` shape:
```python
class RawVideoData(BaseModel):
    platform: str           # "tiktok" | "instagram"
    source_url: str
    creator_name: str | None
    creator_url: str | None
    caption_text: str | None  # raw caption, full text
    thumbnail_url: str | None
    embed_html: str | None
```

### AI layer

```
services/ai/
  recipe_extractor.py       LLM: RawVideoData → RecipeDraft
  ingredient_normalizer.py  LLM: raw ingredient text → canonical English name
  grocery_optimizer.py      logic: selected recipes + inventory → grocery list
```

`recipe_extractor.py` calls Claude with a structured output prompt and returns:
```python
class RecipeDraft(BaseModel):
    dish_name: str
    ingredients: list[IngredientDraft]
    steps: list[str]
    confidence: float   # 0.0–1.0, low = needs manual review

class IngredientDraft(BaseModel):
    raw_text: str       # exactly as found in caption
    quantity: str | None
    unit: str | None
    notes: str | None   # "crunchy", "deep roast", etc.
```

`ingredient_normalizer.py` maps each `IngredientDraft` to a canonical name:
```python
class NormalizedIngredient(BaseModel):
    raw_text: str
    canonical_name: str   # English, lowercase, singular
    category: str         # "produce" | "dairy" | "meat" | "pantry" | "spice" | "other"
    quantity: str | None
    unit: str | None
```

### Inventory layer

```
services/inventory/
  inventory_matcher.py    compares recipe ingredients against inventory items
```

Returns per-recipe cookability:
```python
class CookabilityResult(BaseModel):
    recipe_id: str
    status: str             # "ready" | "missing_1" | "missing_2" | "missing_many"
    missing_count: int
    missing_ingredients: list[str]
    available_ingredients: list[str]
```

---

## Data flow — share a TikTok

```
1. User taps Share in TikTok app
2. iOS Share Sheet appears
3. User selects "Grocery List"
4. Share Extension activates
5. Extension extracts URL from share payload
6. Extension POSTs { "url": "..." } to backend /ingest/link
7. Extension shows loading spinner
8. Backend: platform_detector → "tiktok"
9. Backend: tiktok_oembed → RawVideoData (caption in title field)
10. Backend: recipe_extractor → RecipeDraft (Claude API)
11. Backend: ingredient_normalizer → NormalizedIngredient list
12. Backend: stores Recipe + Ingredients in Postgres
13. Backend: returns RecipeResponse to extension
14. Extension shows recipe card preview (dish name + ingredient count)
15. User taps "Save" — extension closes
16. Main app shows saved recipe with missing ingredients highlighted
```

---

## Key technical decisions

| Decision | Choice | Reason |
|---|---|---|
| TikTok data | oEmbed (no auth) | Free, stable, returns full caption |
| Instagram data | Playwright | Only reliable no-auth option |
| LLM | Claude (claude-3-5-haiku for speed) | Structured JSON output, fast |
| Database | PostgreSQL via Supabase | Free tier, managed, SwiftUI-friendly REST |
| Auth (v1) | None (local only) | Ship faster, add later |
| iOS persistence | SwiftData | Native, simple for v1 |
| Backend deploy | Railway or Fly.io | Simple, cheap, fast CI |

---

## Share Extension constraints

- iOS gives Share Extensions ~30s and limited memory (~120MB)
- Extension must NOT: download video, run Whisper, call multiple APIs
- Extension MUST: capture URL, POST to backend, show result, exit
- Use App Groups to share a URL queue between extension and main app
- If backend is slow, extension queues URL locally and main app processes on next open

---

## Ingredient normalization strategy

Priority order:
1. Direct dictionary lookup (fast, free, no LLM call) for common items
2. LLM normalization for unknown/foreign-language items

Always store both:
- `raw_text`: "2 tbsp crunchy peanut butter (I like @manilife_ deep roast)"
- `canonical_name`: "peanut butter"

This preserves creator intent while enabling inventory matching.
