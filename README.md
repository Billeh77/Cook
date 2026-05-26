# Grocery List

An inventory-aware grocery assistant. Share a TikTok or Instagram cooking video → app extracts the recipe → compares against your pantry → generates a grocery list for what you're missing.

## Monorepo structure

```
grocery-list/
  CLAUDE.md                 ← Claude Code project memory
  docs/                     ← specs, architecture, API contract, data model, prompts
  backend/                  ← Python FastAPI backend
  ios/                      ← SwiftUI app + Share Extension (Phase 2)
  infra/                    ← docker-compose for local Postgres
```

## Quick start (backend)

**Prerequisites**: Python 3.12+, Docker

```bash
# 1. Start Postgres
cd infra && docker compose up -d

# 2. Install backend deps
cd backend
pip install uv
uv sync

# 3. Configure environment
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY

# 4. Run dev server
uvicorn app.main:app --reload

# 5. Test it
curl http://localhost:8000/health

curl -X POST http://localhost:8000/ingest/link \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.tiktok.com/@alfiecooks_/video/7617527660482268438"}'

# 6. Run tests
pytest
```

## Build phases

| Phase | Status | Description |
|---|---|---|
| 1 | In progress | Backend pipeline: ingest → extract → normalize |
| 2 | Planned | iOS SwiftUI app |
| 3 | Planned | iOS Share Extension |
| 4 | Planned | Auth + cloud sync |

## Key design

- TikTok oEmbed (no API key needed) → full caption → Claude extraction → normalized ingredients
- Inventory matching: `canonical_name` exact match between recipe ingredients and pantry
- Cookability computed at query time (not stored)
- Share Extension: thin — just captures URL, POSTs to backend, shows result
