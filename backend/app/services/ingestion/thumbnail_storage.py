"""
Downloads a thumbnail from an expiring CDN URL and re-hosts it in Supabase
Storage so the URL is permanent and never subject to token expiry.

Requires:
  - SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars set on the server
  - A public Storage bucket named "thumbnails" created in the Supabase dashboard
"""
import httpx
from app.config import settings

BUCKET = "thumbnails"


async def rehost_thumbnail(source_url: str, recipe_id: str) -> str | None:
    """
    Downloads `source_url` and uploads it to Supabase Storage under
    thumbnails/<recipe_id>.<ext>.

    Returns the permanent public URL on success, or None if anything fails
    (caller keeps the original URL as a fallback).
    """
    if not settings.supabase_service_role_key or not settings.supabase_url:
        return None

    try:
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
            # 1. Download from the external CDN
            dl = await client.get(source_url)
            if dl.status_code != 200:
                print(f"[thumbnail_storage] download failed ({dl.status_code}): {source_url[:80]}")
                return None

            image_bytes = dl.content
            content_type = dl.headers.get("content-type", "image/jpeg").split(";")[0].strip()
            ext = "png" if "png" in content_type else "jpg"

            # 2. Upload to Supabase Storage
            path = f"{recipe_id}.{ext}"
            upload = await client.post(
                f"{settings.supabase_url}/storage/v1/object/{BUCKET}/{path}",
                content=image_bytes,
                headers={
                    "Authorization": f"Bearer {settings.supabase_service_role_key}",
                    "Content-Type": content_type,
                    "x-upsert": "true",
                },
            )

            if upload.status_code in (200, 201):
                public_url = (
                    f"{settings.supabase_url}/storage/v1/object/public/{BUCKET}/{path}"
                )
                print(f"[thumbnail_storage] stored: {public_url}")
                return public_url
            else:
                print(f"[thumbnail_storage] upload failed ({upload.status_code}): {upload.text[:200]}")

    except Exception as e:
        print(f"[thumbnail_storage] error: {e}")

    return None
