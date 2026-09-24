import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';

Future<void> initFcm(ApiClient api) async {
  try {
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token != null) await api.registerDevice(token);
    messaging.onTokenRefresh.listen((t) => api.registerDevice(t));
  } catch (_) {}
}
