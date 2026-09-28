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
  });

  final String? category;
  final bool emergency;
  final bool needsDetail;
  final String title;
}

/// Asks Jev about [description]. Returns null when the person should stay
/// and fix the text, or when the check could not be shown.
Future<ReportJudgment?> reviewReportText(
  BuildContext context,
  String description,
) async {
  Map<String, dynamic> result;
  try {
    result = await ApiService.analyzeVoiceReport(description);
  } catch (e) {
    return ReportJudgment(
      category: null,
      emergency: false,
      needsDetail: false,
      title: '',
    );
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
      'Add one more detail so a crew knows what is wrong and where to look.',
    );
    return null;
  }

  final raw = (result['category'] as String?)?.trim() ?? '';
  return ReportJudgment(
    category: _matchCategory(raw),
    emergency: false,
    needsDetail: false,
    title: (result['title'] as String?)?.trim() ?? '',
  );
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
