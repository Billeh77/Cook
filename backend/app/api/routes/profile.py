"""
Profile routes — currently covers AI chef avatar generation.

POST /profile/avatar
  Accepts a user photo, generates a Pixar-style chef avatar via Replicate,
  stores it in Supabase Storage, updates the user's auth metadata, and
  returns the permanent avatar URL.

Generation takes 20–40 seconds; the client should show a progress indicator.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.services.ai.avatar_generator import (
    generate_chef_avatar,
    upload_avatar_to_storage,
    update_user_avatar_metadata,
)

router = APIRouter()

MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB


class AvatarResponse(BaseModel):
    avatar_url: str


@router.post("/avatar", response_model=AvatarResponse)
async def generate_avatar(
    file: UploadFile = File(..., description="JPEG or PNG photo of the user's face"),
    user_id: str = Depends(get_current_user),
):
    """
    1. Validate upload
    2. Generate Pixar chef avatar via Replicate (~20–40 s)
    3. Store result in Supabase Storage
    4. Update Supabase auth metadata so iOS session refresh picks it up
    5. Return permanent URL
    """
    # 1. Validate
    if file.content_type not in ("image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"):
        raise HTTPException(status_code=400, detail="File must be a JPEG, PNG, WEBP, or HEIC image")

    image_bytes = await file.read()
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image too large — maximum 10 MB")
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")

    # 2. Generate via Replicate
    try:
        generated_bytes = await generate_chef_avatar(image_bytes)
    except Exception as e:
        detail = f"{type(e).__name__}: {e}"
        print(f"[profile/avatar] generation error: {detail}")
        raise HTTPException(status_code=502, detail=detail)

    # 3. Store in Supabase Storage
    try:
        avatar_url = await upload_avatar_to_storage(user_id, generated_bytes)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))

    # 4. Update auth metadata (best-effort — don't fail the request if this errors)
    await update_user_avatar_metadata(user_id, avatar_url)

    # 5. Return URL
    return AvatarResponse(avatar_url=avatar_url)
