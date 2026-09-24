import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../queue.dart';
import '../scan.dart';
import '../theme.dart';

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
