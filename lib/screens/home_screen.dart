import 'package:flutter/material.dart';

import '../api.dart';
import '../queue.dart';
import '../theme.dart';
import '../ui.dart';
import '../updater.dart';
import 'manage.dart';
import 'profile.dart';
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
  int _pending = 0;
  String _ver = '';

  @override
  void initState() {
    super.initState();
    s = widget.summary;
    _loadPending();
    appVersion().then((v) { if (mounted) setState(() => _ver = v); });
  }

  Future<void> _loadPending() async {
    final n = await OfflineQueue.count();
    if (mounted) setState(() => _pending = n);
  }

  Future<void> _sync() async {
    final sent = await OfflineQueue.flush(widget.api);
    await _loadPending();
    if (mounted) {
      toast(context, sent > 0 ? 'Отправлено: $sent' : 'Нет сети');
    }
  }

  Future<void> _refresh() async {
    try {
      final d = await widget.api.home();
      if (mounted) setState(() => s = d);
      await OfflineQueue.flush(widget.api);
    } catch (_) {}
    await _loadPending();
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

    return Scaffold(
      appBar: AppBar(
        title: Text('ЧЗОГ · КАБИНЕТ${_ver.isEmpty ? '' : ' · v$_ver'}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(tooltip: 'Обновить', onPressed: _refresh, icon: const Icon(Icons.refresh, color: kSoft)),
          IconButton(tooltip: 'Выйти', onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: kSoft)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: kAccent,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // профиль
            card(
              Row(children: [
                Text('${user['avatar'] ?? '🧭'}', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${user['login'] ?? ''}', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('${user['role'] ?? ''}${('${user['member'] ?? ''}').isEmpty ? '' : ' · ${user['member']}'}', style: kSub),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: kMute),
              ]),
              onTap: () => _open(ProfileScreen(api: widget.api)),
            ),
            const SizedBox(height: 8),
            // показатели
            Row(children: [
              _stat(onSite ? 'НА ОБЪЕКТЕ' : 'НЕ НА ОБЪЕКТЕ', onSite ? 'да' : '—', Icons.place_outlined,
                  () => _open(PassesScreen(api: widget.api)), accent: onSite ? kAccent2 : kSoft),
              const SizedBox(width: 8),
              _stat('НА ПОДПИСЬ', '$pending', Icons.draw_outlined,
                  () => _open(DocumentsScreen(api: widget.api)), accent: pending > 0 ? kAccent : kSoft),
              const SizedBox(width: 8),
              _stat('УВЕДОМЛ.', '$unread', Icons.notifications_none,
                  () => _open(NotificationsScreen(api: widget.api)), accent: unread > 0 ? kAccent : kSoft),
            ]),
            if (nextShift != null) ...[
              const SizedBox(height: 12),
              card(
                Row(children: [
                  const Icon(Icons.schedule, color: kAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('БЛИЖАЙШАЯ СМЕНА', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 1)),
                      Text('${nextShift['day']} · ${nextShift['shift'] == 'night' ? 'ночная' : 'дневная'} · начало ${nextShift['start']}',
                          style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: kMute),
                ]),
                onTap: () => _open(ShiftsScreen(api: widget.api)),
              ),
            ],
            if (_pending > 0) ...[
              const SizedBox(height: 12),
              card(
                Row(children: [
                  const Icon(Icons.cloud_off, color: kAccent2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('$_pending действий ждут сети', style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
                  TextButton(onPressed: _sync, child: const Text('ОТПРАВИТЬ', style: TextStyle(color: kAccent2, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            groupHeader('РАЗДЕЛЫ'),
            _tiles(perms),
            const SizedBox(height: 16),
            creditFooter(),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, VoidCallback onTap, {Color accent = kAccent}) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
            child: Column(children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(color: accent, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 9, letterSpacing: 0.5)),
            ]),
          ),
        ),
      );

  Widget _tiles(List<String> perms) {
    final groups = <List<Object>>[
      ['ОСНОВНОЕ', <Widget>[
        _tile('Приказы', 'документы и подписи', Icons.description_outlined, () => _open(DocumentsScreen(api: widget.api))),
        _tile('Объекты', 'здания, посты, зоны', Icons.location_city_outlined, () => _open(LocationsScreen(api: widget.api))),
        _tile('Смены', 'моё расписание', Icons.schedule, () => _open(ShiftsScreen(api: widget.api))),
        _tile('Проходы', 'вход / выход', Icons.login, () => _open(PassesScreen(api: widget.api))),
        _tile('Новости', 'лента и объявления', Icons.newspaper_outlined, () => _open(NewsScreen(api: widget.api))),
        _tile('Уведомления', 'что нового', Icons.notifications_none, () => _open(NotificationsScreen(api: widget.api))),
      ]],
      ['ДЕЙСТВИЯ', <Widget>[
        _tile('Инцидент', 'рапорт · фото · GPS', Icons.report_problem_outlined, () => _open(ReportScreen(api: widget.api))),
        _tile('Заявка', 'баг · идея · доступ', Icons.assignment_outlined, () => _open(RequestScreen(api: widget.api))),
      ]],
      ['РУКОВОДИТЕЛЮ', <Widget>[
        if (perms.contains('manage_security')) _tile('Все смены', 'табель', Icons.event_note_outlined, () => _open(ManageShiftsScreen(api: widget.api))),
        if (perms.contains('manage_security')) _tile('Журнал проходов', 'кто где', Icons.list_alt_outlined, () => _open(ManagePassesScreen(api: widget.api))),
        if (perms.contains('manage_security')) _tile('Инциденты', 'ССБ, нарушения', Icons.warning_amber_outlined, () => _open(ManageIncidentsScreen(api: widget.api))),
        if (perms.contains('manage_services')) _tile('Заявки', 'внутренние', Icons.assignment_outlined, () => _open(ManageRequestsScreen(api: widget.api))),
        if (perms.contains('manage_members')) _tile('Личные дела', 'участники', Icons.folder_shared_outlined, () => _open(ManageMembersScreen(api: widget.api))),
        if (perms.contains('manage_members')) _tile('Анкеты', 'заявки на службу', Icons.how_to_reg_outlined, () => _open(ApplicationsScreen(api: widget.api))),
      ]],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.where((g) => (g[1] as List).isNotEmpty).map((g) {
        final tiles = g[1] as List<Widget>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(children: [
                Text('${g[0]}', style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: kLine)),
              ]),
            ),
            ...tiles.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: t)),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _tile(String title, String sub, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, color: kAccent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: kMute, size: 20),
          ]),
        ),
      );
}
