import 'dart:async';

import 'package:flutter/material.dart';
import 'package:street_sync/VoiceReportScreen.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/ViewReportsScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenOnMap,
    this.statsTourKey,
    this.quickActionsTourKey,
    this.recentReportsTourKey,
  });

  /// Opens the Map tab; pass [reportId] to focus that pin.
  final void Function({int? reportId})? onOpenOnMap;
  final GlobalKey? statsTourKey;
  final GlobalKey? quickActionsTourKey;
  final GlobalKey? recentReportsTourKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  static const _blue = Color(0xFF2196F3);
  static const _iconBg = Color(0xFFE8F4FD);

  final List<String> cat = ReportCategories.all;
  String? _selectedCat;
  List<dynamic> _recentReports = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 5;

  int _nearbyCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  /// Bumps on each refresh so stale prefetch / loads don't overwrite newer UI.
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _paintCachedFeed() async {
    final cachedReports = await ApiService.getCachedHomeFeed(_selectedCat);
    final cachedHasMore = await ApiService.getCachedHomeHasMore(_selectedCat);
    final cachedStats = _selectedCat == null
        ? await ApiService.getCachedReportStats()
        : null;

    if (!mounted) return;

    final hasFeed = cachedReports != null && cachedReports.isNotEmpty;

    setState(() {
      if (hasFeed) {
        _recentReports = List<dynamic>.from(cachedReports);
        _hasMore = cachedHasMore ?? false;
        _isLoading = false;
      } else {
        _recentReports = [];
        _hasMore = cachedHasMore ?? false;
        // Nothing to show yet — keep / start skeleton until network paints.
        _isLoading = true;
      }
      if (cachedStats != null) {
        _nearbyCount = cachedStats['nearby'] ?? 0;
        _inProgressCount = cachedStats['in_progress'] ?? 0;
        _resolvedCount = cachedStats['resolved'] ?? 0;
      }
    });
  }

  Future<void> _persistFeed(
    String? category,
    List<dynamic> reports,
    bool hasMore,
  ) async {
    await ApiService.cacheHomeFeed(category, reports);
    await ApiService.cacheHomeHasMore(category, hasMore);
  }

  Future<void> _loadReports({bool forceNetwork = false}) async {
    if (!forceNetwork) {
      await _paintCachedFeed();
    }

    final selected = _selectedCat;
    final results = await Future.wait([
      ApiService.getReportsFeed(
        amount: _pageSize + 1,
        category: selected,
      ),
      ApiService.getReportStats(),
    ]);

    final raw = results[0] as List<dynamic>?;
    final stats = results[1] as Map<String, int>?;

    if (!mounted) return;
    // User may have switched chips while this request was in flight.
    if (selected != _selectedCat) return;

    if (raw != null) {
      final page = ApiService.trimFeedPage(raw, _pageSize);
      await _persistFeed(selected, page.items, page.hasMore);
      if (!mounted || selected != _selectedCat) return;
      setState(() {
        _recentReports = page.items;
        _hasMore = page.hasMore;
        if (stats != null) {
          _nearbyCount = stats['nearby'] ?? 0;
          _inProgressCount = stats['in_progress'] ?? 0;
          _resolvedCount = stats['resolved'] ?? 0;
        }
        _isLoading = false;
      });
      return;
    }
    if (mounted && selected == _selectedCat) {
      setState(() {
        if (stats != null) {
          _nearbyCount = stats['nearby'] ?? 0;
          _inProgressCount = stats['in_progress'] ?? 0;
          _resolvedCount = stats['resolved'] ?? 0;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _recentReports.isEmpty) return;

    final lastTime = _recentReports.last['time']?.toString();
    if (lastTime == null || lastTime.isEmpty) return;

    final selected = _selectedCat;
    setState(() => _isLoadingMore = true);

    final raw = await ApiService.getReportsFeed(
      amount: _pageSize + 1,
      category: selected,
      before: lastTime,
    );

    if (!mounted) return;
    if (selected != _selectedCat) {
      setState(() => _isLoadingMore = false);
      return;
    }

    if (raw == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    final page = ApiService.trimFeedPage(raw, _pageSize);
    final merged = [..._recentReports, ...page.items];
    await _persistFeed(selected, merged, page.hasMore);

    if (!mounted || selected != _selectedCat) return;

    setState(() {
      _recentReports = merged;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
    });
  }

  /// Pull-to-refresh: wipe report caches, skeleton, load active chip first,
  /// then warm every other chip into cache in the background.
  ///
  /// Active-chip-first is faster *to feel ready* than loading everything then
  /// splitting — the feed API is already per-category + paged, so "All" isn't
  /// just the sum of the other chips' first pages.
  Future<void> _fetchReports() async {
    final gen = ++_loadGen;
    final activeCat = _selectedCat;

    await ApiService.clearHomeReportCaches();
    if (!mounted || gen != _loadGen) return;

    setState(() {
      _isLoading = true;
      _recentReports = [];
      _hasMore = false;
    });

    final results = await Future.wait([
      ApiService.getReportsFeed(
        amount: _pageSize + 1,
        category: activeCat,
      ),
      ApiService.getReportStats(),
    ]);

    if (!mounted || gen != _loadGen) return;

    final raw = results[0] as List<dynamic>?;
    final stats = results[1] as Map<String, int>?;

    // Only paint if user is still on the chip we refreshed for.
    if (activeCat == _selectedCat) {
      if (raw != null) {
        final page = ApiService.trimFeedPage(raw, _pageSize);
        await _persistFeed(activeCat, page.items, page.hasMore);
        if (!mounted || gen != _loadGen) return;
        if (activeCat == _selectedCat) {
          setState(() {
            _recentReports = page.items;
            _hasMore = page.hasMore;
            if (stats != null) {
              _nearbyCount = stats['nearby'] ?? 0;
              _inProgressCount = stats['in_progress'] ?? 0;
              _resolvedCount = stats['resolved'] ?? 0;
            }
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          if (stats != null) {
            _nearbyCount = stats['nearby'] ?? 0;
            _inProgressCount = stats['in_progress'] ?? 0;
            _resolvedCount = stats['resolved'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } else if (raw != null) {
      // User switched chips; still cache the refreshed active-at-start feed.
      final page = ApiService.trimFeedPage(raw, _pageSize);
      await _persistFeed(activeCat, page.items, page.hasMore);
    }

    if (!mounted || gen != _loadGen) return;
    unawaited(_prefetchOtherCategoryFeeds(
      gen: gen,
      skipCategory: activeCat,
    ));
  }

  Future<void> _prefetchOtherCategoryFeeds({
    required int gen,
    required String? skipCategory,
  }) async {
    // null = All, then each category chip.
    final categories = <String?>[null, ...ReportCategories.all];
    final others =
        categories.where((c) => c != skipCategory).toList(growable: false);

    await Future.wait(others.map((category) async {
      if (gen != _loadGen) return;
      final raw = await ApiService.getReportsFeed(
        amount: _pageSize + 1,
        category: category,
      );
      if (gen != _loadGen || raw == null) return;
      final page = ApiService.trimFeedPage(raw, _pageSize);
      await _persistFeed(category, page.items, page.hasMore);
    }));
  }

  TextStyle get _sectionTitle =>
      const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink);

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recently';
    }
  }

  IconData _iconFromCat(String category) => ReportCategories.icon(category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _fetchReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    KeyedSubtree(
                      key: widget.quickActionsTourKey,
                      child: twocardsection(context),
                    ),
                    const SizedBox(height: 20),
                    KeyedSubtree(
                      key: widget.recentReportsTourKey,
                      child: Column(
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const ReportListSkeleton(count: 4)
                    else
                      ..._recentReports.map(
                        (r) => _buildReportCard(
                          icon: _iconFromCat(r['category']),
                          severity: r['severity'] as String,
                          name:
                              (r['title'] as String?)?.trim().isNotEmpty == true
                              ? r['title'] as String
                              : (r['description'] as String? ?? 'Report'),
                          location: r['location'] as String,
                          time: _formatTime(r['time'] as String),
                          onTap: () {
                            final raw = r['id'];
                            final id = raw is int ? raw : int.tryParse('$raw');
                            widget.onOpenOnMap?.call(reportId: id);
                          },
                        ),
                      ),
                    if (!_isLoading && _recentReports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No reports in this category',
                            style: TextStyle(color: _muted, fontSize: 14),
                          ),
                        ),
                      ),
                    if (!_isLoading && _hasMore && _recentReports.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: _isLoadingMore ? null : _loadMore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _blue.withValues(
                                alpha: 0.6,
                              ),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            child: Text(
                              _isLoadingMore ? 'Loading...' : 'Show more',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = options[i];
          final selected = (_selectedCat ?? 'All') == label;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (selected) {
              if (!selected) return;
              final nextCat = label == 'All' ? null : label;
              if (nextCat == _selectedCat) return;

              setState(() {
                _selectedCat = nextCat;
                // Don't force-hide Show more — cached hasMore paints next.
              });
              // Use cache for this category (feed + hasMore), then refresh.
              _loadReports();
            },
            selectedColor: _blue.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? _blue : _muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(color: selected ? _blue : Colors.grey.shade300),
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
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
        ),
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
          color: Colors.green,
          icon: Icons.camera_alt,
          title: 'Photo report',
          subtitle: 'Take a picture',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CommunityReportScreen()),
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
    return KeyedSubtree(
      key: widget.statsTourKey,
      child: Row(
        children: [
          _statCard(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            value: _nearbyCount.toString(),
            label: 'Nearby',
            onTap: () => _openStatusReports(filter: 'nearby', title: 'Nearby'),
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.build_rounded,
            iconColor: Colors.orange,
            value: _inProgressCount.toString(),
            label: 'In progress',
            onTap: () =>
                _openStatusReports(filter: 'in_progress', title: 'In progress'),
          ),
          const SizedBox(width: 10),
          _statCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            value: _resolvedCount.toString(),
            label: 'Resolved',
            onTap: () =>
                _openStatusReports(filter: 'resolved', title: 'Resolved'),
          ),
        ],
      ),
    );
  }

  void _openStatusReports({required String filter, required String title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewReportsScreen(filter: filter, title: title),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
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
          Text(
            'Hi ${ApiService.firstName}',
            style: const TextStyle(
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
