import 'package:flutter/material.dart';
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
  int _index = 0;
  int? _focusReportId;

  /// Switch to Map. Pass [reportId] only when opening from a home report.
  void openMap({int? reportId}) {
    setState(() {
      _focusReportId = reportId;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenOnMap: openMap),
          MapScreen(
            isActive: _index == 1,
            initialReportId: _focusReportId,
          ),
          const Leaderboard(),
          const Profile(),
        ],
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
