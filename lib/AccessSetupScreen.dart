import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/first_run.dart';

/// Last step of account setup. Explains location and the microphone, then
/// raises the system dialogs before the home guide starts.
class AccessSetupScreen extends StatefulWidget {
  const AccessSetupScreen({super.key});

  @override
  State<AccessSetupScreen> createState() => _AccessSetupScreenState();
}

class _AccessSetupScreenState extends State<AccessSetupScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _pageBg = Color(0xFFF7F8FA);

  bool _busy = false;

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
    try {
      await SpeechToText().initialize();
    } catch (_) {}
    await _continueToApp();
  }

  Future<void> _notNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _continueToApp();
  }

  Future<void> _continueToApp() async {
    await FirstRun.markPermissionsAsked();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(showAiTourOnStart: true),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 36, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why we ask',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A report only helps if someone can find the problem and understand it. We ask for these when you create an account so that moment isn’t a surprise later.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _AccessRow(
                        icon: Icons.location_on_outlined,
                        title: 'Location',
                        body:
                            'So the report is pinned to the street you’re standing on. A crew can go there directly instead of guessing from a description.',
                      ),
                      const SizedBox(height: 12),
                      const _AccessRow(
                        icon: Icons.mic_none_rounded,
                        title: 'Microphone',
                        body:
                            'So you can say what’s wrong out loud, instead of typing on the sidewalk. Your phone turns that into the report. The recording stays on your phone.',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _allow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _ink.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _busy ? null : _notNow,
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
