"""
Instagram ingestion using Playwright to render the page and extract visible text.

Instagram blocks direct HTTP requests, so we use a headless browser.
This is best-effort: Instagram may still block, login-gate, or change their DOM.

NOT implemented for v1 — placeholder shows the interface the route expects.
"""
from app.services.ingestion.tiktok_oembed import RawVideoData


class InstagramIngestionError(Exception):
    pass


async def fetch_instagram_reel(url: str) -> RawVideoData:
    """
    Fetches Instagram reel metadata by rendering the page with Playwright.
    Returns RawVideoData with the same shape as TikTok ingestion.

    TODO: implement with playwright
    """
    raise NotImplementedError(
        "Instagram ingestion is not yet implemented. "
        "Share a TikTok link for now."
    )
