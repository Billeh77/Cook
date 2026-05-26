import httpx
from pydantic import BaseModel


OEMBED_ENDPOINT = "https://www.tiktok.com/oembed"
USER_AGENT = "Mozilla/5.0 (compatible; GroceryListApp/0.1)"


class RawVideoData(BaseModel):
    platform: str
    source_url: str
    creator_name: str | None = None
    creator_url: str | None = None
    caption_text: str | None = None
    thumbnail_url: str | None = None
    embed_html: str | None = None


class TikTokOEmbedError(Exception):
    pass


async def fetch_tiktok_oembed(url: str) -> RawVideoData:
    """
    Fetches public TikTok video metadata using the oEmbed API.
    No API key required. Returns RawVideoData.

    The TikTok oEmbed 'title' field contains the full caption text.
    """
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(
            OEMBED_ENDPOINT,
            params={"url": url},
            headers={"User-Agent": USER_AGENT},
        )

    if response.status_code != 200:
        raise TikTokOEmbedError(
            f"TikTok oEmbed returned {response.status_code}: {response.text[:200]}"
        )

    data = response.json()

    return RawVideoData(
        platform="tiktok",
        source_url=url,
        creator_name=data.get("author_name"),
        creator_url=data.get("author_url"),
        # TikTok returns the full caption in the 'title' field
        caption_text=data.get("title"),
        thumbnail_url=data.get("thumbnail_url"),
        embed_html=data.get("html"),
    )
