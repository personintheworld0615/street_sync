import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _sessionKey = 'current_user';
  static const _cacheRecentReports = 'cache_recent_reports';
  static const _cacheReportStats = 'cache_report_stats';
  static const _cacheDraftReports = 'cache_draft_reports';
  static const _cacheSubmittedReports = 'cache_submitted_reports';
  static const _cacheTopUsers = 'cache_top_users';
  static const _cacheUserScopedId = 'cache_user_scoped_id';

  static String get _devHost =>
      dotenv.maybeGet('DEV_HOST')?.trim().isNotEmpty == true
          ? dotenv.get('DEV_HOST').trim()
          : 'localhost';

  static int get _devPort =>
      int.tryParse(dotenv.maybeGet('API_PORT') ?? '') ?? 8001;

  // Automatically switch base URL depending on the platform
  static String get baseUrl {
    // If you have a CLOUD_URL in your .env, use it. 
    // Otherwise, fallback to local/emulator addresses.
    final cloudUrl = dotenv.maybeGet('CLOUD_URL');
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      return cloudUrl;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_devPort';
    }
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

  /// Full name for profile, leaderboard "you", etc.
  static String get userName {
    final last = lastName.trim();
    if (last.isEmpty) return firstName;
    return '$firstName $last';
  }

  static String? get userEmail => currentUser?['email'] as String?;

  static String? get token => currentUser?['access_token'] as String?;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return;
    try {
      currentUser = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('loadSession Error: $e');
      currentUser = null;
      await prefs.remove(_sessionKey);
    }
  }

  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentUser == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(currentUser));
    }
  }

  static Future<void> logout() async {
    currentUser = null;
    await _saveSession();
    await clearDataCache();
  }

  static Future<void> clearDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRecentReports);
    await prefs.remove(_cacheReportStats);
    await prefs.remove(_cacheDraftReports);
    await prefs.remove(_cacheSubmittedReports);
    await prefs.remove(_cacheTopUsers);
    await prefs.remove(_cacheUserScopedId);
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

  /// Returns null on success, or an error message on failure.
  static Future<String?> signup({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    try {
      final response = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'first_name': firstname,
              'last_name': lastname,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        currentUser = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession();
        return null;
      }

      return _errorFromResponse(response, fallback: 'Signup failed');
    } catch (e) {
      print('Signup Error ($url): $e');
      return 'Cannot reach API at $baseUrl. Is the server running?';
    }
  }

  /// Returns null on success, or an error message on failure.
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        currentUser = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession();
        return null;
      }

      return _errorFromResponse(response, fallback: 'Login failed');
    } catch (e) {
      print('Login Error ($url): $e');
      return 'Cannot reach API at $baseUrl. Is the server running?';
    }
  }

  static Future<String?> deleteAccount() async {
    final id = userId;
    if (id == null) {
      return 'Not logged in';
    }

    final url = Uri.parse('$baseUrl/auth/delete/$id');
    try {
      final response = await http
          .delete(url, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        await logout();
        return null;
      }

      return _errorFromResponse(response, fallback: 'Could not delete account');
    } catch (e) {
      print('Delete Account Error ($url): $e');
      return 'Cannot reach API at $baseUrl. Is the server running?';
    }
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
  }) async {
    final effectiveUserId = userId ?? ApiService.userId;
    if (effectiveUserId == null) {
      print('submitReport: no logged-in user');
      return false;
    }

    final url = Uri.parse('$baseUrl/reports');
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        await File(imagePath).exists();

    try {
      final request = http.MultipartRequest('POST', url);
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
      }

      final streamed = await request.send().timeout(
            Duration(seconds: hasImage ? 60 : 15),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        await logout();
        return false;
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('submitReport failed: ${response.statusCode} ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Connection Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getRecentReports({int amount = 3}) async {
    final url = Uri.parse('$baseUrl/reports/recent?amount=$amount');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        await cacheRecentReports(list);
        return list;
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
    return [];
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
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 8));
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
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
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
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) {
        await logout();
        return [];
      }
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
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) {
        await logout();
        return [];
      }
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
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) {
        await logout();
        return [];
      }
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
}
