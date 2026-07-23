import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Automatically switch base URL depending on the platform
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000'; // iOS and Web
  }

  // Store the logged-in user's info
  static Map<String, dynamic>? currentUser;

  static Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        currentUser = jsonDecode(response.body);
        return true;
      }
    } catch (e) {
      print('Signup Error: $e');
    }
    return false;
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        currentUser = jsonDecode(response.body);
        return true;
      }
    } catch (e) {
      print('Login Error: $e');
    }
    return false;
  }

  static Future<bool> submitReport({
    required String description,
    required String category,
    required String location,
    required String severity,
    required bool isDraft,
    double latitude = 0.0,
    double longitude = 0.0,
    int? userId,
  }) async {
    final url = Uri.parse('$baseUrl/reports');
    final effectiveUserId = userId ?? currentUser?['user_id'] ?? 1;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': description,
          'category': category,
          'latitude': latitude,
          'longitude': longitude,
          'location': location,
          'time': DateTime.now().toIso8601String(),
          'severity': severity.toLowerCase(),
          'user_id': effectiveUserId,
          'isDraft': isDraft,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Connection Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getRecentReports({int amount = 10}) async {
    final url = Uri.parse('$baseUrl/reports/recent?amount=$amount');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getDraftReports(int userid) async {
    final url = Uri.parse('$baseUrl/reports/user/$userid/drafts');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching draft reports: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getSubmittedReports(int userid) async {
    final url = Uri.parse('$baseUrl/reports/user/$userid/submitted');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching submitted reports: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getTopUsers(int userId) async {
    final url = Uri.parse('$baseUrl/users/top/$userId');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching top users: $e');
    }
    return [];
  }


}
