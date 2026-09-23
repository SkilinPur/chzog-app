import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

const _title = TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold);
const _sub = TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11);
const _muted = TextStyle(color: kMute, fontFamily: 'monospace', fontSize: 11);

Widget _scaffold(String title, Widget body) => Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2))),
      body: body,
    );

Widget _loading() => const Center(child: CircularProgressIndicator(color: kAccent));
Widget _empty(String t) => Center(child: Text(t, style: _muted));
Widget _err(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(e is ApiException ? e.message : 'Ошибка сети',
            textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontFamily: 'monospace')),
      ),
    );

Widget _card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
      child: child,
    );

Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(text, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 10)),
    );

String _fmt(Object? iso) {
  final s = iso?.toString() ?? '';
  return s.length < 16 ? s : '${s.substring(0, 10)} ${s.substring(11, 16)}';
}

void _toast(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'monospace'))));

// ==================== ВСЕ СМЕНЫ ====================

class ManageShiftsScreen extends StatefulWidget {
  final ApiClient api;
  const ManageShiftsScreen({super.key, required this.api});

  @override
  State<ManageShiftsScreen> createState() => _ManageShiftsScreenState();
}

class _ManageShiftsScreenState extends State<ManageShiftsScreen> {
  final _day = TextEditingController();
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mShifts();
  }

  void _reload() => setState(() => _f = widget.api.mShifts(day: _day.text.trim()));

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  Color _st(String s) => switch (s) {
        'done' => kAccent2,
        'absent' => kDanger,
        'leave' => kSoft,
        _ => kAccent,
      };

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ВСЕ СМЕНЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _day,
                style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Дата (ГГГГ-ММ-ДД)', isDense: true),
                onSubmitted: (_) => _reload(),
              ),
            ),
            IconButton(onPressed: _reload, icon: const Icon(Icons.search, color: kSoft)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Смен нет');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((s) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${s['day']} · ${s['shift'] == 'night' ? 'ночь' : 'день'}', style: _title)),
                        _tag('${s['status']}', _st('${s['status']}')),
                      ]),
                      Text('${s['member']} · ${s['post'] ?? ''} · ${s['location'] ?? ''}', style: _sub),
                      const SizedBox(height: 4),
                      Row(children: [
                        TextButton(
                          onPressed: () async {
                            await widget.api.mShiftStatus(s['id'] as int, 'done');
                            _reload();
                          },
                          child: const Text('✓ Отработана', style: TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.api.mShiftStatus(s['id'] as int, 'absent');
                            _reload();
                          },
                          child: const Text('Неявка', style: TextStyle(color: kDanger, fontFamily: 'monospace', fontSize: 12)),
                        ),
                      ]),
                    ]))).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ==================== ЖУРНАЛ ПРОХОДОВ ====================

class ManagePassesScreen extends StatefulWidget {
  final ApiClient api;
  const ManagePassesScreen({super.key, required this.api});

  @override
  State<ManagePassesScreen> createState() => _ManagePassesScreenState();
}

