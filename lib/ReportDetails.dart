import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:street_sync/report_categories.dart';

class ReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  static const _cta = Color(0xFF111827);
  static const _iconBg = Color(0xFFEEF0F3);

  Map<String, dynamic> get report => widget.report;

  String get _title {
    final title = report['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final desc = report['description']?.toString().trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return 'Untitled report';
  }

  String get _category =>
      report['category']?.toString().trim().isNotEmpty == true
          ? report['category'].toString()
          : 'Other';

  String get _status {
    final value = (report['status']?.toString() ?? 'Open').trim();
    if (value.isEmpty) return 'Open';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String get _severity {
    final value = (report['severity']?.toString() ?? '').trim();
    if (value.isEmpty) return 'Unknown';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  String get _location =>
      report['location']?.toString().trim().isNotEmpty == true
          ? report['location'].toString()
          : 'Unknown location';

  String get _description {
    final value = report['description']?.toString().trim() ?? '';
    return value.isEmpty ? 'No description provided.' : value;
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFFB8C00);
      case 'low':
        return const Color(0xFF43A047);
      default:
        return _muted;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF2160E1);
      case 'in progress':
        return const Color(0xFFFB8C00);
      case 'resolved':
        return const Color(0xFF43A047);
      case 'draft':
        return _muted;
      default:
        return _cta;
    }
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return 'Recently';
    }
  }

  Widget? _buildReportImage(dynamic raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    Widget image;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(
        value,
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 260,
            color: _iconBg,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    } else if (value.startsWith('data:image') && value.contains(',')) {
      try {
        final b64 = value.split(',').last;
        image = Image.memory(
          base64Decode(b64),
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }

    return image;
  }

  Widget _imageFallback() {
    final catColor = ReportCategories.color(_category);
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cta
      ),
      child: Center(
        child: Icon(
          ReportCategories.icon(_category),
          size: 64,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportImage = _buildReportImage(report['image']);
    final hasPhoto = reportImage != null;
    final severityColor = _severityColor(_severity);
    final statusColor = _statusColor(_status);

    return Scaffold(
      backgroundColor: _pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasPhoto ? 260 : 180,
            pinned: true,
            stretch: true,
            backgroundColor: _cta,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Report',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  hasPhoto ? reportImage! : _imageFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(
                              label: ReportCategories.label(_category),
                              color: Colors.white,
                              background: Colors.white.withValues(alpha: 0.2),
                              icon: ReportCategories.icon(_category),
                            ),
                            _chip(
                              label: _status,
                              color: Colors.white,
                              background: statusColor.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _metaCard(
                          icon: Icons.priority_high_rounded,
                          iconColor: severityColor,
                          label: 'Severity',
                          value: _severity,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metaCard(
                          icon: Icons.schedule_rounded,
                          iconColor: _cta,
                          label: 'Reported',
                          value: _formatTime(report['time']?.toString() ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: _cta,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _location,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    child: Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      children: [
                        _detailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _category,
                        ),
                        const Divider(height: 22),
                        _detailRow(
                          icon: Icons.flag_outlined,
                          label: 'Status',
                          value: _status,
                          valueColor: statusColor,
                        ),
                        const Divider(height: 22),
                        _detailRow(
                          icon: Icons.bolt_outlined,
                          label: 'Severity',
                          value: _severity,
                          valueColor: severityColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required Color background,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return _sectionCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? _ink,
          ),
        ),
      ],
    );
  }
}
