"""
Backfill cuisine for existing recipes that don't have one.

Queries all recipes with cuisine IS NULL, asks the LLM to classify each one,
and updates only the ones where the LLM returns a non-null cuisine.
Null is the right answer for generic/fusion recipes — the script never forces one.

Usage (from the backend/ directory):
    uv run python scripts/backfill_cuisine.py              # dry run (prints, no writes)
    uv run python scripts/backfill_cuisine.py --write      # actually updates the DB

Requires DATABASE_URL and ANTHROPIC_API_KEY in the environment (or .env file).
"""
import argparse
import asyncio
import json
import time
import sys
from pathlib import Path

# Add the backend root to sys.path so `app` imports work
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv(Path(__file__).parent.parent / ".env")

from sqlmodel import Session, select, create_engine
from app.config import settings
from app.models import Recipe

VALID_CUISINES = {
    "italian", "mexican", "chinese", "japanese", "thai", "indian",
    "mediterranean", "middle eastern", "french", "american", "korean",
    "greek", "spanish", "vietnamese", "moroccan", "caribbean",
    "latin american", "turkish", "persian",
}

SYSTEM_PROMPT = """\
You are a cuisine classifier for a recipe app. Classify the cuisine or return null.

Valid values: "italian" | "mexican" | "chinese" | "japanese" | "thai" | "indian" |
"mediterranean" | "middle eastern" | "french" | "american" | "korean" | "greek" |
"spanish" | "vietnamese" | "moroccan" | "caribbean" | "latin american" | "turkish" | "persian"

STRONG SIGNALS — always classify these:
- Dish name contains "Thai" or "thai" → thai
- Dish name contains "Pad", "Panang", "Som Tam", "Larb", "Tom Yum", "Green Curry", "Red Curry" → thai
- Dish name contains "Teriyaki", "Miso", "Ramen", "Sushi", "Katsu", "Tonkatsu", "Gyoza" → japanese
- Dish name contains "Shawarma", "Kofta", "Lebanese", "Falafel", "Hummus" → middle eastern
- Dish name contains "Taco", "Burrito", "Quesadilla", "Enchilada", "Salsa", "Chipotle", "Street Corn" → mexican
- Dish name contains "Pasta", "Risotto", "Pesto", "Carbonara", "Alfredo", "Parmesan" → italian
- Dish name contains "Pad See Ew", "Drunken Noodles", "Massaman" → thai
- Dish name contains "Pho", "Banh Mi", "Vietnamese" → vietnamese
- Dish name contains "Beef with Broccoli", "Fried Rice", "Kung Pao", "Dim Sum", "Dragon" → chinese
- Dish name contains "Tzatziki", "Pita", "Gyro", "Souvlaki" → greek
- Dish name contains "BBQ" (American style), "Buffalo", "Ranch" → american
- Dish name contains "Brioche", "Croissant", "Coq au Vin", "Beurre" → french

Return null ONLY for truly generic dishes with no cultural identity: plain wraps,
smoothies, basic egg dishes, generic protein bowls with no ethnic seasoning.

Return ONLY a JSON object: {"cuisine": "thai"} or {"cuisine": null}
No explanation, no markdown, no code fences.
"""


async def classify_cuisine(client, dish_name: str, caption: str | None) -> str | None:
    caption_snippet = (caption or "")[:800]  # keep prompt short
    user_msg = f"Dish: {dish_name}\n\nCaption:\n{caption_snippet}"

    message = await client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=64,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_msg}],
    )
    raw = message.content[0].text.strip()
    try:
        data = json.loads(raw)
        cuisine = data.get("cuisine")
        if cuisine and cuisine.lower() in VALID_CUISINES:
            return cuisine.lower()
    except (json.JSONDecodeError, AttributeError):
        pass
    return None


async def main(write: bool) -> None:
    if not settings.anthropic_api_key:
        print("ERROR: ANTHROPIC_API_KEY not set")
        sys.exit(1)

    import anthropic
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    engine = create_engine(settings.database_url)

    with Session(engine) as session:
        recipes = session.exec(
            select(Recipe).where(Recipe.cuisine == None)  # noqa: E711
        ).all()

    print(f"Found {len(recipes)} recipes without cuisine")
    if not recipes:
        return

    updated = 0
    skipped = 0

    for i, recipe in enumerate(recipes, 1):
        print(f"[{i}/{len(recipes)}] {recipe.dish_name!r}", end=" ... ", flush=True)

        cuisine = await classify_cuisine(client, recipe.dish_name, recipe.raw_caption)

        if cuisine:
            print(f"→ {cuisine}", end="")
            if write:
                with Session(engine) as session:
                    db_recipe = session.get(Recipe, recipe.id)
                    if db_recipe:
                        db_recipe.cuisine = cuisine
                        session.add(db_recipe)
                        session.commit()
                print(" [saved]")
            else:
                print(" [dry run]")
            updated += 1
        else:
            print("→ null (skipped)")
            skipped += 1

        # Respect rate limits — Haiku is fast but don't hammer the API
        if i < len(recipes):
            time.sleep(0.3)

    print(f"\nDone. Updated: {updated}  Skipped (null): {skipped}")
    if not write:
        print("(dry run — rerun with --write to apply changes)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="Actually write to the DB")
    args = parser.parse_args()
    asyncio.run(main(write=args.write))
