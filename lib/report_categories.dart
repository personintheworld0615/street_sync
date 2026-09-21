import 'package:flutter/material.dart';

/// Single source for report category ids, labels, icons, and colors.
/// Stored DB values stay as the constants below (don't rename casually).
class ReportCategories {
  ReportCategories._();

  static const streetsAndTransportation = 'Streets & Transportation';
  static const trashAndEnvironment = 'Trash & Environment';
  static const natureAndWater = 'Nature & Water';
  static const buildingsAndPublicSpaces = 'Buildings & Public Spaces';
  static const other = 'Other';

  static const roadDamage = streetsAndTransportation;
  static const publicWorks = trashAndEnvironment;
  static const environmental = natureAndWater;
  static const accessibility = buildingsAndPublicSpaces;

  static const all = [
    streetsAndTransportation,
    trashAndEnvironment,
    natureAndWater,
    buildingsAndPublicSpaces,
    other,
  ];

  static const Map<String, List<String>> specificOptions = {
    streetsAndTransportation: [
      'Pothole',
      'Damaged Sidewalk/Curb',
      'Traffic Light',
      'Street Light',
      'Damaged/Missing Sign',
      'Road Debris',
      'Parking/Traffic',
      'Other',
    ],
    trashAndEnvironment: [
      'Litter/Garbage',
      'Missed Trash/Recycling',
      'Illegal Dumping',
      'Graffiti',
      'Pollution',
      'Hazardous Waste',
      'Noise',
      'Other',
    ],
    natureAndWater: [
      'Fallen Tree/Branch',
      'Overgrown Vegetation',
      'Tree Maintenance',
      'Flooding',
      'Clogged Storm Drain',
      'Standing Water',
      'Sewer/Water Problem',
      'Other',
    ],
    buildingsAndPublicSpaces: [
      'Building Damage',
      'Property Maintenance',
      'Construction/Code Violation',
      'Housing/Rental Problem',
      'Park Maintenance',
      'Animal Issue',
      'Rodent/Insect Issue',
      'Other',
    ],
    other: [
      'Other',
    ],
  };

  /// Main categories only (excludes Other) — useful for map "Other" filtering.
  static const primary = [
    streetsAndTransportation,
    trashAndEnvironment,
    natureAndWater,
    buildingsAndPublicSpaces,
  ];

  static String label(String? category) {
    switch (category) {
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
        return category?.trim().isNotEmpty == true ? category!.trim() : 'Other';
    }
  }

  static String shortLabel(String? category) {
    switch (category) {
      case streetsAndTransportation:
        return 'Street';
      case trashAndEnvironment:
        return 'Trash';
      case natureAndWater:
        return 'Nature';
      case buildingsAndPublicSpaces:
        return 'Building';
      default:
        return 'Other';
    }
  }

  static String subtitle(String? category) {
    switch (category) {
      case streetsAndTransportation:
        return 'Potholes, lights, signs, traffic, sidewalks';
      case trashAndEnvironment:
        return 'Litter, dumping, graffiti, pollution, noise';
      case natureAndWater:
        return 'Trees, branches, flooding, drains, water';
      case buildingsAndPublicSpaces:
        return 'Building issues, code violations, parks, animals';
      default:
        return 'Anything that doesn\'t fit above';
    }
  }

  static IconData icon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'streets & transportation':
        return Icons.add_road;
      case 'trash & environment':
        return Icons.delete_outline_rounded;
      case 'nature & water':
        return Icons.park_outlined;
      case 'buildings & public spaces':
        return Icons.business_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  static Color color(String? category) {
    switch (category) {
      case streetsAndTransportation:
        return Colors.red;
      case trashAndEnvironment:
        return Colors.orange;
      case natureAndWater:
        return Colors.green;
      case buildingsAndPublicSpaces:
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  static bool isPrimary(String? category) => primary.contains(category);
}
