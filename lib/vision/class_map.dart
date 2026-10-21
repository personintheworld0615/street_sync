import 'package:street_sync/report_categories.dart';

/// The 10 classes in [yolomodel/urban_multi.yaml], in model order.
class UrbanClasses {
  UrbanClasses._();

  static const labels = [
    'Damaged Road issues',
    'Pothole Issues',
    'Illegal Parking Issues',
    'Broken Road Sign Issues',
    'Fallen trees',
    'Littering/Garbage',
    'Vandalism/Graffiti',
    'Dead Animal Pollution',
    'Broken sidewalk',
    'Damaged Electric wires and poles',
  ];

  static const categories = [
    ReportCategories.streetsAndTransportation,
    ReportCategories.pothole,
    ReportCategories.parkingTraffic,
    ReportCategories.damagedMissingSign,
    ReportCategories.fallenTreeBranch,
    ReportCategories.litterGarbage,
    ReportCategories.graffiti,
    ReportCategories.animalIssue,
    ReportCategories.damagedSidewalkCurb,
    ReportCategories.streetLight,
  ];

  static String label(int classId) {
    if (classId < 0 || classId >= labels.length) return 'Unknown';
    return labels[classId];
  }

  static String category(int classId) {
    if (classId < 0 || classId >= categories.length) return ReportCategories.other;
    return categories[classId];
  }

  /// 1 low, 2 medium, 3 high. A large box bumps one step. A tiny box drops one.
  static int level(int classId, double areaFraction) {
    var level = switch (classId) {
      1 || 4 || 7 || 9 => 3,
      5 || 6 => 1,
      _ => 2,
    };
    if (areaFraction >= 0.15 && level < 3) level += 1;
    if (areaFraction < 0.03 && level > 1) level -= 1;
    return level;
  }

  static String severity(int classId, double areaFraction) {
    return switch (level(classId, areaFraction)) {
      1 => 'Low',
      3 => 'High',
      _ => 'Medium',
    };
  }

  static String reason(int classId, double areaFraction) {
    final share = (areaFraction * 100).round();
    return '${label(classId)} · $share% of the frame · ${severity(classId, areaFraction)}';
  }

  static String titleFor(int classId) {
    return switch (classId) {
      0 => 'Damaged road',
      1 => 'Pothole',
      2 => 'Illegal parking',
      3 => 'Broken road sign',
      4 => 'Fallen tree',
      5 => 'Litter',
      6 => 'Graffiti',
      7 => 'Dead animal',
      8 => 'Broken sidewalk',
      9 => 'Damaged wires or pole',
      _ => 'Street issue',
    };
  }

  static String descriptionFor({
    required int classId,
    required double confidence,
    required double areaFraction,
  }) {
    final pct = (confidence * 100).round();
    final share = (areaFraction * 100).round();
    return '${label(classId)} detected on device, $pct% confidence, about $share% of the frame.';
  }
}
