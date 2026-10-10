import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:street_sync/api_service.dart';

/// Polls the signed-in user's updates.
/// An update is unread until its card has been on the Updates screen.
class UpdateAlerts {
  UpdateAlerts._();

  static final unseen = ValueNotifier<int>(0);

  /// Bumped so the Updates list can reload. Home, Map, and an open report stay put.
  static final refreshTick = ValueNotifier<int>(0);

  /// Bumped when a newer unread update arrives and the user should be told.
  static final notice = ValueNotifier<int>(0);

  static const _readKey = 'updates_read_ids';
  static const _legacySeenKey = 'updates_last_seen_id';
  static final Set<int> _readIds = {};
  static List<dynamic> _latest = [];
  static String _signature = '';
  static Timer? _timer;
  static bool _polling = false;
  static bool _loaded = false;
  static int? _loadedForUserId;

  static String _scopedReadKey(int? userId) =>
      userId == null ? _readKey : '${_readKey}_u$userId';

  static bool isRead(int id) => _readIds.contains(id);

  static void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 40), (_) => poll());
    poll();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Clear in-memory state on logout so the next account starts clean.
  static void reset() {
    stop();
    _readIds.clear();
    _latest = [];
    _signature = '';
    _loaded = false;
    _loadedForUserId = null;
    unseen.value = 0;
  }

  static int idOf(dynamic item) {
    if (item is! Map) return 0;
    final id = item['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
  }

  static Future<void> _ensureLoaded() async {
    final userId = ApiService.userId;
    if (_loaded && _loadedForUserId == userId) return;
    _readIds.clear();
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedReadKey(userId);
    var stored = prefs.getStringList(key) ?? const [];
    // Migrate legacy device-wide key into the scoped one once.
    if (stored.isEmpty && userId != null) {
      stored = prefs.getStringList(_readKey) ?? const [];
      if (stored.isNotEmpty) {
        await prefs.setStringList(key, stored);
        await prefs.remove(_readKey);
      }
    }
    for (final raw in stored) {
      final id = int.tryParse(raw);
      if (id != null) _readIds.add(id);
    }
    _loaded = true;
    _loadedForUserId = userId;
  }

  static Future<void> markRead(Iterable<int> ids) async {
    await _ensureLoaded();
    final fresh = ids.where((id) => id > 0 && _readIds.add(id)).toList();
    if (fresh.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedReadKey(ApiService.userId),
      _readIds.map((id) => id.toString()).toList(),
    );
    _publish(notify: false);
  }

  static void _publish({required bool notify}) {
    final count = _latest.where((item) => !_readIds.contains(idOf(item))).length;
    final isNew = notify && count > unseen.value;
    unseen.value = count;
    if (isNew) notice.value++;
  }

  static Future<void> _migrateLegacySeen() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getInt(_legacySeenKey);
    if (legacy == null) return;
    for (final item in _latest) {
      final id = idOf(item);
      if (id > 0 && id <= legacy) _readIds.add(id);
    }
    await prefs.setStringList(
      _scopedReadKey(ApiService.userId),
      _readIds.map((id) => id.toString()).toList(),
    );
    await prefs.remove(_legacySeenKey);
  }

  static Future<void> poll() async {
    if (_polling || ApiService.userId == null) return;
    _polling = true;
    try {
      await _ensureLoaded();
      final raw = await ApiService.getUpdates();
      if (raw == null) return;
      _latest = raw;
      await _migrateLegacySeen();
      final nextSignature = _latest.map(idOf).join(',');
      if (nextSignature != _signature) {
        _signature = nextSignature;
        refreshTick.value++;
      }
      _publish(notify: true);
    } finally {
      _polling = false;
    }
  }
}
