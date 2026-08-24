import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'Confirmation.dart';
import 'ConfirmationVoiceReport.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:street_sync/geocoding_utils.dart';
import 'package:street_sync/report_categories.dart';
class Updatething extends StatefulWidget {
  Updatething({
    super.key,
    this.category,
    this.title,
    this.description,
    this.severity,
    this.otherCategory,
    this.imagePath,
    this.existingImageUrl,
    this.draftId,
    this.latitude,
    this.longitude,
  });

  final String? category;
  final String? title;
  final String? description;
  final String? severity;
  final String? otherCategory;
  final String? imagePath;
  final String? existingImageUrl;
  final int? draftId;
  final double? latitude;
  final double? longitude;

  factory Updatething.fromDraft(Map<String, dynamic> draft) {
    final image = draft['image'] as String?;
    final imagePath = draft['imagePath'] as String?;
    final serverUrl = (image != null &&
            (image.startsWith('http://') || image.startsWith('https://')))
        ? image
        : null;
    final id = draft['id'];
    return Updatething(
      category: draft['category'] as String?,
      title: draft['title'] as String?,
      description: draft['description'] as String?,
      severity: draft['severity'] as String?,
      otherCategory: draft['othercat'] as String?,
      imagePath: imagePath,
      existingImageUrl: serverUrl,
      draftId: id is int ? id : (id is num ? id.toInt() : null),
      latitude: (draft['latitude'] as num?)?.toDouble(),
      longitude: (draft['longitude'] as num?)?.toDouble(),
    );
  }

  bool get hasDraftData =>
      draftId != null ||
      category != null ||
      title != null ||
      description != null ||
      severity != null ||
      otherCategory != null ||
      imagePath != null ||
      existingImageUrl != null ||
      latitude != null ||
      longitude != null;

  @override
  State<Updatething> createState() => _UpdateThingState();
}

class _UpdateThingState extends State<Updatething> {
  LatLng position = const LatLng(40.3573, -74.6672);
  Set<Marker> _markers = {};
  static const _cta = Color(0xFF111827);
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String? _existingImageUrl;
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
        title: Text(
          widget.hasDraftData ? 'Continue draft' : 'Report',
          style: const TextStyle(
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
                      'Review and finish your report',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTitleCard(),
                    if (_imageWasProvided) ...[
                      const SizedBox(height: 14),
                      _buildPhotoCard(),
                    ],
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
  void initState() {
    super.initState();
    _applyDraftFields();
    _initLocation();
  }

  static const _knownCategories = {
    ...ReportCategories.all,
  };

  void _applyDraftFields() {
    final cat = widget.category;
    if (cat != null && _knownCategories.contains(cat)) {
      _selectedCategory = cat;
    } else if (cat != null && cat != 'Voice') {
      _selectedCategory = 'Other';
      _otherCategoryController.text = cat;
    }

    final other = widget.otherCategory;
    if (other != null && other.isNotEmpty) {
      _selectedCategory = 'Other';
      _otherCategoryController.text = other;
    }

    final description = widget.description;
    if (description != null && description.isNotEmpty) {
      _descriptionController.text = description;
      _descirption = description;
    }

    final title = widget.title;
    if (title != null && title.isNotEmpty) {
      _titleController.text = title;
    }

    final severity = widget.severity;
    if (severity != null && severity.isNotEmpty) {
      _selectedSeverity = _normalizeSeverity(severity);
    }

    final imagePath = widget.imagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      _image = XFile(imagePath);
    } else {
      final url = widget.existingImageUrl?.trim();
      if (url != null && url.isNotEmpty) {
        _existingImageUrl = url;
      }
    }
  }

  bool get _hasPhoto =>
      _image != null ||
      (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

  /// True when a local path or server image URL was passed into this screen.
  bool get _imageWasProvided {
    final path = widget.imagePath;
    if (path != null && path.isNotEmpty) return true;
    final url = widget.existingImageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  String _normalizeSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      default:
        return severity;
    }
  }

  Future<void> _initLocation() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      position = LatLng(lat, lng);
      _markers = {
        Marker(markerId: const MarkerId('report'), position: position),
      };
      setState(() => _ready = true);
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
      return;
    }
    await _gotouser();
  }

  Widget _buildPhotoCard() {
    if (!_hasPhoto) {
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
                        color: _cta.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: _cta,
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
                    color: _cta.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cta.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 22, color: _cta),
                      SizedBox(width: 8),
                      Text(
                        'Upload from library',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _cta,
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

    final Widget photo = _image != null
        ? Image.file(
            File(_image!.path),
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 900,
          )
        : Image.network(
            _existingImageUrl!,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 280,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          photo,
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
                      onTap: () => setState(() {
                        _image = null;
                        _existingImageUrl = null;
                      }),
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    icon: ReportCategories.icon(ReportCategories.roadDamage),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.publicWorks,
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
                    icon: ReportCategories.icon(ReportCategories.environmental),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryChip(
                    value: ReportCategories.accessibility,
                    icon: ReportCategories.icon(ReportCategories.accessibility),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCategoryChip(
              value: ReportCategories.other,
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
                    hintText: 'Enter other category',
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
    required IconData icon,
  }) {
    final selected = _selectedCategory == value;

    return _Pressable(
      onTap: () {
        setState(() => _selectedCategory = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _cta.withValues(alpha: 0.1) : Colors.grey[50],
          border: Border.all(
            color: selected ? _cta : Colors.grey[300]!,
            width: selected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? _cta : _muted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ReportCategories.label(value),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _cta : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
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
        _existingImageUrl = null;
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
        _existingImageUrl = null;
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
                      backgroundColor: _cta,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async{
                      String severity = await _autoSeverityCalc(_selectedCategory!);
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
      child: _Pressable(

        onTap: () async {
          if (_submitting) return;
          final errors = <String>[];
          if (_titleController.text.trim().isEmpty) errors.add('title');
          if (_imageWasProvided && !_hasPhoto) errors.add('photo');
          if (_selectedCategory == null) errors.add('category');
          if (_selectedSeverity == null) errors.add('severity');
          if (_descriptionController.text.trim().isEmpty) {
            errors.add('description');
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
            final address = await translateLocation(
              position.latitude,
              position.longitude,
              includeRegion: true,
              fallback:
                  '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
            );
            if (!mounted) return;
            setState(() => _submitting = false);

            final title = _titleController.text.trim();
            final description = _descriptionController.text.trim();
            final othercat = _selectedCategory == 'Other'
                ? _otherCategoryController.text.trim()
                : '';

            if (!_imageWasProvided) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfirmationVoiceReport(
                    title: title,
                    description: description,
                    location: address,
                    latitude: position.latitude,
                    longitude: position.longitude,
                    othercat: othercat,
                  ),
                ),
              );
              return;
            }

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Confirmation(
                  category: _selectedCategory!,
                  title: title,
                  description: description,
                  image: _image,
                  existingImageUrl: _existingImageUrl,
                  draftId: widget.draftId,
                  severity: _selectedSeverity!,
                  location: address,
                  latitude: position.latitude,
                  longitude: position.longitude,
                  othercat: othercat,
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
            color: _submitting ? _cta.withValues(alpha: 0.5) : _cta,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _cta.withValues(alpha: 0.35),
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
    );
  }
}
Future<String> _autoSeverityCalc(String category) async {
  switch (category) {
    case 'Accessibility':
      return 'high';
    case 'Road Damage':
    case 'Public Works':
      return 'Medium';
    case 'Environmental':
      return 'Low';
    case 'Other':
    default:
      return 'Medium';
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
