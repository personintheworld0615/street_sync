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
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            height: 100,
            color: Colors.blue,
            child: Column(
              children: [
                //row for profile
                //row for picture and  column for the 3 things in same row
                //row the three cards 
              ],
            ),
          ),
          SingleChildScrollView(
            child: Column(
              //my reports section with a blank create report button if there is no reports 
              //u can use my card from homepage for it
              //Card(

                //prefrences secotin
             // )
            ),
          ),
        ],
      ),
    );
  }
}
