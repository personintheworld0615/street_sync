import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:street_sync/auth_service.dart';
import 'dart:io' show File, Platform;

class ApiService {
  static const _sessionKey = 'current_user';
  static const _secure = FlutterSecureStorage();
  static const _cacheRecentReports = 'cache_recent_reports';
  static const _cacheReportStats = 'cache_report_stats';
  static const _cacheHomeFeeds = 'cache_home_feeds';
  static const _cacheHomeHasMore = 'cache_home_has_more';
  static const _cacheHomeLocation = 'cache_home_location_label';
  static const _cacheDraftReports = 'cache_draft_reports';
  static const _cacheSubmittedReports = 'cache_submitted_reports';
  static const _cacheTopUsers = 'cache_top_users';
  static const _cacheUserScopedId = 'cache_user_scoped_id';
  static const _cacheFilterReports = 'cache_filter_reports';
  static const filterCacheTtl = Duration(minutes: 3);

  /// Set when [submitReport] returns false. Cleared at the start of each submit.
  static String? lastSubmitError;

  static String homeFeedKey(String? category) {
    final c = category?.trim();
    if (c == null || c.isEmpty) return 'All';
    return c;
  }

  static String get _devHost =>
      dotenv.maybeGet('DEV_HOST')?.trim().isNotEmpty == true
          ? dotenv.get('DEV_HOST').trim()
          : 'localhost';

  static int get _devPort =>
      int.tryParse(dotenv.maybeGet('API_PORT') ?? '') ?? 8000;

