import pytest
from app.services.ingestion.platform_detector import detect_platform, UnsupportedPlatformError


def test_detects_tiktok():
    url = "https://www.tiktok.com/@alfiecooks_/video/7617527660482268438"
    assert detect_platform(url) == "tiktok"


def test_detects_tiktok_without_www():
    url = "https://tiktok.com/@creator/video/123"
    assert detect_platform(url) == "tiktok"


def test_detects_instagram():
    url = "https://www.instagram.com/reel/ABC123/"
    assert detect_platform(url) == "instagram"


def test_raises_for_unsupported_platform():
    with pytest.raises(UnsupportedPlatformError):
        detect_platform("https://youtube.com/watch?v=abc")


def test_raises_for_random_url():
    with pytest.raises(UnsupportedPlatformError):
        detect_platform("https://example.com/recipe")
