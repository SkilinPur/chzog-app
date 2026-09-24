import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

const _docStatus = {'draft': 'проект', 'active': 'действует', 'cancelled': 'отменён', 'archived': 'архив'};
Color _stColor(String s) => switch (s) {
      'active' => kAccent2,
      'cancelled' => kDanger,
      'draft' => kAccent,
      _ => kSoft,
    };

class DocumentsScreen extends StatefulWidget {
  final ApiClient api;
  const DocumentsScreen({super.key, required this.api});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _q = TextEditingController();
  String _status = '';
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.documents();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _f = widget.api.documents(q: _q.text.trim(), status: _status));

  @override
  Widget build(BuildContext context) {
    return screen(
      'ПРИКАЗЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(children: [
            Row(children: [
              Expanded(child: searchBox(_q, hint: 'Поиск: номер, заголовок', onSubmit: _reload)),
              IconButton(onPressed: _reload, icon: const Icon(Icons.search, color: kSoft)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              chip('все', _status == '', () { setState(() => _status = ''); _reload(); }),
              const SizedBox(width: 4),
              chip('проект', _status == 'draft', () { setState(() => _status = 'draft'); _reload(); }),
              const SizedBox(width: 4),
              chip('действует', _status == 'active', () { setState(() => _status = 'active'); _reload(); }),
              const SizedBox(width: 4),
              chip('отменён', _status == 'cancelled', () { setState(() => _status = 'cancelled'); _reload(); }),
            ]),
            const SizedBox(height: 10),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return loading();
              if (snap.hasError) return errorState(snap.error!);
              final items = snap.data ?? [];
              return RefreshIndicator(
                color: kAccent,
                onRefresh: () async => _reload(),
                child: items.isEmpty
                    ? ListView(children: [const SizedBox(height: 120), empty('Приказов нет')])
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: items.map((d) => card(
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text('${d['num']} · ${d['title']}', style: kTitle)),
                                  if (d['need_sign'] == true) Padding(padding: const EdgeInsets.only(right: 4), child: tag('НА ПОДПИСЬ', kAccent)),
                                  tag(_docStatus['${d['status']}'] ?? '${d['status']}', _stColor('${d['status']}')),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text('${d['date']}', style: kSub),
                                  const Spacer(),
                                  if (d['has_pdf'] == true) const Icon(Icons.picture_as_pdf_outlined, size: 14, color: kMute),
                                ]),
                              ]),
                              onTap: () => _open(d['id'] as int),
                            )).toList(),
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocumentDetailScreen(api: widget.api, id: id)));
    _reload();
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
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.document(widget.id);
  }

  void _reload() => setState(() => _f = widget.api.document(widget.id));

  Future<void> _sign(int signId, String status) async {
    try {
      await widget.api.sign(widget.id, signId, status);
      _reload();
    } catch (e) {
      if (mounted) toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'ПРИКАЗ',
      FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final d = snap.data ?? {};
          final signs = (d['signatories'] as List? ?? []).cast<Map<String, dynamic>>();
          final mine = signs.where((s) => s['mine'] == true && s['status'] == 'pending').toList();
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['num']}', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${d['title']}', style: kTitle),
                const SizedBox(height: 8),
                infoRow('Дата', '${d['date']}'),
                infoRow('Тип', '${d['type'] ?? ''}'),
                infoRow('Статус', '${d['status_label'] ?? d['status']}'),
                infoRow('Версия', '${d['version'] ?? 1}'),
              ])),
              if (('${d['summary'] ?? ''}').isNotEmpty) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Кратко', style: kMuted),
                Text('${d['summary']}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12)),
              ])),
              if (('${d['body'] ?? ''}').isNotEmpty) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Текст', style: kMuted),
                Text('${d['body']}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12)),
              ])),
              if (('${d['file_url'] ?? ''}').isNotEmpty)
                card(Row(children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: kAccent),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('PDF-версия приказа', style: kTitle)),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://chzog.iniproject.ru${d['file_url']}'), mode: LaunchMode.externalApplication),
                    child: const Text('Открыть', style: TextStyle(color: kAccent, fontFamily: 'monospace')),
                  ),
                ])),
              groupHeader('ПОДПИСИ'),
              ...signs.map((s) => card(Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['position'] ?? ''}', style: kSub),
                      Text('${s['name']}', style: kTitle),
                    ])),
                    tag('${s['status']}', s['status'] == 'signed' ? kAccent2 : (s['status'] == 'rejected' ? kDanger : kSoft)),
                  ]))),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => _sign(mine.first['id'] as int, 'signed'),
                  child: const Text('ПОДПИСАТЬ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger), shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => _sign(mine.first['id'] as int, 'rejected'),
                  child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ],
              creditFooter(),
            ],
          );
        },
      ),
    );
  }
}