class _ManagePassesScreenState extends State<ManagePassesScreen> {
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mPasses();
  }

  void _reload() => setState(() => _f = widget.api.mPasses());

  Future<void> _add() async {
    final members = await widget.api.mMembers();
    final locations = await widget.api.mLocations();
    if (!mounted) return;
    var memberId = 0;
    var locId = 0;
    var direction = 'in';
    final person = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: const Text('Новый проход', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(
                  initialValue: memberId,
                  dropdownColor: kPanel,
                  decoration: const InputDecoration(labelText: 'Сотрудник'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('— вписать вручную —', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                    ...members.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text('${m['name']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))),
                  ],
                  onChanged: (v) => setD(() => memberId = v ?? 0),
                ),
                if (memberId == 0)
                  TextField(controller: person, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13), decoration: const InputDecoration(labelText: 'Имя')),
                DropdownButtonFormField<int>(
                  initialValue: locId,
                  dropdownColor: kPanel,
                  decoration: const InputDecoration(labelText: 'Объект'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('— не указан —', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                    ...locations.map((l) => DropdownMenuItem(value: l['id'] as int, child: Text('${l['name']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))),
                  ],
                  onChanged: (v) => setD(() => locId = v ?? 0),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  dropdownColor: kPanel,
                  decoration: const InputDecoration(labelText: 'Направление'),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('вход', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                    DropdownMenuItem(value: 'out', child: Text('выход', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                  ],
                  onChanged: (v) => setD(() => direction = v ?? 'in'),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.mPassSave({'member_id': memberId, 'person': person.text.trim(), 'location_id': locId, 'direction': direction});
      _reload();
    } catch (e) {
      if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ЖУРНАЛ ПРОХОДОВ',
      Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.all(8), child: IconButton(onPressed: _add, icon: const Icon(Icons.add, color: kAccent))),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Проходов нет');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((p) {
                  final out = p['direction'] == 'out';
                  return _card(Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${out ? 'Выход' : 'Вход'} · ${p['location'] ?? ''}', style: _title),
                      Text('${p['person']} · ${_fmt(p['at'])}${p['lat'] != null ? ' · GPS' : ''}', style: _sub),
                    ])),
                    _tag(out ? 'OUT' : 'IN', out ? kAccent : kAccent2),
                  ]));
                }).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ==================== ИНЦИДЕНТЫ ====================

class ManageIncidentsScreen extends StatefulWidget {
  final ApiClient api;
  const ManageIncidentsScreen({super.key, required this.api});

  @override
  State<ManageIncidentsScreen> createState() => _ManageIncidentsScreenState();
}

class _ManageIncidentsScreenState extends State<ManageIncidentsScreen> {
  String _status = '';
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mIncidents();
  }

  void _reload() => setState(() => _f = widget.api.mIncidents(status: _status));

  Color _sev(String s) => switch (s) {
        'critical' => kDanger,
        'high' => kAccent,
        'medium' => kAccent2,
        _ => kSoft,
      };

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ИНЦИДЕНТЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _fbtn('ВСЕ', ''),
            const SizedBox(width: 6),
            _fbtn('ОТКРЫТЫЕ', 'open'),
            const SizedBox(width: 6),
            _fbtn('ЗАКРЫТЫЕ', 'closed'),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Инцидентов нет');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((i) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${i['title']}', style: _title)),
                        _tag('${i['severity']}', _sev('${i['severity']}')),
                      ]),
                      Text('${i['kind']} · ${i['member'] ?? ''} · ${_fmt(i['at'])}', style: _sub),
                      if ('${i['details'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${i['details']}', style: _muted)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _tag(i['status'] == 'open' ? 'открыт' : 'закрыт', i['status'] == 'open' ? kDanger : kAccent2),
                        const Spacer(),
                        if (i['status'] == 'open')
                          TextButton(
                            onPressed: () async {
                              await widget.api.mIncidentClose(i['id'] as int);
                              _reload();
                            },
                            child: const Text('Закрыть', style: TextStyle(color: kAccent2, fontFamily: 'monospace')),
                          ),
                      ]),
                    ]))).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _fbtn(String label, String value) => Expanded(
        child: GestureDetector(
          onTap: () { setState(() => _status = value); _reload(); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _status == value ? kAccent : kPanel, border: Border.all(color: _status == value ? kAccent : kLine)),
            child: Text(label, style: TextStyle(color: _status == value ? kBg : kSoft, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      );
}

// ==================== ДЕЛА / ПРИКАЗЫ / ОБЪЕКТЫ (руководителю) ====================

class ManageMembersScreen extends StatefulWidget {
  final ApiClient api;
  const ManageMembersScreen({super.key, required this.api});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final _q = TextEditingController();
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mMembers();
  }

  void _reload() => setState(() => _f = widget.api.mMembers(q: _q.text.trim()));

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ЛИЧНЫЕ ДЕЛА',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: _q, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13), decoration: const InputDecoration(labelText: 'Поиск', isDense: true), onSubmitted: (_) => _reload())),
            IconButton(onPressed: _reload, icon: const Icon(Icons.search, color: kSoft)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Пусто');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((m) => _card(Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m['name']}', style: _title),
                        Text('${m['callsign'] ?? ''} · ${m['department'] ?? ''} · ${m['status'] ?? ''}', style: _sub),
                      ])),
                      _tag('допуск ${m['clearance']}', kAccent2),
                    ]))).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class ManageDocumentsScreen extends StatefulWidget {
  final ApiClient api;
  const ManageDocumentsScreen({super.key, required this.api});

  @override
  State<ManageDocumentsScreen> createState() => _ManageDocumentsScreenState();
}

