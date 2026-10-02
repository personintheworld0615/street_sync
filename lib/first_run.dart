import 'package:shared_preferences/shared_preferences.dart';

/// First-open flags. A missing tour flag means an existing account, so
/// upgrades do not replay the guide.
class FirstRun {
  static const tourSeenKey = 'street_sync_ai_tour_seen_v1';
  static const permissionsAskedKey = 'street_sync_permissions_asked_v1';
  static const signedInBeforeKey = 'street_sync_has_signed_in';

  static Future<void> markTourPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tourSeenKey, false);
  }

  static Future<void> markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tourSeenKey, true);
  }

  static Future<bool> isTourPending() async {
    final prefs = await SharedPreferences.getInstance();
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
