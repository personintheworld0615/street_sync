import 'package:shared_preferences/shared_preferences.dart';

/// First-open flags. Tour progress is stored per user id when known, with a
/// legacy device-wide key as fallback. A missing tour flag means an existing
/// account, so upgrades do not replay the guide.
class FirstRun {
  static const tourSeenKey = 'street_sync_ai_tour_seen_v1';
  static const permissionsAskedKey = 'street_sync_permissions_asked_v1';
  static const signedInBeforeKey = 'street_sync_has_signed_in';

  static String _tourKey(int? userId) =>
      userId == null ? tourSeenKey : '${tourSeenKey}_u$userId';

  static Future<void> markTourPending({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourKey(userId), false);
    if (userId != null) await prefs.setBool(tourSeenKey, false);
  }

  static Future<void> markTourSeen({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourKey(userId), true);
    if (userId != null) await prefs.setBool(tourSeenKey, true);
  }

  static Future<bool> isTourPending({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getBool(_tourKey(userId));
    if (scoped != null) return scoped == false;
    return prefs.getBool(tourSeenKey) == false;
  }

  static Future<void> markPermissionsAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(permissionsAskedKey, true);
  }

  static Future<bool> permissionsWereAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(permissionsAskedKey) ?? false;
  }

  static Future<void> markSignedInBefore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(signedInBeforeKey, true);
  }

  static Future<bool> hasSignedInBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(signedInBeforeKey) ?? false;
  }
}