class _ManageDocumentsScreenState extends State<ManageDocumentsScreen> {
  final _q = TextEditingController();
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mDocuments();
  }

  void _reload() => setState(() => _f = widget.api.mDocuments(q: _q.text.trim()));

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРИКАЗЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: _q, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13), decoration: const InputDecoration(labelText: 'Поиск', isDense: true), onSubmitted: (_) => _reload())),
            IconButton(onPressed: _reload, icon: const Icon(Icons.search, color: kSoft)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Пусто');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((d) => _card(Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('№ ${d['num']} · ${d['title']}', style: _title),
                        Text('${d['date']} · ${d['type'] ?? ''}', style: _sub),
                      ])),
                      _tag('${d['status_label'] ?? d['status']}', d['status'] == 'active' ? kAccent2 : kSoft),
                    ]))).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class ManageLocationsScreen extends StatefulWidget {
  final ApiClient api;
  const ManageLocationsScreen({super.key, required this.api});

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mLocations();
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ОБЪЕКТЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _err(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Пусто');
          return ListView(
            padding: const EdgeInsets.all(12),
            children: items.map((l) => _card(Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l['name']}', style: _title),
                    Text('${l['type'] ?? ''} · ${l['status'] ?? ''}', style: _sub),
                  ])),
                  _tag('гриф ${l['clearance']}', kAccent2),
                ]))).toList(),
          );
        },
      ),
    );
  }
}

// ==================== ЗАЯВКИ (руководителю) ====================

class ManageRequestsScreen extends StatefulWidget {
  final ApiClient api;
  const ManageRequestsScreen({super.key, required this.api});

  @override
  State<ManageRequestsScreen> createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  String _status = '';
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.mRequests();
  }

  void _reload() => setState(() => _f = widget.api.mRequests(status: _status));

  Color _st(String s) => switch (s) {
        'approved' => kAccent2,
        'rejected' => kDanger,
        'done' => kSoft,
        _ => kAccent,
      };

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ЗАЯВКИ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _fbtn('ВСЕ', ''),
            const SizedBox(width: 6),
            _fbtn('НОВЫЕ', 'new'),
            const SizedBox(width: 6),
            _fbtn('РЕШЁННЫЕ', 'approved'),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _err(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return _empty('Заявок нет');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items.map((r) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${r['title']}', style: _title)),
                        _tag('${r['status']}', _st('${r['status']}')),
                      ]),
                      Text('${r['kind']} · ${r['author'] ?? ''} · ${_fmt(r['at'])}', style: _sub),
                      if ('${r['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['body']}', style: _muted)),
                      const SizedBox(height: 4),
                      Row(children: [
                        TextButton(
                          onPressed: () async {
                            await widget.api.mRequestDecide(r['id'] as int, 'approved');
                            _reload();
                          },
                          child: const Text('Одобрить', style: TextStyle(color: kAccent2, fontFamily: 'monospace')),
                        ),
                        TextButton(
                          onPressed: () async {
                            await widget.api.mRequestDecide(r['id'] as int, 'rejected');
                            _reload();
                          },
                          child: const Text('Отклонить', style: TextStyle(color: kDanger, fontFamily: 'monospace')),
                        ),
                      ]),
                    ]))).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _fbtn(String label, String value) => Expanded(
        child: GestureDetector(
          onTap: () { setState(() => _status = value); _reload(); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _status == value ? kAccent : kPanel, border: Border.all(color: _status == value ? kAccent : kLine)),
            child: Text(label, style: TextStyle(color: _status == value ? kBg : kSoft, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      );
}
