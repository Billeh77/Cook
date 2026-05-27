"""
FastAPI dependencies for authentication.

Every protected route depends on get_current_user(), which calls the
Supabase auth API to validate the bearer token. This approach never
needs the JWT secret and handles key rotation automatically.
"""
import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.config import settings

_bearer = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> str:
    """
    Validates a Supabase access token by calling the Supabase Auth API.

    Returns the authenticated user's UUID (the `id` field from Supabase's
    /auth/v1/user response, which equals the `sub` claim in the JWT).

    Raises 401 if the token is missing, expired, or invalid.
    Raises 503 if the Supabase auth service is unreachable.
    """
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Auth not configured on server",
        )

    token = credentials.credentials

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{settings.supabase_url}/auth/v1/user",
                headers={
                    "Authorization": f"Bearer {token}",
                    "apikey": settings.supabase_anon_key,
                },
            )
    except httpx.RequestError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Auth service unreachable",
        )

    if response.status_code == 401:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Auth service returned {response.status_code}",
        )

    data = response.json()
    user_id: str | None = data.get("id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token valid but user ID missing",
        )

    return user_id
