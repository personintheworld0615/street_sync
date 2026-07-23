import 'package:flutter/material.dart';
import 'package:street_sync/api_service.dart';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  _LeaderboardState createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  List<dynamic> _topUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    final users = await ApiService.getTopUsers(1); // Default user ID 1
    if (mounted) {
      setState(() {
        _topUsers = users;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Sort to ensure rank 1 is first
    _topUsers.sort((a, b) => b['total_reports'].compareTo(a['total_reports']));
    
    // Safety check for empty list
    if (_topUsers.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          children: [
            header([]),
            const Expanded(child: Center(child: Text('No leaderboard data available.'))),
          ],
        ),
      );
    }

    final topThree = _topUsers.take(3).toList();
    final remaining = _topUsers.skip(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: _fetchLeaderboard,
        child: Column(
          children: [
            header(topThree),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: playerList(remaining),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget header(List<dynamic> topThree) {
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
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 5),
          const Text(
            'Top contributors this week',
            style: TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 30),
          if (topThree.isNotEmpty) topThreeSection(topThree),
        ],
      ),
    );
  }

  Widget topThreeSection(List<dynamic> topThree) {
    // Reorder for visual podium: 2, 1, 3
    List<dynamic> podium = [];
    if (topThree.length >= 2) podium.add(topThree[1]);
    podium.add(topThree[0]);
    if (topThree.length >= 3) podium.add(topThree[2]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: podium.map((user) {
        int originalIndex = topThree.indexOf(user);
        return _topThreePodium(
          name: user['name'],
          score: user['total_reports'].toString(),
          rank: originalIndex + 1,
          color: originalIndex == 0 ? const Color(0xFFFFD700) : (originalIndex == 1 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
          isFirst: originalIndex == 0,
        );
      }).toList(),
    );
  }

  Widget _topThreePodium({
    required String name,
    required String score,
    required int rank,
    required Color color,
    bool isFirst = false,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: CircleAvatar(
                radius: isFirst ? 45 : 35,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: isFirst ? 50 : 40, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            if (isFirst)
              const Positioned(
                top: -25,
                child: Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 30),
              ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          score,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget playerList(List<dynamic> remaining) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 15),
      physics: const BouncingScrollPhysics(),
      itemCount: remaining.length,
      itemBuilder: (context, index) {
        final user = remaining[index];
        return _playerRow(
          rank: (index + 4).toString(),
          name: user['name'],
          score: user['total_reports'].toString(),
          isYou: user['id'] == 1, // Assume current user is 1
        );
      },
    );
  }

  Widget _playerRow({
    required String rank,
    required String name,
    required String score,
    bool isYou = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isYou ? Colors.blue.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isYou ? Colors.blue.withOpacity(0.2) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rank,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[400]),
            ),
          ),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFF1F2F6),
            child: Icon(Icons.person, size: 25, color: Colors.grey),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              isYou ? '$name (You)' : name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isYou ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF2D3436),
              ),
            ),
          ),
          Text(
            score,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E88E5)),
          ),
        ],
      ),
    );
  }
}
