import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deep link Supabase sends the session back to. Same scheme on iOS and Android.
const kAuthRedirectUrl = 'com.streetsync.mobile://login-callback';

/// User closed the Google/Apple sheet — LoginScreen should reset quietly.
const kOAuthCanceled = 'canceled';

class AuthService {
  AuthService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static Session? get session => auth.currentSession;
  static User? get user => auth.currentUser;
  static String? get accessToken => session?.accessToken;
  static bool get isSignedIn => session != null;

  static bool _initialized = false;
  static bool _googleReady = false;

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
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        _initialized = true;
      } else {
        debugPrint('Sorry there was an error on our end. Please try again later.');
      }
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      await auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on TimeoutException {
      return 'Sign-in timed out. Check your connection and try again.';
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  static String get _googleWebClientId =>
      dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim() ?? '';
  static String get _googleIosClientId =>
      dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID')?.trim() ?? '';

  static Future<void> _ensureGoogleSignIn() async {
    if (_googleReady) return;
    final webClientId = _googleWebClientId;
    if (webClientId.isEmpty) {
      throw StateError('GOOGLE_WEB_CLIENT_ID missing from assets/.env');
    }
    // iOS needs the iOS client id; Android uses the web/server client id.
    final iosClientId = _googleIosClientId;
    final useIosClient =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    await GoogleSignIn.instance.initialize(
      clientId: useIosClient && iosClientId.isNotEmpty ? iosClientId : null,
      serverClientId: webClientId,
    );
    _googleReady = true;
  }

  /// Native Google account picker → Supabase session (stays in-app).
  ///
  /// Uses the same Google provider you configured in the Supabase dashboard
  /// (Authorized Client IDs + Skip nonce check on iOS). Avoids the blank
  /// browser OAuth page that supabase_flutter leaves stuck after redirect.
  static Future<String?> signInWithGoogle() async {
    if (!isConfigured) return 'Supabase not configured.';
    if (kIsWeb) {
      return signInWithOAuth(OAuthProvider.google);
    }
    try {
      await _ensureGoogleSignIn();
      // Account picker only — do NOT call authorizeScopes(). That second step
      // opens a Google consent webview that often renders blank on iOS/Android.
      // Supabase only needs the ID token for signInWithIdToken.
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return 'Google Sign-In did not return an ID token. '
            'Check GOOGLE_WEB_CLIENT_ID (server client) in assets/.env.';
      }

      // Soft-read an access token if Google already granted scopes (no UI).
      String? accessToken;
      try {
        final existing = await googleUser.authorizationClient
            .authorizationForScopes(const ['email', 'profile']);
        accessToken = existing?.accessToken;
      } catch (_) {}

      await auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          )
          .timeout(const Duration(seconds: 20));
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return kOAuthCanceled;
      }
      return e.description?.isNotEmpty == true
          ? e.description!
          : 'Google Sign-In failed.';
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('nonce')) {
        return 'Google sign-in rejected (nonce). In Supabase → Auth → '
            'Google, enable “Skip nonce check”, then try again.';
      }
      if (msg.contains('audience') || msg.contains('client')) {
        return 'Google client ID mismatch. Add your Web + iOS client IDs under '
            'Supabase → Auth → Google → Authorized Client IDs.';
      }
      return e.message;
    } on TimeoutException {
      return 'Google Sign-In timed out. Try again.';
    } catch (e) {
      return 'Google Sign-In failed: $e';
    }
  }

  /// Browser OAuth (Apple, or Google on web).
  ///
  /// In-app browsers often stay on a blank page after the deep-link callback
  /// (supabase_flutter limitation), so we open the system browser instead.
  static Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (!isConfigured) return 'Supabase not configured.';
    try {
      final opened = await auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : kAuthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!opened) return 'Could not open the sign-in page.';
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
      if (_googleReady) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await auth.signOut();
    } catch (_) {}
  }

  static Future<bool> refreshSession() async {
    if (!isConfigured) return false;
    try {
      final result = await auth
          .refreshSession()
          .timeout(const Duration(seconds: 15));
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

  static String? get firstNameFromUser => user?.userMetadata?['first_name'] as String?;
  static String? get lastNameFromUser => user?.userMetadata?['last_name'] as String?;
}
