import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:street_sync/CommunityReportScreen.dart';
import 'package:street_sync/VoiceReportScreen.dart';
import 'package:street_sync/ai_tour.dart';
import 'package:street_sync/Profile.dart';
import 'package:street_sync/UpdatesScreen.dart';

import 'HomeScreen.dart';
import 'Map.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _tourSeenKey = 'street_sync_ai_tour_seen_v1';
  // Match HomeScreen: charcoal CTA, not teal.
  static const _cta = Color(0xFF111827);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _dockBg = Color(0xFFFFFFF8);
  static const _selectedPill = Color(0xFFE8EAED);

  int _index = 0;
  int? _focusReportId;
  bool _showTour = false;

  final _statsTourKey = GlobalKey();
  final _quickActionsTourKey = GlobalKey();
  final _recentReportsTourKey = GlobalKey();
  final _homeNavTourKey = GlobalKey();
  final _mapNavTourKey = GlobalKey();
  final _addNavTourKey = GlobalKey();
  final _updatesNavTourKey = GlobalKey();
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
          title: 'Browse reports on the map',
          content:
              'Reports shows issues geographically so you can see clusters, locations, and the issue nearest you.',
          icon: Icons.location_on_outlined,
        ),
        TourStep(
          targetKey: _addNavTourKey,
          title: 'Report from anywhere',
          content:
              'Tap + to start a voice or photo report without leaving the tab you’re on.',
          icon: Icons.add_rounded,
        ),
        TourStep(
          targetKey: _updatesNavTourKey,
          title: 'Stay in the loop',
          content:
              'Updates collects status changes and neighborhood activity as reports move forward.',
          icon: Icons.notifications_none_rounded,
        ),
        TourStep(
          targetKey: _profileNavTourKey,
          title: 'Manage your work',
          content:
              'Your profile keeps drafts, submitted reports, badges, and account preferences in one place.',
          icon: Icons.person_rounded,
        ),
      ];

  void openMap({int? reportId}) {
    setState(() {
      _focusReportId = reportId;
      _index = 1;
    });
  }

  void _onNavTap(int stackIndex) {
    setState(() {
      if (stackIndex == 1) {
        _focusReportId = null;
      }
      _index = stackIndex;
    });
  }

  void _openNewReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Report an issue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to capture it.',
                  style: TextStyle(fontSize: 14, color: _muted),
                ),
                const SizedBox(height: 18),
                _ReportSheetOption(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Voice report',
                  subtitle: 'Describe the issue hands-free',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoiceReportScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ReportSheetOption(
                  icon: Icons.photo_camera_outlined,
                  title: 'Photo report',
                  subtitle: 'Snap a picture and add details',
                  onTap: () {
                    Navigator.pop(ctx);
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBody: true,
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
              const UpdatesScreen(),
              const Profile(),
            ],
          ),
          floatingActionButton: _showTour
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: FloatingActionButton.small(
                    onPressed: _startTour,
                    tooltip: 'Start AI tour',
                    backgroundColor: const Color(0xFF152033),
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.auto_awesome),
                  ),
                ),
          bottomNavigationBar: _FloatingNavDock(
            currentIndex: _index,
            onSelect: _onNavTap,
            onAdd: _openNewReportSheet,
            homeKey: _homeNavTourKey,
            reportsKey: _mapNavTourKey,
            addKey: _addNavTourKey,
            updatesKey: _updatesNavTourKey,
            profileKey: _profileNavTourKey,
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

class _ReportSheetOption extends StatelessWidget {
  const _ReportSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _MainShellState._ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _MainShellState._ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _MainShellState._muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _MainShellState._muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingNavDock extends StatelessWidget {
  const _FloatingNavDock({
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    required this.homeKey,
    required this.reportsKey,
    required this.addKey,
    required this.updatesKey,
    required this.profileKey,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final GlobalKey homeKey;
  final GlobalKey reportsKey;
  final GlobalKey addKey;
  final GlobalKey updatesKey;
  final GlobalKey profileKey;

  @override
  Widget build(BuildContext context) {
    // Sit low — only a tiny inset above the home indicator, not full SafeArea.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset > 0 ? 16 : 18),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: DecoratedBox(
            decoration: BoxDecoration(
              color: _MainShellState._dockBg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _DockItem(
                        key: homeKey,
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Home',
                        selected: currentIndex == 0,
                        onTap: () => onSelect(0),
                      ),
                    ),
                    Expanded(
                      child: _DockItem(
                        key: reportsKey,
                        icon: Icons.location_on_outlined,
                        selectedIcon: Icons.location_on_rounded,
                        label: 'Reports',
                        selected: currentIndex == 1,
                        onTap: () => onSelect(1),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: KeyedSubtree(
                          key: addKey,
                          child: Material(
                            color: _MainShellState._cta,
                            shape: const CircleBorder(),
                            elevation: 0,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onAdd,
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DockItem(
                        key: updatesKey,
                        icon: Icons.notifications_none_rounded,
                        selectedIcon: Icons.notifications_rounded,
                        label: 'Updates',
                        selected: currentIndex == 2,
                        onTap: () => onSelect(2),
                      ),
                    ),
                    Expanded(
                      child: _DockItem(
                        key: profileKey,
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        selected: currentIndex == 3,
                        onTap: () => onSelect(3),
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
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _MainShellState._ink : _MainShellState._muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? _MainShellState._selectedPill
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
