import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String code;
  ApiException(this.code);

  String get message {
    switch (code) {
      case 'bad_credentials':
        return 'Неверный логин или пароль';
      case 'blocked':
        return 'Учётная запись заблокирована';
      case 'bad_code':
        return 'Неверный код 2FA';
      case 'expired':
        return 'Сессия истекла, войдите заново';
      case 'unauthorized':
        return 'Требуется вход';
      default:
        return 'Ошибка: $code';
    }
  }

  @override
  String toString() => message;
}

class ApiClient {
  static const String base = 'https://chzog.iniproject.ru';
  final _storage = const FlutterSecureStorage();
  String? _token;

  Future<String?> token() async => _token ??= await _storage.read(key: 'token');

  Future<void> _setToken(String? value) async {
    _token = value;
    if (value == null) {
      await _storage.delete(key: 'token');
    } else {
      await _storage.write(key: 'token', value: value);
    }
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(Uri.parse('$base$path'), headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw ApiException((data['error'] ?? 'error').toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String login, String password) async {
    final data = await _post('/api/auth/login',
        {'login': login, 'password': password, 'device': 'android'});
    if (data['need_2fa'] == false) {
      await _setToken(data['token'] as String);
    }
    return data;
  }

  Future<Map<String, dynamic>> login2fa(String pending, String code) async {
    final data = await _post('/api/auth/2fa', {'token': pending, 'code': code});
    await _setToken(data['token'] as String);
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    await token();
    final resp = await http
        .get(Uri.parse('$base/api/me'), headers: _headers())
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw ApiException((data['error'] ?? 'unauthorized').toString());
    }
    return data['user'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await token();
    try {
      await http.post(Uri.parse('$base/api/auth/logout'), headers: _headers());
    } catch (_) {}
    await _setToken(null);
  }

  Future<dynamic> _get(String path) async {
    await token();
    final resp = await http
        .get(Uri.parse('$base$path'), headers: _headers())
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(resp.body);
    if (resp.statusCode != 200) {
      throw ApiException(((data is Map ? data['error'] : 'error') ?? 'error').toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    await token();
    final resp = await http
        .post(Uri.parse('$base$path'), headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw ApiException((data['error'] ?? 'error').toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> home() async => (await _get('/api/home')) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> documents() async =>
      ((await _get('/api/documents'))['items'] as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> document(int id) async =>
      (await _get('/api/documents/$id'))['document'] as Map<String, dynamic>;

  Future<void> sign(int docId, int signId, String status) =>
      _postJson('/api/documents/$docId/sign', {'sign_id': signId, 'status': status});

  Future<List<Map<String, dynamic>>> locations() async =>
      ((await _get('/api/locations'))['items'] as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> location(int id) async =>
      (await _get('/api/locations/$id'))['location'] as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> shifts() async =>
      ((await _get('/api/shifts'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> shiftStatus(int id, String status) => _postJson('/api/shifts/$id/status', {'status': status});

  Future<void> shiftSwap(int id, {int? toMemberId}) =>
      _postJson('/api/shifts/$id/swap', {if (toMemberId != null) 'to_member_id': toMemberId});

  Future<void> shiftStart(int id) => _postJson('/api/shifts/$id/start', {});

  Future<List<Map<String, dynamic>>> colleagues() async =>
      ((await _get('/api/colleagues'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> shiftFinish(int id, {String report = '', String? photoPath}) async {
    await token();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/shifts/$id/finish'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.fields['report'] = report;
    if (photoPath != null) req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final resp = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
    if (resp.statusCode >= 400) {
      final d = resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body) as Map<String, dynamic>;
      throw ApiException((d['error'] ?? 'error').toString());
    }
  }

  Future<List<Map<String, dynamic>>> passes() async =>
      ((await _get('/api/passes'))['items'] as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> passState() async => (await _get('/api/passes/state')) as Map<String, dynamic>;

  Future<void> createRequest({required String kind, required String title, String body = ''}) =>
      _postJson('/api/request', {'kind': kind, 'title': title, 'body': body});

  Future<List<Map<String, dynamic>>> myRequests() async =>
      ((await _get('/api/requests'))['items'] as List).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> mRequests({String status = ''}) async =>
      ((await _get('/api/manage/requests?status=$status'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> mRequestDecide(int id, String status, {String note = ''}) =>
      _postJson('/api/manage/requests/decide', {'id': id, 'status': status, 'note': note});

  Future<String> checkin(String location, {double? lat, double? lng, double? accuracy}) async {
    final data = await _postJson('/api/checkin', {
      'location': location,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
    });
    return (data['direction'] ?? '') as String;
  }

  Future<String> checkinQr(String qr, {double? lat, double? lng, double? accuracy}) async {
    final data = await _postJson('/api/checkin', {
      'qr': qr,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
    });
    return (data['direction'] ?? '') as String;
  }

  Future<List<Map<String, dynamic>>> news() async =>
      ((await _get('/api/news'))['items'] as List).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> notifications() async =>
      ((await _get('/api/notifications'))['items'] as List).cast<Map<String, dynamic>>();

  Future<int> reportIncident({
    required String title,
    String details = '',
    String kind = 'incident',
    String severity = 'low',
    int? locationId,
    double? lat,
    double? lng,
    String? photoPath,
  }) async {
    await token();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/incidents'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.fields['title'] = title;
    req.fields['details'] = details;
    req.fields['kind'] = kind;
    req.fields['severity'] = severity;
    if (locationId != null) req.fields['location_id'] = '$locationId';
    if (lat != null) req.fields['lat'] = '$lat';
    if (lng != null) req.fields['lng'] = '$lng';
    if (photoPath != null) req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final resp = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)));
    final data = resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) throw ApiException((data['error'] ?? 'error').toString());
    return (data['id'] ?? 0) as int;
  }

  Future<void> notificationsRead() => _postJson('/api/notifications/read', {});

  Future<void> notificationRead(int id) => _postJson('/api/notifications/$id/read', {});

  Future<Map<String, dynamic>> application(int id) async =>
      (await _get('/api/applications/$id'))['application'] as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> applications() async =>
      ((await _get('/api/applications'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> decideApplication(int id, String status) =>
      _postJson('/api/applications/$id/decide', {'status': status});

  // ---------- Руководителю (/api/manage/*) ----------

  Future<List<Map<String, dynamic>>> mShifts({String day = ''}) async =>
      ((await _get('/api/manage/shifts?day=${Uri.encodeQueryComponent(day)}'))['items'] as List)
          .cast<Map<String, dynamic>>();

  Future<void> mShiftSave(Map<String, dynamic> body) => _postJson('/api/manage/shifts/save', body);

  Future<void> mShiftStatus(int id, String status) => _postJson('/api/manage/shifts/status', {'id': id, 'status': status});

  Future<List<Map<String, dynamic>>> mPasses() async =>
      ((await _get('/api/manage/passes'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> mPassSave(Map<String, dynamic> body) => _postJson('/api/manage/passes/save', body);

  Future<List<Map<String, dynamic>>> mIncidents({String status = ''}) async =>
      ((await _get('/api/manage/incidents?status=$status'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> mIncidentClose(int id) => _postJson('/api/manage/incidents/close', {'id': id});

  Future<List<Map<String, dynamic>>> mMembers({String q = ''}) async =>
      ((await _get('/api/manage/members?q=${Uri.encodeQueryComponent(q)}'))['items'] as List)
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> mDocuments({String q = ''}) async =>
      ((await _get('/api/manage/documents?q=${Uri.encodeQueryComponent(q)}'))['items'] as List)
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> mLocations() async =>
      ((await _get('/api/manage/locations'))['items'] as List).cast<Map<String, dynamic>>();
}
