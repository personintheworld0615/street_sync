import 'package:flutter/material.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/draft_reports.dart';
import 'package:street_sync/report_severity.dart';

class ConfirmationVoiceReport extends StatefulWidget {
  const ConfirmationVoiceReport({
    super.key,
    required this.location,
    required this.description,
    this.othercat = '',
  });

  final String location;
  final String description;
  final String othercat;

  @override
  State<ConfirmationVoiceReport> createState() =>
      _ConfirmationVoiceReportState();
}

class _ConfirmationVoiceReportState extends State<ConfirmationVoiceReport> {
  static const _primaryBlue = Color(0xFF2196F3);

  String get _inferredCategory => inferCategory(widget.description);

  String get _autoSeverity => autoSeverity(
        category: _inferredCategory,
        description: widget.description,
      );

  Color _getColorForSeverity(String sev) {
    switch (sev.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color get _severityColor => _getColorForSeverity(_autoSeverity);

  Map<String, dynamic> _reportMap({required String status}) {
    final category = _inferredCategory;
    return {
      'category': category,
      'location': widget.location,
      'description': widget.description,
      'severity': _autoSeverity,
      'othercat': widget.othercat,
      'status': status,
      'time': DateTime.now().toIso8601String(),
      'source': 'voice',
      'icon': Icons.mic_outlined,
      'name': category,
      'bgColor': Colors.orange[100]!,
    };
  }

  Future<void> _showSubmittedThenGoHome() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _primaryBlue,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Report submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thanks your report is on its way.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _saveAsDraft() {
    draftReports.add(_reportMap(status: 'Draft'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved as draft'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Confirm Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 12),
                  _buildWhatHappensNext(),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _primaryBlue,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 26,
            child: const Icon(
              Icons.check_circle_outline,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review your report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Make sure everything looks right before submitting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Report Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            _buildSummaryRow(
              icon: Icons.category_outlined,
              iconColor: Colors.blue,
              label: 'Category',
              value: _inferredCategory,
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.location_on_outlined,
              iconColor: Colors.red,
              label: 'Location',
              value: widget.location,
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.description_outlined,
              iconColor: Colors.purple,
              label: 'Description',
              value: widget.description,
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.warning_amber_rounded,
              iconColor: _severityColor,
              label: 'Severity (Auto-detected)',
              value: _autoSeverity,
              isSuggested: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 16,
      color: Colors.grey[300],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isSuggested = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isSuggested) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: iconColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          'SUGGESTED',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatHappensNext() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT HAPPENS NEXT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            isActive: true,
            stepNumber: 1,
            text: 'Your report is reviewed by city staff',
          ),
          const SizedBox(height: 14),
          _buildStep(
            stepNumber: 2,
            text: 'Field team is dispatched to assess',
          ),
          const SizedBox(height: 14),
          _buildStep(
            stepNumber: 3,
            text: 'Issue is scheduled for repair',
          ),
          const SizedBox(height: 14),
          _buildStep(
            stepNumber: 4,
            text: 'You receive a resolution notification',
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String text,
    bool isActive = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? _primaryBlue : Colors.grey[300],
          child: isActive
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.grey[900] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showSubmittedThenGoHome,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                'Confirm and Submit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveAsDraft,
              icon: Icon(
                Icons.bookmark_add_outlined,
                size: 20,
                color: Colors.grey[800],
              ),
              label: Text(
                'Save as draft',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
