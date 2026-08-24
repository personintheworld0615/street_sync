import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:street_sync/ConfirmationVoiceReport.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/geocoding_utils.dart';
import 'package:street_sync/voice_mic_control.dart';

class VoiceReportScreen extends StatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  State<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends State<VoiceReportScreen>
    with SingleTickerProviderStateMixin {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF757575);
  static const _cta = Color(0xFF111827);
  static const _defaultLatLng = LatLng(40.3573, -74.6672);

  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _isRecording = false;
  bool _isSubmitting = false;
  bool _locationLoading = true;
  String _statusText = 'Tap the microphone to start recording';
  String _transcript = '';
  String _locationLabel = 'Finding location…';
  double? _lat;
  double? _long;
  Future<void>? _locationFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initSpeech();
    _locationFuture = _captureLocation(updateUi: true);
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

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _captureLocation({bool updateUi = false}) async {
    try {
      var permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (updateUi && mounted) {
          setState(() {
            _locationLoading = false;
            _locationLabel = 'Set location';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _long = pos.longitude;
      final label = await translateLocation(pos.latitude, pos.longitude);
      if (updateUi && mounted) {
        setState(() {
          _locationLoading = false;
          _locationLabel = label;
        });
      } else {
        _locationLabel = label;
        _locationLoading = false;
      }
    } catch (_) {
      if (updateUi && mounted) {
        setState(() {
          _locationLoading = false;
          _locationLabel = 'Set location';
        });
      }
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

    // Refresh GPS in parallel if we don't have one yet.
    if (_lat == null || _long == null) {
      _locationFuture = _captureLocation(updateUi: true);
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
        setState(() => _transcript = _fixSomeTypeos(result.recognizedWords));
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

  Future<void> _openLocationPicker() async {
    final initial = LatLng(
      _lat ?? _defaultLatLng.latitude,
      _long ?? _defaultLatLng.longitude,
    );
    var draft = initial;

    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LocationPickerSheet(
          initial: initial,
          onChanged: (latLng) => draft = latLng,
          onConfirm: () => Navigator.pop(ctx, draft),
        );
      },
    );

    if (picked == null || !mounted) return;
    final label = await translateLocation(picked.latitude, picked.longitude);
    if (!mounted) return;
    setState(() {
      _lat = picked.latitude;
      _long = picked.longitude;
      _locationLabel = label;
      _locationLoading = false;
    });
  }

  Future<void> _goToConfirmation() async {
    if (_transcript.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _locationFuture;

      final analysis = await ApiService.analyzeVoiceReport(_transcript);

      final lat = _lat;
      final lng = _long;
      final location = (lat != null && lng != null)
          ? await translateLocation(
              lat,
              lng,
              includeRegion: true,
              fallback:
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            )
          : 'Location unavailable';

      if (!mounted) return;

      final polished = (analysis['description'] as String?)?.trim();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmationVoiceReport(
            title: analysis['title'] as String,
            description: (polished != null && polished.isNotEmpty)
                ? polished
                : _transcript,
            location: location,
            latitude: lat ?? 0.0,
            longitude: lng ?? 0.0,
            category: analysis['category'] as String?,
            severity: analysis['severity'] as String?,
            aiRationale: analysis['rationale'] as String?,
            rawTranscript: _transcript,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in voice report flow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSubmit = !_isRecording && _transcript.isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final transcriptH = (screenH * 0.28).clamp(180.0, 260.0);

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
          'Voice report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Column(
                children: [
                  _buildLocationPill(),
                  if (!_isRecording &&
                      _statusText !=
                          'Tap the microphone to start recording' &&
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
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        VoiceMicControl(
                          isRecording: _isRecording,
                          animation: _pulseAnimation,
                          onTap: _toggleRecording,
                          accent: _cta,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isRecording ? 'Listening...' : 'Tap to record',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isRecording
                                ? const Color(0xFF5B6B75)
                                : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: transcriptH,
                    child: _buildTranscriptPanel(),
                  ),
                  SizedBox(height: showSubmit ? 10 : 20),
                ],
              ),
            ),
          ),
          if (showSubmit) _buildSubmitBar(bottomInset),
        ],
      ),
    );
  }

  Widget _buildLocationPill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openLocationPicker,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
    );
  }

  Widget _buildTranscriptPanel() {
    final hasText = _transcript.isNotEmpty;
    final labelColor = hasText ? _ink : _muted;

    return GlassCard(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      shape: const LiquidRoundedSuperellipse(borderRadius: 22),
      settings: const LiquidGlassSettings(
        thickness: 28,
        blur: 12,
        glassColor: Color(0x66FFFFFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: labelColor,
              ),
              const SizedBox(width: 7),
              Text(
                'Live transcript',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                hasText
                    ? _transcript
                    : 'Your description will show up here as you speak…',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                  color: hasText ? _ink : Colors.grey[500],
                  fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar(double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomInset),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _goToConfirmation,
          style: ElevatedButton.styleFrom(
            backgroundColor: _cta,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: _cta.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
