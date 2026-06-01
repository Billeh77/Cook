import uuid
from datetime import datetime, timezone
from typing import Optional, List
from sqlmodel import SQLModel, Field
from sqlalchemy import Column, JSON, Text


def _now() -> datetime:
    return datetime.now(timezone.utc)


class Recipe(SQLModel, table=True):
    __tablename__ = "recipes"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)  # Supabase auth UUID
    dish_name: str
    creator_name: Optional[str] = None
    source_url: str
    thumbnail_url: Optional[str] = None
    embed_html: Optional[str] = Field(default=None, sa_column=Column(Text, nullable=True))
    platform: str
    raw_caption: Optional[str] = Field(default=None, sa_column=Column(Text, nullable=True))
    steps: Optional[List[str]] = Field(default=None, sa_column=Column(JSON, nullable=True))
    confidence: float = 0.0
    created_at: datetime = Field(default_factory=_now)
    # Recipe tags — populated by LLM at ingest time, null for older recipes
    meal_type: Optional[str] = None        # "breakfast" | "lunch" | "dinner" | "dessert"
    servings: Optional[int] = None
    effort: Optional[str] = None          # "easy" | "medium" | "hard"
    time_minutes: Optional[int] = None
    is_batch_prep: bool = False
    protein_level: Optional[str] = None   # "high" | "medium" | "low"
    calorie_level: Optional[str] = None   # "low" | "medium" | "high" — per serving
    protein_source: Optional[str] = None  # "chicken" | "beef" | "pork" | "fish" | "seafood" | "eggs" | "lamb" | "turkey" | "vegan" | "vegetarian"
    is_favorited: bool = False


class Ingredient(SQLModel, table=True):
    __tablename__ = "ingredients"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    recipe_id: uuid.UUID = Field(foreign_key="recipes.id", index=True)
    raw_text: str
    canonical_name: str
    quantity: Optional[str] = None
    unit: Optional[str] = None
    notes: Optional[str] = None
    category: str = "other"


class InventoryItem(SQLModel, table=True):
    __tablename__ = "inventory_items"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)  # Supabase auth UUID
    canonical_name: str = Field(index=True)
    status: str = "in_stock"  # in_stock | low | out_of_stock | always_have
    updated_at: datetime = Field(default_factory=_now)


class Album(SQLModel, table=True):
    __tablename__ = "albums"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)
    name: str
    created_at: datetime = Field(default_factory=_now)


class AlbumRecipe(SQLModel, table=True):
    __tablename__ = "album_recipes"

    album_id: uuid.UUID = Field(foreign_key="albums.id", primary_key=True)
    recipe_id: uuid.UUID = Field(foreign_key="recipes.id", primary_key=True)
    added_at: datetime = Field(default_factory=_now)


class PlannedMeal(SQLModel, table=True):
    __tablename__ = "planned_meals"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)
    recipe_id: uuid.UUID = Field(foreign_key="recipes.id")
    added_at: datetime = Field(default_factory=_now)


class CookingLog(SQLModel, table=True):
    __tablename__ = "cooking_logs"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)
    recipe_id: uuid.UUID = Field(foreign_key="recipes.id")
    dish_name: str                                    # denormalised — survives recipe deletion
    cooked_at: datetime = Field(default_factory=_now)
    servings: int = Field(default=1)


class GroceryListItem(SQLModel, table=True):
    __tablename__ = "grocery_list_items"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: str = Field(index=True)  # Supabase auth UUID
    canonical_name: str
    category: str = "other"
    checked: bool = False
    recipe_id: Optional[uuid.UUID] = Field(default=None, foreign_key="recipes.id")
    created_at: datetime = Field(default_factory=_now)
