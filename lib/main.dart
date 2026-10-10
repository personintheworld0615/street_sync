import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:street_sync/LoginScreen.dart';
import 'package:street_sync/ResetPasswordScreen.dart';
import 'package:street_sync/WelcomeScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep native splash (logo on #F7F8FA) until Flutter paints WelcomeScreen.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // Load env + Supabase before UI so login never races an uninitialized client.
  try {
    await dotenv.load(fileName: 'assets/.env', isOptional: true);
    await AuthService.initialize();
    await ApiService.loadSession();
  } catch (e) {
    debugPrint('Startup init error: $e');
  }
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      child: const StreetSyncApp(),
      adaptiveQuality: true,
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}

class StreetSyncApp extends StatefulWidget {
  const StreetSyncApp({super.key});

  @override
  State<StreetSyncApp> createState() => _StreetSyncAppState();
}

class _StreetSyncAppState extends State<StreetSyncApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;
  bool _listening = false;
  int _authAttachAttempts = 0;
  bool _isSignedIn = AuthService.isSignedIn;

  @override
  void initState() {
    super.initState();
    _isSignedIn = AuthService.isSignedIn;
    // Auth may not be ready until WelcomeScreen finishes init.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachAuthListener());
  }

  void _attachAuthListener() {
    if (_listening || !mounted) return;

    if (!AuthService.isConfigured) {
      if (_authAttachAttempts >= 50) return; // ~10s
      _authAttachAttempts++;
      Future<void>.delayed(const Duration(milliseconds: 200), _attachAuthListener);
      return;
    }

    _listening = true;
    _authSub = AuthService.auth.onAuthStateChange.listen((data) {
      final signedIn = AuthService.isSignedIn;
      if (signedIn != _isSignedIn) {
        if (mounted) setState(() => _isSignedIn = signedIn);
      }

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
        return;
      }
      if (data.event == AuthChangeEvent.signedOut) {
        ApiService.currentUser = null;
        _navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  static Route<dynamic> _fallbackRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final uri = Uri.tryParse(name);
    final hasAuthCallback = uri != null &&
        (uri.queryParameters.containsKey('code') ||
            uri.queryParameters.containsKey('error') ||
            uri.queryParameters.containsKey('token'));

    return MaterialPageRoute(
      builder: (_) => hasAuthCallback ? const LoginScreen() : const WelcomeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      themeMode: _isSignedIn ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C9CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardColor: const Color(0xFF111827),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const WelcomeScreen(),
      onGenerateRoute: (settings) => _fallbackRoute(settings),
      onUnknownRoute: (settings) => _fallbackRoute(settings),
    );
  }
}
