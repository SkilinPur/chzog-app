import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'sections.dart';

class HomeScreen extends StatelessWidget {
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  const HomeScreen({super.key, required this.api, required this.user, required this.onLogout});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final perms = (user['permissions'] as List?)?.cast<String>() ?? [];
    final tiles = <_Tile>[
      _Tile('ПРИКАЗЫ', 'документы и подписи', () => _open(context, DocumentsScreen(api: api))),
      _Tile('ОБЪЕКТЫ', 'здания, посты, зоны', () => _open(context, LocationsScreen(api: api))),
      _Tile('СМЕНЫ', 'моё расписание', () => _open(context, ShiftsScreen(api: api))),
      _Tile('ПРОХОДЫ', 'вход / выход', () => _open(context, PassesScreen(api: api))),
      _Tile('НОВОСТИ', 'лента и объявления', () => _open(context, NewsScreen(api: api))),
      _Tile('УВЕДОМЛЕНИЯ', 'что нового', () => _open(context, NotificationsScreen(api: api))),
      if (perms.contains('manage_members'))
        _Tile('АНКЕТЫ', 'заявки на службу', () => _open(context, ApplicationsScreen(api: api))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ЧЗОГ · КАБИНЕТ',
            style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(tooltip: 'Выйти', onPressed: onLogout, icon: const Icon(Icons.logout, color: kSoft)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine2)),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['login'] ?? '',
                    style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _kv('Должность', (user['role'] ?? '—').toString()),
                _kv('Дело', (user['member'] ?? '—').toString()),
                _kv('Допуск', (user['clearance'] ?? '—').toString()),
                _kv('Пояс', (user['timezone'] ?? '—').toString()),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: tiles.map((t) => _tile(t)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k.toUpperCase(), style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11))),
          Expanded(child: Text(v, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
        ]),
      );

  Widget _tile(_Tile t) => InkWell(
        onTap: t.onTap,
        child: Container(
          decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t.title, style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(t.sub, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11)),
            ],
          ),
        ),
      );
}

class _Tile {
  final String title;
  final String sub;
  final VoidCallback onTap;
  _Tile(this.title, this.sub, this.onTap);
}
