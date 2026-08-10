import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:street_sync/Mainshell.dart';
import 'package:street_sync/ResetPasswordScreen.dart';
import 'package:street_sync/WelcomeScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreetSyncApp());
}




class StreetSyncApp extends StatefulWidget {
  const StreetSyncApp({super.key});

  @override
  State<StreetSyncApp> createState() => _StreetSyncAppState();
}

class _StreetSyncAppState extends State<StreetSyncApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (AuthService.isConfigured) {
      _authSub = AuthService.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _navKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          );
          return;
        }
        if (data.event == AuthChangeEvent.signedOut) {
          _navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (_) => false,
          );
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool signedIn = false;
    if (AuthService.isConfigured) {
      try {
        signedIn = ApiService.userId != null || AuthService.isSignedIn;
      } catch (e) {
        debugPrint('Auth check error: $e');
      }
    }

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: signedIn ? const MainShell() : const WelcomeScreen(),
    );
  }
}
