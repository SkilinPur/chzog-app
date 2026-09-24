import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class NewsScreen extends StatefulWidget {
  final ApiClient api;
  const NewsScreen({super.key, required this.api});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<Map<String, dynamic>>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.news();
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'НОВОСТИ',
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final items = snap.data ?? [];
          return RefreshIndicator(
            color: kAccent,
            onRefresh: () async => setState(() => _f = widget.api.news()),
            child: items.isEmpty
                ? ListView(children: [const SizedBox(height: 120), empty('Новостей нет')])
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: items.map((n) => card(
                          border: n['pinned'] == true ? kAccent : kLine,
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (n['pinned'] == true) Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 14, color: kAccent)),
                              Expanded(child: Text('${n['title']}', style: kTitle)),
                            ]),
                            const SizedBox(height: 4),
                            Text('${n['author'] ?? ''} · ${fmtDateTime(n['created_at'])}', style: kSub),
                            if (('${n['body'] ?? ''}').isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 6), child: Text('${n['body']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12))),
                          ]),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsDetailScreen(item: n))),
                        )).toList(),
                  ),
          );
        },
      ),
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const NewsDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => screen(
        'НОВОСТЬ',
        ListView(
          padding: const EdgeInsets.all(14),
          children: [
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['title']}', style: TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('${item['author'] ?? ''} · ${fmtDateTime(item['created_at'])}', style: kSub),
            ])),
            if (('${item['body'] ?? ''}').isNotEmpty)
              card(Text('${item['body']}', style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13, height: 1.5))),
            creditFooter(),
          ],
        ),
      );
}
