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
    this.pill,
    this.category,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String location;
  final String time;
  final String? pill;
  final String? category;
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
    final status = (report['status'] as String?)?.trim();
    if (status != null && status.isNotEmpty) {
      switch (status.toLowerCase()) {
        case 'in_progress':
        case 'inprogress':
          return 'In Progress';
        default:
          return status;
      }
    }
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
    switch (pill.trim().toLowerCase()) {
      case 'draft':
        return const Color(0xFFB86B2A);
      case 'open':
        return const Color(0xFF2160E1);
      case 'in progress':
      case 'in_progress':
        return const Color(0xFFFB8C00);
      case 'resolved':
        return const Color(0xFF43A047);
      default:
        return _muted;
    }
  }

  static String _formatPillLabel(String pill) {
    final trimmed = pill.trim();
    if (trimmed.isEmpty) return 'Unknown';
    switch (trimmed.toLowerCase()) {
      case 'in progress':
      case 'in_progress':
        return 'In Progress';
      case 'open':
        return 'Open';
      case 'resolved':
        return 'Resolved';
      case 'draft':
        return 'Draft';
      default:
        return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPill = pill != null && pill!.trim().isNotEmpty;
    final pillLabel = showPill ? _formatPillLabel(pill!) : '';
    final accent = ReportCategories.color(category);
    final iconBg = accent.withValues(alpha: 0.12);

    final titleStyle = GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: _ink,
      height: 1.2,
      letterSpacing: -0.25,
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 22, color: accent),
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
                            if (showPill) ...[
                              Text(' · ', style: metaStyle),
                              Text(
                                pillLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: pillColor(pill!),
                                  height: 1.2,
                                ),
                              ),
                            ],
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
