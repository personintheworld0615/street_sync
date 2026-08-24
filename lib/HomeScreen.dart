import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/VoiceReportScreen.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/ViewReportsScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_list_card.dart';
import 'package:street_sync/skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenOnMap,
    this.statsTourKey,
    this.quickActionsTourKey,
    this.recentReportsTourKey,
    this.voiceActionTourKey,
  });

  /// Opens the Map tab; pass [reportId] to focus that pin.
  final void Function({int? reportId})? onOpenOnMap;
  final GlobalKey? statsTourKey;
  final GlobalKey? quickActionsTourKey;
  final GlobalKey? recentReportsTourKey;
  final GlobalKey? voiceActionTourKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _cta = Color(0xFF111827);

  static TextStyle get _tBrand => GoogleFonts.nunito(
        fontSize: 50,
        fontWeight: FontWeight.w700,
        color: Colors.black,
        height: 1.0,
        letterSpacing: 1.2,
      );
  static TextStyle get _tGreeting => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: Colors.black,
        height: 1.2,
        letterSpacing: -0.2,
      );
  static TextStyle get _tLocation => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _muted,
        height: 1.25,
      );
  static TextStyle get _tStatValue => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _ink,
        height: 1.1,
        letterSpacing: -0.3,
      );
  static TextStyle get _tStatLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF6B7280),
        height: 1.2,
      );
  static TextStyle get _tNearYou => GoogleFonts.inter(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        color: _ink,
        height: 1.1,
        letterSpacing: -0.5,
      );
  static TextStyle get _tFilter => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _muted,
        height: 1.2,
      );
  static TextStyle get _tFilterSelected => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _ink,
        height: 1.2,
      );

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
  int _loadGen = 0;

  String _locationLabel = 'Locating…';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadLocation();
  }

  Future<void> _paintCachedFeed() async {
    final cachedReports = await ApiService.getCachedHomeFeed(_selectedCat);
    final cachedHasMore = await ApiService.getCachedHomeHasMore(_selectedCat);
    final cachedStats = _selectedCat == null
        ? await ApiService.getCachedReportStats()
        : null;

    if (!mounted) return;

    final hasCached = cachedReports != null;

    setState(() {
      if (hasCached) {
        _recentReports = List<dynamic>.from(cachedReports);
        _hasMore = cachedHasMore ?? false;
        _isLoading = false;
      } else {
        _recentReports = [];
        _hasMore = cachedHasMore ?? false;
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
      final page = ApiService.trimFeedPage(raw, _pageSize);
      await _persistFeed(activeCat, page.items, page.hasMore);
    }

    if (!mounted || gen != _loadGen) return;
    await _loadLocation(forceRefresh: true);
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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadLocation({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await ApiService.getCachedHomeLocation();
      if (cached != null && mounted) {
        setState(() => _locationLabel = cached);
      }
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        if (_locationLabel == 'Locating…') {
          setState(() => _locationLabel = 'No location found');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final places =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;

      var label = 'No location found';
      if (places.isNotEmpty) {
        final p = places.first;
        final city = (p.locality?.trim().isNotEmpty == true)
            ? p.locality!.trim()
            : (p.subAdministrativeArea?.trim() ?? '');
        final region = p.administrativeArea?.trim() ?? '';
        if (city.isNotEmpty && region.isNotEmpty) {
          label = '$city, $region';
        } else if (city.isNotEmpty) {
          label = city;
        } else if (region.isNotEmpty) {
          label = region;
        }
      }

      if (label != 'No location found') {
        await ApiService.cacheHomeLocation(label);
      }
      if (!mounted) return;
      setState(() => _locationLabel = label);
    } catch (_) {
      if (!mounted) return;
      if (_locationLabel == 'Locating…') {
        setState(() => _locationLabel = 'No location found');
      }
    }
  }

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

  IconData _iconFromCat(String? category) => ReportCategories.icon(category);

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: widget.recentReportsTourKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Near you', style: _tNearYou),
                          const SizedBox(height: 22),
                          _buildCategoryFilters(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const ReportListSkeleton(count: 4)
                    else
                      ..._recentReports.map(
                        (r) {
                          final map = Map<String, dynamic>.from(r as Map);
                          final title =
                              (map['title'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? map['title'] as String
                                  : (map['description'] as String? ?? 'Report');
                          return ReportListCard(
                            icon: _iconFromCat(map['category'] as String?),
                            pill: ReportListCard.displayPill(map),
                            title: title,
                            location: map['location'] as String? ?? '',
                            time: _formatTime(map['time'] as String? ?? ''),
                            onTap: () {
                              final raw = map['id'];
                              final id =
                                  raw is int ? raw : int.tryParse('$raw');
                              widget.onOpenOnMap?.call(reportId: id);
                            },
                          );
                        },
                      ),
                    if (!_isLoading && _recentReports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No reports in this category',
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    if (!_isLoading && _hasMore && _recentReports.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Center(
                          child: Material(
                            color: const Color(0xFFE8EAED),
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: _isLoadingMore ? null : _loadMore,
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Text(
                                  _isLoadingMore ? 'Loading...' : 'Show more',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    color: _isLoadingMore ? _muted : _ink,
                                  ),
                                ),
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
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final value = options[i];
          final label =
              value == 'All' ? 'All' : ReportCategories.label(value);
          final selected = (_selectedCat ?? 'All') == value;

          return GestureDetector(
            onTap: () {
              final nextCat = value == 'All' ? null : value;
              if (nextCat == _selectedCat) return;
              setState(() => _selectedCat = nextCat);
              _loadReports();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8EAED) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: selected ? _tFilterSelected : _tFilter,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget twocardsection(BuildContext context) {
    return KeyedSubtree(
      key: widget.quickActionsTourKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(25, 14, 10, 14),
        decoration: BoxDecoration(
          color: _cta,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Report an issue',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _reportModeChip(
                    key: widget.voiceActionTourKey,
                    icon: Icons.graphic_eq_rounded,
                    label: 'Voice',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VoiceReportScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  _reportModeChip(
                    icon: Icons.photo_camera_outlined,
                    label: 'Photo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityReportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportModeChip({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget threecard() {
    return KeyedSubtree(
      key: widget.statsTourKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Row(
              children: [
                _statCell(
                  value: _nearbyCount.toString(),
                  label: 'nearby',
                  onTap: () => _openStatusReports(
                    filter: 'nearby',
                    title: 'Nearby',
                  ),
                ),
                _statDivider(),
                _statCell(
                  value: _inProgressCount.toString(),
                  label: 'active',
                  onTap: () => _openStatusReports(
                    filter: 'in_progress',
                    title: 'In progress',
                  ),
                ),
                _statDivider(),
                _statCell(
                  value: _resolvedCount.toString(),
                  label: 'resolved',
                  onTap: () => _openStatusReports(
                    filter: 'resolved',
                    title: 'Resolved',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.55),
    );
  }

  Widget _statCell({
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: _tStatValue,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: _tStatLabel,
              ),
            ],
          ),
        ),
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

  Widget header() {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Transform.scale(
                scale: 1.05,
                child: Opacity(
                  opacity: 1.0,
                  child: Image.asset(
                    'assets/images/home_hero.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.15),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.08),
                  _pageBg.withValues(alpha: 0.4),
                  _pageBg.withValues(alpha: 0.88),
                  _pageBg,
                ],
                stops: const [0.0, 0.3, 0.58, 0.84, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.scale(
                scaleX: 1.0,
                scaleY: 1.0,
                alignment: Alignment.centerLeft,
                child: Text('StreetSync', style: _tBrand),
              ),
              const SizedBox(height: 8),
              Text(
                '$_greeting, ${ApiService.firstName}',
                style: _tGreeting,
              ),
              const SizedBox(height: 4),
              Text(
                _locationLabel,
                style: _tLocation,
              ),
              const SizedBox(height: 28),
              threecard(),
              const SizedBox(height: 20),
              twocardsection(context),
            ],
          ),
        ),
      ],
    );
  }
}
