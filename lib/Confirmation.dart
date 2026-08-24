import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_severity.dart';

class Confirmation extends StatefulWidget {
  const Confirmation({
    super.key,
    required this.category,
    required this.location,
    required this.title,
    required this.description,
    required this.severity,
    this.image,
    this.existingImageUrl,
    this.draftId,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.othercat = "",
  });

  final String category;
  final String location;
  final String title;
  final String description;
  final String severity;
  final XFile? image;

  /// Server photo URL when continuing a draft without a new local file.
  final String? existingImageUrl;

  /// When set, submit updates this draft in place instead of creating a new row.
  final int? draftId;
  final double latitude;
  final double longitude;
  final String othercat;

  @override
  State<Confirmation> createState() => _ConfirmationState();
}

class _ConfirmationState extends State<Confirmation> {
  static const _cta = Color(0xFF111827);
  bool _submitting = false;
  bool _savingDraft = false;
  late String _title;
  late String _description;
  late String _category;
  bool _severityDetailsEdited = false;

  bool get _busy => _submitting || _savingDraft;

  @override
  void initState() {
    super.initState();
    _title = widget.title.trim();
    _description = widget.description.trim();
    _category = widget.category.trim().isEmpty
        ? ReportCategories.other
        : widget.category.trim();
  }

  Color get _severityColor {
    switch (_currentSeverity.toLowerCase()) {
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

  String get _currentSeverity {
    if (!_severityDetailsEdited) return widget.severity;
    return autoSeverity(category: _category, description: _description);
  }

  Future<void> _saveAsDraft() async {
    if (_busy) return;
    if (!_validateEditableFields()) return;
    setState(() => _savingDraft = true);

    final success = await ApiService.submitReport(
      title: _title,
      description: _description,
      category: _category,
      location: widget.location,
      severity: _currentSeverity,
      isDraft: true,
      latitude: widget.latitude,
      longitude: widget.longitude,
      imagePath: widget.image?.path,
      draftId: widget.draftId,
      existingImageUrl: widget.existingImageUrl,
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

  Future<void> _confirmAndSubmit() async {
    if (_busy) return;
    if (!_validateEditableFields()) return;
    setState(() => _submitting = true);

    final success = await ApiService.submitReport(
      title: _title,
      description: _description,
      category: _category,
      location: widget.location,
      severity: _currentSeverity,
      isDraft: false,
      latitude: widget.latitude,
      longitude: widget.longitude,
      imagePath: widget.image?.path,
      draftId: widget.draftId,
      existingImageUrl: widget.existingImageUrl,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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

  bool _validateEditableFields() {
    final missing = <String>[];
    if (_title.trim().isEmpty) missing.add('title');
    if (_category.trim().isEmpty) missing.add('category');
    if (_description.trim().isEmpty) missing.add('description');

    if (missing.isEmpty) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please enter a ${missing.first}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  Future<void> _editTextField({
    required String label,
    required String initialValue,
    required int maxLines,
    required ValueChanged<String> onSaved,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || !mounted) return;
    if (result.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label cannot be empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => onSaved(result.trim()));
  }

  Future<void> _editCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...ReportCategories.all.map(
                (category) => ListTile(
                  title: Text(ReportCategories.label(category)),
                  subtitle: Text(ReportCategories.subtitle(category)),
                  leading: Icon(ReportCategories.icon(category)),
                  trailing: _category == category
                      ? const Icon(Icons.check_rounded, color: _cta)
                      : null,
                  onTap: () => Navigator.pop(context, category),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _category = result;
      _severityDetailsEdited = true;
    });
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
          onPressed: () => Navigator.pop(context, true),
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
                  _buildPicture(),
                  const SizedBox(height: 12),
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

  Widget _buildPicture() {
    final local = widget.image;
    final url = widget.existingImageUrl?.trim();

    Widget image;
    if (local != null) {
      image = Image.file(
        File(local.path),
        height: 280,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 900,
      );
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        height: 280,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoFallback(),
      );
    } else {
      image = _photoFallback();
    }

    return ClipRRect(borderRadius: BorderRadius.circular(22), child: image);
  }

  Widget _photoFallback() {
    return Container(
      height: 280,
      width: double.infinity,
      color: Colors.grey[300],
      child: Icon(Icons.image_outlined, size: 56, color: Colors.grey[600]),
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
            backgroundColor: Colors.white.withValues(alpha: 0.2),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              icon: Icons.title_outlined,
              iconColor: Colors.indigo,
              label: 'Title',
              value: _title,
              onEdit: () => _editTextField(
                label: 'Title',
                initialValue: _title,
                maxLines: 1,
                onSaved: (value) => _title = value,
              ),
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.category_outlined,
              iconColor: _cta,
              label: 'Category',
              value: _category,
              onEdit: _editCategory,
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
              value: _description,
              onEdit: () => _editTextField(
                label: 'Description',
                initialValue: _description,
                maxLines: 5,
                onSaved: (value) {
                  _description = value;
                  _severityDetailsEdited = true;
                },
              ),
            ),
            _summaryDivider(),
            _buildSummaryRow(
              icon: Icons.warning_amber_rounded,
              iconColor: _severityColor,
              label: 'Severity',
              value: _currentSeverity,
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
    VoidCallback? onEdit,
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
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
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Edit $label',
              onPressed: _busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
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
          _buildStep(stepNumber: 2, text: 'Field team is dispatched to assess'),
          const SizedBox(height: 14),
          _buildStep(stepNumber: 3, text: 'Issue is scheduled for repair'),
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
              onPressed: _busy ? null : _confirmAndSubmit,
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
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => Navigator.pop(context, true),
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.grey[800],
              ),
              label: Text(
                'Go Back To Edit',
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
