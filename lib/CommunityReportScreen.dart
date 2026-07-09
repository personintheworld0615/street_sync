import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class CommunityReportScreen extends StatefulWidget {
  const CommunityReportScreen({super.key});

  @override
  State<CommunityReportScreen> createState() => _CommunityReportScreenState();
}

class _CommunityReportScreenState extends State<CommunityReportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Community Report', 
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                )
              ),
            SizedBox(height: 2),
            Text('Report issues in your community', style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DottedBorder(
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      )
    );
  }
}