"""
Instagram ingestion using Playwright to render the page and extract visible text.

Instagram blocks direct HTTP requests and oEmbed requires a Meta access token,
so we use a headless Chromium browser.  The rendered body.innerText contains the
full creator caption — something raw HTTP cannot access.

Speed strategy: a singleton Browser is kept alive for the lifetime of the process.
Launching Chromium once (on first request) costs ~1–2 s; subsequent requests each
open a fresh BrowserContext in the existing browser, which takes <200 ms.

Best-effort: Instagram may occasionally show a login wall or change their DOM.
When that happens caption_text will be None and the route returns needs_manual_review.
"""
import asyncio
import re
from urllib.parse import urlparse, urlunparse

from playwright.async_api import (
    async_playwright,
    Browser,
    Playwright,
    TimeoutError as PlaywrightTimeoutError,
)

from app.services.ingestion.tiktok_oembed import RawVideoData


class InstagramIngestionError(Exception):
    pass


# ── Singleton browser ─────────────────────────────────────────────────────────
# Kept alive for the process lifetime so every Instagram ingest reuses the same
# Chromium process instead of launching a new one per request.

_pw: Playwright | None = None
_browser: Browser | None = None
_browser_lock = asyncio.Lock()

_LAUNCH_ARGS = [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--disable-dev-shm-usage",   # avoids /dev/shm OOM in containers
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
]


async def _get_browser() -> Browser:
    """Return the shared Browser, (re)launching it if needed."""
    global _pw, _browser
    async with _browser_lock:
        if _browser is None or not _browser.is_connected():
            # Clean up any stale playwright instance
            if _pw is not None:
                try:
                    await _pw.stop()
                except Exception:
                    pass
            _pw = await async_playwright().start()
            _browser = await _pw.chromium.launch(headless=True, args=_LAUNCH_ARGS)
    return _browser


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


# ── Creator name extraction ───────────────────────────────────────────────────

def _parse_creator_name(og_title: str | None, og_desc: str | None) -> str | None:
    """
    Robustly extract the creator's display name from Instagram metadata.

    og:description after JS render typically follows:
        "12K Likes, 45 Comments - handle on Instagram: \"caption text…\""
    That's the most reliable source — try it first.

    og:title is only trusted when it contains @ or • (clear name markers).
    If it looks like a full caption sentence we skip it entirely, which avoids
    saving the recipe caption as the creator name.
    """
    # 1. og:description — "... - Name on Instagram: ..."
    if og_desc:
        m = re.search(r"[-–]\s*(.+?)\s+on\s+Instagram", og_desc, re.IGNORECASE)
        if m:
            name = m.group(1).strip()
            if name and len(name) < 80 and name.lower() != "instagram":
                return name

    # 2. og:title — only if it contains a username marker
    if og_title and og_title.lower() not in ("instagram", ""):
        if "@" in og_title or "•" in og_title:
            # "Display Name (@handle) • Instagram photos and videos"
            m = re.match(r"^(.+?)\s*[\(@•]", og_title)
            if m:
                name = m.group(1).strip()
                if name and name.lower() != "instagram":
                    return name

    return None


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
    Walk the rendered page lines and keep only the caption region:
    - Skip known UI-chrome lines.
    - Stop at footer / 'suggested' signals.
    - Cap at 120 lines (avoids sending a full comment thread to the LLM).

    The LLM extractor already knows to ignore social noise, so we just need
    reasonable trimming, not perfect isolation.
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
    Render an Instagram Reel with the shared headless Chromium and extract text.

    Returns RawVideoData in the same shape as TikTok ingestion so the route
    can handle both platforms identically.
    """
    clean_url = _clean_instagram_url(url)

    browser = await _get_browser()
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

    try:
        await page.goto(clean_url, wait_until="domcontentloaded", timeout=30_000)

        # Wait until the main content article appears — returns as soon as it's
        # ready rather than sleeping a fixed amount of time.
        try:
            await page.wait_for_selector("article", timeout=7_000)
        except PlaywrightTimeoutError:
            # No article element → probably a login wall; we'll detect that below
            # via the short caption check.
            pass

        # Read metadata (populated by client-side JS after hydration).
        thumbnail_url: str | None = await page.evaluate(
            "document.querySelector('meta[property=\"og:image\"]')?.content ?? null"
        )
        og_title: str | None = await page.evaluate(
            "document.querySelector('meta[property=\"og:title\"]')?.content ?? null"
        )
        og_desc: str | None = await page.evaluate(
            "document.querySelector('meta[property=\"og:description\"]')?.content ?? null"
        )
        body_text: str = await page.evaluate("document.body.innerText")

    except PlaywrightTimeoutError:
        raise InstagramIngestionError(f"Timed out loading Instagram URL: {clean_url}")
    finally:
        await page.close()
        await context.close()

    creator_name = _parse_creator_name(og_title, og_desc)
    caption_text = _extract_caption_region(body_text)

    # < 30 chars remaining → Instagram showed a login wall.
    if len(caption_text) < 30:
        caption_text = None

    return RawVideoData(
        platform="instagram",
        source_url=clean_url,
        creator_name=creator_name,
        caption_text=caption_text,
        thumbnail_url=thumbnail_url,
        embed_html=None,   # Instagram has no public oEmbed embed HTML
    )
