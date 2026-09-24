import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

final _local = FlutterLocalNotificationsPlugin();

Future<void> _initLocal() async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

void _show(String title, String body) {
  _local.show(
    id: 0,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'chzog_channel',
        'Уведомления ЧЗОГ',
        channelDescription: 'Уведомления приложения ЧЗОГ',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

Future<void> initFcm(ApiClient api) async {
  try {
    await Firebase.initializeApp();
    await _initLocal();
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token != null) await api.registerDevice(token);
    messaging.onTokenRefresh.listen((t) => api.registerDevice(t));
    FirebaseMessaging.onMessage.listen((m) {
      _show(m.notification?.title ?? 'ЧЗОГ', m.notification?.body ?? '');
    });
  } catch (_) {}
}
