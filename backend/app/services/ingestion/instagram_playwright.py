"""
Instagram ingestion using Playwright to render the page and extract visible text.

Instagram blocks direct HTTP requests and oEmbed requires a Meta access token,
so we use a headless Chromium browser. The rendered body.innerText contains the
full creator caption — something raw HTTP cannot access.

Best-effort: Instagram may occasionally show a login wall or change their DOM.
When that happens caption_text will be None and the route returns needs_manual_review.
"""
import re
from urllib.parse import urlparse, urlunparse

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

from app.services.ingestion.tiktok_oembed import RawVideoData


class InstagramIngestionError(Exception):
    pass


# ── URL normalisation ─────────────────────────────────────────────────────────

def _clean_instagram_url(url: str) -> str:
    """Strip tracking query params (igsh=, igshid=, …) and keep only the reel path."""
    parsed = urlparse(url)
    clean = parsed._replace(
        scheme="https",
        netloc="www.instagram.com",
        query="",
        fragment="",
    )
    return urlunparse(clean)


# ── Text cleaning ─────────────────────────────────────────────────────────────

_STOP_SIGNALS = [
    "About", "Help", "Press", "API", "Jobs", "Privacy", "Terms",
    "Locations", "Meta Verified", "© 202", "Suggested for you",
    "See more posts from",
]

_NOISE_RE = re.compile(
    r"^("
    r"Log in|Sign up|Instagram|See more|More options"
    r"|Follow|Following|Message|Comments?"
    r"|\d[\d,.KM]* likes?"
    r"|\d[\d,.KM]* comments?"
    r"|View all \d+ comments?"
    r"|See translation|Translate"
    r"|Join .+ on Instagram|Keep up with"
    r"|Share|Save|Like"
    r")$",
    re.IGNORECASE,
)


def _extract_caption_region(full_text: str) -> str:
    """
    Walk the rendered page lines and keep only the caption region.
    Stops at footer/navigation signals and caps at 120 lines.
    """
    kept: list[str] = []
    for line in full_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if any(sig in stripped for sig in _STOP_SIGNALS):
            break
        if _NOISE_RE.match(stripped):
            continue
        kept.append(stripped)
        if len(kept) >= 120:
            break
    return "\n".join(kept).strip()


# ── Main entry point ──────────────────────────────────────────────────────────

async def fetch_instagram_reel(url: str) -> RawVideoData:
    """
    Render an Instagram Reel with headless Chromium and extract visible text.
    Returns RawVideoData in the same shape as TikTok ingestion.
    """
    clean_url = _clean_instagram_url(url)

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu",
                    "--no-first-run",
                    "--no-default-browser-check",
                ],
            )
            context = await browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
                locale="en-US",
                viewport={"width": 1280, "height": 900},
            )
            page = await context.new_page()

            await page.goto(clean_url, wait_until="domcontentloaded", timeout=30_000)

            try:
                await page.wait_for_selector("article", timeout=7_000)
            except PlaywrightTimeoutError:
                pass  # Possible login wall — caption length check below will catch it.

            og_title: str | None = await page.evaluate(
                "document.querySelector('meta[property=\"og:title\"]')?.content ?? null"
            )
            thumbnail_url: str | None = await page.evaluate(
                "document.querySelector('meta[property=\"og:image\"]')?.content ?? null"
            )
            body_text: str = await page.evaluate("document.body.innerText")

            await browser.close()

    except PlaywrightTimeoutError as e:
        raise InstagramIngestionError(f"Timed out loading Instagram URL: {clean_url}") from e
    except Exception as e:
        # Catches Playwright launch failures (missing Chromium, OOM, etc.)
        raise InstagramIngestionError(
            f"Playwright error for {clean_url}: {type(e).__name__}: {e}"
        ) from e

    # ── Creator name ──────────────────────────────────────────────────────────
    # og:title format: 'Nick Nesgoda on Instagram: "caption..."'
    # Extract everything before " on Instagram".
    creator_name: str | None = None
    if og_title:
        marker = " on Instagram"
        idx = og_title.find(marker)
        if idx != -1:
            creator_name = og_title[:idx].strip() or None

    # ── Caption ───────────────────────────────────────────────────────────────
    caption_text = _extract_caption_region(body_text)
    if len(caption_text) < 30:
        caption_text = None  # Likely a login wall

    return RawVideoData(
        platform="instagram",
        source_url=clean_url,
        creator_name=creator_name,
        caption_text=caption_text,
        thumbnail_url=thumbnail_url,
        embed_html=None,
    )
