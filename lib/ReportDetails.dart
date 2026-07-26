import 'dart:convert';

import 'package:flutter/material.dart';

class ReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

String _formatTime(String timeStr) {
  try {
    final dt = DateTime.parse(timeStr);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return 'Recently';
  }
}

Widget? _buildReportImage(dynamic raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;

  Widget image;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    // Supabase Storage public URL
    image = Image.network(
      value,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox(
        height: 220,
        child: Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
        ),
      ),
    );
  } else if (value.startsWith('data:image') && value.contains(',')) {
    // Legacy base64 rows still in the DB
    try {
      final b64 = value.split(',').last;
      image = Image.memory(
        base64Decode(b64),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } catch (_) {
      return null;
    }
  } else {
    return null;
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: image,
  );
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final reportImage = _buildReportImage(widget.report['image']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.report['title']?.toString() ?? 'Untitled',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Category: ${widget.report['category'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            if (reportImage != null) ...[
              const SizedBox(height: 10),
              reportImage,
            ],
            const SizedBox(height: 10),
            Text(
              'Location: ${widget.report['location'] ?? 'Unknown location'}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Time: ${_formatTime(widget.report['time']?.toString() ?? '')}',
            ),
          ],
        ),
      ),
    );
  }
}
