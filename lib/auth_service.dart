import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kAuthRedirectUrl = 'com.example.streetsync://login-callback';

class AuthService {
  AuthService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static Session? get session => auth.currentSession;
  static User? get user => auth.currentUser;
  static String? get accessToken => session?.accessToken;
  static bool get isSignedIn => session != null;

  static bool _initialized = false;
  static bool _googleInitialized = false;

  /// Safely check if Supabase is initialized.
  static bool get isConfigured {
    try {
      return _initialized && Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static String get supabaseUrl => dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  static String get supabaseAnonKey => dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
  static String get googleWebClientId => dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim() ?? '';
  static String get googleIosClientId => dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID')?.trim() ?? '';

  static Future<void> initialize() async {
    if (kIsWeb) _initialized = false;
    if (_initialized) return;

    final url = supabaseUrl;
    final anon = supabaseAnonKey;

    if (url.isEmpty || anon.isEmpty) {
      debugPrint('AuthService: Credentials missing in assets/.env');
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anon,
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      );
      _initialized = true;
      unawaited(_ensureGoogleInitialized());
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        _initialized = true;
      } else {
        debugPrint('Supabase Init Error: $e');
      }
    }
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final webClientId = googleWebClientId;
    if (webClientId.isEmpty) return;
    
    try {
      await GoogleSignIn.instance.initialize(
        clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
        serverClientId: webClientId,
      );
      _googleInitialized = true;
    } catch (e) {
      debugPrint('Google Sign-In Init Error: $e');
    }
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      final res = await auth.signUp(
        email: email,
        password: password,
        data: {'first_name': firstName, 'last_name': lastName},
        emailRedirectTo: kAuthRedirectUrl,
      );
      if (res.session == null && res.user != null) {
        return 'Check your email to confirm your account.';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign up failed: $e';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      await auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  static Future<String?> signInWithGoogle() async {
    if (!isConfigured) return 'Supabase not configured.';
    if (googleWebClientId.isEmpty) return 'Google Web Client ID missing.';

    try {
      await _ensureGoogleInitialized();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = null; // authenticate() currently only provides idToken in this version

      if (idToken == null) return 'Google did not return an ID token.';

      await auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  static Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      await auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : kAuthRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'OAuth failed: $e';
    }
  }

  static Future<String?> resetPassword(String email) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      await auth.resetPasswordForEmail(email, redirectTo: kAuthRedirectUrl);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not send reset email: $e';
    }
  }

  static Future<String?> updatePassword(String newPassword) async {
    try {
      await auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not update password: $e';
    }
  }

  static Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
      await auth.signOut();
    } catch (_) {}
  }

  static Future<bool> refreshSession() async {
    if (!isConfigured) return false;
    try {
      final result = await auth.refreshSession();
      return result.session != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureFreshSession() async {
    if (!isConfigured) return false;
    final s = session;
    if (s == null) return false;
    if (!s.isExpired) return true;
    return refreshSession();
  }

  static bool isEmailConfirmBlocker(String? error) {
    if (error == null) return false;
    final msg = error.toLowerCase();
    return msg.contains('rate limit') || msg.contains('confirm');
  }

  static String? get firstNameFromUser => user?.userMetadata?['first_name'] as String?;
  static String? get lastNameFromUser => user?.userMetadata?['last_name'] as String?;
}
