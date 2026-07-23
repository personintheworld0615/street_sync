/// Shared category inference + severity scoring for voice and community reports.

const categoryPriority = [
  'Accessibility',
  'Road Damage',
  'Public Works',
  'Environmental',
  'Other',
];

const categoryKeywords = {
  'Accessibility': [
    'wheelchair',
    'ramp',
    'curb cut',
    'accessible',
    'ada',
    'crosswalk signal',
    'blind',
    'cane',
  ],
  'Road Damage': [
    'pothole',
    'crack',
    'pavement',
    'asphalt',
    'road',
    'sidewalk broken',
    'sinkhole',
  ],
  'Public Works': [
    'streetlight',
    'lamp',
    'traffic light',
    'sign',
    'hydrant',
    'manhole',
    'trash',
    'dumpster',
    'graffiti',
  ],
  'Environmental': [
    'flood',
    'flooding',
    'tree',
    'branch',
    'litter',
    'spill',
    'pollution',
    'drainage',
    'storm drain',
  ],
};

const urgencyKeywords = [
  'blocked',
  'unsafe',
  'injury',
  'injured',
  'flooding',
  'fallen',
  'no ramp',
  'entire lane',
  'emergency',
  'dangerous',
  'collapsed',
  'fire',
  'gas leak',
];

const downgradeKeywords = [
  'minor',
  'small',
  'cosmetic',
  'faded',
  'slowly',
  'not urgent',
];

int keywordHits(String desc, List<String> keywords) {
  var hits = 0;
  for (final keyword in keywords) {
    if (desc.contains(keyword)) hits++;
  }
  return hits;
}

/// Infers a report category from free-text (used by voice reports).
String inferCategory(String description) {
  final desc = description.toLowerCase();
  var bestCategory = 'Other';
  var bestHits = 0;

  for (final category in categoryPriority) {
    if (category == 'Other') continue;
    final hits = keywordHits(desc, categoryKeywords[category]!);
    if (hits > bestHits) {
      bestHits = hits;
      bestCategory = category;
    }
    // On tie, keep earlier (higher-priority) category.
  }

  return bestHits == 0 ? 'Other' : bestCategory;
}

/// Scores severity from a known category + description keywords.
String autoSeverity({
  required String category,
  required String description,
}) {
  final desc = description.toLowerCase();

  var score = switch (category) {
    'Accessibility' => 3,
    'Road Damage' => 2,
    'Public Works' => 2,
    'Environmental' => 1,
    _ => 2,
  };

  score += keywordHits(desc, urgencyKeywords).clamp(0, 2);
  score -= keywordHits(desc, downgradeKeywords).clamp(0, 2);

  if (score >= 3) return 'High';
  if (score <= 1) return 'Low';
  return 'Medium';
}
