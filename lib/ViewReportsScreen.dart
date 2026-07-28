import 'package:flutter/material.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/ReportDetails.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/skeleton.dart';

/// Home stat-card destination: nearby / in progress / resolved reports.
class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({
    super.key,
    required this.filter,
    required this.title,
  });

  /// One of: `nearby`, `in_progress`, `resolved`.
  final String filter;
  final String title;

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  static const _ink = Color(0xFF1A237E);
  static const _muted = Color(0xFF5B677A);

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await ApiService.getReportsByFilter(widget.filter);
    if (!mounted) return;
    setState(() {
      _reports = (raw ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(15),
                children: const [ReportListSkeleton(count: 5)],
              )
            : _reports.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No ${widget.title.toLowerCase()} reports',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(15),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      final title = report['title'] as String?;
                      final name = (title != null && title.trim().isNotEmpty)
                          ? title
                          : report['name'] as String? ??
                              report['category'] as String? ??
                              'Report';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReportDetailsScreen(report: report),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: _reportCard(
                            icon: ReportCategories.icon(
                              report['category'] as String?,
                            ),
                            status: _formatStatus(
                              report['status'] as String?,
                            ),
                            name: name,
                            location: report['location'] as String? ?? '',
                            time: _formatTime(report['time']),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CommunityReportScreen()),
          );
        },
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New report'),
      ),
    );
  }

  String _formatStatus(String? status) {
    final value = (status ?? 'Open').trim();
    if (value.isEmpty) return 'Open';
    // Keep "In Progress" readable.
    if (value.toLowerCase() == 'in progress') return 'In Progress';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  String _formatTime(dynamic time) {
    if (time is String) {
      final parsed = DateTime.tryParse(time);
      if (parsed != null) {
        final diff = DateTime.now().difference(parsed);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
        if (diff.inHours < 24) return '${diff.inHours} hrs ago';
        return '${diff.inDays} days ago';
      }
      return time;
    }
    return '';
  }

  Widget _reportCard({
    required IconData icon,
    required String status,
    required String location,
    required String name,
    required String time,
  }) {
    const iconBg = Color(0xFFE8F4FD);
    const blue = Color(0xFF2196F3);
    const ink = Color(0xFF152033);
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: iconBg,
            child: Icon(icon, size: 22, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFFB86B2A);
      case 'open':
        return Colors.blue[700]!;
      case 'in progress':
        return Colors.orange[800]!;
      case 'resolved':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}
