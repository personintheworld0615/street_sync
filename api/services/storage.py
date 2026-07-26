"""Upload report images to Supabase Storage; DB only stores the public URL."""

from __future__ import annotations

import base64
import os
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


def _config() -> Tuple[str, str, str]:
    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    service_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY") or ""
    bucket = os.getenv("SUPABASE_STORAGE_BUCKET") or "report-images"
    if not supabase_url or not service_key:
        raise HTTPException(
            status_code=503,
            detail=(
                "Image storage is not configured. Set SUPABASE_URL and "
                "SUPABASE_SERVICE_KEY in the API .env."
            ),
        )
    return supabase_url, service_key, bucket


def upload_report_image(
    data: bytes,
    content_type: str = "image/jpeg",
    filename: Optional[str] = None,
) -> str:
    if not data:
        raise HTTPException(status_code=400, detail="Empty image upload")

    supabase_url, service_key, bucket = _config()
    content_type = (content_type or "image/jpeg").split(";")[0].strip().lower()
    ext = _MIME_TO_EXT.get(content_type)
    if not ext and filename and "." in filename:
        ext = filename.rsplit(".", 1)[-1].lower()
    if not ext:
        ext = "jpg"
        content_type = "image/jpeg"

    object_path = f"reports/{uuid.uuid4().hex}.{ext}"
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
