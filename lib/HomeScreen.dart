import 'package:flutter/material.dart';
import 'package:street_sync/VoiceReportScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],//lighter
      body: Column(
        children: [
          header(),
          threecard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActionCard(
                  color: Colors.blue,
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
                  title: 'Community Report',
                  subtitle: 'Take a picture',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoiceReportScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
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
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 160,
          child: Card(
            margin: EdgeInsets.zero,
            color: color,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
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

  Container threecard() {
    return Container(
          padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Padding(padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.directions_bike, size: 30, color: Colors.blue),
                        Text('6', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('Nearby issues', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                      ],
                    )),
                ),
              ),
               Expanded(

                 child: Card(
                   margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                   color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Padding(padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.directions_bike, size: 30, color: Colors.blue),
                        Text('6', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('In Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                      ],
                    )),
                               ),
               ),
               Expanded(
                 child: Card(
                   margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Padding(padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.directions_bike, size: 30, color: Colors.blue),
                        Text('6', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                      ],
                    )),
                               ),
               ),

            ],
          ),
        );
  }

  Container header() {
    return Container(
          width: double.infinity,
          color: Colors.blue,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'StreetSync',
                style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Good morning Aarav',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'West Windsor, NJ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
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
