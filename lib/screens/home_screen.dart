import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'sections.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> summary;
  final Future<void> Function() onLogout;

  const HomeScreen({super.key, required this.api, required this.summary, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> s;

  @override
  void initState() {
    super.initState();
    s = widget.summary;
  }

  Future<void> _refresh() async {
    try {
      final d = await widget.api.home();
      if (mounted) setState(() => s = d);
    } catch (_) {}
  }

  void _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = (s['user'] as Map).cast<String, dynamic>();
    final perms = (user['permissions'] as List?)?.cast<String>() ?? [];
    final unread = (s['unread'] ?? 0) as int;
    final pending = (s['pending_signatures'] ?? 0) as int;
    final onSite = s['on_site'] == true;
    final nextShift = s['next_shift'] as Map?;

    final tiles = <_Tile>[
      _Tile('ПРИКАЗЫ', 'документы и подписи', pending > 0 ? '$pending' : null, () => _open(DocumentsScreen(api: widget.api))),
      _Tile('ОБЪЕКТЫ', 'здания, посты, зоны', null, () => _open(LocationsScreen(api: widget.api))),
      _Tile('СМЕНЫ', 'моё расписание', null, () => _open(ShiftsScreen(api: widget.api))),
      _Tile('ПРОХОДЫ', 'вход / выход', null, () => _open(PassesScreen(api: widget.api))),
      _Tile('НОВОСТИ', 'лента и объявления', null, () => _open(NewsScreen(api: widget.api))),
      _Tile('УВЕДОМЛЕНИЯ', 'что нового', unread > 0 ? '$unread' : null, () => _open(NotificationsScreen(api: widget.api))),
      if (perms.contains('manage_members'))
        _Tile('АНКЕТЫ', 'заявки на службу', null, () => _open(ApplicationsScreen(api: widget.api))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ЧЗОГ · КАБИНЕТ',
            style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(tooltip: 'Обновить', onPressed: _refresh, icon: const Icon(Icons.refresh, color: kSoft)),
          IconButton(tooltip: 'Выйти', onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: kSoft)),
        ],
      ),
      body: RefreshIndicator(
        color: kAccent,
        backgroundColor: kPanel,
        onRefresh: _refresh,
        child: ListView(
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
                  _kv('Позывной', (user['callsign'] ?? '—').toString()),
                  _kv('Подразделение', (user['department'] ?? '—').toString()),
                  _kv('Допуск', (user['clearance'] ?? '—').toString()),
                  _kv('Пояс', (user['timezone'] ?? '—').toString()),
                  _kv('2FA', user['totp'] == true ? 'включена' : 'выключена'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _stat(onSite ? 'НА ОБЪЕКТЕ' : 'НЕ НА ОБЪЕКТЕ', onSite ? kAccent2 : kSoft,
                  (s['on_site_location'] ?? '').toString())),
              const SizedBox(width: 8),
              Expanded(child: _stat('НА ПОДПИСЬ', pending > 0 ? kAccent : kSoft, '$pending')),
              const SizedBox(width: 8),
              Expanded(child: _stat('УВЕДОМЛ.', unread > 0 ? kAccent : kSoft, '$unread')),
            ]),
            if (nextShift != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: kPanel, border: Border.all(color: kAccent)),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.schedule, color: kAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('БЛИЖАЙШАЯ СМЕНА', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 1)),
                      Text('${nextShift['day']} · ${nextShift['shift'] == 'night' ? 'ночная' : 'дневная'} · начало ${nextShift['start']}',
                          style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: tiles.map((t) => _tile(t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 120, child: Text(k.toUpperCase(), style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11))),
          Expanded(child: Text(v, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
        ]),
      );

  Widget _stat(String label, Color color, String value) => Container(
        decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(children: [
          Text(value.isEmpty ? '—' : value,
              style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 9, letterSpacing: 0.5)),
        ]),
      );

  Widget _tile(_Tile t) => InkWell(
        onTap: t.onTap,
        child: Container(
          decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
          padding: const EdgeInsets.all(14),
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.title, style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(t.sub, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11)),
              ],
            ),
            if (t.badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: kAccent),
                  child: Text(t.badge!, style: const TextStyle(color: kBg, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      );
}

class _Tile {
  final String title;
  final String sub;
  final String? badge;
  final VoidCallback onTap;
  _Tile(this.title, this.sub, this.badge, this.onTap);
}
