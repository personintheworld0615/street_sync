import 'package:flutter/material.dart';
import 'package:street_sync/CommunityReportScreen.dart';

class MyReportsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  const MyReportsScreen({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A237E),
        title: const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView.separated(
              padding: const EdgeInsets.all(15),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = reports[index];
                return _reportCard(
                  icon: report['icon'] as IconData,
                  status: report['status'] as String,
                  name: report['name'] as String,
                  location: report['location'] as String,
                  time: report['time'] as String,
                  bgColor: report['bgColor'] as Color,
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


  Widget _reportCard({
    required IconData icon,
    required String status,
    required String location,
    required String name,
    required String time,
    required Color bgColor,
  }) {
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
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
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
              Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFB86B2A);
      case 'Open':
        return Colors.blue[700]!;
      case 'Resolved':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}
