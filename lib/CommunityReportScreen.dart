import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'Confirmation.dart';
import 'Mainshell.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_severity.dart';
class CommunityReportScreen extends StatefulWidget {
  
  CommunityReportScreen({super.key});

  @override
  State<CommunityReportScreen> createState() => _CommunityReportScreenState();
}

class _CommunityReportScreenState extends State<CommunityReportScreen> {
  LatLng position = const LatLng(40.3573, -74.6672); // same default as Map.dart
  Set<Marker> _markers = {};
  static const _blue = Color(0xFF2196F3);
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String? _selectedCategory;
  final _otherCategoryController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _descirption;
  String? _selectedSeverity;

  bool _showSeverity = false;
   GoogleMapController? _controller;
   bool _ready =false;
  bool _submitting = false;
  bool _savingDraft = false;

  bool get _busy => _submitting || _savingDraft;

  @override
  void dispose() {
    _otherCategoryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _pageBg,
        foregroundColor: _ink,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text(
          'Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera report',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Capture and report issues as you walk',
                      style: TextStyle(
                        fontSize: 15,
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPhotoCard(),
                    const SizedBox(height: 16),
                    _buildTitleCard(),
                    const SizedBox(height: 14),
                    _buildCategoryCard(),
                    const SizedBox(height: 14),
                    _buildDescriptionCard(),
                    const SizedBox(height: 14),
                    _buildLocationCard(),
                    const SizedBox(height: 14),
                    if (_selectedSeverity != null) _buildSeverityCard(),
                    if (_selectedSeverity == null) _buildSeverityCardNew(),
                  ],
                ),
              ),
            ),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }
  @override
  void initState(){
    super.initState();
    _gotouser();
  }

  Widget _buildPhotoCard() {
    if (_image == null) {
      return Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              _Pressable(
                onTap: _captureImage,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Take a photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to capture or upload',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey[300], thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey[300], thickness: 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Pressable(
                onTap: _selectImageFromGalary,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 22, color: _blue),
                      SizedBox(width: 8),
                      Text(
                        'Upload from library',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Image.file(
            File(_image!.path),
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 900,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0F1724)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Pressable(
                      onTap: _captureImage,
                      child: _overlayBtn(Icons.camera_alt_outlined, 'Retake'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Pressable(
                      onTap: () => setState(() => _image = null),
                      child: _overlayBtn(
                        Icons.delete_outline_rounded,
                        'Remove',
                      ),
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
  Future<void> _gotouser() async{
    final userLocation = await Geolocator.getCurrentPosition();
    final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);
    setState(() {
       position = userLatLng;
       _markers = {
         Marker(
           markerId: const MarkerId('report'),
           position: userLatLng,
         ),
       };
       _ready = true;
    });
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(position,15));
  }

  Widget _buildLocationCard(){
    return  Card(
     color: Colors.white,
     elevation: 2,
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
     child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[800])),
          SizedBox(height: 10,),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                initialCameraPosition:
                    CameraPosition(target: position, zoom: 15),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                markers: _markers,
                onMapCreated: (c) async {
                  _controller = c;
                  if (_ready) {
                    await c.animateCamera(
                      CameraUpdate.newLatLngZoom(position, 15),
                    );
                  }
                },
                onTap: (latLng) {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    position = latLng;
                    _markers = {
                      Marker(
                        markerId: const MarkerId('report'),
                        position: latLng,
                      ),
                    };
                  });
                },
              ),
            ),
          ),
        ],
      ),
    )
    );
  }

  Widget _overlayBtn(IconData icon, String label) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "What's wrong?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.roadDamage,
                    label: ReportCategories.label(ReportCategories.roadDamage),
                    subtitle: ReportCategories.subtitle(ReportCategories.roadDamage),
                    icon: ReportCategories.icon(ReportCategories.roadDamage),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.publicWorks,
                    label: ReportCategories.label(ReportCategories.publicWorks),
                    subtitle: ReportCategories.subtitle(ReportCategories.publicWorks),
                    icon: ReportCategories.icon(ReportCategories.publicWorks),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.environmental,
                    label: ReportCategories.label(ReportCategories.environmental),
                    subtitle: ReportCategories.subtitle(ReportCategories.environmental),
                    icon: ReportCategories.icon(ReportCategories.environmental),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.accessibility,
                    label: ReportCategories.label(ReportCategories.accessibility),
                    subtitle: ReportCategories.subtitle(ReportCategories.accessibility),
                    icon: ReportCategories.icon(ReportCategories.accessibility),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCategoryChip(
              value: ReportCategories.other,
              label: ReportCategories.label(ReportCategories.other),
              subtitle: ReportCategories.subtitle(ReportCategories.other),
              icon: ReportCategories.icon(ReportCategories.other),
            ),
            if (_selectedCategory == ReportCategories.other) ...[
              const SizedBox(height: 10),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _otherCategoryController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. noise, stray animal, abandoned car',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(18, 12, 16, 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedCategory == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 88,
      decoration: BoxDecoration(
        color: selected ? _blue.withValues(alpha: 0.1) : Colors.grey[50],
        border: Border.all(
          color: selected ? _blue : Colors.grey[300]!,
          width: selected ? 1.8 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedCategory = value),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected ? _blue : _muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? _blue : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Tooltip(
              message: subtitle,
              triggerMode: TooltipTriggerMode.tap,
              preferBelow: false,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: selected ? _blue : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => FocusScope.of(context).nextFocus(),
                decoration: const InputDecoration(
                  hintText: 'Give your report a short title...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(18, 14, 16, 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textInputAction: TextInputAction.done,
                controller: _descriptionController,
                onChanged: (value) {
                  _descirption = value;
                },
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                  hintText: 'What should the city worker know on arrival...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(18, 14, 16, 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  Future<void> _selectImageFromGalary() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }
    Widget _buildSeverityCard() {
      return Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Severity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSeverityChip(
                      label: 'Low',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSeverityChip(
                      label: 'Medium',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSeverityChip(
                      label: 'High',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  Widget _buildSeverityCardNew() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (_selectedCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a category'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final severity = autoSeverity(
                        category: _selectedCategory!,
                        description: _descriptionController.text,
                      );
                      setState(() => _selectedSeverity = severity);
                    },
                    child: Text('Calculate Severity',style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white),),
                  ),
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip({
    required String label,
    required Color color,
  }) {
    final selected = _selectedSeverity == label;

    return _Pressable(
      onTap: () {
        setState(() => _selectedSeverity = label);
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey[50],
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: selected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _saveAsDraft() async {
    if (_busy) return;
    setState(() => _savingDraft = true);

    String location = 'Location not set';
    try {
      location = await _addressFromLatLng(position);
    } catch (_) {}

    final category = _selectedCategory == 'Other'
        ? (_otherCategoryController.text.trim().isEmpty
            ? 'Other'
            : _otherCategoryController.text.trim())
        : (_selectedCategory ?? 'Other');
    final description = _descriptionController.text.trim();
    final title = _titleController.text.trim();
    final severity = _selectedSeverity ?? 'medium';

    final success = await ApiService.submitReport(
      title: title,
      description: description,
      category: category,
      location: location,
      severity: severity,
      isDraft: true,
      latitude: position.latitude,
      longitude: position.longitude,
      imagePath: _image?.path,
    );

    if (!mounted) return;
    setState(() => _savingDraft = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save draft. Is the API running?'),
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

  Widget _buildSubmitBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pressable(
            onTap: () async {
              if (_busy) return;
              final errors = <String>[];
              if (_titleController.text.trim().isEmpty) errors.add('title');
              if (_image == null) errors.add('photo');
              if (_selectedCategory == null) errors.add('category');
              if (_descriptionController.text.trim().isEmpty) {
                errors.add('description');
              }
              if (_selectedSeverity == null) {
                errors.add('severity');
              }
              if (_markers.isEmpty) errors.add('location');

              if (errors.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please add: ${errors.join(', ')}'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              setState(() => _submitting = true);
              try {
                final address = await _addressFromLatLng(position);
                if (!mounted) return;
                setState(() => _submitting = false);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Confirmation(
                      category: _selectedCategory!,
                      title: _titleController.text.trim(),
                      description: _descriptionController.text.trim(),
                      image: _image!,
                      severity: _selectedSeverity!,
                      location: address,
                      latitude: position.latitude,
                      longitude: position.longitude,
                    ),
                  ),
                );
              } catch (_) {
                if (mounted) setState(() => _submitting = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not get address. Try again.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _busy ? _blue.withValues(alpha: 0.5) : _blue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                  : const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

Future<String> _addressFromLatLng(LatLng pos) async {
  try {
    final places = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    if (places.isEmpty) {
      return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    }
    final p = places.first;
    final parts = [
      if (p.street?.isNotEmpty == true) p.street!,
      if (p.locality?.isNotEmpty == true) p.locality!,
      if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
    ];
    return parts.isEmpty
        ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
        : parts.join(', ');
  } catch (_) {
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
