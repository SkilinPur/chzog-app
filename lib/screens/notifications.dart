import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class NotificationsScreen extends StatefulWidget {
  final ApiClient api;
  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.notifications();
  }

  void _reload() => setState(() => _f = widget.api.notifications());

  Future<void> _readAll() async {
    try {
      await widget.api.notificationsRead();
      _reload();
    } catch (e) {
      if (mounted) toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  Future<void> _read(int id) async {
    try {
      await widget.api.notificationRead(id);
      _reload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'УВЕДОМЛЕНИЯ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final items = snap.data ?? [];
          final unread = items.where((n) => n['read'] != true).length;
          return Column(children: [
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(children: [
                  Text('непрочитанных: $unread', style: kSub),
                  const Spacer(),
                  TextButton(onPressed: _readAll, child: const Text('Прочитать всё', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
                ]),
              ),
            Expanded(
              child: RefreshIndicator(
                color: kAccent,
                onRefresh: () async => _reload(),
                child: items.isEmpty
                    ? ListView(children: [const SizedBox(height: 120), empty('Уведомлений нет')])
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: items.map((n) => card(
                              border: n['read'] == true ? kLine : kAccent,
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  if (n['read'] != true) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.circle, size: 8, color: kAccent)),
                                  Expanded(child: Text('${n['title']}', style: kTitle)),
                                ]),
                                if (('${n['body'] ?? ''}').isNotEmpty)
                                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('${n['body']}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12))),
                                const SizedBox(height: 4),
                                Text(fmtDateTime(n['created_at']), style: kMuted),
                              ]),
                              onTap: n['read'] == true ? null : () => _read(n['id'] as int),
                            )).toList(),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