  static String get baseUrl {
    final cloudUrl = dotenv.maybeGet('CLOUD_URL');
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      return cloudUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:$_devPort';
    }

    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:$_devPort';
      }
    } catch (_) {}

    return 'http://$_devHost:$_devPort';
  }

  // Store the logged-in user's info
  static Map<String, dynamic>? currentUser;

  static int? get userId {
    final id = currentUser?['user_id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  static String get firstName =>
      currentUser?['first_name'] as String? ?? 'Citizen';

  static String get lastName =>
      currentUser?['last_name'] as String? ?? '';

  static String get userName {
    final last = lastName.trim();
    if (last.isEmpty) return firstName;
    return '$firstName $last';
  }

  static String? get userEmail => currentUser?['email'] as String?;

  static String? get userPicture {
    final raw = currentUser?['picture'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// True when /auth/sync just created this profile row.
  static bool get isNewUser => currentUser?['is_new_user'] == true;

  /// Server flag; missing means unknown (do not force the tour).
  static bool get aiTourCompleted {
    final v = currentUser?['ai_tour_completed'];
    return v is bool ? v : true;
  }

  static bool get needsAiTour {
    final v = currentUser?['ai_tour_completed'];
    if (v is bool) return !v;
    return false;
  }

  static String? get token {
    if (AuthService.isConfigured) {
      final supabaseToken = AuthService.accessToken;
      if (supabaseToken != null && supabaseToken.isNotEmpty) return supabaseToken;
    }
    return currentUser?['access_token'] as String?;
  }

  static Future<void> updateUserPicture(String pictureUrl) async {
    if (currentUser == null) return;
    currentUser = {...currentUser!, 'picture': pictureUrl};
    await _saveSession();
  }

  static Future<void> loadSession() async {
    if (AuthService.isConfigured) {
      final fresh = await AuthService.ensureFreshSession();
      if (fresh) {
        final error = await syncFromSupabase();
        if (error == null) return;
        print('loadSession sync error: $error');
        // Soft-fallback in syncFromSupabase may still have set currentUser.
        if (userId != null) return;
      }

      // Supabase is on — don't resurrect a legacy session token.
      currentUser = null;
      await _saveSession();
      return;
    }

    // Legacy session (pre-Supabase installs), now read from encrypted storage.
    final raw = await _readSessionRaw();
    if (raw == null || raw.isEmpty) return;
    try {
      currentUser = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('loadSession Error: $e');
      currentUser = null;
      await _saveSession();
    }
  }

  static Future<void> _syncAccessTokenIntoSession() async {
    final access = AuthService.accessToken;
    if (currentUser == null || access == null || access.isEmpty) return;
    currentUser = {...currentUser!, 'access_token': access};
    await _saveSession();
  }

  /// Sends an authenticated request. On 401: refresh once, retry once.
  /// Returns null only after logout (refresh failed or second 401).
  static Future<http.Response?> _authorized(
    Future<http.Response> Function() send,
  ) async {
    await AuthService.ensureFreshSession();

    var response = await send();
    if (response.statusCode != 401) return response;

    final refreshed = await AuthService.refreshSession();
    if (!refreshed) {
      await logout();
      return null;
    }
    await _syncAccessTokenIntoSession();

    response = await send();
    if (response.statusCode == 401) {
      await logout();
      return null;
    }
    return response;
  }

  static Future<String?> _readSessionRaw() async {
    try {
      final secure = await _secure.read(key: _sessionKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (e) {
      print('secure session read: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_sessionKey);
    if (legacy == null || legacy.isEmpty) return null;
    try {
      await _secure.write(key: _sessionKey, value: legacy);
    } catch (e) {
      print('secure session migrate: $e');
      return legacy;
    }
    await prefs.remove(_sessionKey);
    return legacy;
  }

  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    if (currentUser == null) {
      try {
        await _secure.delete(key: _sessionKey);
      } catch (e) {
        print('secure session delete: $e');
      }
      return;
    }
    try {
      await _secure.write(key: _sessionKey, value: jsonEncode(currentUser));
    } catch (e) {
      print('secure session write: $e');
    }
  }

  /// Pulls the Supabase session into [currentUser] and ensures a matching
  /// row exists in the StreetSync API (`/auth/sync`).
  /// Returns null on success, `'user-not-found'` when [createIfMissing] is
  /// false and no profile exists, or an error message.
  static Future<String?> syncFromSupabase({
    String? firstName,
    String? lastName,
    bool createIfMissing = true,
  }) async {
    await AuthService.ensureFreshSession();
    final access = AuthService.accessToken;
    final authUser = AuthService.user;
    if (access == null || authUser == null) {
      currentUser = null;
      await _saveSession();
      return 'Not signed in';
    }

    final url = Uri.parse('$baseUrl/auth/sync');
    try {
      final response = await _authorized(
        () => http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AuthService.accessToken ?? access}',
              },
              body: jsonEncode({
                if (firstName != null && firstName.isNotEmpty)
                  'first_name': firstName,
                if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
                'create_if_missing': createIfMissing,
              }),
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response == null) return 'Not signed in';

      if (response.statusCode == 404) {
        return 'user-not-found';
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        currentUser = {
          ...body,
          'access_token': AuthService.accessToken ?? access,
        };
        await _saveSession();
        return null;
      }

      // Soft-fallback so the app can still open if the API is down.
      // Skip inventing a profile when the caller asked not to create one.
      if (!createIfMissing) {
        return _errorFromResponse(response, fallback: 'Could not sync profile');
      }
      currentUser = {
        'access_token': AuthService.accessToken ?? access,
        'user_id': currentUser?['user_id'],
        'first_name': firstName ??
            AuthService.firstNameFromUser ??
            currentUser?['first_name'] ??
            'Citizen',
        'last_name': lastName ??
            AuthService.lastNameFromUser ??
            currentUser?['last_name'] ??
            '',
        'email': authUser.email,
        'picture': currentUser?['picture'] ??
            authUser.userMetadata?['avatar_url'] ??
            authUser.userMetadata?['picture'],
        'ai_tour_completed': currentUser?['ai_tour_completed'] ?? true,
        'is_new_user': false,
      };
      await _saveSession();
      return _errorFromResponse(response, fallback: 'Could not sync profile');
    } catch (e) {
      print('syncFromSupabase Error ($url): $e');
      if (!createIfMissing) {
        return 'Cannot reach API at $baseUrl. Is the server running?';
      }
      currentUser = {
        'access_token': AuthService.accessToken ?? access,
        'user_id': currentUser?['user_id'],
        'first_name': firstName ?? AuthService.firstNameFromUser ?? 'Citizen',
        'last_name': lastName ?? AuthService.lastNameFromUser ?? '',
        'email': authUser.email,
        'picture': authUser.userMetadata?['avatar_url'] ??
            authUser.userMetadata?['picture'],
        'ai_tour_completed': currentUser?['ai_tour_completed'] ?? true,
        'is_new_user': false,
      };
      await _saveSession();
      return 'Cannot reach API at $baseUrl. Is the server running?';
    }
  }

  static Future<void> logout() async {
    await AuthService.signOut();
    currentUser = null;
    await _saveSession();
    await clearDataCache();
  }

  static Future<void> clearDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRecentReports);
    await prefs.remove(_cacheReportStats);
    await prefs.remove(_cacheHomeFeeds);
    await prefs.remove(_cacheHomeHasMore);
    await prefs.remove(_cacheDraftReports);
    await prefs.remove(_cacheSubmittedReports);
    await prefs.remove(_cacheTopUsers);
    await prefs.remove(_cacheUserScopedId);
    await prefs.remove(_cacheFilterReports);
  }

  static Future<List<dynamic>?> _readListCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (e) {
      print('cache read error ($key): $e');
    }
    return null;
  }

  static Future<void> _writeListCache(String key, List<dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static Future<void> _ensureUserScopedCache(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedFor = prefs.getInt(_cacheUserScopedId);
    if (cachedFor == userId) return;
    await prefs.remove(_cacheDraftReports);
    await prefs.remove(_cacheSubmittedReports);
    await prefs.remove(_cacheTopUsers);
    await prefs.setInt(_cacheUserScopedId, userId);
  }

  static Future<List<dynamic>?> getCachedRecentReports() =>
      _readListCache(_cacheRecentReports);

  static Future<void> cacheRecentReports(List<dynamic> reports) =>
      _writeListCache(_cacheRecentReports, reports);

  static Future<Map<String, dynamic>> _readJsonMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      print('cache read error ($key): $e');
    }
    return {};
  }

  static Future<void> _writeJsonMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  /// Full home feed list for a category (All includes Show more pages).
  static Future<List<dynamic>?> getCachedHomeFeed(String? category) async {
    final map = await _readJsonMap(_cacheHomeFeeds);
    final raw = map[homeFeedKey(category)];
    if (raw is List) return List<dynamic>.from(raw);
    return null;
  }

  static Future<void> cacheHomeFeed(
    String? category,
    List<dynamic> reports,
  ) async {
    final map = await _readJsonMap(_cacheHomeFeeds);
    map[homeFeedKey(category)] = reports;
    await _writeJsonMap(_cacheHomeFeeds, map);
  }

  static Future<bool?> getCachedHomeHasMore(String? category) async {
    final map = await _readJsonMap(_cacheHomeHasMore);
    final value = map[homeFeedKey(category)];
    if (value is bool) return value;
    return null;
  }

  static Future<void> cacheHomeHasMore(String? category, bool hasMore) async {
    final map = await _readJsonMap(_cacheHomeHasMore);
    map[homeFeedKey(category)] = hasMore;
    await _writeJsonMap(_cacheHomeHasMore, map);
  }

  /// Request [pageSize]+1 items; return at most [pageSize] plus a real hasMore.
  static ({List<dynamic> items, bool hasMore}) trimFeedPage(
    List<dynamic> raw,
    int pageSize,
  ) {
    final hasMore = raw.length > pageSize;
    final items = hasMore ? raw.sublist(0, pageSize) : List<dynamic>.from(raw);
    return (items: items, hasMore: hasMore);
  }

  static Future<Map<String, int>?> getCachedReportStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheReportStats);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return {
        'nearby': (decoded['nearby'] as num?)?.toInt() ?? 0,
        'in_progress': (decoded['in_progress'] as num?)?.toInt() ?? 0,
        'resolved': (decoded['resolved'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      print('cache read error ($_cacheReportStats): $e');
      return null;
    }
  }

  static Future<void> cacheReportStats(Map<String, int> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheReportStats, jsonEncode(stats));
  }

  /// City/region label for the Home header (device location, not user-scoped).
  static Future<String?> getCachedHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheHomeLocation)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static Future<void> cacheHomeLocation(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheHomeLocation, trimmed);
  }

  static Future<List<dynamic>?> getCachedDraftReports(int userId) async {
    await _ensureUserScopedCache(userId);
    return _readListCache(_cacheDraftReports);
  }

  static Future<void> cacheDraftReports(int userId, List<dynamic> reports) async {
    await _ensureUserScopedCache(userId);
    await _writeListCache(_cacheDraftReports, reports);
  }

  static Future<List<dynamic>?> getCachedSubmittedReports(int userId) async {
    await _ensureUserScopedCache(userId);
    return _readListCache(_cacheSubmittedReports);
  }

  static Future<void> cacheSubmittedReports(
    int userId,
    List<dynamic> reports,
  ) async {
    await _ensureUserScopedCache(userId);
    await _writeListCache(_cacheSubmittedReports, reports);
  }

  static Future<List<dynamic>?> getCachedTopUsers(int userId) async {
    await _ensureUserScopedCache(userId);
    return _readListCache(_cacheTopUsers);
  }

  static Future<void> cacheTopUsers(int userId, List<dynamic> users) async {
    await _ensureUserScopedCache(userId);
    await _writeListCache(_cacheTopUsers, users);
  }

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final t = token;
    if (t != null && t.isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  /// Email/password signup through Supabase Auth only.
  /// Returns null on success, 'confirm-email' when a link is required, or an
  /// error message. A profile sync failure does not undo a real session.
  static Future<String?> signup({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    if (!AuthService.isConfigured) {
      return 'Supabase is not configured. Add SUPABASE_URL and '
          'SUPABASE_ANON_KEY to assets/.env';
    }

    final error = await AuthService.signUp(
      email: email.trim(),
      password: password,
      firstName: firstname,
      lastName: lastname,
    );
    if (error == kEmailConfirmPending) return 'confirm-email';
    if (error != null) return _friendlyAuthMessage(error);

    final syncError = await syncFromSupabase(
      firstName: firstname,
      lastName: lastname,
    );
    if (syncError != null) {
      debugPrint('signup profile sync: $syncError');
    }
    return null;
  }

  /// Email/password login via Supabase Auth, then profile sync with the API.
  /// Unconfirmed accounts stay blocked until the user opens the email link.
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final error = await AuthService.signIn(email: email, password: password);
    if (AuthService.isEmailConfirmBlocker(error)) {
      return 'Confirm your email first. Open the link we sent to ${email.trim()}, then sign in.';
    }
    if (error != null) return _friendlyAuthMessage(error);
    final syncError = await syncFromSupabase();
    if (syncError != null) {
      debugPrint('login profile sync: $syncError');
    }
    return null;
  }

  static String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid') &&
        (lower.contains('credential') || lower.contains('login'))) {
      return 'Email or password is incorrect.';
    }
    if (lower.contains('already') &&
        (lower.contains('registered') || lower.contains('exist'))) {
      return 'Email already registered';
    }
    return message;
  }

  static bool isInvalidCredentials(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('incorrect') ||
        (lower.contains('invalid') &&
            (lower.contains('credential') || lower.contains('login')));
  }

  static bool isAlreadyRegistered(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('already') &&
        (lower.contains('registered') ||
            lower.contains('exist') ||
            lower.contains('in use'));
  }

  static String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        return detail.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Completes an OAuth session (after deep link) and syncs the API profile.
  /// Pass [createIfMissing] false to detect a brand-new Google/Apple user
  /// before terms agreement creates the profile.
  static Future<String?> completeOAuthSession({
    bool createIfMissing = true,
  }) async {
    if (!AuthService.isSignedIn) return 'OAuth sign-in did not complete';
    final syncError = await syncFromSupabase(createIfMissing: createIfMissing);
    if (syncError == 'user-not-found') return syncError;
    if (syncError != null) {
      debugPrint('oauth profile sync: $syncError');
      if (!createIfMissing) return syncError;
    }
    return null;
  }

  /// Persist that the home AI tour was finished or skipped.
  static Future<void> markAiTourCompleted() async {
    if (currentUser != null) {
      currentUser = {...currentUser!, 'ai_tour_completed': true};
      await _saveSession();
    }
    if (userId == null || token == null) return;
    final url = Uri.parse('$baseUrl/auth/tour-complete');
    try {
      final response = await _authorized(
        () => http
            .post(
              url,
              headers: _headers,
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response == null) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        currentUser = {
          ...?currentUser,
          ...body,
          'ai_tour_completed': true,
          'access_token': token,
        };
        await _saveSession();
      }
    } catch (e) {
      debugPrint('markAiTourCompleted: $e');
    }
  }

  /// Uploads a profile photo to Supabase via the API.
  /// Returns the public URL on success, or null on failure.
  static Future<String?> uploadProfilePicture(String imagePath) async {
    if (userId == null) {
      print('uploadProfilePicture: no logged-in user');
      return null;
    }
    if (!await File(imagePath).exists()) {
      print('uploadProfilePicture: file missing');
      return null;
    }

    final url = Uri.parse('$baseUrl/auth/picture');
    try {
      final response = await _authorized(() async {
        final request = http.MultipartRequest('POST', url);
        final t = token;
        if (t != null && t.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $t';
        }
        request.files
            .add(await http.MultipartFile.fromPath('image', imagePath));
        final streamed =
            await request.send().timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      });
      if (response == null) return null;

      if (response.statusCode != 200 && response.statusCode != 201) {
        print(
          'uploadProfilePicture failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final picture = body['picture'] as String?;
      if (picture == null || picture.trim().isEmpty) return null;
      await updateUserPicture(picture.trim());
      return picture.trim();
    } catch (e) {
      print('uploadProfilePicture Error: $e');
      return null;
    }
  }

  static Future<String?> deleteAccount() async {
    final id = userId;
    final url = id != null
        ? Uri.parse('$baseUrl/auth/delete/$id')
        : Uri.parse('$baseUrl/auth/delete');
    try {
      final response = await _authorized(
        () => http
            .delete(url, headers: _headers)
            .timeout(const Duration(seconds: 30)),
      );
      if (response == null) return null; // already logged out

      if (response.statusCode == 200) {
        final deletedAuth = _responseFlag(response, 'supabase_auth_deleted');
        if (deletedAuth == false) {
          return 'Could not delete the sign-in account. Your profile was not removed.';
        }
        await logout();
        return null;
      }

      return _errorFromResponse(response, fallback: 'Could not delete account');
    } catch (e) {
      print('Delete Account Error ($url): $e');
      return 'Could not delete the account. Try again.';
    }
  }

  static bool? _responseFlag(http.Response response, String key) {
    try {
      final body = jsonDecode(response.body);
      final value = body is Map ? body[key] : null;
      if (value is bool) return value;
    } catch (_) {}
    return null;
  }

  static String _errorFromResponse(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  /// Submits a report as multipart/form-data so photos go to Supabase Storage
  /// (API stores only the public URL in Postgres).
  ///
  /// Pass [draftId] to update/publish an existing draft in place (so it leaves
  /// the drafts list). Pass [existingImageUrl] to keep a server photo when no
  /// new local file is uploaded.
  static Future<bool> submitReport({
    required String title,
    required String description,
    required String category,
    required String location,
    required String severity,
    required bool isDraft,
    double latitude = 0.0,
    double longitude = 0.0,
    int? userId,
    String? imagePath,
    int? draftId,
    String? existingImageUrl,
  }) async {
    final effectiveUserId = userId ?? ApiService.userId;
    lastSubmitError = null;
    if (effectiveUserId == null) {
      print('submitReport: no logged-in user');
      lastSubmitError = 'Sign in before submitting a report.';
      return false;
    }

    final updating = draftId != null;
    final url = updating
        ? Uri.parse('$baseUrl/reports/$draftId')
        : Uri.parse('$baseUrl/reports');
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        await File(imagePath).exists();

    try {
      final response = await _authorized(() async {
        final request = http.MultipartRequest(updating ? 'PUT' : 'POST', url);
        final t = token;
        if (t != null && t.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $t';
        }

        request.fields.addAll({
          'title': title,
          'description': description,
          'category': category,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'location': location,
          'time': DateTime.now().toIso8601String(),
          'severity': severity.toLowerCase(),
          'user_id': effectiveUserId.toString(),
          'isDraft': isDraft.toString(),
        });

        if (hasImage) {
          request.files.add(
            await http.MultipartFile.fromPath('image', imagePath!),
          );
        } else if (updating &&
            existingImageUrl != null &&
            existingImageUrl.trim().isNotEmpty) {
          request.fields['existing_image_url'] = existingImageUrl.trim();
        }

        final streamed = await request.send().timeout(
              Duration(seconds: hasImage ? 60 : 15),
            );
        return http.Response.fromStream(streamed);
      });
      if (response == null) {
        lastSubmitError = 'Could not reach the server. Try again.';
        return false;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('submitReport failed: ${response.statusCode} ${response.body}');
        lastSubmitError = _errorDetail(response.body) ??
            'Could not submit the report. Try again.';
        return false;
      }
      await clearUserReportCaches();
      return true;
    } catch (e) {
      print('Connection Error: $e');
      lastSubmitError = 'Could not submit the report. Try again.';
      return false;
    }
  }

  static Future<void> clearUserReportCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheDraftReports);
    await prefs.remove(_cacheSubmittedReports);
    await prefs.remove(_cacheTopUsers);
    await prefs.remove(_cacheHomeFeeds);
    await prefs.remove(_cacheHomeHasMore);
    await prefs.remove(_cacheRecentReports);
    await prefs.remove(_cacheReportStats);
    await prefs.remove(_cacheFilterReports);
  }

  /// Home pull-to-refresh: drop feed + stats caches so the next load is fresh.
  static Future<void> clearHomeReportCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheHomeFeeds);
    await prefs.remove(_cacheHomeHasMore);
    await prefs.remove(_cacheRecentReports);
    await prefs.remove(_cacheReportStats);
  }

  /// Returns null on network/HTTP failure so callers can keep cached UI.
  static Future<List<dynamic>?> getRecentReports({int amount = 3}) async {
    final url = Uri.parse('$baseUrl/reports/recent?amount=$amount');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 5)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheRecentReports(list);
        return list;
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
    return null;
  }

  /// Cursor feed for Home "Show more". Pass [before] as the oldest loaded
  /// report's `time` to fetch the next older page.
  /// Returns null on network/HTTP failure so callers can keep cached UI.
  static Future<List<dynamic>?> getReportsFeed({
    int amount = 10,
    String? category,
    String? before,
  }) async {
    final params = <String, String>{
      'amount': amount.toString(),
    };
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (before != null && before.isNotEmpty) {
      params['before'] = before;
    }

    final url = Uri.parse('$baseUrl/reports/feed').replace(queryParameters: params);
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 8)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      print('Feed error: ${response.statusCode}');
    } catch (e) {
      print('Error fetching feed: $e');
    }
    return null;
  }

  static Future<int?> _countReports(String path) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 5)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.length;
      }
      print('Stats error ($path): ${response.statusCode}');
    } catch (e) {
      print('Error fetching $path: $e');
    }
    return null;
  }

  /// Nearby / in-progress / resolved lists. Entries older than 3 minutes are dropped.
  static Future<List<dynamic>?> getCachedReportsByFilter(String filter) async {
    final map = await _readJsonMap(_cacheFilterReports);
    final entry = map[filter];
    if (entry is! Map) return null;
    final savedAt = entry['saved_at'];
    final items = entry['items'];
    if (savedAt is! num || items is! List) return null;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt.toInt();
    if (age >= filterCacheTtl.inMilliseconds) {
      map.remove(filter);
      await _writeJsonMap(_cacheFilterReports, map);
      return null;
    }
    return List<dynamic>.from(items);
  }

  static Future<void> cacheReportsByFilter(
    String filter,
    List<dynamic> items,
  ) async {
    final map = await _readJsonMap(_cacheFilterReports);
    map[filter] = {
      'saved_at': DateTime.now().millisecondsSinceEpoch,
      'items': items,
    };
    await _writeJsonMap(_cacheFilterReports, map);
  }

  /// Home stat lists: [filter] is `nearby`, `in_progress`, or `resolved`.
  static Future<List<dynamic>?> getReportsByFilter(String filter) async {
    final path = switch (filter) {
      'nearby' => '/reports/nearme',
      'in_progress' => '/reports/in_progress',
      'resolved' => '/reports/resolved',
      _ => null,
    };
    if (path == null) return null;

    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 8)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheReportsByFilter(filter, list);
        return list;
      }
      print('getReportsByFilter ($path): ${response.statusCode}');
    } catch (e) {
      print('Error fetching $path: $e');
    }
    return null;
  }

  /// Returns null if any stats request fails (keep cached counts).
  static Future<Map<String, int>?> getReportStats() async {
    final counts = await Future.wait([
      _countReports('/reports/nearme'),
      _countReports('/reports/in_progress'),
      _countReports('/reports/resolved'),
    ]);

    if (counts.any((c) => c == null)) return null;

    final stats = {
      'nearby': counts[0]!,
      'in_progress': counts[1]!,
      'resolved': counts[2]!,
    };
    await cacheReportStats(stats);
    return stats;
  }
  

  static Future<List<dynamic>> getDraftReports(int userid) async {
    final url = Uri.parse('$baseUrl/reports/user/$userid/drafts');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 5)),
      );
      if (response == null) return [];
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheDraftReports(userid, list);
        return list;
      }
    } catch (e) {
      print('Error fetching draft reports: $e');
    }
    return [];
  }
 

  static Future<List<dynamic>> getSubmittedReports(int userid) async {
    final url = Uri.parse('$baseUrl/reports/user/$userid/submitted');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 5)),
      );
      if (response == null) return [];
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheSubmittedReports(userid, list);
        return list;
      }
    } catch (e) {
      print('Error fetching submitted reports: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getTopUsers(int userId) async {
    final url = Uri.parse('$baseUrl/users/top/$userId');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 5)),
      );
      if (response == null) return [];
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheTopUsers(userId, list);
        return list;
      }
    } catch (e) {
      print('Error fetching top users: $e');
    }
    return [];
  }

  /// Calls POST /reports/analyze-voice → title, description, category, plus
  /// category fields and a spoken place. [rewrite] false skips the paid
  /// cleanup when only the emergency / detail checks are needed.
  static Future<Map<String, dynamic>> analyzeVoiceReport(
    String description, {
    bool rewrite = true,
  }) async {
    final url = Uri.parse('$baseUrl/reports/analyze-voice');
    final response = await _authorized(
      () => http
          .post(
            url,
            headers: _headers,
            body: jsonEncode({'description': description, 'rewrite': rewrite}),
          )
          .timeout(const Duration(seconds: 60)),
    );
    if (response == null) {
      throw Exception('Session expired. Please sign in again.');
    }

    if (response.statusCode != 200) {
      String detail = 'AI analysis failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = (data['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      throw Exception('AI returned an empty title.');
    }

    final polished = (data['description'] as String?)?.trim().isNotEmpty == true
        ? (data['description'] as String).trim()
        : (data['summary'] as String?)?.trim() ?? '';

    return {
      'title': title,
      'description': polished,
      'severity': (data['severity'] as String?)?.toLowerCase() ?? 'medium',
      'category': (data['category'] as String?)?.trim().isNotEmpty == true
          ? data['category'] as String
          : 'Other',
      'rationale': (data['rationale'] as String?)?.trim() ?? '',
      'emergency': data['emergency'] == true,
      'needsDetail': data['needs_detail'] == true,
      'needsDetailReasons': _stringList(data['needs_detail_reasons']),
      'fields': data['fields'] is Map
          ? Map<String, String?>.from(
              (data['fields'] as Map).map(
                (k, v) => MapEntry(k.toString(), v?.toString()),
              ),
            )
          : <String, String?>{},
      'missingFields': _stringList(data['missing_fields']),
      'mentionedLocation': (data['mentioned_location'] as String?)?.trim(),
    };
  }

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((e) => e.toString()).toList() : <String>[];

  static Future<String> generateAITitle(String description) async {
    final result = await analyzeVoiceReport(description);
    return result['title'] as String;
  }

  static Future<Map<String, dynamic>?> getReport(int id) async {
    final url = Uri.parse('$baseUrl/reports/$id');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 8)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      print('getReport: ${response.statusCode}');
    } catch (e) {
      print('getReport Error: $e');
    }
    return null;
  }

  static Future<List<dynamic>?> getReportUpdates(int reportId) async {
    final url = Uri.parse('$baseUrl/reports/$reportId/updates?amount=50');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers).timeout(const Duration(seconds: 8)),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      if (response.statusCode == 404) return [];
      print('getReportUpdates: ${response.statusCode}');
    } catch (e) {
      print('getReportUpdates Error: $e');
    }
    return null;
  }

  /// Status-change feed for the logged-in user (Updates tab).
  static Future<List<dynamic>?> getUpdates({int amount = 50}) async {
    final url = Uri.parse('$baseUrl/updates?amount=$amount');
    try {
      final response = await _authorized(
        () => http.get(url, headers: _headers),
      );
      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      // Production may not have /updates deployed yet.
      if (response.statusCode == 404) return [];
      print('getUpdates: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('getUpdates Error: $e');
      return null;
    }
  }
}
