import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';

const _titleStyle = TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold);
const _subStyle = TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11);

Widget _scaffold(String title, Widget body) => Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2))),
      body: body,
    );

Widget _loading() => const Center(child: CircularProgressIndicator(color: kAccent));
Widget _empty(String t) => Center(child: Text(t, style: const TextStyle(color: kMute, fontFamily: 'monospace')));
Widget _error(Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(e is ApiException ? e.message : 'Ошибка загрузки',
          textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontFamily: 'monospace')),
    ),
  );

Widget _card({required String title, String? sub, List<Widget> extra = const [], VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _titleStyle),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: _subStyle)),
            ...extra,
          ],
        ),
      ),
    );

// ---------- Приказы ----------

class DocumentsScreen extends StatelessWidget {
  final ApiClient api;
  const DocumentsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРИКАЗЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: api.documents(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Приказов нет');
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items
                .map((d) => _card(
                      title: '${d['num']} · ${d['title']}',
                      sub: '${d['date']} · ${d['status_label'] ?? d['status']} · гриф ${d['clearance']}${d['has_pdf'] == true ? ' · PDF' : ''}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DocumentDetailScreen(api: api, id: d['id'] as int)),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class DocumentDetailScreen extends StatefulWidget {
  final ApiClient api;
  final int id;
  const DocumentDetailScreen({super.key, required this.api, required this.id});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _future = widget.api.document(widget.id);
  }

  void _reload() => setState(() => _future = widget.api.document(widget.id));

  Future<void> _sign(int signId, String status) async {
    try {
      await widget.api.sign(widget.id, signId, status);
      setState(() => _msg = status == 'signed' ? '✍️ Подписано' : '🕓 Отложено');
      _reload();
    } catch (e) {
      setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРИКАЗ',
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final d = snap.data!;
          final signs = (d['signatories'] as List).cast<Map<String, dynamic>>();
          final fields = (d['fields'] as Map?)?.cast<String, dynamic>() ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if ((d['template_header'] ?? '') != '')
                Text(d['template_header'], style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text('${d['num']} · ${d['title']}', style: _titleStyle.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text('${d['date']} · ${d['status_label'] ?? d['status']} · v${d['version']}', style: _subStyle),
              const SizedBox(height: 14),
              if ((d['body'] ?? '') != '')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
                  child: Text(d['body'], style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13, height: 1.6)),
                ),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...fields.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 130, child: Text(e.key.toUpperCase(), style: _subStyle)),
                        Expanded(child: Text('${e.value}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
                      ]),
                    )),
              ],
              const SizedBox(height: 16),
              const Text('ПОДПИСИ', style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 8),
              ...signs.map((s) {
                final mine = s['mine'] == true && s['status'] != 'signed';
                return _card(
                  title: s['name'] ?? '',
                  sub: s['position'] ?? '',
                  extra: [
                    const SizedBox(height: 8),
                    Row(children: [
                      _statusTag((s['status'] ?? '').toString()),
                      const Spacer(),
                      if (mine) ...[
                        TextButton(onPressed: () => _sign(s['id'] as int, 'signed'), child: const Text('✍️ Подписать', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
                        TextButton(onPressed: () => _sign(s['id'] as int, 'postponed'), child: const Text('🕓 Отложить', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
                      ],
                    ]),
                  ],
                );
              }),
              if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace'))),
              if ((d['file_url'] ?? '') != '')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: () => launchUrl(Uri.parse(ApiClient.base + (d['file_url'] as String))),
                    child: const Text('Открыть PDF', style: TextStyle(color: kAccent, fontFamily: 'monospace')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusTag(String status) {
    final (label, color) = switch (status) {
      'signed' => ('подписано', kAccent2),
      'postponed' => ('отложено', kAccent),
      _ => ('ожидает', kSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11)),
    );
  }
}

// ---------- Объекты ----------

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
          final rows = {
            'Тип': l['type'],
            'Состояние': l['status'],
            'Зоны': l['zones'],
            'Описание': l['description'],
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l['name'] ?? '', style: _titleStyle.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              ...rows.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 110, child: Text(e.key.toUpperCase(), style: _subStyle)),
                      Expanded(child: Text('${e.value ?? '—'}'.isEmpty ? '—' : '${e.value ?? '—'}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13))),
                    ]),
                  )),
              if ((l['coords_url'] ?? '') != '')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: OutlinedButton(
                    onPressed: () => launchUrl(Uri.parse(l['coords_url'] as String)),
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

// ---------- Смены ----------

class ShiftsScreen extends StatelessWidget {
  final ApiClient api;
  const ShiftsScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'МОИ СМЕНЫ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: api.shifts(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _loading();
          if (snap.hasError) return _error(snap.error!);
          final items = snap.data ?? [];
          if (items.isEmpty) return _empty('Смен нет');
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items
                .map((s) => _card(
                      title: '${s['day'] ?? s['date']} · ${s['shift'] == 'night' ? 'ночная' : 'дневная'}',
                      sub: '${s['post'] ?? ''} · ${s['status'] ?? ''}',
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

// ---------- Проходы ----------

class PassesScreen extends StatefulWidget {
  final ApiClient api;
  const PassesScreen({super.key, required this.api});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _loc = TextEditingController(text: 'КПП-1');
  String? _msg;

  @override
  void initState() {
    super.initState();
    _future = widget.api.passes();
  }

  Future<void> _checkin() async {
    try {
      final dir = await widget.api.checkin(_loc.text.trim());
      setState(() => _msg = dir == 'out' ? 'Отмечен выход' : 'Отмечен вход');
      setState(() => _future = widget.api.passes());
    } catch (e) {
      setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРОХОДЫ',
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Объект')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: _checkin,
                child: const Text('ОТМЕТИТЬ', style: TextStyle(fontFamily: 'monospace')),
              ),
            ]),
          ),
          if (_msg != null) Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12)),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return _loading();
                if (snap.hasError) return _error(snap.error!);
                final items = snap.data ?? [];
                if (items.isEmpty) return _empty('Проходов нет');
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: items
                      .map((p) => _card(
                            title: '${p['direction'] == 'out' ? 'выход' : 'вход'} · ${p['location'] ?? ''}',
                            sub: (p['at'] ?? '').toString().replaceFirst('T', ' '),
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Новости ----------

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
            children: items.map((n) => _card(title: n['title'] ?? '', sub: '${n['body'] ?? ''}\n— ${n['author'] ?? ''}')).toList(),
          );
        },
      ),
    );
  }
}

