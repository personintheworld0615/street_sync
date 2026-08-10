import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:street_sync/LoginScreen.dart';
import 'package:street_sync/ResetPasswordScreen.dart';
import 'package:street_sync/WelcomeScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env', isOptional: true);
    await AuthService.initialize();
    await ApiService.loadSession();
  } catch (e) {
    debugPrint('Startup init error: $e');
  }
  runApp(const StreetSyncApp());
}
//stuff pls take this
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
          ApiService.currentUser = null;
          _navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
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
    final signedIn = ApiService.userId != null ||
        (AuthService.isConfigured && AuthService.isSignedIn);

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: WelcomeScreen(alreadySignedIn: signedIn),
    );
  }
}
