import 'package:flutter/material.dart';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  _LeaderboardState createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  static const _primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Column(

          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Top reporters this week',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
              ),
            ),
            SizedBox(height: 12),

          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildLeadershipCard(
                    username: 'Username',
                    score: 'Score',
                    image: 'assets/images/profile.jpg',
                    rank: 3,
                  ),
                  _buildLeadershipCard(
                    username: 'Imsosadandnfadifap',
                    score: '130',
                    image: 'assets/images/profile.jpg',
                    rank: 1,
                    isFirst: true,
                  ),
                  _buildLeadershipCard(
                    username: 'Username',
                    score: 'Score',
                    image: 'assets/images/profile.jpg',
                    rank: 2,
                    isSecond: true,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildPlayerCard(
                      username: "hi",
                      score: "320",
                      image: 'assets/images/profile.jpg',
                      place: '4'
                    ),
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4'
                    ),
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4'
                    ),
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4'
                    ),
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4'
                    ),
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4'
                    ),
                    //this one is for you if ur not up there
                    
                    _buildPlayerCard(
                        username: "hi",
                        score: "320",
                        image: 'assets/images/profile.jpg',
                        place: '4',
                        you: true,
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildPlayerCard({
    required String username,
    required String score,
    required String image,
    required String place,
    bool you = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20)
      ),
      color: you ? _primaryBlue.withValues(alpha: 0.12) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20,12,25,12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              place,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundImage: AssetImage(image),
              radius: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                you ? 'You' : username,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              score,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _rankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); 
      case 2:
        return const Color(0xFFC0C0C0); 
      default:
        return const Color(0xFFCD7F32); 
    }
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _rankBadgeColor(rank),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadershipCard({
    required String username,
    required String score,
    required String image,
    required int rank,
    bool isFirst = false,
    bool isSecond = false,
  }) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            isFirst ? 40 : isSecond ? 30 : 20,
            10,
            isFirst ? 28 : isSecond ? 24 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage(image),
                    radius: isFirst ? 50 : isSecond ? 45 : 40,
                  ),
                  Positioned(
                    top: -6,
                    right: isFirst ? 4 : 0,
                    child: _buildRankBadge(rank),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                username,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                score,
                style: TextStyle(
                  fontSize: isFirst ? 18 : isSecond ? 17 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}