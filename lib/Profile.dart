import 'package:flutter/material.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        child: Column(
          children: [
            header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
              child: Column(
                children: [
                  impactScoreCard(),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('3 of 6 earned', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  badgesGrid(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: IconButton(onPressed: () {}, icon: const Icon(Icons.settings, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://i.pravatar.cc/150?u=alex'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: CircleAvatar(radius: 9, backgroundColor: Colors.green)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Krish Sinha', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('krishworld432@gmail.com', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _infoChip(Icons.location_on, 'West Windsor, NJ'),
                        const SizedBox(width: 8),
                        _infoChip(null, 'Aura King', color: const Color(0xFF26C6DA)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _statBox('23', 'Reports'),
              const SizedBox(width: 12),
              _statBox('141', 'Upvotes'),
              const SizedBox(width: 12),
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
      decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.white),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget impactScoreCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Civic Impact Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Top 12% in district', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progress to City Champion', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('740 / 1000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(value: 0.74, minHeight: 10, backgroundColor: Color(0xFFEEEEEE), valueColor: AlwaysStoppedAnimation(Colors.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 65, height: 65,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blue, Color(0xFF1565C0)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: const Text('740', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget badgesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: [
        _badgeCard('Top Reporter', Icons.emoji_events, Colors.orange, true),
        _badgeCard('Community Walker', Icons.directions_walk, Colors.orangeAccent, true),
        _badgeCard('Fast Responder', Icons.bolt, Colors.redAccent, true),
        _badgeCard('City Champion', Icons.stars, Colors.amber, false),
        _badgeCard('Voice Pioneer', Icons.mic, Colors.grey, false),
        _badgeCard('Collaborator', Icons.handshake, Colors.blue, false),
      ],
    );
  }

  Widget _badgeCard(String title, IconData icon, Color color, bool earned) {
    return Opacity(
      opacity: earned ? 1 : 0.5,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(earned ? Icons.check_circle : Icons.lock, size: 16, color: earned ? Colors.green : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}