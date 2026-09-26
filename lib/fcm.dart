import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

final _local = FlutterLocalNotificationsPlugin();

final StreamController<Map<String, dynamic>> chatEvents = StreamController.broadcast();
final ValueNotifier<int> currentChatRoom = ValueNotifier(0);

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

void _handleChat(Map<String, dynamic> data, {bool forceNotify = false}) {
  final room = int.tryParse(data['room'] ?? '') ?? 0;
  if (!forceNotify && room != 0 && room == currentChatRoom.value) {
    chatEvents.add(data);
    return;
  }
  chatEvents.add(data);
  _show(data['room_name']?.isNotEmpty == true ? data['room_name']! : 'ЧЗОГ', data['body'] ?? '');
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
      final data = m.data;
      if (data['type'] == 'chat') {
        _handleChat(data);
        return;
      }
      _show(m.notification?.title ?? 'ЧЗОГ', m.notification?.body ?? '');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data['type'] == 'chat') chatEvents.add(m.data);
    });
    final initial = await messaging.getInitialMessage();
    if (initial != null && initial.data['type'] == 'chat') chatEvents.add(initial.data);
  } catch (_) {}
}
