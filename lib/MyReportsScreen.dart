import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/ReportDetails.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_list_card.dart';

class MyReportsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  const MyReportsScreen({super.key, required this.reports});

  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
        title: Text(
          'My reports',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
      ),
      body: reports.isEmpty
          ? Center(
              child: Text(
                'No reports yet',
                style: GoogleFonts.inter(color: _muted, fontSize: 15),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return ReportListCard(
                  icon: report['icon'] as IconData? ??
                      ReportCategories.icon(report['category'] as String?),
                  title: ReportListCard.displayTitle(report),
                  location: report['location'] as String? ?? '',
                  time: ReportListCard.formatTime(report['time']),
                  pill: ReportListCard.displayPill(report),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailsScreen(report: report),
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: const NewReportBlackCta(),
      ),
    );
  }
}
