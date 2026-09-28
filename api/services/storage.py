"""Upload images to Supabase Storage; DB only stores the public URL."""

from __future__ import annotations

import base64
import os
import time
import uuid
from typing import Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import HTTPException

_MIME_TO_EXT = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
}


def _credentials() -> Tuple[str, str]:
    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    service_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY") or ""
    if not supabase_url or not service_key:
        raise HTTPException(
            status_code=503,
            detail=(
                "Image storage is not configured. Set SUPABASE_URL and "
                "SUPABASE_SERVICE_KEY in the API .env."
            ),
        )
    return supabase_url, service_key


def _report_bucket() -> str:
    return os.getenv("SUPABASE_STORAGE_BUCKET") or "report-images"


def _avatar_bucket() -> str:
    return os.getenv("SUPABASE_AVATAR_BUCKET") or "profile-pictures"


def _upload_bytes(
    *,
    bucket: str,
    object_path: str,
    data: bytes,
    content_type: str,
) -> str:
    supabase_url, service_key = _credentials()
    upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{object_path}"

    req = Request(upload_url, data=data, method="POST")
    req.add_header("Authorization", f"Bearer {service_key}")
    req.add_header("apikey", service_key)
    req.add_header("Content-Type", content_type)
    req.add_header("x-upsert", "true")

    try:
        with urlopen(req, timeout=60) as resp:
            if resp.status not in (200, 201):
                body = resp.read().decode("utf-8", errors="replace")
                raise HTTPException(
                    status_code=502,
                    detail=f"Storage upload failed ({resp.status}): {body}",
                )
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise HTTPException(
            status_code=502,
            detail=f"Storage upload failed ({e.code}): {body}",
        ) from e
    except URLError as e:
        raise HTTPException(
            status_code=502,
            detail=f"Could not reach Supabase Storage: {e.reason}",
        ) from e

    return f"{supabase_url}/storage/v1/object/public/{bucket}/{object_path}"


MAX_IMAGE_BYTES = 8 * 1024 * 1024


def _sniff_image(data: bytes) -> str:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    raise HTTPException(
        status_code=400,
        detail="Upload must be a JPEG, PNG, GIF, or WebP image",
    )


def _checked_image(data: bytes) -> Tuple[bytes, str, str]:
    if not data:
        raise HTTPException(status_code=400, detail="Empty image upload")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image must be 8 MB or smaller")
    content_type = _sniff_image(data)
    return data, content_type, _MIME_TO_EXT[content_type]


def assert_storage_image_url(url: str) -> str:
    """Only keep image links that already live in this project's Storage."""
    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    prefix = f"{supabase_url}/storage/v1/object/public/"
    value = url.strip()
    if not supabase_url or not value.startswith(prefix):
        raise HTTPException(
            status_code=400,
            detail="Image URL must be a Street Sync storage link",
        )
    return value


def upload_report_image(
    data: bytes,
    content_type: str = "image/jpeg",
    filename: Optional[str] = None,
) -> str:
    _ = (content_type, filename)
    data, content_type, ext = _checked_image(data)
    object_path = f"reports/{uuid.uuid4().hex}.{ext}"
    return _upload_bytes(
        bucket=_report_bucket(),
        object_path=object_path,
        data=data,
        content_type=content_type,
    )


def upload_user_picture(
    *,
    user_id: int,
    data: bytes,
    content_type: str = "image/jpeg",
    filename: Optional[str] = None,
) -> str:
    """Upload (or replace) a profile avatar in the dedicated avatars bucket."""
    data, content_type, ext = _checked_image(data)
    _ = filename
    object_path = f"{user_id}.{ext}"
    url = _upload_bytes(
        bucket=_avatar_bucket(),
        object_path=object_path,
        data=data,
        content_type=content_type,
    )
    # Bust CDN / client caches when the same object path is overwritten.
    return f"{url}?v={int(time.time())}"


def persist_report_image(image: Optional[str]) -> Optional[str]:
    """
    Normalize an image field for DB storage.
    - None / empty → None
    - http(s) URL → keep as-is (already in Storage)
    - data URI / raw base64 → upload to Storage, return public URL
    """
    if image is None:
        return None
    value = image.strip()
    if not value:
        return None
    if value.startswith("http://") or value.startswith("https://"):
        return value

    content_type = "image/jpeg"
    raw = value
    if value.startswith("data:") and ";base64," in value:
        header, raw = value.split(";base64,", 1)
        # data:image/jpeg
        if ":" in header:
            content_type = header.split(":", 1)[1].strip() or content_type

    try:
        data = base64.b64decode(raw, validate=False)
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid image data") from e

    return upload_report_image(data, content_type=content_type)