// ---------- Уведомления ----------

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

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'УВЕДОМЛЕНИЯ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextButton(
            onPressed: () async {
              await widget.api.notificationsRead();
              setState(() => _future = widget.api.notifications());
            },
            child: const Text('Отметить прочитанными', style: TextStyle(color: kSoft, fontFamily: 'monospace')),
          ),
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
                children: items
                    .map((n) => _card(
                          title: n['title'] ?? '',
                          sub: '${n['body'] ?? ''}${n['read'] == true ? ' · прочитано' : ''}',
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ---------- Анкеты ----------

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
            children: items.map((a) {
              final pending = a['status'] == 'new' || a['status'] == 'review';
              return _card(
                title: '${a['name']} · ${a['desired_role'] ?? ''}',
                sub: '${a['contact'] ?? ''}\n${a['note'] ?? ''}',
                extra: [
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(a['status'].toString(), style: _subStyle),
                    const Spacer(),
                    if (pending) ...[
                      TextButton(onPressed: () async { await widget.api.decideApplication(a['id'] as int, 'accepted'); _reload(); },
                          child: const Text('Принять', style: TextStyle(color: kAccent2, fontFamily: 'monospace'))),
                      TextButton(onPressed: () async { await widget.api.decideApplication(a['id'] as int, 'rejected'); _reload(); },
                          child: const Text('Отклонить', style: TextStyle(color: kDanger, fontFamily: 'monospace'))),
                    ],
                  ]),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
