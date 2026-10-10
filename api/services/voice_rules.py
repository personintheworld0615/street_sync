"""Free, rule-based steps for voice reports.

Everything here runs before any paid model call: transcript cleanup, keyword
categories, a "does this name a problem" check, and field / location
extraction. Keep rules conservative; a wrong rewrite is worse than none.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Normalize
# ---------------------------------------------------------------------------

# (pattern, replacement). Only high-confidence speech-to-text confusions.
_STT_FIXES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bpot[\s-]holes\b", re.I), "potholes"),
    (re.compile(r"\bpot[\s-]hole\b", re.I), "pothole"),
    (re.compile(r"\bwhole in the (road|street|sidewalk)\b", re.I), r"hole in the \1"),
    (re.compile(r"\bstreet[\s-]?lights\b", re.I), "street lights"),
    (re.compile(r"\bstreet[\s-]?light\b", re.I), "street light"),
    (re.compile(r"\bstreet[\s-]?lamps?\b", re.I), "street light"),
    (re.compile(r"\blamp[\s-]?posts?\b", re.I), "street light"),
    (re.compile(r"\blight poll\b", re.I), "light pole"),
    (re.compile(r"\bpoll (number|#|tag)\b", re.I), r"pole \1"),
    (re.compile(r"\btraffic lite\b", re.I), "traffic light"),
    (re.compile(r"\bstop lights?\b", re.I), "traffic light"),
    (re.compile(r"\bside[\s-]walks\b", re.I), "sidewalks"),
    (re.compile(r"\bside[\s-]walk\b", re.I), "sidewalk"),
    (re.compile(r"\bstorm[\s-]?drains\b", re.I), "storm drains"),
    (re.compile(r"\bstorm[\s-]?drain\b", re.I), "storm drain"),
    (re.compile(r"\bman[\s-]holes?\b", re.I), "manhole"),
    (re.compile(r"\b(?:grafitti|graffitti|grafiti|graffity|graffitti)\b", re.I), "graffiti"),
    (re.compile(r"\bfire hydrent\b", re.I), "fire hydrant"),
    (re.compile(r"\bside of the rode\b", re.I), "side of the road"),
]

# "bottle" is the most common STT miss for "pothole", but real bottles exist.
_BOTTLE = re.compile(r"\b(bottles?)\b", re.I)
_REAL_BOTTLE_BEFORE = re.compile(
    r"\b(?:water|glass|plastic|beer|wine|soda|empty|broken|liquor|a few|some)\s+$",
    re.I,
)
_LITTER_CONTEXT = re.compile(r"\b(?:litter|trash|garbage|recycl\w*|dumped|bin)\b", re.I)

_FILLER = re.compile(r"\b(?:um+|uh+|erm+|hmm+|you know)\b[,]?\s*", re.I)
_REPEATED_WORD = re.compile(r"\b(\w+)(?:\s+\1\b)+", re.I)
_SPACES = re.compile(r"\s+")


@dataclass
class Normalized:
    text: str
    replacements: list[str] = field(default_factory=list)
    filler_removed: int = 0


def normalize_transcript(raw: str) -> Normalized:
    text = raw.strip()
    replacements: list[str] = []

    for pattern, repl in _STT_FIXES:
        text, n = pattern.subn(repl, text)
        if n:
            replacements.append(f"{pattern.pattern}->{repl}")

    if not _LITTER_CONTEXT.search(text):
        def _bottle(match: re.Match[str]) -> str:
            if _REAL_BOTTLE_BEFORE.search(text[: match.start()]):
                return match.group(0)
            replacements.append("bottle->pothole")
            return "potholes" if match.group(1).lower().endswith("s") else "pothole"

        text = _BOTTLE.sub(_bottle, text)

    text, filler = _FILLER.subn("", text)
    text = _REPEATED_WORD.sub(r"\1", text)
    text = _SPACES.sub(" ", text).strip(" ,")
    return Normalized(text=text, replacements=replacements, filler_removed=filler)


# ---------------------------------------------------------------------------
# Keyword categories (fine-grained, same names as Jev's list)
# ---------------------------------------------------------------------------

_FINE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "Pothole": ("pothole", "potholes", "hole in the road", "hole in the street", "sinkhole"),
    "Damaged Sidewalk/Curb": ("sidewalk", "sidewalks", "curb", "kerb", "curb ramp"),
    "Traffic Light": ("traffic light", "traffic lights", "traffic signal", "walk signal", "crosswalk signal"),
    "Street Light": ("street light", "street lights", "light pole", "light is out", "lights are out"),
    "Damaged/Missing Sign": ("stop sign", "street sign", "road sign", "yield sign", "speed limit sign", "sign is missing", "sign is down"),
    "Road Debris": ("debris", "glass in the road", "rocks in the road", "tire in the road", "blocking the road"),
    "Parking/Traffic": ("parking", "parked", "double parked", "blocking my driveway", "speeding"),
    "Litter/Garbage": ("litter", "garbage", "trash everywhere", "overflowing trash", "trash can"),
    "Missed Trash/Recycling": ("recycling", "not picked up", "wasn't picked up", "missed pickup", "missed trash"),
    "Illegal Dumping": ("dumped", "dumping", "mattress", "old couch", "tires dumped"),
    "Graffiti": ("graffiti", "spray paint", "spray painted", "tagged"),
    "Pollution": ("pollution", "oil spill", "spill", "smoke", "fumes"),
    "Hazardous Waste": ("hazardous", "chemical", "needles", "syringe", "syringes", "asbestos"),
    "Noise": ("noise", "loud music", "too loud"),
    "Fallen Tree/Branch": ("fallen tree", "tree fell", "tree down", "fallen branch", "branch fell", "branches down"),
    "Overgrown Vegetation": ("overgrown", "weeds", "bushes blocking", "grass is too tall"),
    "Tree Maintenance": ("dead tree", "tree trimming", "tree needs", "tree is leaning", "dying tree"),
    "Flooding": ("flood", "flooded", "flooding"),
    "Clogged Storm Drain": ("storm drain", "storm drains", "catch basin", "drain is clogged", "clogged drain"),
    "Standing Water": ("standing water", "puddle", "water pooling"),
    "Sewer/Water Problem": ("sewer", "sewage", "water main", "manhole", "fire hydrant", "water leak", "broken pipe"),
    "Building Damage": ("building is damaged", "broken window", "roof is", "wall collapsed"),
    "Property Maintenance": ("abandoned house", "vacant lot", "vacant house", "boarded up"),
    "Construction/Code Violation": ("construction", "code violation", "no permit"),
    "Housing/Rental Problem": ("landlord", "rental", "tenant"),
    "Park Maintenance": ("park", "playground", "bench", "picnic table"),
    "Animal Issue": ("dead animal", "stray dog", "stray cat", "dead deer", "raccoon", "loose dog"),
    "Rodent/Insect Issue": ("rat", "rats", "rodent", "rodents", "mice", "roaches", "wasp nest", "bees"),
}

# Longer phrases are more specific than single words, so they weigh more.
_FINE_PATTERNS = {
    category: [
        (re.compile(rf"\b{re.escape(p)}\b", re.I), len(p.split()) + 1)
        for p in phrases
    ]
    for category, phrases in _FINE_KEYWORDS.items()
}


@dataclass
class KeywordCategory:
    category: str  # "Other" when nothing matched
    strong: bool  # a single clear winner


def keyword_category(text: str) -> KeywordCategory:
    scores: dict[str, int] = {}
    for category, patterns in _FINE_PATTERNS.items():
        score = sum(weight for pattern, weight in patterns if pattern.search(text))
        if score:
            scores[category] = score
    if not scores:
        return KeywordCategory("Other", strong=False)
    ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
    best, best_score = ranked[0]
    runner_up = ranked[1][1] if len(ranked) > 1 else 0
    return KeywordCategory(best, strong=best_score > runner_up)


# ---------------------------------------------------------------------------
# Enough information?
# ---------------------------------------------------------------------------

# Words that say what is wrong. Without one of these a crew can't act.
_PROBLEM_CUES = re.compile(
    r"\b(?:"
    r"broken|broke|damaged|damage|cracked|cracks?|crumbling|uneven|sinking|"
    r"holes?|potholes?|sinkhole|deep|"
    r"(?:is|are|been|went|keeps going|keep going) out|not working|doesn'?t work|"
    r"isn'?t working|flickering|flicker\w*|dark|stuck|"
    r"missing|knocked (?:over|down)|fallen|fell|down|leaning|hanging|"
    r"blocked|blocking|clogged|overflowing|overgrown|"
    r"flood\w*|leak\w*|spill\w*|pooling|standing water|puddles?|"
    r"dumped|dumping|litter\w*|trash|garbage|debris|"
    r"graffiti|tagged|vandali[sz]ed|spray paint\w*|"
    r"smell\w*|stinks?|sewage|fumes|smoke|"
    r"loud|noise|"
    r"dead|stray|loose|rats?|rodents?|mice|roaches|infest\w*|nest|"
    r"exposed|sparking|hazard\w*|dangerous|unsafe|"
    r"needs? (?:repair|fixing|to be fixed|trimming|cleaning)|"
    r"abandoned|vacant|violation"
    r")\b",
    re.I,
)

_GREETING_ONLY = re.compile(
    r"^(?:hi|hello|hey|test|testing|okay|ok|yes|no|um|uh|hmm)[\s.!?]*$",
    re.I,
)


def meaningful_word_count(text: str) -> int:
    return len(re.findall(r"[A-Za-z0-9']+", text))


def has_problem_cue(text: str) -> bool:
    return bool(_PROBLEM_CUES.search(text))


def is_greeting_only(text: str) -> bool:
    return bool(_GREETING_ONLY.match(text.strip()))


# ---------------------------------------------------------------------------
# Category fields
# ---------------------------------------------------------------------------

REQUIRED_FIELDS: dict[str, tuple[str, ...]] = {
    "Street Light": ("pole_number",),
}

_POLE_LABELED = re.compile(
    r"\bpole\s*(?:number|num|no\.?|#|tag|id)\s*(?:is|was|says|reads|of)?\s*[:#]?\s*"
    r"([A-Za-z0-9][A-Za-z0-9-]{1,11})",
    re.I,
)
_POLE_BARE = re.compile(r"\bpole\s+#?([A-Za-z]{0,3}-?\d{3,}[A-Za-z0-9-]*)\b", re.I)


def extract_pole_number(text: str) -> str | None:
    for pattern in (_POLE_LABELED, _POLE_BARE):
        match = pattern.search(text)
        if match and any(ch.isdigit() for ch in match.group(1)):
            return match.group(1).upper().strip("-")
    return None


_EXTRACTORS = {
    "pole_number": extract_pole_number,
}


def extract_fields(text: str, category: str) -> dict[str, str | None]:
    return {name: _EXTRACTORS[name](text) for name in REQUIRED_FIELDS.get(category, ())}


# ---------------------------------------------------------------------------
# Spoken location
# ---------------------------------------------------------------------------

_SUFFIX = (
    r"(?:street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|way|"
    r"court|ct|place|pl|parkway|pkwy|highway|hwy|terrace|ter|circle|cir|square|sq)"
)
# A street-name word: anything except prepositions / articles, so
# "2 cars on Main Street" doesn't become an address.
_TOKEN = (
    r"(?!(?:on|at|in|near|by|and|the|of|to|from|for|is|are|was|a|an|my|it|there)\b)"
    r"[A-Za-z0-9'.]+\s+"
)
_NAME = rf"(?:{_TOKEN}){{1,3}}?"

_ADDRESS = re.compile(rf"\b(\d{{1,5}}\s+{_NAME}{_SUFFIX})\b", re.I)
_INTERSECTION = re.compile(
    rf"\b(?:corner of|intersection of|at|on)\s+"
    rf"((?:{_TOKEN}){{1,3}}?(?:{_SUFFIX}\s+)?(?:and|&)\s+{_NAME}{_SUFFIX})\b",
    re.I,
)
_ON_STREET = re.compile(
    rf"\b(?:on|at|along|near|by|down)\s+({_NAME}{_SUFFIX})\b",
    re.I,
)
_LOCATION_STOPWORDS = {
    "the", "this", "that", "my", "our", "a", "an", "same", "middle", "of",
    "side", "main", "whole", "entire", "your", "their",
}


def _real_place(phrase: str) -> bool:
    words = re.findall(r"[A-Za-z0-9']+", phrase.lower())[:-1]  # drop suffix
    # "main" alone is a real street ("Main St"); "the main road" is not.
    if words == ["main"]:
        return True
    return any(w not in _LOCATION_STOPWORDS for w in words)


def extract_spoken_location(text: str) -> str | None:
    for pattern in (_ADDRESS, _INTERSECTION, _ON_STREET):
        for match in pattern.finditer(text):
            phrase = _SPACES.sub(" ", match.group(1)).strip(" ,.")
            if _real_place(phrase):
                return phrase
    return None
