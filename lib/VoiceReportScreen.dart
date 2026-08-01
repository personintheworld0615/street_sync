import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:street_sync/ConfirmationVoiceReport.dart';
import 'package:street_sync/api_service.dart';

class VoiceReportScreen extends StatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  State<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends State<VoiceReportScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF2196F3);
  static const _pageBg = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF152033);
  static const _muted = Color(0xFF5B677A);

  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _isRecording = false;
  bool _isSubmitting = false;
  String _statusText = 'Tap the microphone to start recording';
  String _transcript = '';
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
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initSpeech();
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

  Future<void> _captureLocation() async {
    try {
      var permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _long = pos.longitude;
    } catch (_) {
      // Location is best-effort; recording should still work.
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

    // Capture GPS in parallel so it doesn't delay the mic opening.
    _locationFuture = _captureLocation();

    setState(() {
      _transcript = '';
      _isRecording = true;
      _statusText = 'Listening… describe the issue in a few sentences';
      _animationController.repeat(reverse: true);
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

  Future<String> _addressFromCoords(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final p = places.first;
      final parts = [
        if (p.street?.isNotEmpty == true) p.street!,
        if (p.locality?.isNotEmpty == true) p.locality!,
        if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
      ];
      return parts.isEmpty
          ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
          : parts.join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
  }

  Future<void> _goToConfirmation() async {
    if (_transcript.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      // Finish GPS if still in flight from the mic tap.
      await _locationFuture;

      final analysis = await ApiService.analyzeVoiceReport(_transcript);

      final lat = _lat;
      final lng = _long;
      final location = (lat != null && lng != null)
          ? await _addressFromCoords(lat, lng)
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
            aiConfidence: analysis['confidence'] as double?,
            aiRationale: analysis['rationale'] as String?,
            rawTranscript: _transcript,
          ),
        ),
      );
    } catch (e) {
      print('Error in voice report flow: $e');
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speak the issue',
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
                    'Describe what you see and we will turn it into a report',
                    style: TextStyle(
                      fontSize: 15,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildRecordingCard()),
                ],
              ),
            ),
          ),
          if (showSubmit) _buildSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildRecordingCard() {
    final accent = _isRecording ? Colors.red : _blue;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? 'Recording' : 'Ready',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _ink,
                height: 1.35,
              ),
            ),
            const Spacer(),
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? 'Tap to stop' : 'Tap to record',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            _buildTranscriptPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptPanel() {
    final hasText = _transcript.isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasText
              ? _blue.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 16,
                color: hasText ? _blue : _muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: hasText ? _blue : _muted,
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
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _goToConfirmation,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: _blue.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
