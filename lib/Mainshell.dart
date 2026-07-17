import 'package:flutter/material.dart';
import 'package:street_sync/Leaderboard.dart';
import 'package:street_sync/Profile.dart';

import 'HomeScreen.dart';
import 'Map.dart';

class MainShell extends StatefulWidget{
      const MainShell({super.key});

    @override
    State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
       int _index = 0;
        final _screens = [
            const HomeScreen(),
            const MapScreen(),
            const Profile(),
            const Leaderboard(),
        ];
    @override
    Widget build(BuildContext context) {
     
        return Scaffold(
            body: _screens[_index],
            bottomNavigationBar: BottomNavigationBar(
                selectedItemColor: const Color(0xFF2196F3),
                unselectedItemColor: const Color(0xFF5B677A),
                backgroundColor: Colors.white,
                type: BottomNavigationBarType.fixed,
                elevation: 8,
                currentIndex: _index,
                onTap: (index) => setState(() => _index = index),
                items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                    BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
                    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                    BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
                ],
            ),
        );
    }
}
