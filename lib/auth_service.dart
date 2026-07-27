import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deep link scheme registered in AndroidManifest / Info.plist.
/// Also add this exact URL under Supabase → Authentication → URL Configuration
/// → Additional Redirect URLs.
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

  static String get supabaseUrl {
    final fromAssets = dotenv.maybeGet('SUPABASE_URL')?.trim();
    if (fromAssets != null && fromAssets.isNotEmpty) return fromAssets;
    return '';
  }

  /// Publishable / anon key only — never the service role key.
  static String get supabaseAnonKey {
    final key = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ??
        dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY')?.trim() ??
        '';
    return key;
  }

  static String get googleWebClientId =>
      dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim() ?? '';

  static String get googleIosClientId =>
      dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID')?.trim() ?? '';

  static Future<void> initialize() async {
    final url = supabaseUrl;
    final anon = supabaseAnonKey;
    if (url.isEmpty || anon.isEmpty) {
      debugPrint(
        'AuthService: missing SUPABASE_URL or SUPABASE_ANON_KEY in assets/.env',
      );
      _initialized = false;
      return;
    }
    await Supabase.initialize(
      url: url,
      publishableKey: anon,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;

    // Warm up native Google Sign-In (no browser).
    unawaited(_ensureGoogleInitialized());
  }

  static bool get isConfigured => _initialized;

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final webClientId = googleWebClientId;
    if (webClientId.isEmpty) {
      debugPrint('AuthService: GOOGLE_WEB_CLIENT_ID missing in assets/.env');
      return;
    }
    final iosClientId = googleIosClientId;
    await GoogleSignIn.instance.initialize(
      // iOS/macOS client id (optional but recommended for those platforms)
      clientId: iosClientId.isEmpty ? null : iosClientId,
      // Web client id — required so we get an ID token for Supabase
      serverClientId: webClientId,
    );
    _googleInitialized = true;
  }

  static String? get firstNameFromUser {
    final meta = user?.userMetadata ?? {};
    final direct = meta['first_name'] as String?;
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final full = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        '';
    if (full.trim().isEmpty) return null;
    return full.trim().split(RegExp(r'\s+')).first;
  }

  static String? get lastNameFromUser {
    final meta = user?.userMetadata ?? {};
    final direct = meta['last_name'] as String?;
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final full = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        '';
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return parts.sublist(1).join(' ');
  }

  /// Returns null on success, or an error message.
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    try {
      await auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  static bool isEmailConfirmBlocker(String? error) {
    if (error == null) return false;
    final msg = error.toLowerCase();
    return msg.contains('rate limit') ||
        msg.contains('not confirmed') ||
        msg.contains('email not confirmed');
  }

  /// Native Google Sign-In (account picker in-app). No Chrome tab.
  /// Falls back to browser OAuth only if native auth isn't supported.
  static Future<String?> signInWithGoogle() async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    if (googleWebClientId.isEmpty) {
      return 'Add GOOGLE_WEB_CLIENT_ID to assets/.env';
    }

    try {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        // Web / unsupported platforms — browser OAuth fallback.
        return signInWithOAuth(OAuthProvider.google);
      }

      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return 'Google did not return an ID token. '
            'Add an iOS OAuth client (bundle com.example.streetSync) '
            'and set GOOGLE_IOS_CLIENT_ID, or check GOOGLE_WEB_CLIENT_ID.';
      }

      String? accessToken;
      try {
        final authz = await googleUser.authorizationClient
            .authorizationForScopes(const ['email', 'profile']);
        accessToken = authz?.accessToken;
      } catch (_) {
        // ID token alone is enough for Supabase.
      }

      await auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was canceled';
      }
      return 'Google sign-in failed: ${e.description ?? e.code.name}';
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  /// Browser OAuth (Apple, or Google fallback). Prefer [signInWithGoogle]
  /// for Google so the flow stays in-app.
  static Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    try {
      await auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : kAuthRedirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.inAppBrowserView,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      // inAppBrowserView isn't available on every desktop build — retry external.
      try {
        await auth.signInWithOAuth(
          provider,
          redirectTo: kIsWeb ? null : kAuthRedirectUrl,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        return null;
      } catch (e2) {
        return 'OAuth failed: $e2';
      }
    }
  }

  /// Sends a password-reset email. Returns null on success.
  static Future<String?> resetPassword(String email) async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    try {
      await auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : kAuthRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not send reset email: $e';
    }
  }

  /// Call after the user lands from a recovery deep link.
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
    if (!Supabase.instance.isInitialized) return;
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Google signOut error: $e');
    }
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }
}