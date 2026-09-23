import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  const HomeScreen({super.key, required this.api, required this.user, required this.onLogout});

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(k.toUpperCase(),
                  style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12)),
            ),
            Expanded(
              child: Text(v.isEmpty ? '—' : v,
                  style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final perms = (user['permissions'] as List?)?.cast<String>() ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ЧЗОГ · КАБИНЕТ',
            style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: kSoft),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine2)),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['login'] ?? '',
                    style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _row('Должность', (user['role'] ?? '').toString()),
                _row('Дело', (user['member'] ?? '').toString()),
                _row('Подразделение', (user['department'] ?? '').toString()),
                _row('Допуск', (user['clearance'] ?? '').toString()),
                _row('Часовой пояс', (user['timezone'] ?? '').toString()),
                _row('2FA', user['totp'] == true ? 'включена' : 'выключена'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ПРАВА', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: perms
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: kLine2)),
                      child: Text(p, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('разделы приложения — в разработке',
                style: TextStyle(color: kMute, fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
