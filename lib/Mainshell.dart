import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:street_sync/ai_tour.dart';
import 'package:street_sync/Leaderboard.dart';
import 'package:street_sync/Profile.dart';

import 'HomeScreen.dart';
import 'Map.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _tourSeenKey = 'street_sync_ai_tour_seen_v1';

  int _index = 0;
  int? _focusReportId;
  bool _showTour = false;

  final _statsTourKey = GlobalKey();
  final _quickActionsTourKey = GlobalKey();
  final _recentReportsTourKey = GlobalKey();
  final _homeNavTourKey = GlobalKey();
  final _mapNavTourKey = GlobalKey();
  final _leaderboardNavTourKey = GlobalKey();
  final _profileNavTourKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _maybeStartFirstRunTour();
  }

  Future<void> _maybeStartFirstRunTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tourSeenKey) == true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() => _showTour = true);
      });
    });
  }

  Future<void> _completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenKey, true);
    if (!mounted) return;
    setState(() => _showTour = false);
  }

  void _startTour() {
    setState(() {
      _index = 0;
      _focusReportId = null;
      _showTour = true;
    });
  }

  List<TourStep> get _tourSteps => [
    TourStep(
      targetKey: _statsTourKey,
      title: 'AI guide: neighborhood pulse',
      content:
          'These cards summarize what is happening nearby. Tap one to jump into reports filtered by that status.',
      icon: Icons.auto_awesome,
    ),
    TourStep(
      targetKey: _quickActionsTourKey,
      title: 'Create reports quickly',
      content:
          'Use voice when you want to describe a street issue hands-free, or photo report when a picture explains it faster.',
      icon: Icons.add_location_alt_rounded,
    ),
    TourStep(
      targetKey: _recentReportsTourKey,
      title: 'Scan recent activity',
      content:
          'Filter by category, review nearby reports, and tap a report to open its pin on the map.',
      icon: Icons.manage_search_rounded,
    ),
    TourStep(
      targetKey: _mapNavTourKey,
      title: 'Open the live map',
      content:
          'The map tab shows reports geographically so you can see clusters, locations, and the issue nearest you.',
      icon: Icons.map_rounded,
    ),
    TourStep(
      targetKey: _leaderboardNavTourKey,
      title: 'Track community impact',
      content:
          'Leaderboard highlights active contributors and gives reporting a little progress loop.',
      icon: Icons.leaderboard_rounded,
    ),
    TourStep(
      targetKey: _profileNavTourKey,
      title: 'Manage your work',
      content:
          'Your profile keeps drafts, submitted reports, badges, and account preferences in one place.',
      icon: Icons.person_rounded,
    ),
  ];

  /// Switch to Map. Pass [reportId] only when opening from a home report.
  void openMap({int? reportId}) {
    setState(() {
      _focusReportId = reportId;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                onOpenOnMap: openMap,
                statsTourKey: _statsTourKey,
                quickActionsTourKey: _quickActionsTourKey,
                recentReportsTourKey: _recentReportsTourKey,
              ),
              MapScreen(isActive: _index == 1, initialReportId: _focusReportId),
              const Leaderboard(),
              const Profile(),
            ],
          ),
          floatingActionButton: _showTour
              ? null
              : FloatingActionButton.small(
                  onPressed: _startTour,
                  tooltip: 'Start AI tour',
                  backgroundColor: const Color(0xFF152033),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.auto_awesome),
                ),
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: const Color(0xFF2196F3),
            unselectedItemColor: const Color(0xFF5B677A),
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
            currentIndex: _index,
            onTap: (index) {
              setState(() {
                // Map tab via bottom nav = no forced report focus
                if (index == 1) {
                  _focusReportId = null;
                }
                _index = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home, key: _homeNavTourKey),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map, key: _mapNavTourKey),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard, key: _leaderboardNavTourKey),
                label: 'Leaderboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, key: _profileNavTourKey),
                label: 'Profile',
              ),
            ],
          ),
        ),
        if (_showTour)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: AiTour(steps: _tourSteps, onComplete: _completeTour),
            ),
          ),
      ],
    );
  }
}
