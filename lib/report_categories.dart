import 'package:flutter/material.dart';

/// Single source for report category ids, labels, icons, and colors.
/// The app stores either the top-level category or a specific sub-option.
class ReportCategories {
  ReportCategories._();

  static const streetsAndTransportation = 'Streets & Transportation';
  static const trashAndEnvironment = 'Trash & Environment';
  static const natureAndWater = 'Nature & Water';
  static const buildingsAndPublicSpaces = 'Buildings & Public Spaces';
  static const other = 'Other';

  // Backward-compatible aliases for older code paths that still refer to the
  // original category names.
  static const roadDamage = streetsAndTransportation;
  static const publicWorks = trashAndEnvironment;
  static const environmental = natureAndWater;
  static const accessibility = buildingsAndPublicSpaces;

  static const pothole = 'Pothole';
  static const damagedSidewalkCurb = 'Damaged Sidewalk/Curb';
  static const trafficLight = 'Traffic Light';
  static const streetLight = 'Street Light';
  static const damagedMissingSign = 'Damaged/Missing Sign';
  static const roadDebris = 'Road Debris';
  static const parkingTraffic = 'Parking/Traffic';

  static const litterGarbage = 'Litter/Garbage';
  static const missedTrashRecycling = 'Missed Trash/Recycling';
  static const illegalDumping = 'Illegal Dumping';
  static const graffiti = 'Graffiti';
  static const pollution = 'Pollution';
  static const hazardousWaste = 'Hazardous Waste';
  static const noise = 'Noise';

  static const fallenTreeBranch = 'Fallen Tree/Branch';
  static const overgrownVegetation = 'Overgrown Vegetation';
  static const treeMaintenance = 'Tree Maintenance';
  static const flooding = 'Flooding';
  static const cloggedStormDrain = 'Clogged Storm Drain';
  static const standingWater = 'Standing Water';
  static const sewerWaterProblem = 'Sewer/Water Problem';

  static const buildingDamage = 'Building Damage';
  static const propertyMaintenance = 'Property Maintenance';
  static const constructionCodeViolation = 'Construction/Code Violation';
  static const housingRentalProblem = 'Housing/Rental Problem';
  static const parkMaintenance = 'Park Maintenance';
  static const animalIssue = 'Animal Issue';
  static const rodentInsectIssue = 'Rodent/Insect Issue';

  static const primary = [
    streetsAndTransportation,
    trashAndEnvironment,
    natureAndWater,
    buildingsAndPublicSpaces,
  ];

  static const all = [
    streetsAndTransportation,
    trashAndEnvironment,
    natureAndWater,
    buildingsAndPublicSpaces,
    other,
  ];

  static const Map<String, List<String>> specificOptions = {
    streetsAndTransportation: [
      pothole,
      damagedSidewalkCurb,
      trafficLight,
      streetLight,
      damagedMissingSign,
      roadDebris,
      parkingTraffic,
    ],
    trashAndEnvironment: [
      litterGarbage,
      missedTrashRecycling,
      illegalDumping,
      graffiti,
      pollution,
      hazardousWaste,
      noise,
    ],
    natureAndWater: [
      fallenTreeBranch,
      overgrownVegetation,
      treeMaintenance,
      flooding,
      cloggedStormDrain,
      standingWater,
      sewerWaterProblem,
    ],
    buildingsAndPublicSpaces: [
      buildingDamage,
      propertyMaintenance,
      constructionCodeViolation,
      housingRentalProblem,
      parkMaintenance,
      animalIssue,
      rodentInsectIssue,
    ],
  };

  static String? majorCategoryOf(String? category) {
    if (category == null || category.trim().isEmpty) return null;
    final normalized = category.trim();

    for (final entry in specificOptions.entries) {
      if (entry.value.contains(normalized)) {
        return entry.key;
      }
    }

    if (primary.contains(normalized) || normalized == other) {
      return normalized;
    }

    return null;
  }

  static List<String> optionsFor(String? category) {
    final major = majorCategoryOf(category);
    if (major == null) return const [];
    return specificOptions[major] ?? const [];
  }

  static String label(String? category) {
    if (category == null || category.trim().isEmpty) return 'Other';
    final normalized = category.trim();

    if (normalized == other) return 'Other';
    if (primary.contains(normalized)) {
      switch (normalized) {
        case streetsAndTransportation:
          return 'Streets & Transportation';
        case trashAndEnvironment:
          return 'Trash & Environment';
        case natureAndWater:
          return 'Nature & Water';
        case buildingsAndPublicSpaces:
          return 'Buildings & Public Spaces';
      }
    }

    return normalized;
  }

  static String shortLabel(String? category) {
    final major = majorCategoryOf(category);
    switch (major) {
      case streetsAndTransportation:
        return 'Streets';
      case trashAndEnvironment:
        return 'Trash';
      case natureAndWater:
        return 'Nature';
      case buildingsAndPublicSpaces:
        return 'Buildings';
      case other:
        return 'Other';
      default:
        return 'Other';
    }
  }

  static String subtitle(String? category) {
    switch (majorCategoryOf(category)) {
      case streetsAndTransportation:
        return 'Potholes, signs, traffic, sidewalks';
      case trashAndEnvironment:
        return 'Trash, dumping, litter, pollution';
      case natureAndWater:
        return 'Trees, flooding, drains, standing water';
      case buildingsAndPublicSpaces:
        return 'Buildings, parks, property and animal issues';
      case other:
        return 'Anything that doesn\'t fit above';
      default:
        return 'Anything that doesn\'t fit above';
    }
  }

  static IconData icon(String? category) {
    switch (majorCategoryOf(category)) {
      case streetsAndTransportation:
        return Icons.alt_route_outlined;
      case trashAndEnvironment:
        return Icons.delete_outline_rounded;
      case natureAndWater:
        return Icons.forest_rounded;
      case buildingsAndPublicSpaces:
        return Icons.apartment_rounded;
      case other:
        return Icons.flag_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  static Color color(String? category) {
    switch (majorCategoryOf(category)) {
      case streetsAndTransportation:
        return const Color(0xFFE53935);
      case trashAndEnvironment:
        return const Color(0xFFFB8C00);
      case natureAndWater:
        return const Color(0xFF43A047);
      case buildingsAndPublicSpaces:
        return const Color(0xFF2160E1);
      case other:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  static bool isPrimary(String? category) => primary.contains(majorCategoryOf(category));
}
