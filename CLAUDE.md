# Grocery List — Claude Code Project Memory

## Product mission

This app is an **inventory-aware grocery assistant**. It is not primarily a recipe saver.

Core value:
- User shares a TikTok or Instagram cooking video
- App extracts the recipe and ingredients from the caption/transcript
- App compares ingredients against the user's pantry inventory
- App generates the smallest useful grocery list
- App shows which saved recipes are cookable now or almost cookable

The UX unlock is the **iOS Share Extension**: share a reel or TikTok as if sending it to a friend — the app does the rest.

---

## Monorepo structure

```
grocery-list/
  CLAUDE.md               ← you are here
  README.md
  docs/
    product_spec.md       ← full product requirements
    architecture.md       ← system design
    api_contract.md       ← all API endpoints + request/response shapes
    data_model.md         ← database schema + entity relationships
    ai_prompts.md         ← LLM prompt templates
  backend/
    app/
      main.py
      api/routes/         ← thin route handlers only
      services/
        ingestion/        ← tiktok_oembed.py, instagram_playwright.py
        ai/               ← recipe_extractor.py, ingredient_normalizer.py
        inventory/        ← inventory_matcher.py
      models/             ← SQLModel table definitions
      db/                 ← session.py, migrations/
    tests/
    pyproject.toml
    .env.example
  ios/
    GroceryList/          ← SwiftUI app
    GroceryListShareExtension/
  infra/
    docker-compose.yml
```

---

## Coding standards

### Backend (Python)
- Framework: **FastAPI**
- ORM: **SQLModel** (combines SQLAlchemy + Pydantic)
- Migrations: **Alembic**
- Testing: **pytest** with `httpx` for async route tests
- Package manager: **uv** (`uv sync` to install)
- Keep **routes thin** — business logic belongs in `services/`
- Use **Pydantic models** for all request/response shapes
- Use **structured JSON outputs** from all LLM calls (never free text)
- All LLM calls go through `services/ai/` — never inline in routes
- Always preserve `source_url` and `raw_extracted_text` on every recipe
- Never commit secrets — use `.env` loaded via `python-dotenv`

### iOS (Swift)
- Framework: **SwiftUI**
- Networking: **async/await + URLSession**
- Local persistence: **SwiftData**
- Share Extension: capture URL only, POST to backend, show result
- Keep API response models (`DTOs`) separate from SwiftUI view models
- Never do heavy processing (AI, video download) inside the Share Extension

---

## Environment variables

See `backend/.env.example` for all required variables.

Key ones:
```
ANTHROPIC_API_KEY=
DATABASE_URL=postgresql://...
ENVIRONMENT=development
```

---

## Commands

```bash
# Backend
cd backend
uv sync                                            # install deps (creates .venv/)
uv pip install pytest pytest-asyncio httpx         # install test deps into venv
.venv/bin/python -m pytest -v                      # run tests (use venv python directly - anaconda intercepts pytest)
uvicorn app.main:app --reload                      # run dev server
alembic upgrade head                               # run migrations

# Infra
cd infra
docker compose up -d             # start postgres locally
```

---

## Development workflow for Claude Code

Before making any changes:
1. Read the relevant `docs/` file for the area you are working on
2. Explain which files you plan to edit and why
3. Make the **smallest working change** that satisfies the task
4. Add or update tests for every service function
5. Run `pytest` and confirm passing
6. Summarize what changed and what still needs doing

Work **one service at a time**. Never implement multiple unrelated things in one session.

---

## Build order (phases)

### Phase 1 — Backend pipeline (build first)
1. FastAPI skeleton + health endpoint
2. TikTok oEmbed ingestion service
3. Instagram Playwright ingestion service
4. LLM recipe extractor (structured JSON output)
5. Ingredient normalizer
6. Inventory matcher
7. Grocery list generator

### Phase 2 — iOS app
1. SwiftUI app skeleton (4 tabs: Recipes, Inventory, Grocery List, Can Cook)
2. Saved recipes list + recipe detail screen
3. Inventory management screen
4. Grocery list with check-off
5. Can Cook / missing ingredients ranking

### Phase 3 — Share Extension
1. Share Extension captures TikTok/Instagram URL
2. POSTs URL to backend
3. Shows recipe preview card
4. User confirms → recipe saved

### Phase 4 — Polish
1. Supabase auth
2. Grocery trip history
3. Receipt parsing (future)

---

## Key design decisions

- **TikTok ingestion**: use oEmbed first (`https://www.tiktok.com/oembed?url=...`) — no API key needed, returns full caption in `title` field
- **Instagram ingestion**: Playwright-rendered visible text, best-effort
- **Fallback**: if extraction confidence is low, return status `needs_manual_review` so app can prompt user
- **Ingredient normalization**: always store both `raw_text` (original language) and `canonical_name` (English)
- **Inventory model**: each item has status: `in_stock | low | out_of_stock | always_have`
- **Cookability**: computed at query time — never stored — based on current inventory state
