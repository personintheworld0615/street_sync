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
  bool _isRecording = false;
  bool _isSubmitting = false;
  String _statusText = 'Tap the microphone to start recording';
  String _transcript = '';
  double? _lat;
  double? _long;
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
    _speech.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    var permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    //TODO later we have to do smth if permission is denied
    final pos = await Geolocator.getCurrentPosition();
    _lat = pos.latitude;
    _long = pos.longitude;

    setState(() {
      _transcript = '';
      _isRecording = true;
      _statusText = 'Listening… speak clearly about the issue';
      _animationController.repeat(reverse: true);
    });

    await _speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
      },
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
      // 1. Get AI Title from Backend
      final aiTitle = await ApiService.generateAITitle(_transcript);

      // 2. Get Location Address
      final lat = _lat;
      final lng = _long;
      final location = (lat != null && lng != null)
          ? await _addressFromCoords(lat, lng)
          : 'Location unavailable';

      if (!mounted) return;

      // 3. Navigate with the real AI-generated title
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmationVoiceReport(
            title: aiTitle,
            description: _transcript,
            location: location,
          ),
        ),
      );
    } catch (e) {
      print('Error in voice report flow: $e');
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
                'Transcript',
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
                : 'Your words will show up here as you speak…',
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
