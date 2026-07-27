import 'package:flutter/material.dart';

/// Single source for report category ids, labels, icons, and colors.
/// Stored DB values stay as the constants below (don't rename casually).
class ReportCategories {
  ReportCategories._();

  static const roadDamage = 'Road Damage';
  static const publicWorks = 'Public Works';
  static const environmental = 'Environmental';
  static const accessibility = 'Accessibility';
  static const other = 'Other';

  static const all = [
    roadDamage,
    publicWorks,
    environmental,
    accessibility,
    other,
  ];

  /// Main categories only (excludes Other) — useful for map "Other" filtering.
  static const primary = [
    roadDamage,
    publicWorks,
    environmental,
    accessibility,
  ];

  static String label(String? category) {
    switch (category) {
      case roadDamage:
        return 'Roads';
      case publicWorks:
        return 'Town';
      case environmental:
        return 'Environment';
      case accessibility:
        return 'Accessibility';
      case other:
        return 'Other';
      default:
        return category?.trim().isNotEmpty == true ? category!.trim() : 'Other';
    }
  }

  static String shortLabel(String? category) {
    switch (category) {
      case roadDamage:
        return 'Road';
      case publicWorks:
        return 'Town';
      case environmental:
        return 'Environment';
      case accessibility:
        return 'ADA';
      default:
        return 'Other';
    }
  }

  static String subtitle(String? category) {
    switch (category) {
      case roadDamage:
        return 'Potholes, cracks, pavement';
      case publicWorks:
        return 'Lights, signs, trash, hydrants';
      case environmental:
        return 'Trees, flooding, litter, e-waste';
      case accessibility:
        return 'Ramps, curb cuts, mobility';
      default:
        return 'Anything that doesn\'t fit above';
    }
  }

  static IconData icon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'road damage':
        return Icons.add_road;
      case 'public works':
        return Icons.handyman_outlined;
      case 'environmental':
        return Icons.eco_outlined;
      case 'accessibility':
        return Icons.accessible_forward;
      default:
        return Icons.flag_outlined;
    }
  }

  static Color color(String? category) {
    switch (category) {
      case roadDamage:
        return Colors.red;
      case publicWorks:
        return Colors.orange;
      case environmental:
        return Colors.green;
      case accessibility:
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  static bool isPrimary(String? category) => primary.contains(category);
}
