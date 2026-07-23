import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Automatically switch base URL depending on the platform
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000'; // iOS and Web
  }

  static Future<bool> submitReport({
    required String description,
    required String category,
    required String location,
    required String severity,
    required bool isDraft,
    double latitude = 0.0,
    double longitude = 0.0,
    int userId = 1,
  }) async {
    final url = Uri.parse('$baseUrl/reports');

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
          'user_id': userId,
          'isDraft': isDraft,
        }),
      ).timeout(const Duration(seconds: 5)); // Add timeout

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

  static Future<Map<String, dynamic>?> getUserStats(int userId) async {
    // There isn't a direct "stats" endpoint, but we can get user info
    // From the backend routes, get_user_submitted_reports or similar
    // Actually, get_top_users returns UsersDetailed which has total_reports.
    // Or we can add a specific endpoint if needed.
    // For now, let's use the top users list to find our user or 
    // we might need a get_user endpoint. 
    // Looking at routes/reports.py, there is no get_user(user_id).
    // Let's assume we can get it or just use a placeholder for now if missing.
    // Wait, let's check if I can add a route or if one exists.
    return null;
  }
}
