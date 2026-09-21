import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/ReportDetails.dart';
import 'package:street_sync/api_service.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _soft = Color(0xFFEEF0F3);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE8EAED);

  bool _loading = true;
  List<Map<String, dynamic>> _updates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await ApiService.getUpdates();
    if (!mounted) return;
    setState(() {
      _updates = (raw ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return const Color(0xFF2160E1);
      case 'in progress':
        return const Color(0xFFFB8C00);
      case 'resolved':
        return const Color(0xFF43A047);
      default:
        return _ink;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '';
    }
  }

  String _commentOf(Map<String, dynamic> item) {
    final raw = item['comment'];
    if (raw is! String) return '';
    return raw.trim();
  }

  Future<void> _openReport(Map<String, dynamic> item) async {
    final reportId = item['report_id'];
    if (reportId == null) return;
    // Minimal map so ReportDetails has something to show if fetch fails.
    final seed = <String, dynamic>{
      'id': reportId,
      'title': item['report_title'] ?? 'Report',
      'status': item['new_status'] ?? 'Open',
    };
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(report: seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _ink,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 28, 20, 110 + bottomInset),
            children: [
              Text(
                'Updates',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status changes on your reports show up here.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.4,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: _ink),
                  ),
                )
              else if (_updates.isEmpty)
                _emptyState()
              else
                ..._updates.map(_buildCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _soft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: _ink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No updates yet',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When city staff update your reports,\nyou’ll see them here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final title = (item['report_title'] as String?)?.trim().isNotEmpty == true
        ? (item['report_title'] as String).trim()
        : 'Your report';
    final oldStatus = (item['old_status'] as String?)?.trim() ?? 'Open';
    final newStatus = (item['new_status'] as String?)?.trim() ?? 'Open';
    final comment = _commentOf(item);
    final hasComment = comment.isNotEmpty;
    final timeLabel = _formatTime(item['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openReport(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statusPill(oldStatus),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _muted.withValues(alpha: 0.8),
                      ),
                    ),
                    _statusPill(newStatus),
                  ],
                ),
                if (hasComment) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: _pageBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 18,
                          color: _muted.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            comment,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.45,
                              color: _ink.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
