import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class RequestScreen extends StatefulWidget {
  final ApiClient api;
  const RequestScreen({super.key, required this.api});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'bug';
  String? _msg;
  bool _sending = false;
  late Future<List<Map<String, dynamic>>> _f;

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
    return screen(
      'ЗАЯВКА',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('ТИП', style: kSub),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: kKindLabels.entries.map((e) {
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
          field('Тема', _title),
          field('Описание', _body, maxLines: 4),
          const SizedBox(height: 6),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'ОТПРАВКА…' : 'ОТПРАВИТЬ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
          const SizedBox(height: 18),
          groupHeader('МОИ ЗАЯВКИ'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return loading();
              if (snap.hasError) return errorState(snap.error!);
              final items = snap.data ?? [];
              if (items.isEmpty) return empty('Заявок нет');
              return Column(
                children: items.map((r) => card(Row(children: [
                      Icon(Icons.assignment_outlined, color: _st('${r['status']}'), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['title']}', style: kTitle),
                        Text('${kindLabel('${r['kind']}')} · ${r['status']}', style: kSub),
                      ])),
                    ]))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
