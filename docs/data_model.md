# Data Model — Grocery List

## Entity relationship diagram

```
Recipe
  id (PK)
  dish_name
  creator_name
  creator_url
  source_url          ← original TikTok/Instagram URL
  platform            ← "tiktok" | "instagram"
  thumbnail_url
  raw_caption         ← full text as returned by oEmbed/Playwright
  confidence          ← 0.0–1.0, LLM extraction confidence
  saved_at

RecipeIngredient      ← join: recipe ↔ ingredient
  id (PK)
  recipe_id (FK → Recipe)
  raw_text            ← "2 tbsp crunchy peanut butter (I like @manilife_)"
  canonical_name      ← "peanut butter"
  quantity            ← "2"
  unit                ← "tbsp"
  notes               ← "crunchy"
  category            ← "pantry"
  sort_order          ← preserves original order from caption

InventoryItem
  id (PK)
  canonical_name      ← must match RecipeIngredient.canonical_name for matching
  category
  status              ← "in_stock" | "low" | "out_of_stock" | "always_have"
  added_at
  updated_at

GroceryList
  id (PK)
  created_at
  completed_at        ← null if active, timestamp when user finishes shopping

GroceryListItem
  id (PK)
  grocery_list_id (FK → GroceryList)
  canonical_name
  category
  quantity            ← combined quantity string e.g. "2 portions + 1 serving"
  checked             ← false until user checks off at store
  checked_at

GroceryListRecipe     ← join: grocery list ↔ recipes it was generated from
  grocery_list_id (FK)
  recipe_id (FK)
```

---

## SQLModel definitions (Python)

```python
# models/recipe.py
class Recipe(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    dish_name: str
    creator_name: str | None = None
    creator_url: str | None = None
    source_url: str
    platform: str
    thumbnail_url: str | None = None
    raw_caption: str | None = None
    confidence: float = 1.0
    saved_at: datetime = Field(default_factory=datetime.utcnow)

    ingredients: list["RecipeIngredient"] = Relationship(back_populates="recipe")


class RecipeIngredient(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    recipe_id: uuid.UUID = Field(foreign_key="recipe.id")
    raw_text: str
    canonical_name: str
    quantity: str | None = None
    unit: str | None = None
    notes: str | None = None
    category: str = "other"
    sort_order: int = 0

    recipe: Recipe = Relationship(back_populates="ingredients")


# models/inventory.py
class InventoryItem(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    canonical_name: str = Field(index=True, unique=True)
    category: str = "other"
    status: str = "in_stock"   # in_stock | low | out_of_stock | always_have
    added_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# models/grocery_list.py
class GroceryList(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: datetime | None = None

    items: list["GroceryListItem"] = Relationship(back_populates="grocery_list")


class GroceryListItem(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    grocery_list_id: uuid.UUID = Field(foreign_key="grocerylist.id")
    canonical_name: str
    category: str = "other"
    quantity: str | None = None
    checked: bool = False
    checked_at: datetime | None = None

    grocery_list: GroceryList = Relationship(back_populates="items")
```

---

## Inventory matching logic

```
For each recipe ingredient (canonical_name):
  1. Look up canonical_name in InventoryItem table
  2. If found AND status in ["in_stock", "always_have"] → available
  3. If found AND status == "low" → available (warn)
  4. If not found OR status == "out_of_stock" → missing

cookability:
  - missing_count == 0 → "ready"
  - missing_count == 1 → "missing_1"
  - missing_count == 2 → "missing_2"
  - missing_count >= 3 → "missing_many"
```

Matching is **exact on canonical_name** (lowercase, stripped).
The normalizer is responsible for mapping surface forms to canonical names correctly.

---

## Grocery list generation logic

```
input: list of recipe_ids, current inventory

for each recipe:
  get all RecipeIngredients
  filter to missing (not in inventory or out_of_stock)
  add to combined set

deduplicate by canonical_name
  if same item appears in multiple recipes: combine quantities (best-effort)

exclude "always_have" items

output: GroceryListItem list, sorted by category
```

---

## Categories

Standard categories used across all models:

| value | description |
|---|---|
| `produce` | fresh fruit, vegetables, herbs |
| `dairy` | milk, cheese, eggs, butter, cream |
| `meat` | beef, chicken, pork, seafood |
| `pantry` | canned goods, oils, sauces, condiments, dried goods |
| `spice` | spices, dried herbs, seasonings |
| `grain` | rice, pasta, noodles, bread, flour |
| `frozen` | frozen items |
| `other` | anything not categorized |

---

## Naming conventions

- All `canonical_name` values: **lowercase, English, singular**
  - "eggs" → "egg"
  - "noodles" → "noodle"
  - "spring onions" → "spring onion"
- Matching is case-insensitive exact string match
- Fuzzy matching is a future improvement; for v1 normalization must be precise
