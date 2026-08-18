import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/report_categories.dart';

/// Shared modern-v2 report row used on Home and list screens.
class ReportListCard extends StatelessWidget {
  const ReportListCard({
    super.key,
    required this.icon,
    required this.title,
    required this.location,
    required this.time,
    required this.pill,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String location;
  final String time;
  final String pill;
  final VoidCallback? onTap;

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);

  static String displayTitle(
    Map<String, dynamic> report, {
    String fallback = 'Report',
  }) {
    final title = report['title'] as String?;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    final name = report['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final category = report['category'] as String?;
    if (category != null && category.trim().isNotEmpty) {
      return ReportCategories.label(category);
    }
    return fallback;
  }

  static String displayPill(Map<String, dynamic> report, {String? fallback}) {
    final severity = (report['severity'] as String?)?.trim();
    if (severity != null && severity.isNotEmpty) return severity;
    final status = (report['status'] as String?)?.trim();
    if (status != null && status.isNotEmpty) return status;
    return fallback ?? 'Open';
  }

  static String formatTime(dynamic time) {
    if (time is! String || time.isEmpty) return '';
    final parsed = DateTime.tryParse(time);
    if (parsed == null) return time;
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String shortLocation(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return 'Unknown';
    final comma = trimmed.indexOf(',');
    if (comma > 0) return trimmed.substring(0, comma).trim();
    return trimmed;
  }

  static Color pillColor(String pill) {
    switch (pill.toLowerCase()) {
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFFB8C00);
      case 'low':
        return const Color(0xFF43A047);
      case 'draft':
        return const Color(0xFFB86B2A);
      case 'open':
        return const Color(0xFF4B5563);
      case 'in progress':
        return const Color(0xFFEA580C);
      case 'resolved':
        return const Color(0xFF0F766E);
      default:
        return _muted;
    }
  }

  static Color pillFill(String pill) {
    switch (pill.toLowerCase()) {
      case 'high':
        return const Color(0xFFFFEBEE);
      case 'medium':
        return const Color(0xFFFFF3E0);
      case 'low':
        return const Color(0xFFE8F5E9);
      case 'draft':
        return const Color(0xFFFFF1E6);
      case 'open':
        return const Color(0xFFF3F4F6);
      case 'in progress':
        return const Color(0xFFFFF1E8);
      case 'resolved':
        return const Color(0xFFE6F4F1);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  static String _formatPillLabel(String pill) {
    final trimmed = pill.trim();
    if (trimmed.isEmpty) return 'Unknown';
    if (trimmed.toLowerCase() == 'in progress') return 'In progress';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final pillLabel = _formatPillLabel(pill);

    final titleStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: _ink,
      height: 1.2,
      letterSpacing: -0.2,
    );
    final metaStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: _muted,
      height: 1.2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFEEF0F3),
                    child: Icon(icon, size: 20, color: _ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shortLocation(location),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ),
                            Text(' · ', style: metaStyle),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pillFill(pill),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                pillLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: pillColor(pill),
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Text(' · ', style: metaStyle),
                            Text(time, style: metaStyle),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

/// Soft-black pill CTA used on report list screens.
class NewReportBlackCta extends StatelessWidget {
  const NewReportBlackCta({
    super.key,
    this.label = 'New report',
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const _cta = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: _cta,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityReportScreen(),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
