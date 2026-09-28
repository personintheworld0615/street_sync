import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:street_sync/api_service.dart';

/// Polls the signed-in user's updates and raises a badge when a newer row appears.
class UpdateAlerts {
  UpdateAlerts._();

  static final unseen = ValueNotifier<int>(0);

  /// Bumped only so the Updates list can reload. Home, Map, and an open
  /// report are left alone.
  static final refreshTick = ValueNotifier<int>(0);

  /// Bumped when a newer update arrives and the user should see a notice.
  static final notice = ValueNotifier<int>(0);

  static const _seenKey = 'updates_last_seen_id';
  static Timer? _timer;
  static bool _polling = false;

  static void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 40), (_) => poll());
    poll();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static int _idOf(dynamic item) {
    if (item is! Map) return 0;
    final id = item['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
  }

  static Future<void> poll() async {
    if (_polling || ApiService.userId == null) return;
    _polling = true;
    try {
      final raw = await ApiService.getUpdates();
      if (raw == null) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getInt(_seenKey) ?? 0;
      final count = raw.where((item) => _idOf(item) > seen).length;
      final isNew = count > unseen.value;
      unseen.value = count;
      if (isNew) notice.value++;
    } finally {
      _polling = false;
    }
  }

  static Future<void> markSeen() async {
    final raw = await ApiService.getUpdates();
    var newest = 0;
    if (raw != null) {
      for (final item in raw) {
        final id = _idOf(item);
        if (id > newest) newest = id;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenKey, newest);
    unseen.value = 0;
    refreshTick.value++;
  }
}
