import 'package:flutter/material.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/MyReportsScreen.dart';

import 'MyPendingReportsScreen.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  bool pushNotifications = true;
  bool locationSharing = true;

  // Empty list shows the blank slate. Add maps here to show report cards.
  final List<Map<String, dynamic>> _myReports = [
    {
      'icon': Icons.construction,
      'status': 'Pending',
      'name': 'Large pothole',
      'location': 'Nassau St & Mercer St',
      'time': '12 min ago',
      'bgColor': Colors.pink[200]!,
    },
    {
      'icon': Icons.traffic,
      'status': 'Open',
      'name': 'Broken streetlight',
      'location': 'Witherspoon St',
      'time': '2 hrs ago',
      'bgColor': Colors.amber[200]!,
    },
    {
      'icon': Icons.delete_outline,
      'status': 'Resolved',
      'name': 'Overflowing trash',
      'location': 'Palmer Square',
      'time': '1 day ago',
      'bgColor': Colors.green[200]!,
    },
    {
      'icon': Icons.water_drop_outlined,
      'status': 'Open',
      'name': 'Sidewalk flooding',
      'location': 'University Place',
      'time': '3 days ago',
      'bgColor': Colors.lightBlue[100]!,
    },
    {
      'icon': Icons.park_outlined,
      'status': 'Pending',
      'name': 'Fallen tree branch',
      'location': 'Marquand Park',
      'time': '5 days ago',
      'bgColor': Colors.orange[100]!,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        child: Column(
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
              child: Column(
                children: [
                  // impactScoreCard(),
                  // const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('3 of 6 earned', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  badgesGrid(),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_myReports.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyReportsScreen(reports: _myReports),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text('See all', style: TextStyle(color: Colors.blue[600], fontSize: 13)),

                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  myReportsList(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Pending Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_myReports.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyPendingReportsScreen(reports: _myReports),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text('See all', style: TextStyle(color: Colors.blue[600], fontSize: 13)),
                            ]
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  myPendingReportsList(),
                  prefrencesCard()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget prefrencesCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            _prefRow(
              icon: Icons.notifications_none,
              iconBg: Colors.blue[50]!,
              iconColor: Colors.blue[600]!,
              title: 'Push Notifications',
              subtitle: 'Report updates & nearby alerts',
              trailing: Switch(
                value: pushNotifications,
                activeColor: Colors.blue,
                onChanged: (value) => setState(() => pushNotifications = value),
              ),
            ),
            Divider(color: Colors.grey[200], height: 1),
            _prefRow(
              icon: Icons.shield_outlined,
              iconBg: Colors.blue[50]!,
              iconColor: const Color(0xFF1565C0),
              title: 'Privacy Policy',
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () {},
            ),
            Divider(color: Colors.grey[200], height: 1),
            _prefRow(
              icon: Icons.logout,
              iconBg: Colors.red[50]!,
              iconColor: Colors.red[600]!,
              title: 'Sign Out',
              titleColor: Colors.red[600],
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _prefRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconBg,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: titleColor ?? const Color(0xFF1A237E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
  Widget myPendingReportsList() {
    if (_myReports.isEmpty) {
      return _emptyReportsState("You dont have any pending reports yet");
    }

    final count = _myReports.length.clamp(0, 3);//replace with pending reports
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) Divider(color: Colors.grey[200], height: 1),
            _buildReportCard(
              icon: _myReports[i]['icon'] as IconData,
              status: _myReports[i]['status'] as String,
              name: _myReports[i]['name'] as String,
              location: _myReports[i]['location'] as String,
              time: _myReports[i]['time'] as String,
              bgColor: _myReports[i]['bgColor'] as Color,
            ),
          ],
        ],
      ),
    );
  }
  Widget myReportsList() {
    if (_myReports.isEmpty) {
      return _emptyReportsState("Create a new report");
    }

    final count = _myReports.length.clamp(0, 3);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) Divider(color: Colors.grey[200], height: 1),
            _buildReportCard(
              icon: _myReports[i]['icon'] as IconData,
              status: _myReports[i]['status'] as String,
              name: _myReports[i]['name'] as String,
              location: _myReports[i]['location'] as String,
              time: _myReports[i]['time'] as String,
              bgColor: _myReports[i]['bgColor'] as Color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyReportsState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blue[50],
            child: Icon(Icons.assignment_outlined, size: 28, color: Colors.blue[400]),
          ),
          const SizedBox(height: 14),
          Text(
            'No reports yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CommunityReportScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create a new report'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String status,
    required String location,
    required String name,
    required String time,
    Color bgColor = Colors.red,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              _statusChip(status),
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

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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

  Widget header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: IconButton(onPressed: () {}, icon: const Icon(Icons.settings, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://i.pravatar.cc/150?u=alex'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: CircleAvatar(radius: 9, backgroundColor: Colors.green)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Krish Sinha', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('krishworld432@gmail.com', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _infoChip(Icons.location_on, 'West Windsor, NJ'),
                        const SizedBox(width: 8),
                        _infoChip(null, 'Aura King', color: const Color(0xFF26C6DA)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _statBox('23', 'Reports'),
              const SizedBox(width: 12),
              _statBox('141', 'Upvotes'),
              const SizedBox(width: 12),
              _statBox('18', 'Resolved'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData? icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.white),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget impactScoreCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Civic Impact Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Top 12% in district', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progress to City Champion', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('740 / 1000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(value: 0.74, minHeight: 10, backgroundColor: Color(0xFFEEEEEE), valueColor: AlwaysStoppedAnimation(Colors.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 65, height: 65,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blue, Color(0xFF1565C0)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: const Text('740', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget badgesGrid() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _badgeCard(
                'Top Reporter',
                '10+ accepted reports',
                Icons.emoji_events,
                Colors.amber,
                true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _badgeCard(
                'Community Walker',
                '5 walk sessions',
                Icons.directions_walk,
                Colors.orange,
                true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _badgeCard(
                'Fast Responder',
                'Report within 1hr of issue',
                Icons.bolt,
                Colors.amber,
                true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _badgeCard(
                'City Champion',
                '50+ reports submitted',
                Icons.star,
                Colors.amber,
                false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _badgeCard(
                'Voice Pioneer',
                '10 voice reports',
                Icons.mic,
                Colors.blueGrey,
                false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _badgeCard(
                'Collaborator',
                'Confirmed 20 duplicates',
                Icons.handshake,
                Colors.blue,
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badgeCard(
      String title,
      String description,
      IconData icon,
      Color color,
      bool earned,
      ) {
    return Opacity(
      opacity: earned ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                height: 1.2,
              ),
            ),
            if (earned) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
            ],
          ],
        ),
      ),
    );
  }
}