"""Text signals for deciding whether two reports describe the same issue.

The transformer score uses a pretrained sentence encoder. The word score is
the baseline: shared content words over the union of content words.
"""

from __future__ import annotations

import math
import re

_STOP = {
    "a",
    "an",
    "the",
    "and",
    "or",
    "of",
    "on",
    "in",
    "at",
    "by",
    "to",
    "for",
    "from",
    "with",
    "near",
    "is",
    "are",
    "was",
    "it",
    "this",
    "that",
    "there",
    "my",
    "our",
    "street",
    "road",
    "block",
}


def content_tokens(text: str) -> set[str]:
    words = re.findall(r"[a-z0-9]+", text.lower())
    return {word for word in words if word not in _STOP and len(word) > 2}


def jaccard(left: str, right: str) -> float:
    a = content_tokens(left)
    b = content_tokens(right)
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def cosine(left: list[float], right: list[float]) -> float:
    if len(left) != len(right) or not left:
        return 0.0
    dot = 0.0
    norm_l = 0.0
    norm_r = 0.0
    for a, b in zip(left, right):
        dot += a * b
        norm_l += a * a
        norm_r += b * b
    if norm_l <= 0 or norm_r <= 0:
        return 0.0
    return dot / math.sqrt(norm_l * norm_r)


EARTH_RADIUS_M = 6_371_000
MATCH_RADIUS_M = 40
ACTIVE_STATUSES = {"open", "in progress"}


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lon / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def is_text_candidate(
    category: str,
    other_category: str,
    other_status: str,
    lat: float,
    lon: float,
    other_lat: float,
    other_lon: float,
    radius_m: float = MATCH_RADIUS_M,
) -> bool:
    """True when an existing report is allowed into the cosine step.

    Resolved and draft reports stay out. A different category stays out.
    Anything farther than `radius_m` stays out.
    """
    if category.strip().lower() != other_category.strip().lower():
        return False
    if other_status.strip().lower() not in ACTIVE_STATUSES:
        return False
    return haversine_m(lat, lon, other_lat, other_lon) <= radius_m


_COMPASS = {
    "north": "n",
    "northbound": "n",
    "south": "s",
    "southbound": "s",
    "east": "e",
    "eastbound": "e",
    "west": "w",
    "westbound": "w",
}
_COMPASS_OPPOSITES = {("n", "s"), ("s", "n"), ("e", "w"), ("w", "e")}
_FRONTAGE = re.compile(r"\bin front of the ([a-z]+)\b")
_FRONTAGE_IGNORE = {
    "asphalt",
    "curb",
    "corner",
    "gutter",
    "intersection",
    "lane",
    "pavement",
    "road",
    "shoulder",
    "sidewalk",
    "street",
    "walk",
    "walkway",
}
_POSITIONS = ("stop bar", "crosswalk", "driveway", "hydrant", "mailbox")
_LAMP_OFF = re.compile(
    r"\b(does not turn on|will not come on|does not come on|stays dark|is dark|is out|out at night)\b"
)
_LAMP_ON = re.compile(r"\b(stays on all day|on all day|never shuts off)\b")
_ANIMALS = {
    "deer": "deer",
    "raccoon": "raccoon",
    "dog": "dog",
    "rat": "rat",
    "rats": "rat",
    "cat": "cat",
    "squirrel": "squirrel",
    "bird": "bird",
}


def _compass_codes(text: str) -> set[str]:
    codes = set()
    for word in re.findall(r"[a-z]+", text):
        code = _COMPASS.get(word)
        if code:
            codes.add(code)
    return codes


def _lane_sides(text: str) -> set[str]:
    sides = set()
    if re.search(r"\b(left lane|left side)\b", text):
        sides.add("left")
    if re.search(r"\b(right lane|right side)\b", text):
        sides.add("right")
    return sides


def _frontage_landmarks(text: str) -> set[str]:
    return {
        match
        for match in _FRONTAGE.findall(text)
        if match not in _FRONTAGE_IGNORE
    }


def _positions(text: str) -> set[str]:
    return {phrase for phrase in _POSITIONS if phrase in text}


def _animals(text: str) -> set[str]:
    found = set()
    for word in re.findall(r"[a-z]+", text):
        animal = _ANIMALS.get(word)
        if animal:
            found.add(animal)
    return found


def _lamp_state(text: str) -> str | None:
    off = _LAMP_OFF.search(text) is not None
    on = _LAMP_ON.search(text) is not None
    if off and not on:
        return "off"
    if on and not off:
        return "on"
    return None


def descriptions_conflict(left: str, right: str) -> bool:
    """True when the wording names two different places, states, or animals.

    A high cosine is not a duplicate in those cases. The checks are vetoes:
    they never create a match on their own.
    """
    left_l = left.lower()
    right_l = right.lower()
    left_compass = _compass_codes(left_l)
    right_compass = _compass_codes(right_l)
    if left_compass and right_compass and left_compass.isdisjoint(right_compass):
        for a in left_compass:
            for b in right_compass:
                if (a, b) in _COMPASS_OPPOSITES:
                    return True
    left_sides = _lane_sides(left_l)
    right_sides = _lane_sides(right_l)
    if left_sides and right_sides and left_sides.isdisjoint(right_sides):
        return True
    if ("upstream" in left_l and "downstream" in right_l) or (
        "downstream" in left_l and "upstream" in right_l
    ):
        return True
    left_front = _frontage_landmarks(left_l)
    right_front = _frontage_landmarks(right_l)
    if left_front and right_front and left_front.isdisjoint(right_front):
        return True
    left_pos = _positions(left_l)
    right_pos = _positions(right_l)
    if left_pos and right_pos and left_pos.isdisjoint(right_pos):
        return True
    left_animals = _animals(left_l)
    right_animals = _animals(right_l)
    if left_animals and right_animals and left_animals.isdisjoint(right_animals):
        return True
    left_lamp = _lamp_state(left_l)
    right_lamp = _lamp_state(right_l)
    if left_lamp and right_lamp and left_lamp != right_lamp:
        return True
    left_sign = _sign_failures(left_l)
    right_sign = _sign_failures(right_l)
    if left_sign and right_sign and left_sign.isdisjoint(right_sign):
        return True
    return False


def _sign_failures(text: str) -> set[str]:
    if not re.search(r"\bsign\b", text):
        return set()
    modes = set()
    if re.search(r"\b(knocked|lying|spun|wrong direction|wrong way)\b", text) or "facing the wrong" in text:
        modes.add("down")
    if "blocked by" in text:
        modes.add("obscured")
    if re.search(r"\b(faded|wrong hours|legend)\b", text):
        modes.add("legend")
    return modes


def is_same_issue(score: float, left: str, right: str, threshold: float = 0.5) -> bool:
    if score < threshold:
        return False
    return not descriptions_conflict(left, right)


def report_text(title: str, description: str) -> str:
    title = title.strip()
    description = description.strip()
    if not title:
        return description
    if not description:
        return title
    return f"{title}. {description}"
