/// Shared category inference + severity scoring for voice and community reports.

const categoryPriority = [
  'Streets & Transportation',
  'Trash & Environment',
  'Nature & Water',
  'Buildings & Public Spaces',
  'Other',
];

const categoryKeywords = {
  'Streets & Transportation': [
    'pothole',
    'crack',
    'pavement',
    'asphalt',
    'road',
    'sidewalk',
    'curb',
    'traffic light',
    'street light',
    'sign',
    'road debris',
    'parking',
    'traffic',
  ],
  'Trash & Environment': [
    'litter',
    'garbage',
    'recycling',
    'dumping',
    'graffiti',
    'pollution',
    'hazardous',
    'noise',
    'trash',
  ],
  'Nature & Water': [
    'flood',
    'flooding',
    'tree',
    'branch',
    'vegetation',
    'storm drain',
    'standing water',
    'sewer',
    'water',
  ],
  'Buildings & Public Spaces': [
    'building damage',
    'property maintenance',
    'construction',
    'code violation',
    'housing',
    'park',
    'animal',
    'rodent',
    'insect',
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
    'Streets & Transportation' => 2,
    'Trash & Environment' => 2,
    'Nature & Water' => 1,
    'Buildings & Public Spaces' => 2,
    _ => 2,
  };

  score += keywordHits(desc, urgencyKeywords).clamp(0, 2);
  score -= keywordHits(desc, downgradeKeywords).clamp(0, 2);

  if (score >= 3) return 'High';
  if (score <= 1) return 'Low';
  return 'Medium';
}
