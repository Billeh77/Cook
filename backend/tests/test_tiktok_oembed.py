import pytest
import json
from unittest.mock import AsyncMock, patch, MagicMock

from app.services.ingestion.tiktok_oembed import fetch_tiktok_oembed, TikTokOEmbedError

MOCK_OEMBED_RESPONSE = {
    "version": "1.0",
    "type": "video",
    "title": "10 MINUTE PEANUT BUTTER + CHILLI CRISP NOODLES 🤤 2 tbsp crunchy peanut butter 1 tbsp minced garlic",
    "author_name": "ALFIE STEINER",
    "author_url": "https://www.tiktok.com/@alfiecooks_",
    "provider_name": "TikTok",
    "provider_url": "https://www.tiktok.com",
    "thumbnail_url": "https://example.com/thumb.jpg",
    "html": "<blockquote>...</blockquote>",
}


@pytest.mark.asyncio
async def test_fetch_tiktok_oembed_success():
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = MOCK_OEMBED_RESPONSE

    with patch("httpx.AsyncClient") as mock_client_class:
        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.get = AsyncMock(return_value=mock_response)
        mock_client_class.return_value = mock_client

        result = await fetch_tiktok_oembed("https://www.tiktok.com/@alfiecooks_/video/123")

    assert result.platform == "tiktok"
    assert result.creator_name == "ALFIE STEINER"
    assert result.creator_url == "https://www.tiktok.com/@alfiecooks_"
    assert "peanut butter" in result.caption_text
    assert result.thumbnail_url == "https://example.com/thumb.jpg"


@pytest.mark.asyncio
async def test_fetch_tiktok_oembed_not_found():
    mock_response = MagicMock()
    mock_response.status_code = 404
    mock_response.text = "Not found"

    with patch("httpx.AsyncClient") as mock_client_class:
        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.get = AsyncMock(return_value=mock_response)
        mock_client_class.return_value = mock_client

        with pytest.raises(TikTokOEmbedError):
            await fetch_tiktok_oembed("https://www.tiktok.com/@creator/video/bad")
