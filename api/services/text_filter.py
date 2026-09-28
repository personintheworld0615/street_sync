"""Block obvious profanity in report text. A word list, not a moderation team."""

import re

from fastapi import HTTPException

# Whole words only, so street names are less likely to match by accident.
_BLOCKED = {
    "fuck",
    "fucking",
    "fucker",
    "shit",
    "shitting",
    "bitch",
    "bastard",
    "asshole",
    "dick",
    "cock",
    "pussy",
    "cunt",
    "nigger",
    "nigga",
    "faggot",
    "fag",
    "retard",
    "slut",
    "whore",
}

_WORD = re.compile(r"[a-z0-9']+")


def assert_clean(*parts: str) -> None:
    for part in parts:
        for word in _WORD.findall(part.lower()):
            if word in _BLOCKED:
                raise HTTPException(
                    status_code=400,
                    detail="Please remove inappropriate language and try again.",
                )
