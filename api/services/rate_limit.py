"""In-process sliding-window limits.

Counters live in this process only. A second API instance does not share them.
"""

from __future__ import annotations

import time
from collections import defaultdict
from threading import Lock

from fastapi import HTTPException, Request, status

_lock = Lock()
_buckets: dict[str, list[float]] = defaultdict(list)


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        first = forwarded.split(",")[0].strip()
        if first:
            return first
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def hit(bucket: str, key: str, *, limit: int, window_seconds: int) -> None:
    now = time.monotonic()
    slot = f"{bucket}:{key}"
    with _lock:
        recent = [stamp for stamp in _buckets[slot] if now - stamp < window_seconds]
        if len(recent) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Try again in a little while.",
            )
        recent.append(now)
        _buckets[slot] = recent
        if len(_buckets) > 20000:
            cutoff = now - max(window_seconds, 3600)
            stale = [
                name
                for name, stamps in _buckets.items()
                if not stamps or stamps[-1] < cutoff
            ]
            for name in stale:
                _buckets.pop(name, None)
