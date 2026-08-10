import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/OnboardingFlow.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';

/// Instagram / SeeClickFix-style load splash: logo + small spinner until ready.
class WelcomeScreen extends StatefulWidget {
  /// Kept for call-site compat; routing still uses live auth/session state.
  final bool alreadySignedIn;

  const WelcomeScreen({super.key, this.alreadySignedIn = false});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _bg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _bootstrap();
  }

  bool get _isSignedIn =>
      ApiService.userId != null || AuthService.isSignedIn;

  Future<void> _bootstrap() async {
    await _ensureInitialized();
    if (!mounted) return;

    final next = _isSignedIn ? const MainShell() : const OnboardingFlow();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  Future<void> _ensureInitialized() async {
    try {
      if (dotenv.env.isEmpty) {
        await dotenv.load(fileName: 'assets/.env', isOptional: true);
      }
      await AuthService.initialize();
      await ApiService.loadSession();
    } catch (e) {
      debugPrint('Init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.sizeOf(context).height * 0.18;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/splash_logo.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
