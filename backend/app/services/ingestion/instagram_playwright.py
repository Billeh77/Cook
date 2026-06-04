"""
Instagram ingestion using Playwright to render the page and extract visible text.

Instagram blocks direct HTTP requests and oEmbed requires a Meta access token,
so we use a headless Chromium browser. The rendered body.innerText contains the
full creator caption — something raw HTTP cannot access.

Best-effort: Instagram may occasionally show a login wall or change their DOM.
When that happens, caption_text will be None and the route returns needs_manual_review.
"""
import re
from urllib.parse import urlparse, urlunparse

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

from app.services.ingestion.tiktok_oembed import RawVideoData


class InstagramIngestionError(Exception):
    pass


# ── URL normalisation ─────────────────────────────────────────────────────────

def _clean_instagram_url(url: str) -> str:
    """
    Strip tracking / referral query params (e.g. igsh=, igshid=) and keep only
    the canonical reel path:  https://www.instagram.com/reel/<ID>/
    """
    parsed = urlparse(url)
    # Force https + www for consistency
    clean = parsed._replace(
        scheme="https",
        netloc="www.instagram.com",
        query="",
        fragment="",
    )
    return urlunparse(clean)


# ── Text cleaning ─────────────────────────────────────────────────────────────

# These strings, when found in a line, signal we've left the caption region.
_STOP_SIGNALS = [
    "About",
    "Help",
    "Press",
    "API",
    "Jobs",
    "Privacy",
    "Terms",
    "Locations",
    "Meta Verified",
    "© 202",
    "Suggested for you",
    "See more posts from",
]

# Line-level noise patterns to drop (case-insensitive).
_NOISE_RE = re.compile(
    r"^("
    r"Log in"
    r"|Sign up"
    r"|Instagram"
    r"|See more"
    r"|More options"
    r"|Follow"
    r"|Following"
    r"|Message"
    r"|Comments?"
    r"|\d[\d,.KM]* likes?"
    r"|\d[\d,.KM]* comments?"
    r"|View all \d+ comments?"
    r"|See translation"
    r"|Translate"
    r"|Join .+ on Instagram"
    r"|Keep up with"
    r"|Share"
    r"|Save"
    r"|Like"
    r")$",
    re.IGNORECASE,
)


def _extract_caption_region(full_text: str) -> str:
    """
    Walk the lines of the rendered page and keep only the caption region:
    - Skip known UI-chrome lines.
    - Stop as soon as a footer / "suggested" signal appears.
    - Cap at 120 lines to avoid sending the whole comment section to the LLM.

    The LLM prompt already knows to extract recipe content and ignore social noise,
    so we don't need perfect isolation — just reasonable trimming.
    """
    lines = full_text.splitlines()
    kept: list[str] = []

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # Stop at footer / navigation boundary
        if any(sig in stripped for sig in _STOP_SIGNALS):
            break

        # Drop known chrome lines
        if _NOISE_RE.match(stripped):
            continue

        kept.append(stripped)

        # Cap to avoid ballooning context with comment threads
        if len(kept) >= 120:
            break

    return "\n".join(kept).strip()


# ── Main entry point ──────────────────────────────────────────────────────────

async def fetch_instagram_reel(url: str) -> RawVideoData:
    """
    Render an Instagram Reel URL with headless Chromium and extract visible text.

    Returns RawVideoData with the same shape as TikTok ingestion so the route
    can treat both platforms identically.
    """
    clean_url = _clean_instagram_url(url)

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",   # prevents /dev/shm OOM in containers
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

        try:
            await page.goto(clean_url, wait_until="domcontentloaded", timeout=30_000)
            # Give JS time to hydrate — Instagram is a heavy SPA.
            await page.wait_for_timeout(4_000)
        except PlaywrightTimeoutError:
            await browser.close()
            raise InstagramIngestionError(
                f"Timed out loading Instagram URL: {clean_url}"
            )

        # Grab meta tags (now populated by client-side JS) and body text.
        thumbnail_url: str | None = await page.evaluate(
            "document.querySelector('meta[property=\"og:image\"]')?.content ?? null"
        )
        og_title: str | None = await page.evaluate(
            "document.querySelector('meta[property=\"og:title\"]')?.content ?? null"
        )
        body_text: str = await page.evaluate("document.body.innerText")

        await browser.close()

    # ── Parse creator name from og:title ─────────────────────────────────────
    creator_name: str | None = None
    if og_title and og_title.lower() not in ("instagram", ""):
        # og:title is often "Display Name (@handle) • Instagram photos and videos"
        m = re.match(r"^(.+?)\s*[\(@•]", og_title)
        creator_name = m.group(1).strip() if m else og_title.split("•")[0].strip()
        if creator_name.lower() == "instagram":
            creator_name = None

    # ── Clean body text ───────────────────────────────────────────────────────
    caption_text = _extract_caption_region(body_text)

    # If less than ~30 chars remain, Instagram likely showed a login wall.
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
