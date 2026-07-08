import 'package:flutter/material.dart';

class VoiceReportScreen extends StatelessWidget {
  const VoiceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Report'),
      ),
      body: const Center(
        child: Text('Voice report screen'),
      ),
    );
  }
}
