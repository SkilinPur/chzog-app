import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLock {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  static Future<String?> _pinHash() => _storage.read(key: 'app_pin_hash');

  static Future<bool> isSet() async => (await _pinHash()) != null;

  static Future<String> _salt() async {
    const k = 'app_pin_salt';
    var s = await _storage.read(key: k);
    if (s == null) {
      final r = Random.secure();
      s = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: k, value: s);
    }
    return s;
  }

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final salt = await _salt();
    await _storage.write(key: 'app_pin_hash', value: _hash(salt, pin));
  }

  static Future<bool> verifyPin(String pin) async {
    final h = await _pinHash();
    if (h == null) return true;
    final salt = await _salt();
    return h == _hash(salt, pin);
  }

  static Future<void> clear() async => _storage.delete(key: 'app_pin_hash');

  static Future<bool> biometricsAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> biometric() async {
    try {
      return await _auth.authenticate(localizedReason: 'Подтвердите вход', biometricOnly: true);
    } catch (_) {
      return false;
    }
  }

  static Future<String> mode() async => (await SharedPreferences.getInstance()).getString('lock_mode') ?? 'off';

  static Future<void> setMode(String m) async => (await SharedPreferences.getInstance()).setString('lock_mode', m);

  static Future<int> timeoutMinutes() async => (await SharedPreferences.getInstance()).getInt('lock_timeout') ?? 5;

  static Future<void> setTimeoutMinutes(int m) async => (await SharedPreferences.getInstance()).setInt('lock_timeout', m);
}
