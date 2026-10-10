import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deep link Supabase sends the session back to. Same scheme on iOS and Android.
const kAuthRedirectUrl = 'com.streetsync.mobile://login-callback';

/// Returned by [AuthService.signUp] when the project requires an email link
/// before a session exists.
const kEmailConfirmPending = 'confirm-email';

class AuthService {
  AuthService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static Session? get session => auth.currentSession;
  static User? get user => auth.currentUser;
  static String? get accessToken => session?.accessToken;
  static bool get isSignedIn => session != null;

  static bool _initialized = false;

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
        return kEmailConfirmPending;
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

  /// Google goes through Supabase Auth’s OAuth redirect, same as Apple.
  /// The Google provider is configured in the Supabase dashboard, so the app
  /// does not depend on a native Google client matching each bundle id.
  static Future<String?> signInWithGoogle() {
    return signInWithOAuth(OAuthProvider.google);
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
    return msg.contains('not confirmed') || msg.contains('email_not_confirmed');
  }

  static String? get firstNameFromUser => user?.userMetadata?['first_name'] as String?;
  static String? get lastNameFromUser => user?.userMetadata?['last_name'] as String?;
}
