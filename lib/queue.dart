import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

bool isOffline(Object e) => e is! ApiException;

class PendingAction {
  final String kind;
  final Map<String, dynamic> data;

  PendingAction(this.kind, this.data);

  Map<String, dynamic> toJson() => {'kind': kind, 'data': data};

  static PendingAction fromJson(Map<String, dynamic> j) =>
      PendingAction(j['kind'] as String, (j['data'] as Map).cast<String, dynamic>());
}

class OfflineQueue {
  static const _key = 'pending_actions';

  static Future<List<PendingAction>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => PendingAction.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<PendingAction> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<int> count() async => (await load()).length;

  static Future<void> add(PendingAction a) async {
    final items = await load();
    items.add(a);
    await _save(items);
  }

  static Future<String?> persistPhoto(String path) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dst = '${dir.path}/pending_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).copy(dst);
      return dst;
    } catch (_) {
      return path;
    }
  }

  static Future<int> flush(ApiClient api) async {
    final items = await load();
    if (items.isEmpty) return 0;
    final left = <PendingAction>[];
    var sent = 0;
    for (final a in items) {
      try {
        await _send(api, a);
        sent++;
      } on ApiException catch (e) {
        if (e.code == 'unauthorized' || e.code == 'expired') {
          left.add(a);
        }
      } catch (_) {
        left.add(a);
      }
    }
    await _save(left);
    return sent;
  }

  static Future<void> _send(ApiClient api, PendingAction a) async {
    final d = a.data;
    switch (a.kind) {
      case 'checkin':
        await api.checkinQr((d['qr'] ?? '') as String, lat: _d(d['lat']), lng: _d(d['lng']), accuracy: _d(d['accuracy']));
        break;
      case 'checkin_loc':
        await api.checkin((d['location'] ?? '') as String, lat: _d(d['lat']), lng: _d(d['lng']), accuracy: _d(d['accuracy']));
        break;
      case 'shift_status':
        await api.shiftStatus(d['id'] as int, d['status'] as String);
        break;
      case 'incident':
        await api.reportIncident(
          title: d['title'] as String,
          details: (d['details'] ?? '') as String,
          kind: (d['kind'] ?? 'incident') as String,
          severity: (d['severity'] ?? 'low') as String,
          locationId: d['location_id'] as int?,
          lat: _d(d['lat']),
          lng: _d(d['lng']),
          photoPath: d['photo'] as String?,
        );
        break;
    }
  }

  static double? _d(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  static const _locKey = 'cached_locations';

  static Future<void> cacheLocations(List<Map<String, dynamic>> items) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_locKey, jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> cachedLocations() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_locKey);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }
}
