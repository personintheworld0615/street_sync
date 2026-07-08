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
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
            child: Column(
              children: [
                threecard(),
                const SizedBox(height: 20),
                twocardsection(context),
                //insert map here,
                SizedBox(height: 30,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent reports ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                    Text('Near you ', style: TextStyle(fontSize: 15,fontStyle: FontStyle.italic),)
                  ],
                ),
                const SizedBox(height: 12),
                _buildReportCard(
                  icon: Icons.construction,
                  severityColor: Colors.red,
                  name: 'Large pothole',
                  location: 'Nassau St & Mercer St',
                  time: '12 min ago',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildReportCard({
    required IconData icon,
    required Color severityColor,
    required String location,
    required String name,
    required String time,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.pink[100],
              child: Icon(icon, size: 28, color: Colors.grey[700]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: severityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Row twocardsection(BuildContext context) {
    return Row(
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
                subtitle: 'Take a picture',//hi
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

  Row threecard() {
    return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                  color: Colors.white,
                  elevation: 3,
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
                  elevation: 3,
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
                  elevation: 3,
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
