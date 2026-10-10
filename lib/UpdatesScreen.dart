import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/ReportDetails.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:street_sync/skeleton.dart';
import 'package:street_sync/update_alerts.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key, this.isActive = true});

  /// True only while the Updates tab is the one on screen.
  /// Nullable so a hot reload of an older screen does not crash.
  final bool? isActive;

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
  final Map<int, GlobalKey> _cardKeys = {};
  final Set<int> _keptThisVisit = {};

  @override
  void initState() {
    super.initState();
    UpdateAlerts.refreshTick.addListener(_onUpdatesRefresh);
    _load();
  }

  @override
  void didUpdateWidget(UpdatesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = widget.isActive == true;
    final before = oldWidget.isActive == true;
    if (now && !before) {
      _keptThisVisit.clear();
      _load(quiet: true);
    }
    if (!now && before) {
      _keptThisVisit.clear();
    }
  }

  @override
  void dispose() {
    UpdateAlerts.refreshTick.removeListener(_onUpdatesRefresh);
    super.dispose();
  }

  void _onUpdatesRefresh() {
    _load(quiet: true);
  }

  GlobalKey _keyFor(int id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  List<Map<String, dynamic>> get _shown {
    return _updates.where((item) {
      final id = UpdateAlerts.idOf(item);
      if (_keptThisVisit.contains(id)) return true;
      return !UpdateAlerts.isRead(id);
    }).toList();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;

    if (!quiet) {
      final cached = await ApiService.getCachedUpdates();
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _updates = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = true);
      }
    }

    final raw = await ApiService.getUpdates();
    if (!mounted) return;
    if (raw == null) {
      if (!quiet && _updates.isEmpty) setState(() => _loading = false);
      return;
    }
    setState(() {
      _updates = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _markOnScreen());
  }

  void _markOnScreen() {
    if (!mounted || widget.isActive != true) return;
    final visible = <int>[];
    for (final item in _shown) {
      final id = UpdateAlerts.idOf(item);
      final key = _cardKeys[id];
      if (key != null && _cardIsOnScreen(key)) visible.add(id);
    }
    if (visible.isEmpty) return;
    final already = visible.every(
      (id) => _keptThisVisit.contains(id) && UpdateAlerts.isRead(id),
    );
    _keptThisVisit.addAll(visible);
    UpdateAlerts.markRead(visible);
    if (!already && mounted) setState(() {});
  }

  bool _cardIsOnScreen(GlobalKey key) {
    final cardContext = key.currentContext;
    if (cardContext == null) return false;
    final box = cardContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    final media = MediaQuery.of(context);
    final visibleTop = media.padding.top;
    final visibleBottom = media.size.height - media.padding.bottom - 72;
    final overlap = (bottom < visibleBottom ? bottom : visibleBottom) -
        (topLeft.dy > visibleTop ? topLeft.dy : visibleTop);
    return overlap > 24;
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
    final rawId = item['report_id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null) return;
    final report = await ApiService.getReport(id);
    if (!mounted) return;
    if (report == null) {
      showAppDialog(context, 'Could not open that report.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(report: report),
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification) {
              _markOnScreen();
            }
            return false;
          },
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
                  const UpdateListSkeleton()
                else if (_shown.isEmpty)
                  _emptyState(caughtUp: _updates.isNotEmpty)
                else
                  ..._shown.map(_buildCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required bool caughtUp}) {
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
            const SizedBox(height: 16),
            Text(
              caughtUp ? 'You\'re all caught up' : 'No updates yet',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caughtUp
                  ? 'Updates you\'ve already seen stay off this list.'
                  : 'When city staff update your reports,\nyou’ll see them here.',
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
      key: _keyFor(UpdateAlerts.idOf(item)),
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
