"""Scenario check for the stock MiniLM encoder versus word overlap.

These pairs are the evaluation set for this run. A threshold chosen here is
fit to these cases, not a held-out proof.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from api.services.dedup_text import (
    cosine,
    descriptions_conflict,
    is_same_issue,
    is_text_candidate,
    jaccard,
    report_text,
)
from api.tests.dedup_hundred import CASES

# Plainsboro pin. 10m north is still inside the match radius. 200m is not.
PIN = (40.3334, -74.6004)
NEAR = (40.33349, -74.6004)
FAR = (40.3352, -74.6004)

# (same_issue, title_a, description_a, title_b, description_b)
SCENARIOS = [
    (
        True,
        "Crater in the asphalt",
        "Deep hole in the asphalt near the curb",
        "Dangerous pothole",
        "Dangerous pothole by the sidewalk",
    ),
    (
        True,
        "Flickering streetlight",
        "The lamp post on Witherspoon is buzzing and blinking",
        "Broken lamp",
        "Street light buzzing on Witherspoon Street",
    ),
    (
        True,
        "Trash pile",
        "Trash bags piled at the curb for days",
        "Dumped garbage",
        "Garbage dumped on the sidewalk",
    ),
    (
        True,
        "Tree down",
        "Fallen tree blocking the lane",
        "Branch in the road",
        "Large branch down across the road",
    ),
    (
        True,
        "Park graffiti",
        "Graffiti on the park wall",
        "Spray paint",
        "Spray paint tags on the park building",
    ),
    (
        True,
        "Cracked sidewalk",
        "Uneven broken concrete slabs on the walkway",
        "Sidewalk hazard",
        "Heaved pavement where people walk, easy to trip",
    ),
    (
        False,
        "Deep pothole",
        "Deep pothole in the road",
        "Broken streetlight",
        "Broken streetlight on the corner",
    ),
    (
        False,
        "Litter",
        "Litter on the sidewalk",
        "Cracked sidewalk",
        "Cracked sidewalk concrete",
    ),
    (
        False,
        "Dead animal",
        "Dead animal in the bike lane",
        "Illegal parking",
        "Car parked illegally by the curb",
    ),
    (
        False,
        "Flooded drain",
        "Storm drain flooding the intersection",
        "Pothole",
        "Pothole in the same intersection",
    ),
    (
        False,
        "Broken stop sign",
        "Stop sign knocked over at the corner",
        "Pothole",
        "Pothole next to the stop sign",
    ),
    (
        False,
        "Sidewalk crack",
        "Crack in the sidewalk",
        "Cracked pole",
        "Crack in the streetlight pole",
    ),
]


def test_conflict_vetoes_do_not_reject_real_duplicates():
    pin_cases = [case for case in CASES if case[1]]
    assert len(pin_cases) == 40
    for case in pin_cases:
        left = report_text(case[6], case[7])
        right = report_text(case[8], case[9])
        assert not descriptions_conflict(left, right), case[0]
    assert descriptions_conflict(
        "Deep pothole in the northbound lane",
        "Deep pothole in the southbound lane",
    )
    assert descriptions_conflict(
        "Lamp does not turn on at night",
        "Lamp stays on all day and never shuts off",
    )
    assert descriptions_conflict(
        "Dead raccoon in the bike lane",
        "Rats coming out near the bike lane",
    )
    assert descriptions_conflict(
        "One way sign points the wrong direction",
        "One way sign is blocked by a branch",
    )
    assert is_same_issue(0.95, "Pothole by the curb", "Hole by the sidewalk")
    assert not is_same_issue(0.95, "Pothole in the left lane", "Pothole in the right lane")
    assert not is_same_issue(0.49, "Pothole by the curb", "Hole by the sidewalk")


def test_hundred_cases_at_half():
    from sentence_transformers import SentenceTransformer

    pin = (40.3334, -74.6004)
    near = (40.33349, -74.6004)
    far = (40.3352, -74.6004)
    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    pairs = [(report_text(case[6], case[7]), report_text(case[8], case[9])) for case in CASES]
    flat: list[str] = []
    index: dict[str, int] = {}
    for left, right in pairs:
        for text in (left, right):
            if text not in index:
                index[text] = len(flat)
                flat.append(text)
    vectors = model.encode(flat, normalize_embeddings=True)
    counts = {"TP": 0, "FP": 0, "TN": 0, "FN": 0}
    for case, (left, right) in zip(CASES, pairs):
        coord = near if case[5] == "near" else far
        allowed = is_text_candidate(case[2], case[3], case[4], pin[0], pin[1], coord[0], coord[1])
        if not allowed:
            pred = False
        else:
            score = float(cosine(vectors[index[left]].tolist(), vectors[index[right]].tolist()))
            pred = is_same_issue(score, left, right, threshold=0.5)
        if pred and case[1]:
            counts["TP"] += 1
        elif pred and not case[1]:
            counts["FP"] += 1
        elif not pred and not case[1]:
            counts["TN"] += 1
        else:
            counts["FN"] += 1
    assert counts == {"TP": 33, "FP": 0, "TN": 60, "FN": 7}


def test_word_overlap_baseline_is_defined():
    assert jaccard("deep pothole in the road", "dangerous hole in the asphalt") == 0
    assert jaccard("deep pothole in the road", "deep pothole in the road") == 1


def test_transformer_scenarios():
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    rows: list[tuple[bool, float, float, str, str]] = []

    for same, title_a, desc_a, title_b, desc_b in SCENARIOS:
        left = report_text(title_a, desc_a)
        right = report_text(title_b, desc_b)
        vectors = model.encode([left, right], normalize_embeddings=True)
        transformer = float(cosine(vectors[0].tolist(), vectors[1].tolist()))
        words = jaccard(left, right)
        rows.append((same, transformer, words, left, right))

    by_left = {row[3]: row for row in rows}
    crater = by_left["Crater in the asphalt. Deep hole in the asphalt near the curb"]
    trash = by_left["Trash pile. Trash bags piled at the curb for days"]
    pothole_vs_light = by_left["Deep pothole. Deep pothole in the road"]
    sidewalk_vs_pole = by_left["Sidewalk crack. Crack in the sidewalk"]

    print("\nSAME  TRANSFORMER  WORDS  LEFT  |  RIGHT")
    for same, transformer, words, left, right in rows:
        print(
            f"{str(same):5}  {transformer:6.3f}       {words:5.3f}  "
            f"{left[:42]:42} | {right[:42]}"
        )

    same_scores = [score for same, score, _, _, _ in rows if same]
    different_scores = [score for same, score, _, _, _ in rows if not same]
    print(f"\nsame-issue cosine {min(same_scores):.3f} to {max(same_scores):.3f}")
    print(f"different-issue cosine {min(different_scores):.3f} to {max(different_scores):.3f}")

    # Paraphrases with no shared content words still score above a clearly different issue.
    assert crater[2] == 0
    assert crater[1] > pothole_vs_light[1]
    assert trash[2] == 0
    assert trash[1] > 0.6
    # Shared wording is not enough: a sidewalk crack and a cracked pole overlap.
    assert sidewalk_vs_pole[1] > min(same_scores)


# same_issue, category_a, category_b, status_b, coord_b, titles and descriptions
GATED = [
    (True, "Pothole", "Pothole", "Open", NEAR, "Crater in the asphalt", "Deep hole in the asphalt near the curb", "Dangerous pothole", "Dangerous pothole by the sidewalk"),
    (True, "Street Light", "Street Light", "In Progress", NEAR, "Flickering streetlight", "The lamp post is buzzing and blinking", "Broken lamp", "Street light buzzing all night"),
    (True, "Litter/Garbage", "Litter/Garbage", "Open", NEAR, "Trash pile", "Trash bags piled at the curb for days", "Dumped garbage", "Garbage dumped on the sidewalk"),
    (True, "Fallen Tree/Branch", "Fallen Tree/Branch", "Open", NEAR, "Tree down", "Fallen tree blocking the lane", "Branch in the road", "Large branch down across the road"),
    (True, "Graffiti", "Graffiti", "Open", NEAR, "Park graffiti", "Graffiti on the park wall", "Spray paint", "Spray paint tags on the park building"),
    (True, "Damaged Sidewalk/Curb", "Damaged Sidewalk/Curb", "Open", NEAR, "Cracked sidewalk", "Uneven broken concrete slabs on the walkway", "Sidewalk hazard", "Heaved pavement where people walk, easy to trip"),
    (False, "Pothole", "Street Light", "Open", NEAR, "Deep pothole", "Deep pothole in the road", "Broken streetlight", "Broken streetlight on the corner"),
    (False, "Litter/Garbage", "Damaged Sidewalk/Curb", "Open", NEAR, "Litter", "Litter on the sidewalk", "Cracked sidewalk", "Cracked sidewalk concrete"),
    (False, "Animal Issue", "Parking/Traffic", "Open", NEAR, "Dead animal", "Dead animal in the bike lane", "Illegal parking", "Car parked illegally by the curb"),
    (False, "Clogged Storm Drain", "Pothole", "Open", NEAR, "Flooded drain", "Storm drain flooding the intersection", "Pothole", "Pothole in the same intersection"),
    (False, "Damaged/Missing Sign", "Pothole", "Open", NEAR, "Broken stop sign", "Stop sign knocked over at the corner", "Pothole", "Pothole next to the stop sign"),
    (False, "Damaged Sidewalk/Curb", "Street Light", "Open", NEAR, "Sidewalk crack", "Crack in the sidewalk", "Cracked pole", "Crack in the streetlight pole"),
    (False, "Pothole", "Pothole", "Resolved", NEAR, "Crater in the asphalt", "Deep hole in the asphalt near the curb", "Dangerous pothole", "Dangerous pothole by the sidewalk"),
    (False, "Pothole", "Pothole", "Open", FAR, "Crater in the asphalt", "Deep hole in the asphalt near the curb", "Dangerous pothole", "Dangerous pothole by the sidewalk"),
    (False, "Street Light", "Street Light", "Open", NEAR, "Dark lamp", "The street light bulb is out after dark", "Leaning pole", "Car hit the streetlight pole and it is leaning"),
    (False, "Pothole", "Pothole", "Open", NEAR, "Deep hole", "Deep hole in the travel lane", "Loose cover", "Manhole cover is loose and clanking when cars pass"),
]


def test_gates_drop_cross_category_resolved_and_far():
    kept = []
    for row in GATED:
        same, cat_a, cat_b, status_b, coord_b, *_rest = row
        allowed = is_text_candidate(cat_a, cat_b, status_b, PIN[0], PIN[1], coord_b[0], coord_b[1])
        if same:
            assert allowed, row[5]
        else:
            # Same-category, open, nearby pairs still reach the encoder.
            if cat_a == cat_b and status_b in {"Open", "In Progress"} and coord_b is NEAR:
                assert allowed, row[5]
            else:
                assert not allowed, row[5]
        if allowed:
            kept.append(row)
    assert len(kept) == 8


def test_gated_pairs_separate():
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    same_scores = []
    different_scores = []
    print("\nGATE  SAME  COSINE  LEFT | RIGHT")
    for same, cat_a, cat_b, status_b, coord_b, title_a, desc_a, title_b, desc_b in GATED:
        allowed = is_text_candidate(cat_a, cat_b, status_b, PIN[0], PIN[1], coord_b[0], coord_b[1])
        if not allowed:
            print(f"skip  {str(same):5}  {'--':6}  {title_a[:36]:36} | {title_b[:36]}")
            continue
        left = report_text(title_a, desc_a)
        right = report_text(title_b, desc_b)
        vectors = model.encode([left, right], normalize_embeddings=True)
        score = float(cosine(vectors[0].tolist(), vectors[1].tolist()))
        print(f"keep  {str(same):5}  {score:6.3f}  {left[:36]:36} | {right[:36]}")
        (same_scores if same else different_scores).append(score)

    print(f"\nkept same-issue {min(same_scores):.3f} to {max(same_scores):.3f}")
    print(f"kept different-issue {min(different_scores):.3f} to {max(different_scores):.3f}")
    # Easy paraphrases clear the same-category negatives. The bottom of the
    # same-issue band still touches those negatives, so this set has no cutoff.
    assert min(score for score in same_scores if score > 0.6) > max(different_scores)
    assert min(same_scores) - max(different_scores) < 0.05
