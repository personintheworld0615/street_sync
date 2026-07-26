import 'package:flutter/material.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/LoginScreen.dart';
import 'package:street_sync/MyReportsScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:street_sync/skeleton.dart';

import 'MyDraftReportsScreen.dart';
import 'UpdateThing.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  bool pushNotifications = true;
  bool locationSharing = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _draftReports = [];
  List<Map<String, dynamic>> _submittedReports = [];

  @override
  void initState() {
    super.initState();
    _loadUserReports();
  }

  Future<void> _loadUserReports({bool forceNetwork = false}) async {
    final userId = ApiService.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _draftReports = [];
        _submittedReports = [];
        _isLoading = false;
      });
      return;
    }

    if (!forceNetwork) {
      final cachedDrafts = await ApiService.getCachedDraftReports(userId);
      final cachedSubmitted =
          await ApiService.getCachedSubmittedReports(userId);
      if ((cachedDrafts != null || cachedSubmitted != null) && mounted) {
        setState(() {
          if (cachedDrafts != null) {
            _draftReports = cachedDrafts
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (cachedSubmitted != null) {
            _submittedReports = cachedSubmitted
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          _isLoading = false;
        });
      }
    }

    final results = await Future.wait([
      ApiService.getDraftReports(userId),
      ApiService.getSubmittedReports(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _draftReports = results[0]
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _submittedReports = results[1]
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _fetchUserReports() => _loadUserReports(forceNetwork: true);

  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  static const _blue = Color(0xFF2196F3);
  static const _iconBg = Color(0xFFE8F4FD);

  TextStyle get _sectionTitle => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _ink,
      );

  IconData _iconFromCategory(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'road damage':
        return Icons.construction_rounded;
      case 'public works':
        return Icons.handyman_outlined;
      case 'environmental':
        return Icons.eco_outlined;
      case 'accessibility':
        return Icons.accessible_forward_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ProfileSkeleton();
    }

    final int reportsCount = _submittedReports.length;

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _fetchUserReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              header(ApiService.userName, reportsCount),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    _sectionHeader(
                      title: 'My Drafts',
                      seeAll: _draftReports.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MyDraftReportsScreen(
                                    reports: _draftReports,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    myDraftReportsList(),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      title: 'My Reports',
                      seeAll: _submittedReports.isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MyReportsScreen(
                                    reports: _submittedReports,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    myReportsList(),
                    const SizedBox(height: 20),
                    prefrencesCard(),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      title: 'Badges',
                      trailing: Text(
                        '${reportsCount >= 10 ? 3 : (reportsCount >= 5 ? 2 : (reportsCount >= 1 ? 1 : 0))} of 6 earned',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                    badgesGrid(reportsCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    VoidCallback? seeAll,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: _sectionTitle),
        if (seeAll != null)
          GestureDetector(
            onTap: seeAll,
            child: Text(
              'See all',
              style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          )
        else if (trailing != null)
          trailing,
      ],
    );
  }
  Widget prefrencesCard() {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
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
                color: _muted,
              ),
            ),
            const SizedBox(height: 8),
            _prefRow(
              icon: Icons.notifications_none,
              iconBg: _iconBg,
              iconColor: _blue,
              title: 'Push Notifications',
              subtitle: 'Report updates & nearby alerts',
              trailing: Switch(
                value: pushNotifications,
                activeThumbColor: _blue,
                onChanged: (value) => setState(() => pushNotifications = value),
              ),
            ),
            Divider(color: Colors.grey[200], height: 1),
            _prefRow(
              icon: Icons.shield_outlined,
              iconBg: _iconBg,
              iconColor: _blue,
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
              onTap: () async {
                await ApiService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
            Divider(color: Colors.grey[200], height: 1),
            _prefRow(
              icon: Icons.delete_outline,
              iconBg: Colors.red[50]!,
              iconColor: Colors.red[600]!,
              title: 'Delete Account',
              titleColor: Colors.red[600],
              onTap: _confirmDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and reports. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await ApiService.deleteAccount();
    if (!mounted) return;

    if (error != null) {
      await showErrorPopup(context, error);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
                      color: titleColor ?? _ink,
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
  BoxDecoration get _listDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      );

  Widget myDraftReportsList() {
    if (_draftReports.isEmpty) {
      return _emptyReportsState(
        'Save a report as a draft to finish it later',
      );
    }

    final count = _draftReports.length.clamp(0, 3);
    return Container(
      decoration: _listDecoration,
      child: Column(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) Divider(color: Colors.grey[200], height: 1),
            _buildDraftCard(_draftReports[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> report) {
    final name = (report['title'] as String?)?.trim().isNotEmpty == true
        ? report['title'] as String
        : report['category'] as String? ?? 'Draft report';
    final location = report['location'] as String? ?? '';
    final status = 'Draft';
    final icon = _iconFromCategory(report['category'] as String?);
    final time = _formatDraftTime(report['time']);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Updatething.fromDraft(report)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: _buildReportCard(
        icon: icon,
        status: status,
        name: name,
        location: location,
        time: time,
      ),
    );
  }

  String _formatDraftTime(dynamic time) {
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

  Widget myReportsList() {
    if (_submittedReports.isEmpty) {
      return _emptyReportsState('Create a new report');
    }

    final count = _submittedReports.length.clamp(0, 3);
    return Container(
      decoration: _listDecoration,
      child: Column(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) Divider(color: Colors.grey[200], height: 1),
            _buildSubmittedCard(_submittedReports[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmittedCard(Map<String, dynamic> report) {
    final name = (report['title'] as String?)?.trim().isNotEmpty == true
        ? report['title'] as String
        : report['category'] as String? ?? 'Report';
    return _buildReportCard(
      icon: _iconFromCategory(report['category'] as String?),
      status: _formatStatus(report['status'] as String?),
      name: name,
      location: report['location'] as String? ?? '',
      time: _formatDraftTime(report['time']),
    );
  }

  String _formatStatus(String? status) {
    final value = (status ?? 'Open').trim();
    if (value.isEmpty) return 'Open';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  Widget _emptyReportsState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: _listDecoration,
      child: Column(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: _iconBg,
            child: Icon(Icons.assignment_outlined, size: 28, color: _blue),
          ),
          const SizedBox(height: 14),
          const Text(
            'No drafts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted),
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
              backgroundColor: _blue,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 2),
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
        color: color.withValues(alpha: 0.12),
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
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFFB86B2A);
      case 'open':
        return Colors.blue[700]!;
      case 'resolved':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget header(String name, int reportsCount) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _blue,
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  image: const DecorationImage(
                    image: NetworkImage('https://i.pravatar.cc/150?u=alex'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      ApiService.userEmail ?? 'No email',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoChip(Icons.location_on, 'West Windsor, NJ'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statBox(reportsCount.toString(), 'Reports'),
              const SizedBox(width: 10),
              _statBox('141', 'Upvotes'),
              const SizedBox(width: 10),
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
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.white),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget badgesGrid(int reportsCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: _badgeCard(
              'Top Reporter',
              '10+ accepted',
              Icons.emoji_events,
              Colors.amber,
              reportsCount >= 10,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _badgeCard(
              'Walker',
              '5 walk sessions',
              Icons.directions_walk,
              Colors.orange,
              reportsCount >= 5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _badgeCard(
              'Fast',
              'Report within 1hr',
              Icons.bolt,
              Colors.amber,
              reportsCount >= 1,
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: _muted,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}