import 'package:flutter/material.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:street_sync/report_categories.dart';

/// What Jev decided about a description.
class ReportJudgment {
  const ReportJudgment({
    required this.category,
    required this.emergency,
    required this.needsDetail,
    required this.title,
    this.description,
    this.rationale,
    this.fields = const {},
    this.missingFields = const [],
    this.mentionedLocation,
  });

  final String? category;
  final bool emergency;
  final bool needsDetail;
  final String title;
  final String? description;
  final String? rationale;

  /// Category-specific values, e.g. `pole_number` for a street light.
  final Map<String, String?> fields;

  /// Required fields for [category] that the description did not include.
  final List<String> missingFields;

  /// A street, intersection, or place the person said out loud.
  final String? mentionedLocation;
}

/// Asks Jev about [description]. Returns null when the person should stay
/// and fix the text, or when the check could not be shown. Pass [rewrite]
/// false for a submit-time check that does not need a new title.
Future<ReportJudgment?> reviewReportText(
  BuildContext context,
  String description, {
  bool rewrite = true,
}) async {
  Map<String, dynamic> result;
  try {
    result = await ApiService.analyzeVoiceReport(description, rewrite: rewrite);
  } catch (e) {
    if (context.mounted) {
      await showErrorPopup(
        context,
        'Could not check your report. Check your connection and try again.',
      );
    }
    return null;
  }
  if (!context.mounted) return null;

  if (result['emergency'] == true) {
    await showAppDialog(
      context,
      'This sounds like an emergency. Call 911. Street Sync is for street problems, not emergencies.',
    );
    return null;
  }
  if (result['needsDetail'] == true) {
    await showAppDialog(
      context,
      _needsDetailMessage(result['needsDetailReasons'] as List<String>? ?? []),
    );
    return null;
  }

  final raw = (result['category'] as String?)?.trim() ?? '';
  return ReportJudgment(
    category: _matchCategory(raw),
    emergency: false,
    needsDetail: false,
    title: (result['title'] as String?)?.trim() ?? '',
    description: (result['description'] as String?)?.trim(),
    rationale: (result['rationale'] as String?)?.trim(),
    fields: result['fields'] as Map<String, String?>? ?? const {},
    missingFields: result['missingFields'] as List<String>? ?? const [],
    mentionedLocation: result['mentionedLocation'] as String?,
  );
}

String _needsDetailMessage(List<String> reasons) {
  if (reasons.contains('too_short')) {
    return 'Tell us a little more. Say what is wrong, like "the street light is out" or "there is a deep pothole".';
  }
  if (reasons.contains('no_problem')) {
    return 'Say what is wrong so a crew knows what to fix, like broken, out, blocked, or flooded.';
  }
  if (reasons.contains('unclear_category') || reasons.contains('jev_vague')) {
    return 'This doesn\'t sound like a street or public space problem we can send to a crew. Describe the problem you see outside.';
  }
  return 'Add one more detail so a crew knows what is wrong and where to look.';
}

String? _matchCategory(String raw) {
  if (raw.isEmpty) return null;
  final needle = raw.toLowerCase();
  for (final major in ReportCategories.all) {
    if (major.toLowerCase() == needle) return major;
    for (final option in ReportCategories.optionsFor(major)) {
      if (option.toLowerCase() == needle) return option;
    }
  }
  return null;
}
