import 'package:flutter/material.dart';
import 'package:street_sync/VoiceReportScreen.dart';
import 'package:street_sync/CommunityReportScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  static const _blue = Color(0xFF2196F3);
  static const _iconBg = Color(0xFFE8F4FD);

  final List<String> cat = [
    'Road Damage',
    'Public Works',
    'Environmental',
    'Accessibility',
    'Other',
  ];
  String? _selectedCat;

  // Placeholder recent reports (category as title — matches real data model).
  final List<Map<String, dynamic>> _recentReports = [
    {
      'category': 'Road Damage',
      'location': 'Nassau St & Mercer St',
      'time': '12 min ago',
      'severity': 'high',
      'icon': Icons.construction_rounded,
    },
    {
      'category': 'Public Works',
      'location': 'Witherspoon St',
      'time': '2 hrs ago',
      'severity': 'medium',
      'icon': Icons.handyman_outlined,
    },
    {
      'category': 'Environmental',
      'location': 'Palmer Square',
      'time': '1 day ago',
      'severity': 'low',
      'icon': Icons.eco_outlined,
    },
  ];

  TextStyle get _sectionTitle => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _ink,
      );

  List<Map<String, dynamic>> get _filteredReports {
    if (_selectedCat == null) return _recentReports;
    return _recentReports
        .where((r) => r['category'] == _selectedCat)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  threecard(),
                  const SizedBox(height: 20),
                  Text('Quick actions', style: _sectionTitle),
                  const SizedBox(height: 12),
                  twocardsection(context),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent reports', style: _sectionTitle),
                      const Text(
                        'Near you',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryFilters(),
                  const SizedBox(height: 12),
                  ..._filteredReports.map(
                    (r) => _buildReportCard(
                      icon: r['icon'] as IconData,
                      severity: r['severity'] as String,
                      name: r['category'] as String,
                      location: r['location'] as String,
                      time: r['time'] as String,
                    ),
                  ),
                  if (_filteredReports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No reports in this category',
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final options = ['All', ...cat];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = options[i];
          final selected = (_selectedCat ?? 'All') == label;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCat = label == 'All' ? null : label);
            },
            selectedColor: _blue.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? _blue : _muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected ? _blue : Colors.grey.shade300,
            ),
            backgroundColor: Colors.white,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReportCard({
    required IconData icon,
    required String severity,
    required String location,
    required String name,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _iconBg,
            child: Icon(icon, size: 22, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(fontSize: 12, color: _muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _severityColor(severity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
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

  Widget twocardsection(BuildContext context) {
    return Row(
      children: [
        _buildActionCard(
          color: _blue,
          icon: Icons.mic,
          title: 'Voice report',
          subtitle: 'Speak to report',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VoiceReportScreen(),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _buildActionCard(
          color:  Colors.green,
          icon: Icons.camera_alt,
          title: 'Photo report',
          subtitle: 'Take a picture',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityReportScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget threecard() {
    return Row(
      children: [
        _statCard(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.red,
          value: '6',
          label: 'Nearby',
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.build_rounded,
          iconColor: Colors.orange,
          value: '3',
          label: 'In progress',
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
          value: '12',
          label: 'Resolved',
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    return Container(
      width: double.infinity,
      color: _blue,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'StreetSync',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Good morning Aarav',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me_outlined, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'West Windsor, NJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
