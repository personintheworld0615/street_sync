import 'package:flutter/material.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/UpdateThing.dart';

class MyDraftReportsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  const MyDraftReportsScreen({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A237E),
        title: const Text(
          'My Drafts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: reports.isEmpty
          ? Center(
              child: Text(
                'No drafts yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(15),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = reports[index];
                final title = report['title'] as String?;
                final name = (title != null && title.trim().isNotEmpty)
                    ? title
                    : report['name'] as String? ??
                        report['category'] as String? ??
                        'Draft report';
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Updatething.fromDraft(report),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: _reportCard(
                    icon: report['icon'] as IconData? ??
                        Icons.edit_note_outlined,
                    status: 'Draft',
                    name: name,
                    location: report['location'] as String? ?? '',
                    time: _formatTime(report['time']),
                    bgColor:
                        report['bgColor'] as Color? ?? Colors.orange[100]!,
                  ),
                );
              },
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
    required Color bgColor,
  }) {
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
            backgroundColor: bgColor.withOpacity(0.55),
            child: Icon(icon, size: 22, color: Colors.grey[800]),
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
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        location,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  color: const Color(0xFFB86B2A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB86B2A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(time,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
