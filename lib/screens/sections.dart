import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../queue.dart';
import '../scan.dart';
import '../theme.dart';
import 'webview_screen.dart';

const _titleStyle = TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold);
const _subStyle = TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11);

Widget _scaffold(String title, Widget body) => Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2))),
      body: body,
    );

Widget _loading() => const Center(child: CircularProgressIndicator(color: kAccent));
Widget _empty(String t) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: kMute, fontFamily: 'monospace'))));
Widget _error(Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(e is ApiException ? e.message : 'Ошибка загрузки',
          textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontFamily: 'monospace')),
    ),
  );

String _localTime(String iso) {
  if (iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  } catch (_) {
    return iso.replaceFirst('T', ' ');
  }
}

Widget _card({required String title, String? sub, Widget? leading, List<Widget> extra = const [], VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle),
                  if (sub != null && sub.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: _subStyle)),
                  ...extra,
                ],
              ),
            ),
          ],
        ),
      ),
    );

// ==================== ОБЪЕКТЫ ====================

class LocationsScreen extends StatelessWidget {
  final ApiClient api;
  const LocationsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ОБЪЕКТЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: api.locations(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Объектов нет');
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items
                .map((l) => _card(
                      leading: _thumb(l['photo']),
                      title: l['name'] ?? '',
                      sub: '${l['type'] ?? ''} · ${l['status'] ?? ''}${(l['zones'] ?? '') != '' ? ' · ${l['zones']}' : ''}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LocationDetailScreen(api: api, id: l['id'] as int)),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

Widget _thumb(String? url) {
  final u = (url ?? '');
  if (u.isEmpty) {
    return Container(width: 56, height: 56, color: kPanel2, child: const Icon(Icons.apartment, color: kMute));
  }
  return ClipRRect(
    borderRadius: BorderRadius.zero,
    child: Image.network(ApiClient.base + u, width: 56, height: 56, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: kPanel2, child: const Icon(Icons.broken_image, color: kMute))),
  );
}

class LocationDetailScreen extends StatelessWidget {
  final ApiClient api;
  final int id;
  const LocationDetailScreen({super.key, required this.api, required this.id});

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ОБЪЕКТ',
      FutureBuilder<Map<String, dynamic>>(
        future: api.location(id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final l = snap.data!;
          final photo = (l['photo'] ?? '').toString();
          final rows = {
            'Тип': l['type'],
            'Состояние': l['status'],
            'Зоны': l['zones'],
            'Описание': l['description'],
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (photo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Image.network(ApiClient.base + photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              Text(l['name'] ?? '', style: _titleStyle.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              ...rows.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 110, child: Text(e.key.toUpperCase(), style: _subStyle)),
                      Expanded(child: Text('${e.value ?? '—'}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
                    ]),
                  )),
              if ((l['coords_url'] ?? '') != '')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WebViewScreen(url: l['coords_url'] as String, title: 'КАРТА'),
                    )),
                    child: const Text('Открыть на карте', style: TextStyle(color: kAccent, fontFamily: 'monospace')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== СМЕНЫ ====================

class ShiftsScreen extends StatefulWidget {
  final ApiClient api;
  const ShiftsScreen({super.key, required this.api});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  int _filter = 0;
  bool _calendar = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.shifts();
  }

  void _reload() => setState(() => _future = widget.api.shifts());

  DateTime? _parse(String? iso) => (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso)?.toUtc();

  String _countdown(DateTime start, DateTime end, DateTime now) {
    if (now.isAfter(end)) return 'завершилась';
    if (!now.isBefore(start)) return 'идёт сейчас';
    final d = start.difference(now);
    if (d.inHours >= 24) return 'через ${d.inDays} дн ${d.inHours % 24} ч';
    if (d.inHours >= 1) return 'через ${d.inHours} ч ${d.inMinutes % 60} м';
    return 'через ${d.inMinutes} м';
  }

  Future<void> _mark(Map<String, dynamic> s, String status) async {
    try {
      await widget.api.shiftStatus(s['id'] as int, status);
      _reload();
    } catch (e) {
      if (isOffline(e)) {
        await OfflineQueue.add(PendingAction('shift_status', {'id': s['id'], 'status': status}));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Нет сети — отметка сохранена, отправим позже', style: TextStyle(fontFamily: 'monospace'))));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e is ApiException ? e.message : 'Ошибка', style: const TextStyle(fontFamily: 'monospace'))));
        }
      }
    }
  }

  Future<void> _start(Map<String, dynamic> s) async {
    try {
      await widget.api.shiftStart(s['id'] as int);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Ошибка', style: const TextStyle(fontFamily: 'monospace'))));
      }
    }
  }

  Future<void> _finish(Map<String, dynamic> s) async {
    final report = TextEditingController();
    String? photo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: const Text('Сдать смену', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: report,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Отчёт по смене'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: kAccent2, side: const BorderSide(color: kAccent2), shape: const RoundedRectangleBorder()),
                  onPressed: () async {
                    try {
                      final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
                      if (f != null) setD(() => photo = f.path);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('ФОТО', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                if (photo != null) const Expanded(child: Text('прикреплено', style: TextStyle(fontFamily: 'monospace', color: kAccent2, fontSize: 12))),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('СДАТЬ', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.shiftFinish(s['id'] as int, report: report.text.trim(), photoPath: photo);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Ошибка', style: const TextStyle(fontFamily: 'monospace'))));
      }
    }
  }

  Future<void> _swap(Map<String, dynamic> s) async {
    List<Map<String, dynamic>> people = [];
    try {
      people = await widget.api.colleagues();
    } catch (_) {}
    if (!mounted) return;
    int? toId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: const Text('Замена смены', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: DropdownButtonFormField<int>(
              initialValue: toId,
              dropdownColor: kPanel,
              decoration: const InputDecoration(labelText: 'На кого заменить'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— не указан —', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                ...people.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text('${m['name']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))),
              ],
              onChanged: (v) => setD(() => toId = v),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Запросить', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.shiftSwap(s['id'] as int, toMemberId: toId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Запрос замены отправлен', style: TextStyle(fontFamily: 'monospace'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Ошибка', style: const TextStyle(fontFamily: 'monospace'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('МОИ СМЕНЫ', style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          IconButton(
            tooltip: _calendar ? 'Списком' : 'Календарь',
            onPressed: () => setState(() => _calendar = !_calendar),
            icon: Icon(_calendar ? Icons.view_list : Icons.calendar_month, color: kSoft),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final all = snap.data ?? [];
          if (all.isEmpty) return _empty('Смен нет');
          final now = DateTime.now().toUtc();
          bool running(Map<String, dynamic> s) {
            final st = _parse(s['start_ts'] as String?);
            return st != null && st.add(const Duration(hours: 12)).isAfter(now);
          }
          if (_calendar) return _monthGrid(all, now);
          final upcoming = all.where(running).toList()
            ..sort((a, b) => (_parse(a['start_ts'] as String?) ?? now).compareTo(_parse(b['start_ts'] as String?) ?? now));
          final past = all.where((s) => !running(s)).toList()
            ..sort((a, b) => (_parse(b['start_ts'] as String?) ?? now).compareTo(_parse(a['start_ts'] as String?) ?? now));
          final nearest = upcoming.isNotEmpty ? upcoming.first : null;
          final shown = switch (_filter) { 0 => upcoming, 1 => past, _ => [...upcoming, ...past] };
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (nearest != null) _nearestCard(nearest, now),
              const SizedBox(height: 12),
              Row(children: [_chip('ПРЕДСТОЯЩИЕ', 0), const SizedBox(width: 6), _chip('ПРОШЕДШИЕ', 1), const SizedBox(width: 6), _chip('ВСЕ', 2)]),
              const SizedBox(height: 12),
              if (shown.isEmpty) _empty('Пусто'),
              ...shown.map((s) => _shiftCard(s, now)),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, int value) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _filter == value ? kAccent : kPanel, border: Border.all(color: _filter == value ? kAccent : kLine)),
            child: Text(label, style: TextStyle(color: _filter == value ? kBg : kSoft, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
      );

  Widget _nearestCard(Map<String, dynamic> s, DateTime now) {
    final st = _parse(s['start_ts'] as String?);
    final night = s['shift'] == 'night';
    final countdown = st == null ? '' : _countdown(st, st.add(const Duration(hours: 12)), now);
    return Container(
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kAccent)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('БЛИЖАЙШАЯ СМЕНА', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(night ? Icons.nightlight_round : Icons.wb_sunny, color: night ? kAccent2 : kAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: _titleStyle.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text('начало ${s['start']} · ${s['duration']} ч${(s['post'] ?? '') != '' ? ' · ${s['post']}' : ''}', style: _subStyle),
          ])),
          Text(countdown, style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _shiftCard(Map<String, dynamic> s, DateTime now) {
    final night = s['shift'] == 'night';
    final mates = (s['mates'] as List?)?.cast<String>() ?? [];
    final locId = s['location_id'] as int?;
    final st = _parse(s['start_ts'] as String?);
    final planned = s['status'] == 'planned';
    final started = st != null && !now.isBefore(st);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: locId == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocationDetailScreen(api: widget.api, id: locId))),
          child: Row(children: [
            Icon(night ? Icons.nightlight_round : Icons.wb_sunny, color: night ? kAccent2 : kAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: _titleStyle)),
            _statusTag(s['status_label']?.toString() ?? '', s['status']?.toString() ?? ''),
          ]),
        ),
        const SizedBox(height: 6),
        Text('начало ${s['start']} · ${s['duration']} ч${(s['post'] ?? '') != '' ? ' · ${s['post']}' : ''}', style: _subStyle),
        if (mates.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('в смене: ${mates.join(', ')}', style: _subStyle)),
        if (s['status'] == 'on_shift')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              TextButton(onPressed: () => _finish(s), child: const Text('✓ СДАТЬ СМЕНУ', style: TextStyle(color: kAccent2, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              const Spacer(),
              TextButton(onPressed: () => _swap(s), child: const Text('Замена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
            ]),
          )
        else if (planned)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              TextButton(onPressed: () => _start(s), child: const Text('НАЧАТЬ СМЕНУ', style: TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              if (started)
                TextButton(onPressed: () => _mark(s, 'absent'), child: const Text('Неявка', style: TextStyle(color: kDanger, fontFamily: 'monospace'))),
              const Spacer(),
              TextButton(onPressed: () => _swap(s), child: const Text('Замена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
            ]),
          ),
      ]),
    );
  }

  Widget _statusTag(String label, String status) {
    final color = switch (status) { 'done' => kAccent2, 'absent' => kDanger, 'leave' => kSoft, _ => kAccent };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(border: Border.all(color: color)),
        child: Text(label, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 10)));
  }

  Widget _monthGrid(List<Map<String, dynamic>> all, DateTime now) {
    final nowLocal = now.toLocal();
    final first = DateTime(nowLocal.year, nowLocal.month, 1);
    final daysInMonth = DateTime(nowLocal.year, nowLocal.month + 1, 0).day;
    final lead = (first.weekday - 1); // Пн=0
    final byDay = <String, Map<String, dynamic>>{};
    for (final s in all) {
      byDay[s['day'] as String] = s;
    }
    String dstr(int d) => '${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final s = byDay[dstr(d)];
      final night = s?['shift'] == 'night';
      final isToday = d == nowLocal.day;
      cells.add(GestureDetector(
        onTap: s == null ? null : () => _shiftDialog(s, now),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: s == null ? kPanel : (night ? kAccent2.withValues(alpha: 0.18) : kAccent.withValues(alpha: 0.18)),
            border: Border.all(color: isToday ? kText : kLine),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d', style: TextStyle(color: s == null ? kMute : kText, fontFamily: 'monospace', fontSize: 13)),
            if (s != null)
              Text(night ? 'ночь' : 'день', style: TextStyle(color: night ? kAccent2 : kAccent, fontFamily: 'monospace', fontSize: 8)),
          ]),
        ),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${_monthName(nowLocal.month)} ${nowLocal.year}',
            style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'].map((d) => Expanded(child: Center(child: Text(d, style: _subStyle)))).toList()),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: cells,
        ),
      ],
    );
  }

  String _monthName(int m) => ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'][m];

  void _shiftDialog(Map<String, dynamic> s, DateTime now) {
    final night = s['shift'] == 'night';
    final st = _parse(s['start_ts'] as String?);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: const TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: Text('Начало: ${s['start']}\nДлительность: ${s['duration']} ч\nПост: ${(s['post'] ?? '') == '' ? '—' : s['post']}\nСтатус: ${s['status_label']}${st != null ? '\n${_countdown(st, st.add(const Duration(hours: 12)), now)}' : ''}',
            style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          if (s['status'] == 'planned')
            TextButton(onPressed: () { Navigator.pop(context); _swap(s); }, child: const Text('Замена', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}

// ==================== ПРОХОДЫ ====================

class PassesScreen extends StatefulWidget {
  final ApiClient api;
  const PassesScreen({super.key, required this.api});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  late Future<List<Map<String, dynamic>>> _passes;
  List<Map<String, dynamic>> _locations = [];
  int? _locId;
  String? _msg;
  bool _onSite = false;
  String _stateLoc = '';
  String _stateSince = '';

  @override
  void initState() {
    super.initState();
    _passes = widget.api.passes();
    widget.api.locations().then((l) {
      OfflineQueue.cacheLocations(l);
      if (mounted) setState(() {
        _locations = l;
        _locId = l.isNotEmpty ? l.first['id'] as int : null;
      });
    }).catchError((_) async {
      final cached = await OfflineQueue.cachedLocations();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _locations = cached;
          _locId = cached.first['id'] as int;
        });
      }
    });
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final st = await widget.api.passState();
      if (mounted) {
        setState(() {
          _onSite = st['on_site'] == true;
          _stateLoc = st['location']?.toString() ?? '';
          _stateSince = st['since']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  String _sinceLocal() {
    final d = DateTime.tryParse(_stateSince);
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _checkin() async {
    final locName = (_onSite && _stateLoc.isNotEmpty)
        ? _stateLoc
        : _locations.firstWhere((l) => l['id'] == _locId, orElse: () => {'name': 'КПП-1'})['name'] as String;
    final pos = await currentPosition();
    try {
      final dir = await widget.api.checkin(locName, lat: pos?.latitude, lng: pos?.longitude, accuracy: pos?.accuracy);
      if (!mounted) return;
      setState(() => _msg = (dir == 'out' ? 'Отмечен выход' : 'Отмечен вход') + (pos != null ? ' · GPS' : ''));
      setState(() => _passes = widget.api.passes());
      await _loadStatus();
    } catch (e) {
      if (isOffline(e)) {
        await OfflineQueue.add(PendingAction('checkin_loc', {
          'location': locName,
          'lat': pos?.latitude, 'lng': pos?.longitude, 'accuracy': pos?.accuracy,
        }));
        if (!mounted) return;
        setState(() => _msg = 'Нет сети — сохранено, отправим позже');
      } else {
        setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
      }
    }
  }

  Future<void> _checkinQr() async {
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (raw == null || !mounted) return;
    final token = qrToken(raw);
    if (token == null) {
      setState(() => _msg = 'Неверный QR-код');
      return;
    }
    setState(() => _msg = 'Определяю геопозицию…');
    final pos = await currentPosition();
    try {
      final dir = await widget.api.checkinQr(token, lat: pos?.latitude, lng: pos?.longitude, accuracy: pos?.accuracy);
      if (!mounted) return;
      setState(() => _msg = (dir == 'out' ? 'Отмечен выход' : 'Отмечен вход') + ' · QR' + (pos != null ? ' · GPS' : ''));
      setState(() => _passes = widget.api.passes());
      await _loadStatus();
    } catch (e) {
      if (isOffline(e)) {
        await OfflineQueue.add(PendingAction('checkin', {
          'qr': token,
          'lat': pos?.latitude, 'lng': pos?.longitude, 'accuracy': pos?.accuracy,
        }));
        if (!mounted) return;
        setState(() => _msg = 'Нет сети — сохранено, отправим позже');
      } else {
        setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРОХОДЫ',
      Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kPanel, border: Border.all(color: _onSite ? kAccent2 : kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_onSite ? Icons.login : Icons.logout, color: _onSite ? kAccent2 : kSoft),
              const SizedBox(width: 10),
              Text(_onSite ? 'НА ОБЪЕКТЕ' : 'НЕ НА ОБЪЕКТЕ',
                  style: TextStyle(color: _onSite ? kAccent2 : kSoft, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
            if (_onSite && _stateLoc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('$_stateLoc${_sinceLocal().isEmpty ? '' : ' · с ${_sinceLocal()}'}',
                    style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _locId,
                  dropdownColor: kPanel,
                  decoration: const InputDecoration(labelText: 'Объект'),
                  items: _locations.map((l) => DropdownMenuItem<int>(value: l['id'] as int, child: Text(l['name'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _locId = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: kAccent2, side: const BorderSide(color: kAccent2), shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
                onPressed: _checkinQr,
                child: const Text('QR', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
                onPressed: _locations.isEmpty ? null : _checkin,
                child: Text(_onSite ? 'ВЫЙТИ' : 'ВОЙТИ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
            ]),
            if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('ИСТОРИЯ', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)))),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _passes,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _error(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Проходов нет');
              return ListView(
                padding: const EdgeInsets.all(14),
                children: items.map((p) {
                  final out = p['direction'] == 'out';
                  return _card(
                    leading: Icon(out ? Icons.logout : Icons.login, color: out ? kAccent : kAccent2),
                    title: '${out ? 'Выход' : 'Вход'} · ${p['location'] ?? ''}',
                    sub: _localTime((p['at'] ?? '').toString()),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ==================== НОВОСТИ ====================

class NewsScreen extends StatelessWidget {
  final ApiClient api;
  const NewsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'НОВОСТИ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: api.news(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Новостей нет');
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items.map((n) => _card(
                  title: (n['pinned'] == true ? '📌 ' : '') + (n['title'] ?? ''),
                  sub: '${_localTime((n['created_at'] ?? '').toString())} · ${n['author'] ?? ''}',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _DetailScreen(
                      title: 'НОВОСТЬ',
                      heading: n['title'] ?? '',
                      meta: '${_localTime((n['created_at'] ?? '').toString())} · ${n['author'] ?? ''}',
                      body: n['body'] ?? '',
                    ),
                  )),
                )).toList(),
          );
        },
      ),
    );
  }
}

class _DetailScreen extends StatelessWidget {
  final String title;
  final String heading;
  final String meta;
  final String body;
  const _DetailScreen({required this.title, required this.heading, required this.meta, required this.body});

  @override
  Widget build(BuildContext context) => _scaffold(
        title,
        ListView(padding: const EdgeInsets.all(16), children: [
          Text(heading, style: _titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text(meta, style: _subStyle),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
            child: Text(body.isEmpty ? '[ пусто ]' : body, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13, height: 1.7)),
          ),
        ]),
      );
}

// ==================== УВЕДОМЛЕНИЯ ====================

class NotificationsScreen extends StatefulWidget {
  final ApiClient api;
  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.notifications();
  }

  void _reload() => setState(() => _future = widget.api.notifications());

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'УВЕДОМЛЕНИЯ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            TextButton(onPressed: () async { await widget.api.notificationsRead(); _reload(); },
                child: const Text('Отметить все прочитанными', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _error(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Уведомлений нет');
              return ListView(
                padding: const EdgeInsets.all(14),
                children: items.map((n) {
                  final unread = n['read'] != true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: kPanel, border: Border.all(color: unread ? kAccent : kLine)),
                    child: ListTile(
                      onTap: () async {
                        if (unread) { await widget.api.notificationRead(n['id'] as int); _reload(); }
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _DetailScreen(
                            title: 'УВЕДОМЛЕНИЕ',
                            heading: n['title'] ?? '',
                            meta: _localTime((n['created_at'] ?? '').toString()),
                            body: n['body'] ?? '',
                          ),
                        ));
                      },
                      leading: Icon(unread ? Icons.circle : Icons.circle_outlined, size: 14, color: unread ? kAccent : kMute),
                      title: Text(n['title'] ?? '', style: _titleStyle),
                      subtitle: Text('${n['body'] ?? ''}', style: _subStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ==================== АНКЕТЫ ====================

class ApplicationsScreen extends StatefulWidget {
  final ApiClient api;
  const ApplicationsScreen({super.key, required this.api});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.applications();
  }

  void _reload() => setState(() => _future = widget.api.applications());

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'АНКЕТЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Анкет нет');
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items.map((a) => _card(
                  title: '${a['name']} · ${a['desired_role'] ?? ''}',
                  sub: _statusLabel(a['status'].toString()),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ApplicationDetailScreen(api: widget.api, id: a['id'] as int, onChanged: _reload),
                  )),
                )).toList(),
          );
        },
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'accepted' => 'принята',
        'rejected' => 'отклонена',
        'review' => 'на рассмотрении',
        _ => 'новая',
      };
}

class ApplicationDetailScreen extends StatefulWidget {
  final ApiClient api;
  final int id;
  final VoidCallback onChanged;
  const ApplicationDetailScreen({super.key, required this.api, required this.id, required this.onChanged});

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.application(widget.id);
  }

  Future<void> _decide(String status) async {
    await widget.api.decideApplication(widget.id, status);
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'АНКЕТА',
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final a = snap.data!;
          final pending = a['status'] == 'new' || a['status'] == 'review';
          final rows = {
            'Имя': a['name'],
            'Позывной': a['callsign'],
            'Желаемая должность': a['desired_role'],
            'Контакт': a['contact'],
            'Примечание': a['note'],
            'Статус': a['status'],
            'Подана': _localTime((a['created_at'] ?? '').toString()),
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(a['name'] ?? '', style: _titleStyle.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              ...rows.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 150, child: Text(e.key.toUpperCase(), style: _subStyle)),
                      Expanded(child: Text('${e.value ?? '—'}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
                    ]),
                  )),
              if (pending) ...[
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kAccent2, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                    onPressed: () => _decide('accepted'),
                    child: const Text('ПРИНЯТЬ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger), shape: const RoundedRectangleBorder()),
                    onPressed: () => _decide('rejected'),
                    child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  )),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ==================== ИНЦИДЕНТ / РАПОРТ ====================

class ReportScreen extends StatefulWidget {
  final ApiClient api;
  const ReportScreen({super.key, required this.api});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  List<Map<String, dynamic>> _locations = [];
  int? _locId;
  String _kind = 'incident';
  String _severity = 'medium';
  String? _photoPath;
  String? _msg;
  bool _sending = false;

  static const _kinds = {'incident': 'Инцидент', 'report': 'Рапорт', 'violation': 'Нарушение'};
  static const _severities = {'low': 'Низкая', 'medium': 'Средняя', 'high': 'Высокая', 'critical': 'Критично'};

  @override
  void initState() {
    super.initState();
    widget.api.locations().then((l) {
      OfflineQueue.cacheLocations(l);
      if (mounted) setState(() => _locations = l);
    }).catchError((_) async {
      final cached = await OfflineQueue.cachedLocations();
      if (mounted && cached.isNotEmpty) setState(() => _locations = cached);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
      if (file != null && mounted) setState(() => _photoPath = file.path);
    } catch (e) {
      if (mounted) setState(() => _msg = 'Камера недоступна: $e');
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _msg = 'Укажите заголовок');
      return;
    }
    setState(() { _sending = true; _msg = null; });
    final pos = await currentPosition();
    try {
      final id = await widget.api.reportIncident(
        title: _title.text.trim(),
        details: _details.text.trim(),
        kind: _kind,
        severity: _severity,
        locationId: _locId,
        lat: pos?.latitude,
        lng: pos?.longitude,
        photoPath: _photoPath,
      );
      if (!mounted) return;
      setState(() {
        _msg = 'Отправлено (№$id)${pos != null ? ' · GPS' : ''}${_photoPath != null ? ' · фото' : ''}';
        _title.clear();
        _details.clear();
        _photoPath = null;
      });
    } catch (e) {
      if (isOffline(e)) {
        final saved = _photoPath == null ? null : await OfflineQueue.persistPhoto(_photoPath!);
        await OfflineQueue.add(PendingAction('incident', {
          'title': _title.text.trim(),
          'details': _details.text.trim(),
          'kind': _kind,
          'severity': _severity,
          'location_id': _locId,
          'lat': pos?.latitude,
          'lng': pos?.longitude,
          'photo': saved,
        }));
        if (!mounted) return;
        setState(() {
          _msg = 'Нет сети — сохранено, отправим позже';
          _title.clear();
          _details.clear();
          _photoPath = null;
        });
      } else if (mounted) {
        setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ИНЦИДЕНТ',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('ТИП', style: _subStyle),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: _kinds.entries.map((e) => _pick(e.key, _kind, e.value, (v) => setState(() => _kind = v))).toList()),
          const SizedBox(height: 14),
          const Text('ВАЖНОСТЬ', style: _subStyle),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: _severities.entries.map((e) => _pick(e.key, _severity, e.value, (v) => setState(() => _severity = v))).toList()),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 14),
            decoration: const InputDecoration(labelText: 'Заголовок'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _locId,
            dropdownColor: kPanel,
            decoration: const InputDecoration(labelText: 'Объект'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('— не указан —', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
              ..._locations.map((l) => DropdownMenuItem<int>(value: l['id'] as int, child: Text(l['name'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))),
            ],
            onChanged: (v) => setState(() => _locId = v),
          ),
          const SizedBox(height: 14),
          Row(children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: kAccent2, side: const BorderSide(color: kAccent2), shape: const RoundedRectangleBorder()),
              onPressed: _shoot,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('ФОТО', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            if (_photoPath != null)
              const Expanded(child: Text('снимок прикреплён', style: TextStyle(fontFamily: 'monospace', color: kAccent2, fontSize: 12))),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'ОТПРАВКА…' : 'ОТПРАВИТЬ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
        ],
      ),
    );
  }

  Widget _pick(String value, String current, String label, ValueChanged<String> onPick) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onPick(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: sel ? kAccent : kPanel, border: Border.all(color: sel ? kAccent : kLine)),
        child: Text(label, style: TextStyle(color: sel ? kBg : kSoft, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ==================== ВНУТРЕННЯЯ ЗАЯВКА ====================

class RequestScreen extends StatefulWidget {
  final ApiClient api;
  const RequestScreen({super.key, required this.api});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'access';
  String? _msg;
  bool _sending = false;
  late Future<List<Map<String, dynamic>>> _f;

  static const _kinds = {'bug': 'Баг', 'idea': 'Идея', 'access': 'Доступ', 'equipment': 'Снаряжение', 'transport': 'Транспорт', 'repair': 'Ремонт', 'other': 'Прочее'};

  static String kindLabel(String k) => _kinds[k] ?? k;

  @override
  void initState() {
    super.initState();
    _f = widget.api.myRequests();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Color _st(String s) => switch (s) {
        'approved' => kAccent2,
        'rejected' => kDanger,
        'done' => kSoft,
        _ => kAccent,
      };

  Future<void> _send() async {
    if (_title.text.trim().length < 3) {
      setState(() => _msg = 'Укажите тему (мин. 3 символа)');
      return;
    }
    setState(() { _sending = true; _msg = null; });
    try {
      await widget.api.createRequest(kind: _kind, title: _title.text.trim(), body: _body.text.trim());
      if (!mounted) return;
      setState(() {
        _msg = 'Заявка отправлена';
        _title.clear();
        _body.clear();
        _f = widget.api.myRequests();
      });
    } catch (e) {
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ЗАЯВКА',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('ТИП', style: _subStyle),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: _kinds.entries.map((e) {
            final sel = e.key == _kind;
            return GestureDetector(
              onTap: () => setState(() => _kind = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: sel ? kAccent : kPanel, border: Border.all(color: sel ? kAccent : kLine)),
                child: Text(e.value, style: TextStyle(color: sel ? kBg : kSoft, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),
          TextField(controller: _title, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 14), decoration: const InputDecoration(labelText: 'Тема')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 4, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13), decoration: const InputDecoration(labelText: 'Описание')),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'ОТПРАВКА…' : 'ОТПРАВИТЬ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
          const SizedBox(height: 18),
          const Text('МОИ ЗАЯВКИ', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _error(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Заявок нет');
              return Column(
                children: items.map((r) => _card(
                      leading: Icon(Icons.assignment, color: _st('${r['status']}'), size: 18),
                      title: '${r['title']}',
                      sub: '${_RequestScreenState.kindLabel('${r['kind']}')} · ${r['status']}',
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
