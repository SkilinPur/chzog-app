import 'package:flutter/material.dart';

import '../api.dart';
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
