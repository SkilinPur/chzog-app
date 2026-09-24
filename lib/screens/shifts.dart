import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class ShiftsScreen extends StatefulWidget {
  final ApiClient api;
  const ShiftsScreen({super.key, required this.api});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  late Future<List<Map<String, dynamic>>> _f;
  int _filter = 0;
  bool _calendar = false;

  @override
  void initState() {
    super.initState();
    _f = widget.api.shifts();
  }

  void _reload() => setState(() => _f = widget.api.shifts());

  DateTime? _parse(String? iso) => (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso)?.toUtc();

  String _countdown(DateTime start, DateTime end, DateTime now) {
    if (now.isAfter(end)) return 'завершилась';
    if (!now.isBefore(start)) return 'идёт сейчас';
    final d = start.difference(now);
    if (d.inHours >= 24) return 'через ${d.inDays} дн ${d.inHours % 24} ч';
    if (d.inHours >= 1) return 'через ${d.inHours} ч ${d.inMinutes % 60} м';
    return 'через ${d.inMinutes} м';
  }

  Future<void> _start(Map<String, dynamic> s) async {
    try {
      await widget.api.shiftStart(s['id'] as int);
      _reload();
    } catch (e) {
      if (mounted) toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  Future<void> _finish(Map<String, dynamic> s) async {
    final report = TextEditingController();
    String? photo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: Text('Сдать смену', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              field('Отчёт по смене', report, maxLines: 3),
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: kAccent2, side: BorderSide(color: kAccent2), shape: RoundedRectangleBorder()),
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
                if (photo != null) Expanded(child: Text('прикреплено', style: TextStyle(fontFamily: 'monospace', color: kAccent2, fontSize: 12))),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: RoundedRectangleBorder()),
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
      if (mounted) toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
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
            title: Text('Замена смены', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: DropdownButtonFormField<int>(
              key: ValueKey('swap-$toId'),
              initialValue: toId,
              isExpanded: true,
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
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Запросить', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.shiftSwap(s['id'] as int, toMemberId: toId);
      if (mounted) toast(context, 'Запрос замены отправлен');
    } catch (e) {
      if (mounted) toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'МОИ СМЕНЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final all = snap.data ?? [];
          if (all.isEmpty) return empty('Смен нет');
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
              const SizedBox(height: 10),
              Row(children: [
                chip('ПРЕДСТОЯЩИЕ', _filter == 0, () => setState(() => _filter = 0)),
                const SizedBox(width: 4),
                chip('ПРОШЕДШИЕ', _filter == 1, () => setState(() => _filter = 1)),
                const SizedBox(width: 4),
                chip('ВСЕ', _filter == 2, () => setState(() => _filter = 2)),
              ]),
              const SizedBox(height: 12),
              if (shown.isEmpty) empty('Пусто'),
              ...shown.map((s) => _shiftCard(s, now)),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: _calendar ? 'Списком' : 'Календарь',
          onPressed: () => setState(() => _calendar = !_calendar),
          icon: Icon(_calendar ? Icons.view_list : Icons.calendar_month, color: kSoft),
        ),
      ],
    );
  }

  Widget _nearestCard(Map<String, dynamic> s, DateTime now) {
    final st = _parse(s['start_ts'] as String?);
    final night = s['shift'] == 'night';
    final countdown = st == null ? '' : _countdown(st, st.add(const Duration(hours: 12)), now);
    return card(
      border: kAccent,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('БЛИЖАЙШАЯ СМЕНА', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(night ? Icons.nightlight_round : Icons.wb_sunny, color: night ? kAccent2 : kAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: kTitle.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text('начало ${s['start']} · ${s['duration']} ч${(s['post'] ?? '') != '' ? ' · ${s['post']}' : ''}', style: kSub),
          ])),
          Text(countdown, style: TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _shiftCard(Map<String, dynamic> s, DateTime now) {
    final night = s['shift'] == 'night';
    final mates = (s['mates'] as List?)?.cast<String>() ?? [];
    final st = _parse(s['start_ts'] as String?);
    final planned = s['status'] == 'planned';
    final started = st != null && !now.isBefore(st);
    return card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(night ? Icons.nightlight_round : Icons.wb_sunny, color: night ? kAccent2 : kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: kTitle)),
          tag('${s['status_label'] ?? s['status']}', shiftColor('${s['status']}')),
        ]),
        const SizedBox(height: 6),
        Text('начало ${s['start']} · ${s['duration']} ч${(s['post'] ?? '') != '' ? ' · ${s['post']}' : ''}', style: kSub),
        if (mates.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('в смене: ${mates.join(', ')}', style: kSub)),
        if (s['status'] == 'on_shift')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              TextButton(onPressed: () => _finish(s), child: Text('✓ СДАТЬ СМЕНУ', style: TextStyle(color: kAccent2, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              const Spacer(),
              TextButton(onPressed: () => _swap(s), child: const Text('Замена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
            ]),
          )
        else if (planned)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              TextButton(onPressed: () => _start(s), child: Text('НАЧАТЬ СМЕНУ', style: TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              if (started) TextButton(onPressed: () => _start(s), child: const Text('Неявка', style: TextStyle(color: kDanger, fontFamily: 'monospace'))),
              const Spacer(),
              TextButton(onPressed: () => _swap(s), child: const Text('Замена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
            ]),
          ),
      ]),
    );
  }

  Widget _monthGrid(List<Map<String, dynamic>> all, DateTime now) {
    final nowLocal = now.toLocal();
    final first = DateTime(nowLocal.year, nowLocal.month, 1);
    final daysInMonth = DateTime(nowLocal.year, nowLocal.month + 1, 0).day;
    final lead = (first.weekday - 1);
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
        onTap: s == null ? null : () => _dayDialog(s, now),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: s == null ? kPanel : (night ? kAccent2.withValues(alpha: 0.18) : kAccent.withValues(alpha: 0.18)),
            border: Border.all(color: isToday ? kText : kLine),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d', style: TextStyle(color: s == null ? kMute : kText, fontFamily: 'monospace', fontSize: 13)),
            if (s != null) Text(night ? 'ночь' : 'день', style: TextStyle(color: night ? kAccent2 : kAccent, fontFamily: 'monospace', fontSize: 8)),
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
        Row(children: ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'].map((d) => Expanded(child: Center(child: Text(d, style: kSub)))).toList()),
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

  void _dayDialog(Map<String, dynamic> s, DateTime now) {
    final night = s['shift'] == 'night';
    final st = _parse(s['start_ts'] as String?);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: Text(
            'Начало: ${s['start']}\nДлительность: ${s['duration']} ч\nПост: ${(s['post'] ?? '') == '' ? '—' : s['post']}\nСтатус: ${s['status_label']}${st != null ? '\n${_countdown(st, st.add(const Duration(hours: 12)), now)}' : ''}',
            style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          if (s['status'] == 'planned')
            TextButton(onPressed: () { Navigator.pop(context); _swap(s); }, child: Text('Замена', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}
