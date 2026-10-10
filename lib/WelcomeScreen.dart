import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:street_sync/AccessSetupScreen.dart';
import 'package:street_sync/LoginScreen.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:street_sync/first_run.dart';

/// Branded startup. Holds for one second, then opens account creation
/// or the app if a session already exists.
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
  static const _muted = Color(0xFF6B7280);
  static const _hold = Duration(seconds: 1);

  bool _showWait = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _bootstrap();
  }

  /// Need a real API profile — a bare Supabase session is not enough to open
  /// the shell (feeds, submit, profile all need user_id).
  bool get _isSignedIn => ApiService.userId != null;

  Future<void> _bootstrap() async {
    var ready = false;
    final init = _ensureInitialized().whenComplete(() => ready = true);
    await Future<void>.delayed(_hold);
    if (!ready && mounted) setState(() => _showWait = true);
    await init;
    if (!mounted) return;

    // Orphan OAuth/email session with no profile → force a clean login.
    if (!_isSignedIn && AuthService.isSignedIn) {
      await AuthService.signOut();
    }

    final Widget next;
    if (_isSignedIn) {
      await FirstRun.markSignedInBefore();
      final localPending =
          await FirstRun.isTourPending(userId: ApiService.userId);
      final showTour = ApiService.needsAiTour || localPending;
      final asked = await FirstRun.permissionsWereAsked();
      if (!mounted) return;
      next = showTour && !asked
          ? const AccessSetupScreen()
          : MainShell(showAiTourOnStart: showTour);
    } else {
      final returning = await FirstRun.hasSignedInBefore();
      if (!mounted) return;
      next = LoginScreen(startAsCreateAccount: !returning);
    }

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
      // main() already ran Auth + loadSession; only fill gaps (hot restart).
      if (!AuthService.isConfigured) {
        await AuthService.initialize();
      }
      if (ApiService.userId == null && AuthService.isSignedIn) {
        await ApiService.loadSession();
      } else if (!AuthService.isConfigured) {
        await ApiService.loadSession();
      }
    } catch (e) {
      debugPrint('Init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final centerY = constraints.maxHeight / 2;
          return Stack(
            children: [
              Positioned(
                top: centerY - 48,
                left: 0,
                right: 0,
                child: const Center(
                  child: Image(
                    image: AssetImage('assets/images/splash_logo.png'),
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: centerY + 68,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    const Text(
                      'StreetSync',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Report. Track. Improve.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: _showWait
                          ? const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _ink,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
