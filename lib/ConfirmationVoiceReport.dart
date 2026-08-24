import 'package:flutter/material.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/report_severity.dart';
import 'package:street_sync/api_service.dart';

class ConfirmationVoiceReport extends StatefulWidget {
  const ConfirmationVoiceReport({
    super.key,
    required this.location,
    required this.title,
    required this.description,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.othercat = '',
    this.category,
    this.severity,
    this.aiRationale,
    this.rawTranscript,
  });

  final String location;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String othercat;
  /// AI-provided category (preferred). Falls back to keyword inference if null.
  final String? category;
  /// AI-provided severity (preferred). Falls back to keyword inference if null.
  final String? severity;
  final String? aiRationale;
  /// Original speech transcript when description was AI-polished.
  final String? rawTranscript;

  @override
  State<ConfirmationVoiceReport> createState() =>
      _ConfirmationVoiceReportState();
}

class _ConfirmationVoiceReportState extends State<ConfirmationVoiceReport> {
  static const _cta = Color(0xFF111827);
  bool _submitting = false;
  bool _savingDraft = false;

  bool get _busy => _submitting || _savingDraft;

  bool get _fromAi =>
      widget.category != null ||
      widget.severity != null ||
      widget.aiRationale != null;

  String get _inferredCategory =>
      widget.category?.trim().isNotEmpty == true
          ? widget.category!.trim()
          : inferCategory(widget.description);

  String get _autoSeverity {
    final ai = widget.severity?.trim().toLowerCase();
    if (ai == 'low' || ai == 'medium' || ai == 'high') return ai!;
    return autoSeverity(
      category: _inferredCategory,
      description: widget.rawTranscript ?? widget.description,
    );
  }

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



  Future<void> _showSubmittedThenGoHome() async {
    if (_busy) return;
    setState(() => _submitting = true);

    final success = await ApiService.submitReport(
      title: widget.title,
      description: widget.description,
      category: _inferredCategory,
      location: widget.location,
      severity: _autoSeverity,
      isDraft: false,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );

    if (!mounted) return;

    if (success) {
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
                    color: _cta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: _cta,
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
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach the server. Please try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAsDraft() async {
    if (_busy) return;
    setState(() => _savingDraft = true);

    final success = await ApiService.submitReport(
      title: widget.title,
      description: widget.description,
      category: _inferredCategory,
      location: widget.location,
      severity: _autoSeverity,
      isDraft: true,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _savingDraft = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save draft. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        backgroundColor: _cta,
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
      color: _cta,
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
    final rationale = widget.aiRationale?.trim();
    final raw = widget.rawTranscript?.trim();
    final showRaw = raw != null &&
        raw.isNotEmpty &&
        raw != widget.description.trim();

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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Report Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  if (_fromAi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _cta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _cta.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: _cta,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI analyzed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _cta,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _buildSummaryRow(
              icon: Icons.title_outlined,
              iconColor: Colors.indigo,
              label: 'Title',
              value: widget.title,
              isSuggested: _fromAi,
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.category_outlined,
              iconColor: _cta,
              label: 'Category',
              value: _inferredCategory,
              isSuggested: _fromAi,
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
              label: _fromAi ? 'AI description' : 'Description',
              value: widget.description,
              isSuggested: _fromAi,
            ),
            if (showRaw) ...[
              _summaryDivider(),
              _buildSummaryRow(
                icon: Icons.mic_none_rounded,
                iconColor: Colors.teal,
                label: 'What you said',
                value: raw!,
              ),
            ],
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.warning_amber_rounded,
              iconColor: _severityColor,
              label: _fromAi ? 'Severity' : 'Severity (Auto-detected)',
              value: _autoSeverity,
              isSuggested: true,
            ),
            if (rationale != null && rationale.isNotEmpty) ...[
              _summaryDivider(),
              _buildSummaryRow(
                icon: Icons.lightbulb_outline_rounded,
                iconColor: Colors.amber.shade800,
                label: 'AI rationale',
                value: rationale,
                isSuggested: true,
              ),
            ],
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
                          _fromAi ? 'AI' : 'SUGGESTED',
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
        color: _cta.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cta.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT HAPPENS NEXT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _cta,
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
          backgroundColor: isActive ? _cta : Colors.grey[300],
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
            child: ElevatedButton(
              onPressed: _busy ? null : _showSubmittedThenGoHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cta,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _cta.withValues(alpha: 0.5),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Confirm and Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _saveAsDraft,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _savingDraft
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.grey[800],
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_add_outlined,
                          size: 20,
                          color: Colors.grey[800],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save as draft',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
