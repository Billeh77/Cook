import uuid as _uuid
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.db import get_session
from app.models import Album, AlbumRecipe, Recipe, Ingredient
from app.api.dependencies import get_current_user

router = APIRouter()


# ── Response models ────────────────────────────────────────────────────────────

class AlbumCreate(BaseModel):
    name: str


class AlbumOut(BaseModel):
    id: str
    name: str
    recipe_count: int
    cover_urls: list[str]   # up to 4 thumbnails, most-recently-added first
    created_at: str


class AlbumRecipeOut(BaseModel):
    id: str
    dish_name: str
    creator_name: str | None
    source_url: str
    thumbnail_url: str | None
    platform: str
    ingredient_count: int
    created_at: str
    is_favorited: bool = False


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[AlbumOut])
def list_albums(
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    albums = session.exec(
        select(Album).where(Album.user_id == user_id).order_by(Album.created_at)
    ).all()
    return [_album_out(a, session) for a in albums]


@router.post("", response_model=AlbumOut, status_code=201)
def create_album(
    body: AlbumCreate,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Album name cannot be empty")
    album = Album(user_id=user_id, name=name)
    session.add(album)
    session.commit()
    session.refresh(album)
    return _album_out(album, session)


@router.delete("/{album_id}", status_code=204)
def delete_album(
    album_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(album_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid album ID")
    album = session.get(Album, uid)
    if not album or album.user_id != user_id:
        raise HTTPException(status_code=404, detail="Album not found")
    for ar in session.exec(select(AlbumRecipe).where(AlbumRecipe.album_id == uid)).all():
        session.delete(ar)
    session.delete(album)
    session.commit()


@router.get("/{album_id}/recipes", response_model=list[AlbumRecipeOut])
def get_album_recipes(
    album_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        uid = _uuid.UUID(album_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid album ID")
    album = session.get(Album, uid)
    if not album or album.user_id != user_id:
        raise HTTPException(status_code=404, detail="Album not found")

    ars = session.exec(
        select(AlbumRecipe).where(AlbumRecipe.album_id == uid).order_by(AlbumRecipe.added_at.desc())
    ).all()

    result = []
    for ar in ars:
        recipe = session.get(Recipe, ar.recipe_id)
        if not recipe:
            continue
        count = len(session.exec(select(Ingredient).where(Ingredient.recipe_id == recipe.id)).all())
        result.append(AlbumRecipeOut(
            id=str(recipe.id),
            dish_name=recipe.dish_name,
            creator_name=recipe.creator_name,
            source_url=recipe.source_url,
            thumbnail_url=recipe.thumbnail_url,
            platform=recipe.platform,
            ingredient_count=count,
            created_at=recipe.created_at.isoformat(),
            is_favorited=recipe.is_favorited or False,
        ))
    return result


@router.post("/{album_id}/recipes/{recipe_id}", status_code=204)
def add_recipe_to_album(
    album_id: str,
    recipe_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        album_uid = _uuid.UUID(album_id)
        recipe_uid = _uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid ID")

    album = session.get(Album, album_uid)
    if not album or album.user_id != user_id:
        raise HTTPException(status_code=404, detail="Album not found")

    recipe = session.get(Recipe, recipe_uid)
    if not recipe or recipe.user_id != user_id:
        raise HTTPException(status_code=404, detail="Recipe not found")

    existing = session.exec(
        select(AlbumRecipe).where(
            AlbumRecipe.album_id == album_uid,
            AlbumRecipe.recipe_id == recipe_uid,
        )
    ).first()
    if not existing:
        session.add(AlbumRecipe(album_id=album_uid, recipe_id=recipe_uid))
        session.commit()


@router.delete("/{album_id}/recipes/{recipe_id}", status_code=204)
def remove_recipe_from_album(
    album_id: str,
    recipe_id: str,
    session: Session = Depends(get_session),
    user_id: str = Depends(get_current_user),
):
    try:
        album_uid = _uuid.UUID(album_id)
        recipe_uid = _uuid.UUID(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid ID")

    album = session.get(Album, album_uid)
    if not album or album.user_id != user_id:
        raise HTTPException(status_code=404, detail="Album not found")

    ar = session.exec(
        select(AlbumRecipe).where(
            AlbumRecipe.album_id == album_uid,
            AlbumRecipe.recipe_id == recipe_uid,
        )
    ).first()
    if ar:
        session.delete(ar)
        session.commit()


# ── Helper ─────────────────────────────────────────────────────────────────────

def _album_out(album: Album, session: Session) -> AlbumOut:
    ars = session.exec(
        select(AlbumRecipe)
        .where(AlbumRecipe.album_id == album.id)
        .order_by(AlbumRecipe.added_at.desc())
    ).all()
    cover_urls: list[str] = []
    for ar in ars:
        if len(cover_urls) >= 4:
            break
        recipe = session.get(Recipe, ar.recipe_id)
        if recipe and recipe.thumbnail_url:
            cover_urls.append(recipe.thumbnail_url)
    return AlbumOut(
        id=str(album.id),
        name=album.name,
        recipe_count=len(ars),
        cover_urls=cover_urls,
        created_at=album.created_at.isoformat(),
    )
