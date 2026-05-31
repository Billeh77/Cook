from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import health, ingest, recipes, inventory, grocery_list, albums

app = FastAPI(
    title="Grocery List API",
    description="Inventory-aware grocery assistant backend",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, tags=["health"])
app.include_router(ingest.router, prefix="/ingest", tags=["ingest"])
app.include_router(recipes.router, prefix="/recipes", tags=["recipes"])
app.include_router(inventory.router, prefix="/inventory", tags=["inventory"])
app.include_router(grocery_list.router, prefix="/grocery-list", tags=["grocery-list"])
app.include_router(albums.router, prefix="/albums", tags=["albums"])
