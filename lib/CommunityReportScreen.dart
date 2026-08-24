import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'Confirmation.dart';
import 'Mainshell.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/geocoding_utils.dart';
import 'package:street_sync/report_categories.dart';
import 'package:street_sync/report_severity.dart';
import 'package:street_sync/voice_mic_control.dart';
class CommunityReportScreen extends StatefulWidget {
  
  CommunityReportScreen({super.key});

  @override
  State<CommunityReportScreen> createState() => _CommunityReportScreenState();
}

class _CommunityReportScreenState extends State<CommunityReportScreen>
    with TickerProviderStateMixin {
  LatLng position = const LatLng(40.3573, -74.6672); // same default as Map.dart
  Set<Marker> _markers = {};
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _cta = Color(0xFF111827);
  static const _fieldBorder = Color(0xFFE5E7EB);
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
  bool _generatingTitle = false;
  String _reportMode = 'manual'; // 'manual', 'auto', 'voice'

  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _isRecording = false;
  bool _locationLoading = true;
  String _locationLabel = 'Finding location…';
  String _statusText = 'Tap the microphone to start recording';
  String _transcript = '';
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool get _busy => _submitting || _savingDraft;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _otherCategoryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    _speech.stop();
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
          'New report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoCard(),
                    const SizedBox(height: 18),
                    _buildModeSelector(),
                    const SizedBox(height: 18),
                    if (_reportMode == 'manual')
                      _buildManualCard()
                    else if (_reportMode == 'voice')
                      _buildVoiceCard()
                    else
                      _buildComingSoonforAI(),
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

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _fieldBorder),
      ),
      child: child,
    );
  }

  @override
  void initState(){
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initSpeech();
    _gotouser();
  }
  Widget _buildManualCard(){
    return Column(children: [
                    _buildDescriptionCard(),
                    const SizedBox(height: 14),
                    _buildCategoryCard(),
                    const SizedBox(height: 14),
                    _buildTitleCard(),
                    const SizedBox(height: 14),
                    _buildLocationCard(),
                    const SizedBox(height: 14),
                    if (_selectedSeverity != null) _buildSeverityCard(),
                    if (_selectedSeverity == null) _buildSeverityCardNew(),
    ],);
  }
  Widget _buildComingSoonforAI() {
    return _section(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 28,
                color: _cta,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Coming soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Auto will fill in report details from your photo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCard() {
    return Column(
      children: [
        _buildLocationPill(),
        if (!_isRecording &&
            _statusText != 'Tap the microphone to start recording' &&
            _statusText !=
                'Listening… describe the issue in a few sentences') ...[
          const SizedBox(height: 10),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _muted,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        VoiceMicControl(
          isRecording: _isRecording,
          animation: _pulseAnimation,
          onTap: _toggleRecording,
          accent: _cta,
          size: 220,
        ),
        const SizedBox(height: 14),
        Text(
          _isRecording ? 'Listening...' : 'Tap to record',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 22),
        _buildTranscriptPanel(),
      ],
    );
  }

  Widget _buildLocationPill() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openLocationPicker,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: _ink,
                ),
                const SizedBox(width: 6),
                if (_locationLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: _muted,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      _locationLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyPickedLocation(LatLng latLng) async {
    final label = await translateLocation(latLng.latitude, latLng.longitude);
    if (!mounted) return;
    setState(() {
      position = latLng;
      _markers = {
        Marker(markerId: const MarkerId('report'), position: latLng),
      };
      _ready = true;
      _locationLoading = false;
      _locationLabel = label;
    });
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
  }

  Future<void> _openLocationPicker() async {
    var draft = position;
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LocationPickerSheet(
          initial: position,
          onChanged: (latLng) => draft = latLng,
          onConfirm: () => Navigator.pop(ctx, draft),
        );
      },
    );
    if (picked == null || !mounted) return;
    await _applyPickedLocation(picked);
  }

  Widget _buildTranscriptPanel() {
    final hasText = _transcript.isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 16,
                color: hasText ? _ink : _muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Live transcript',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: hasText ? _ink : _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasText
                ? _transcript
                : 'Your description will show up here as you speak…',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
              color: hasText ? _ink : Colors.grey[500],
              fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _animationController.stop();
          _animationController.reset();
          _statusText = _transcript.isEmpty
              ? 'Couldn’t catch that. Tap the mic to try again.'
              : 'Recording stopped. Review below or tap to re-record.';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _speechReady = available;
      if (!available) {
        _statusText = 'Speech recognition unavailable on this device.';
      }
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (!_isRecording) return;
      setState(() {
        _isRecording = false;
        _animationController.stop();
        _animationController.reset();
        _statusText = _transcript.isEmpty
            ? 'Sorry, we couldn’t hear you. Tap the mic to try again.'
            : 'Recording complete. Review below or tap to re-record.';
      });
    }
  }

  String _fixSomeTypeos(String text) {
    return text.replaceAllMapped(
      RegExp(r'\bbottle\b', caseSensitive: false),
      (_) => 'pothole',
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _speech.stop();
      setState(() {
        _isRecording = false;
        _statusText = _transcript.isEmpty
            ? 'Sorry, we couldn’t hear you. Tap the mic to try again.'
            : 'Recording complete. Review below or tap to re-record.';
        _animationController.stop();
        _animationController.reset();
      });
      return;
    }

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _transcript = '';
      _isRecording = true;
      _statusText = 'Listening… describe the issue in a few sentences';
      _animationController.repeat();
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = _fixSomeTypeos(result.recognizedWords);
        setState(() {
          _transcript = text;
          _descriptionController.text = text;
        });
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildPhotoCard() {
    if (_image == null) {
      return _section(
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
                        color: _cta.withValues(alpha: 0.08),
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
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to capture or upload',
                      style: TextStyle(
                        fontSize: 14,
                        color: _muted,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 13,
                        color: _muted,
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
                    color: _pageBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _fieldBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 22, color: _ink),
                      SizedBox(width: 8),
                      Text(
                        'Upload from library',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
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

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          _buildModeButton(
            mode: 'manual',
            label: 'Manual',
            icon: Icons.edit_note_rounded,
          ),
          _buildModeButton(
            mode: 'auto',
            label: 'Auto',
            icon: Icons.auto_awesome_rounded,
          ),
          _buildModeButton(
            mode: 'voice',
            label: 'Voice',
            icon: Icons.mic_none_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _reportMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (_reportMode == mode) return;
          if (_reportMode == 'voice' && _isRecording) {
            await _speech.stop();
            _animationController.stop();
            _animationController.reset();
            _isRecording = false;
            _statusText = _transcript.isEmpty
                ? 'Tap the microphone to start recording'
                : 'Recording stopped. Review below or tap to re-record.';
          }
          setState(() => _reportMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _cta : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : _muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gotouser() async{
    try {
      final userLocation = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(userLocation.latitude, userLocation.longitude);
      final label = await translateLocation(
        userLatLng.latitude,
        userLatLng.longitude,
      );
      if (!mounted) return;
      setState(() {
         position = userLatLng;
         _markers = {
           Marker(
             markerId: const MarkerId('report'),
             position: userLatLng,
           ),
         };
         _ready = true;
         _locationLoading = false;
         _locationLabel = label;
      });
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(position,15));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationLabel = 'Set location';
      });
    }
  }

  Widget _buildLocationCard(){
    return _section(
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
                  _applyPickedLocation(latLng);
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
    return _section(
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
        color: selected ? _cta.withValues(alpha: 0.08) : Colors.white,
        border: Border.all(
          color: selected ? _cta : _fieldBorder,
          width: selected ? 1.6 : 1,
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
                      color: selected ? _cta : _muted,
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
                        color: selected ? _cta : _ink,
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
                color: selected ? _cta : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return _section(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showTitleInfo(context),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                if (_generatingTitle)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cta,
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _cta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI AUTO-FILL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _cta,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
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
                  hintText: 'Waiting for description...',
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

  void _showTitleInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _cta),
            SizedBox(width: 10),
            Text('AI Title Assist'),
          ],
        ),
        content: const Text(
          'Our AI automatically generates a professional title based on your description. '
          'This helps city workers quickly identify and prioritize issues.\n\n'
          'You can always edit the title manually if you prefer!',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _section(
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
                  _onDescriptionChanged(value);
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

  void _onDescriptionChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () async {
      if (value.trim().length > 10 && _titleController.text.trim().isEmpty) {
        setState(() => _generatingTitle = true);
        try {
          final aiTitle = await ApiService.generateAITitle(value);
          if (mounted && _titleController.text.trim().isEmpty) {
            setState(() {
              _titleController.text = aiTitle;
            });
          }
        } finally {
          if (mounted) setState(() => _generatingTitle = false);
        }
      }
    });
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
      return _section(
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
    return _section(
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
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
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
      location = await translateLocation(
        position.latitude,
        position.longitude,
        includeRegion: true,
        fallback:
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      );
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

              if (_reportMode == 'voice' && _isRecording) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please stop recording before submitting.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              // If in voice mode, analyze the transcript first to auto-fill title/desc/cat/sev
              if (_reportMode == 'voice' && _transcript.isNotEmpty) {
                setState(() => _submitting = true);
                try {
                  final aiResult = await ApiService.analyzeVoiceReport(_transcript);
                  _titleController.text = aiResult['title'] ?? '';
                  _descriptionController.text = aiResult['description'] ?? _transcript;
                  
                  // Extract matching category string from ReportCategories
                  final aiCat = aiResult['category'];
                  if (aiCat != null) {
                    final match = ReportCategories.all.firstWhere(
                      (c) => c.toLowerCase() == aiCat.toLowerCase(),
                      orElse: () => _selectedCategory ?? ReportCategories.other,
                    );
                    _selectedCategory = match;
                  }
                  
                  _selectedSeverity = aiResult['severity'];
                } catch (e) {
                  print('AI voice analysis failed: $e');
                } finally {
                  setState(() => _submitting = false);
                }
              }

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
                final address = await translateLocation(
                  position.latitude,
                  position.longitude,
                  includeRegion: true,
                  fallback:
                      '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                );
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
                color: _busy ? _cta.withValues(alpha: 0.45) : _cta,
                borderRadius: BorderRadius.circular(999),
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
                      'Review',
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
                foregroundColor: _ink,
                side: const BorderSide(color: _fieldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _savingDraft
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _ink,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_add_outlined,
                          size: 20,
                          color: _ink,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Save as draft',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink,
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

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.initial,
    required this.onChanged,
    required this.onConfirm,
  });

  final LatLng initial;
  final ValueChanged<LatLng> onChanged;
  final VoidCallback onConfirm;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late LatLng _position;
  late Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _position = widget.initial;
    _markers = {
      Marker(markerId: const MarkerId('report'), position: _position),
    };
  }

  void _setPosition(LatLng latLng) {
    setState(() {
      _position = latLng;
      _markers = {
        Marker(markerId: const MarkerId('report'), position: latLng),
      };
    });
    widget.onChanged(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.62,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Choose location',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap the map to move the pin',
            style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GoogleMap(
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  initialCameraPosition: CameraPosition(
                    target: widget.initial,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onTap: _setPosition,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Use this location',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
