# API Contract — Grocery List Backend

Base URL (local): `http://localhost:8000`
Base URL (prod): TBD

All requests and responses use `application/json`.

---

## Health

### GET /health
Returns server status.

**Response 200**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

---

## Ingestion

### POST /ingest/link
Accepts a TikTok or Instagram URL, extracts the recipe, normalizes ingredients, and stores the result.

**Request**
```json
{
  "url": "https://www.tiktok.com/@alfiecooks_/video/7617527660482268438"
}
```

**Response 200 — success**
```json
{
  "id": "uuid",
  "status": "success",
  "dish_name": "10 Minute Peanut Butter + Chilli Crisp Noodles",
  "creator_name": "ALFIE STEINER",
  "creator_url": "https://www.tiktok.com/@alfiecooks_",
  "source_url": "https://www.tiktok.com/@alfiecooks_/video/7617527660482268438",
  "thumbnail_url": "https://...",
  "platform": "tiktok",
  "ingredient_count": 11,
  "missing_count": 3,
  "confidence": 0.95
}
```

**Response 200 — needs review**
```json
{
  "id": "uuid",
  "status": "needs_manual_review",
  "dish_name": null,
  "confidence": 0.2,
  "raw_caption": "This recipe is 🔥🔥🔥 #fyp #food"
}
```

**Response 422** — invalid URL or unsupported platform
```json
{
  "detail": "Unsupported platform. Supported: tiktok, instagram"
}
```

---

## Recipes

### GET /recipes
Returns all saved recipes with cookability.

**Query params**
- `filter`: `all` | `ready` | `almost` (default: `all`)
- `sort`: `saved_at` | `missing_count` (default: `saved_at`)

**Response 200**
```json
{
  "recipes": [
    {
      "id": "uuid",
      "dish_name": "Peanut Butter Noodles",
      "creator_name": "ALFIE STEINER",
      "source_url": "https://...",
      "thumbnail_url": "https://...",
      "platform": "tiktok",
      "ingredient_count": 11,
      "missing_count": 2,
      "missing_ingredients": ["chilli crisp", "rice wine vinegar"],
      "saved_at": "2025-01-15T10:30:00Z"
    }
  ],
  "total": 12
}
```

### GET /recipes/{id}
Returns full recipe detail.

**Response 200**
```json
{
  "id": "uuid",
  "dish_name": "Peanut Butter Noodles",
  "creator_name": "ALFIE STEINER",
  "creator_url": "https://www.tiktok.com/@alfiecooks_",
  "source_url": "https://...",
  "thumbnail_url": "https://...",
  "platform": "tiktok",
  "raw_caption": "10 MINUTE PEANUT BUTTER...",
  "steps": [
    "Get all your ingredients in a frying pan",
    "Heat your oil until starting to smoke",
    "Pour over the aromatics, whisking well to combine",
    "Cook noodles according to packet instructions",
    "Toss noodles through sauce, loosening with noodle liquid"
  ],
  "ingredients": [
    {
      "id": "uuid",
      "raw_text": "2 tbsp crunchy peanut butter",
      "canonical_name": "peanut butter",
      "quantity": "2",
      "unit": "tbsp",
      "category": "pantry",
      "in_inventory": true
    },
    {
      "id": "uuid",
      "raw_text": "2 tsp chilli crisp",
      "canonical_name": "chilli crisp",
      "quantity": "2",
      "unit": "tsp",
      "category": "pantry",
      "in_inventory": false
    }
  ],
  "saved_at": "2025-01-15T10:30:00Z"
}
```

### DELETE /recipes/{id}
Deletes a saved recipe.

**Response 204** — no content

---

## Inventory

### GET /inventory
Returns all inventory items.

**Response 200**
```json
{
  "items": [
    {
      "id": "uuid",
      "canonical_name": "peanut butter",
      "category": "pantry",
      "status": "in_stock",
      "added_at": "2025-01-10T08:00:00Z"
    },
    {
      "id": "uuid",
      "canonical_name": "olive oil",
      "category": "pantry",
      "status": "always_have"
    }
  ],
  "total": 24
}
```

### POST /inventory
Adds an item to inventory.

**Request**
```json
{
  "canonical_name": "chilli crisp",
  "category": "pantry",
  "status": "in_stock"
}
```

**Response 201**
```json
{
  "id": "uuid",
  "canonical_name": "chilli crisp",
  "category": "pantry",
  "status": "in_stock",
  "added_at": "2025-01-15T11:00:00Z"
}
```

### PATCH /inventory/{id}
Updates an inventory item's status.

**Request**
```json
{
  "status": "out_of_stock"
}
```

**Response 200** — returns updated item

### DELETE /inventory/{id}
Removes an item from inventory.

**Response 204**

---

## Grocery List

### GET /grocery-list
Returns the current active grocery list.

**Response 200**
```json
{
  "id": "uuid",
  "items": [
    {
      "id": "uuid",
      "canonical_name": "chilli crisp",
      "category": "pantry",
      "quantity": "2 tsp",
      "checked": false,
      "recipe_ids": ["uuid1", "uuid2"]
    },
    {
      "id": "uuid",
      "canonical_name": "noodles",
      "category": "pantry",
      "quantity": "2 portions",
      "checked": true,
      "recipe_ids": ["uuid1"]
    }
  ],
  "generated_at": "2025-01-15T09:00:00Z"
}
```

### POST /grocery-list/generate
Generates a new grocery list from selected recipes minus current inventory.

**Request**
```json
{
  "recipe_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Response 201** — returns same shape as GET /grocery-list

### PATCH /grocery-list/items/{item_id}/check
Marks a grocery list item as checked (purchased), updates inventory.

**Request**
```json
{
  "checked": true
}
```

**Response 200**
```json
{
  "id": "uuid",
  "canonical_name": "chilli crisp",
  "checked": true
}
```

---

## Error format

All errors follow:
```json
{
  "detail": "Human-readable error message"
}
```

HTTP status codes used:
- `200` success
- `201` created
- `204` deleted
- `400` bad request
- `404` not found
- `422` validation error
- `500` internal server error
