import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:street_sync/ReportDetails.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_list_card.dart';
import 'package:street_sync/skeleton.dart';

/// Home stat-card destination: nearby / in progress / resolved reports.
class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({
    super.key,
    required this.filter,
    required this.title,
  });

  /// One of: `nearby`, `in_progress`, `resolved`.
  final String filter;
  final String title;

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await ApiService.getReportsByFilter(widget.filter);
    if (!mounted) return;
    setState(() {
      _reports = (raw ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
  }

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
          widget.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _ink,
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: const [ReportListSkeleton(count: 5)],
              )
            : _reports.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: Center(
                          child: Text(
                            'No ${widget.title.toLowerCase()} reports',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return ReportListCard(
                        icon: ReportCategories.icon(
                          report['category'] as String?,
                        ),
                        title: ReportListCard.displayTitle(report),
                        location: report['location'] as String? ?? '',
                        time: ReportListCard.formatTime(report['time']),
                        pill: ReportListCard.displayPill(report),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReportDetailsScreen(report: report),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: const NewReportBlackCta(),
      ),
    );
  }
}
