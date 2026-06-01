"""
AI chef avatar generation using Replicate's face-to-many model.

Model: fofr/face-to-many (Pixar style)
Cost:  ~$0.02–0.05 per image
Flow:  user photo → base64 → Replicate → output URL → download → Supabase Storage
"""
import base64
import io

import httpx

from app.config import settings


# ── Replicate ──────────────────────────────────────────────────────────────────

async def generate_chef_avatar(image_bytes: bytes) -> bytes:
    """
    Sends image_bytes to Replicate's fofr/face-to-many model (Pixar style)
    and returns the generated image as bytes.

    Raises RuntimeError on any failure.
    """
    if not settings.replicate_api_token:
        raise RuntimeError("REPLICATE_API_TOKEN is not configured")

    import replicate

    # Replicate accepts base64 data URIs directly — no temp storage needed.
    b64 = base64.b64encode(image_bytes).decode()
    data_uri = f"data:image/jpeg;base64,{b64}"

    client = replicate.Client(api_token=settings.replicate_api_token)

    # Pin to the specific version hash — without it Replicate returns 404 because
    # the model has no "default" deployment configured.
    MODEL = "fofr/face-to-many:a07f252abbbd832009640b27f063ea52d87d7a23a185ca165bec23b5adc8deaf"

    # use_file_output=False → output is a plain list of URL strings (no FileOutput wrapping)
    output = await client.async_run(
        MODEL,
        input={
            "image": data_uri,
            "style": "3D",
            "prompt": "cute chef wearing a white chef hat and apron, warm cozy kitchen background, soft lighting, friendly smile, high quality",
            "negative_prompt": "ugly, blurry, bad anatomy, distorted face, watermark",
            "number_of_outputs": 1,
            "number_of_images_per_pose": 1,
            "output_format": "jpg",
            "output_quality": 90,
        },
        use_file_output=False,
    )

    # output is a list of URL strings
    if not output:
        raise RuntimeError("Replicate returned no output")

    image_url = str(output[0])
    async with httpx.AsyncClient(timeout=60.0) as http:
        resp = await http.get(image_url)
        resp.raise_for_status()
        return resp.content


# ── Supabase Storage ───────────────────────────────────────────────────────────

async def upload_avatar_to_storage(user_id: str, image_bytes: bytes) -> str:
    """
    Uploads image_bytes to the Supabase Storage `avatars` bucket and returns
    the permanent public URL.

    The bucket must exist and be set to public. This uses the service-role key
    so it bypasses RLS.
    """
    path = f"{user_id}.jpg"
    upload_url = f"{settings.supabase_url}/storage/v1/object/avatars/{path}"

    headers = {
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "image/jpeg",
        # Overwrite if the user regenerates their avatar
        "x-upsert": "true",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(upload_url, headers=headers, content=image_bytes)
        if resp.status_code not in (200, 201):
            raise RuntimeError(f"Storage upload failed: {resp.status_code} {resp.text}")

    return f"{settings.supabase_url}/storage/v1/object/public/avatars/{path}"


# ── Supabase Auth metadata ─────────────────────────────────────────────────────

async def update_user_avatar_metadata(user_id: str, avatar_url: str) -> None:
    """
    Updates the Supabase auth user's user_metadata.avatar_url via the Admin API
    so that refreshing the session on the iOS side picks up the new image.
    """
    url = f"{settings.supabase_url}/auth/v1/admin/users/{user_id}"
    headers = {
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "apikey": settings.supabase_service_role_key,
        "Content-Type": "application/json",
    }
    body = {"user_metadata": {"avatar_url": avatar_url}}

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.put(url, headers=headers, json=body)
        if resp.status_code not in (200, 201):
            # Non-fatal — the iOS side caches the URL locally anyway
            print(f"[avatar] metadata update failed: {resp.status_code} {resp.text}")
