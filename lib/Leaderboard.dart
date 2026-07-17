import 'package:flutter/material.dart';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  _LeaderboardState createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          header(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: playerList(),
            ),
          ),
        ],
      ),
    );
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
          topThreeSection(),
        ],
      ),
    );
  }

  Widget topThreeSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _topThreePodium(
          name: 'Sarah J.',
          score: '1120',
          rank: 2,
          height: 140,
          color: const Color(0xFFC0C0C0),
        ),
        _topThreePodium(
          name: 'Alex Rivera',
          score: '1450',
          rank: 1,
          height: 170,
          color: const Color(0xFFFFD700),
          isFirst: true,
        ),
        _topThreePodium(
          name: 'Marcus K.',
          score: '980',
          rank: 3,
          height: 130,
          color: const Color(0xFFCD7F32),
        ),
      ],
    );
  }

  Widget _topThreePodium({
    required String name,
    required String score,
    required int rank,
    required double height,
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

  Widget playerList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 15),
      physics: const BouncingScrollPhysics(),
      children: [
        _playerRow(rank: '4', name: 'James Wilson', score: '850'),
        _playerRow(rank: '5', name: 'Elena Gomez', score: '720'),
        _playerRow(rank: '6', name: 'Kevin Hart', score: '690'),
        _playerRow(rank: '7', name: 'Aarav Sharma', score: '640', isYou: true),
        _playerRow(rank: '8', name: 'Linda Chen', score: '580'),
        _playerRow(rank: '9', name: 'Robert Fox', score: '510'),
        _playerRow(rank: '10', name: 'Emily Blunt', score: '490'),
        _playerRow(rank: '11', name: 'Chris Pratt', score: '450'),
      ],
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
