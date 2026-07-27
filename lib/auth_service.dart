import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  static bool _initialized = false;

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
  }

  static bool get isConfigured => _initialized;

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
  static Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    try {
      final res = await auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
        emailRedirectTo: kAuthRedirectUrl,
      );
      if (res.session == null) {
        return 'Check your email to confirm your account, then log in.';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign up failed: $e';
    }
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

  /// Opens the provider in an external browser; completion arrives via
  /// [auth.onAuthStateChange] after the deep link returns.
  static Future<String?> signInWithOAuth(OAuthProvider provider) async {
    if (!isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }
    try {
      await auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : kAuthRedirectUrl,
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'OAuth failed: $e';
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
      await auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }
}
