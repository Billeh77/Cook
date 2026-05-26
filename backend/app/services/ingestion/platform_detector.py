from urllib.parse import urlparse


class UnsupportedPlatformError(Exception):
    pass


SUPPORTED_PLATFORMS = {
    "tiktok.com": "tiktok",
    "www.tiktok.com": "tiktok",
    "instagram.com": "instagram",
    "www.instagram.com": "instagram",
}


def detect_platform(url: str) -> str:
    """
    Detects the platform from a URL.

    Returns "tiktok" or "instagram".
    Raises UnsupportedPlatformError if the URL is not from a supported platform.
    """
    try:
        parsed = urlparse(url)
        host = parsed.netloc.lower().lstrip("www.")
        # Try with and without www prefix
        platform = SUPPORTED_PLATFORMS.get(parsed.netloc.lower()) or SUPPORTED_PLATFORMS.get(
            f"www.{parsed.netloc.lower()}"
        )
        if not platform:
            # Try stripping www
            bare = parsed.netloc.lower().removeprefix("www.")
            platform = SUPPORTED_PLATFORMS.get(bare)

        if not platform:
            raise UnsupportedPlatformError(
                f"Unsupported platform '{parsed.netloc}'. Supported: tiktok, instagram"
            )
        return platform
    except UnsupportedPlatformError:
        raise
    except Exception as e:
        raise UnsupportedPlatformError(f"Could not parse URL: {e}")
