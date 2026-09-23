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

  Future<List<Map<String, dynamic>>> passes() async =>
      ((await _get('/api/passes'))['items'] as List).cast<Map<String, dynamic>>();

  Future<String> checkin(String location) async =>
      ((await _postJson('/api/checkin', {'location': location}))['direction'] ?? '') as String;

  Future<List<Map<String, dynamic>>> news() async =>
      ((await _get('/api/news'))['items'] as List).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> notifications() async =>
      ((await _get('/api/notifications'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> notificationsRead() => _postJson('/api/notifications/read', {});

  Future<List<Map<String, dynamic>>> applications() async =>
      ((await _get('/api/applications'))['items'] as List).cast<Map<String, dynamic>>();

  Future<void> decideApplication(int id, String status) =>
      _postJson('/api/applications/$id/decide', {'status': status});
}
