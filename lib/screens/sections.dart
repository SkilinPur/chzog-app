import 'package:flutter/material.dart';

import '../api.dart';
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

// ==================== ПРИКАЗЫ ====================

class DocumentsScreen extends StatefulWidget {
  final ApiClient api;
  const DocumentsScreen({super.key, required this.api});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.api.documents();
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      'ПРИКАЗЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _query,
            decoration: const InputDecoration(labelText: 'Поиск по номеру или названию', prefixIcon: Icon(Icons.search, color: kSoft)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return _loading();
              if (snap.hasError) return _error(snap.error!);
              final q = _query.text.trim().toLowerCase();
              final items = (snap.data ?? []).where((d) =>
                  q.isEmpty ||
                  '${d['num']} ${d['title']}'.toLowerCase().contains(q)).toList();
              if (items.isEmpty) return _empty('Ничего не найдено');
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: items
                    .map((d) => _card(
                          title: '${d['num']} · ${d['title']}',
                          sub: '${d['date']} · ${d['status_label'] ?? d['status']} · гриф ${d['clearance']}${d['has_pdf'] == true ? ' · PDF' : ''}',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => DocumentDetailScreen(api: widget.api, id: d['id'] as int)),
                          ),
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
          final signed = signs.where((s) => s['status'] == 'signed').length;
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
              Text('ПОДПИСИ · $signed из ${signs.length}',
                  style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
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
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WebViewScreen(url: ApiClient.base + (d['file_url'] as String), title: 'ПРИКАЗ · PDF'),
                    )),
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
          final today = DateTime.now().toIso8601String().substring(0, 10);
          return ListView(
            padding: const EdgeInsets.all(14),
            children: items.map((s) {
              final night = s['shift'] == 'night';
              final isToday = s['day'] == today;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kPanel, border: Border.all(color: isToday ? kAccent : kLine)),
                child: Row(children: [
                  Icon(night ? Icons.nightlight_round : Icons.wb_sunny, color: night ? kAccent2 : kAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['day']} · ${night ? 'ночная' : 'дневная'}', style: _titleStyle),
                      const SizedBox(height: 4),
                      Text('начало ${night ? '00:00' : '12:00'}${(s['post'] ?? '') != '' ? ' · ${s['post']}' : ''}', style: _subStyle),
                    ]),
                  ),
                  if (isToday) const Text('СЕГОДНЯ', style: TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 10, letterSpacing: 1)),
                ]),
              );
            }).toList(),
          );
        },
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

  @override
  void initState() {
    super.initState();
    _passes = widget.api.passes();
    widget.api.locations().then((l) {
      if (mounted) setState(() {
        _locations = l;
        _locId = l.isNotEmpty ? l.first['id'] as int : null;
      });
    }).catchError((_) {});
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final items = await widget.api.passes();
    if (mounted) setState(() => _onSite = items.isNotEmpty && items.first['direction'] == 'in');
  }

  Future<void> _checkin() async {
    final loc = _locations.firstWhere((l) => l['id'] == _locId, orElse: () => {'name': 'КПП-1'});
    try {
      final dir = await widget.api.checkin(loc['name'] as String);
      setState(() => _msg = dir == 'out' ? 'Отмечен выход' : 'Отмечен вход');
      setState(() => _passes = widget.api.passes());
      await _loadStatus();
    } catch (e) {
      setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
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
