# Auto Severity Classification Plan

## Current state

Today severity is basically a category lookup:

| Category | Severity |
|----------|----------|
| Accessibility | high |
| Road Damage / Public Works | medium |
| Environmental | low |
| Other / default | medium |

That ignores description, photo, and location, so every pothole and every faded crosswalk get the same score.

---

## Ways to improve

### 1. Rule / keyword scoring (best next step)

Score from **category + description** with weights, then map to low/medium/high.

- **Urgency words:** `blocked`, `unsafe`, `flooding`, `fallen`, `injury`, `wheelchair`, `no ramp` → bump up
- **Size / impact:** `large`, `deep`, `entire lane`, `multiple` → bump up
- **Soft language:** `minor`, `small crack`, `cosmetic`, `faded` → bump down
- **Category base** stays as the current defaults, then description adjusts ±1 level

Works offline, easy to explain to judges, and fits the existing edit-on-confirmation flow.

### 2. Structured “impact checklist”

Instead of free-text-only scoring, ask 2–3 quick yes/no after category (or infer them from text):

- Blocks traffic / sidewalk?
- Safety risk (trip, flood, exposed wire)?
- Affects accessibility?

Severity = function of those answers. More accurate than keywords alone, still simple.

### 3. Photo-aware classification

The app already captures an image — use it:

- **Vision LLM** (GPT-4o / Gemini): “Rate infrastructure severity 1–3 given category + photo + description.”
- Or lighter: detect “large defect vs small” with a small vision model / Cloud Vision labels.

Good for Road Damage (pothole size) where text is vague. Keep a text fallback if the API fails.

### 4. Location / context signals

GPS can refine priority:

- Near school, hospital, bus stop, or busy intersection → +severity
- Same issue reported nearby recently (cluster) → +severity or “confirmed”
- Side street vs main artery (if road class data is available)

Especially strong for West Windsor / municipal dispatch story.

### 5. Hybrid scoring model

Combine signals into a 0–100 score, then bucket:

| Signal | Weight idea |
|--------|-------------|
| Category base | 30% |
| Description urgency | 25% |
| Photo assessment | 25% |
| Location criticality | 10% |
| Repeat reports nearby | 10% |

Show the user: *“Suggested: High — large pothole blocking lane near Nassau St”* so they trust (and can override) it.

### 6. LLM on description + category (voice-friendly)

For camera *and* voice reports, send category + description/transcript to the FastAPI backend:

```text
Classify severity low|medium|high for municipal triage.
Return JSON: { severity, reason, confidence }
```

Rules: accessibility/safety language → high; cosmetic → low. Cache or rate-limit; fall back to the current category switch if offline.

### 7. Learn from corrections

Users already can edit severity on confirmation. Log:

`auto_suggested` vs `user_final` + category/description

Later: tune keyword weights, or fine-tune a small classifier. Great “closes the loop” demo for the App Challenge.

### 8. Municipal priority mapping

Align labels with how cities actually triage:

- **High:** life safety, ADA blocked, flooding into roadway
- **Medium:** significant damage, needs crew soon
- **Low:** aesthetics, minor wear

Publish that rubric in-app so auto-class feels intentional, not random.

---

## Suggested path for StreetSync

1. **Now:** category base + description keyword/impact rules (+ short reason on confirm).
2. **Next:** same logic for voice transcripts.
3. **If time:** optional vision pass for Road Damage only.
4. **Polish:** log overrides; show “why we suggested this.”

Biggest win vs effort: stop using category alone — **description (and later photo) should be able to push a “medium” road report to high or low.**
