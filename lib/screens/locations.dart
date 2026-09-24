import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import 'webview_screen.dart';

class LocationsScreen extends StatefulWidget {
  final ApiClient api;
  const LocationsScreen({super.key, required this.api});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _q = TextEditingController();
  String _type = '';
  List<String> _types = [];
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() => widget.api.locationsData(q: _q.text.trim(), type: _type);

  void _reload() => setState(() => _f = _load());

  @override
  Widget build(BuildContext context) {
    return screen(
      'ОБЪЕКТЫ',
      FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final d = snap.data ?? {};
          final items = (d['items'] as List? ?? []).cast<Map<String, dynamic>>();
          final types = (d['types'] as List? ?? []).cast<String>();
          if (_types.isEmpty && types.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _types = types); });
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                Expanded(child: searchBox(_q, hint: 'Поиск: название, зоны', onSubmit: _reload)),
                IconButton(onPressed: _reload, icon: const Icon(Icons.search, color: kSoft)),
              ]),
            ),
            if (_types.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _typeChip('все', ''),
                    ..._types.map((t) => _typeChip(t, t)),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: kAccent,
                onRefresh: () async => _reload(),
                child: items.isEmpty
                    ? ListView(children: [const SizedBox(height: 120), empty('Объектов нет')])
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: items.map(_locCard).toList(),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _typeChip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 6, top: 6),
        child: GestureDetector(
          onTap: () { setState(() => _type = value); _reload(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _type == value ? kAccent : kPanel,
              border: Border.all(color: _type == value ? kAccent : kLine),
            ),
            child: Text(label, style: TextStyle(color: _type == value ? kBg : kSoft, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      );

  Widget _locCard(Map<String, dynamic> l) {
    final photo = '${l['photo'] ?? ''}';
    final url = photo.isEmpty ? '' : 'https://chzog.iniproject.ru$photo';
    return card(
      Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: kBg, border: Border.all(color: kLine)),
          child: url.isEmpty
              ? Icon(Icons.location_city_outlined, color: kAccent, size: 22)
              : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.location_city_outlined, color: kAccent, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['name']}', style: kTitle),
            Text('${l['type'] ?? ''}${('${l['status'] ?? ''}').isEmpty ? '' : ' · ${l['status']}'}${('${l['zones'] ?? ''}').isEmpty ? '' : ' · ${l['zones']}'}', style: kSub),
          ]),
        ),
        const Icon(Icons.chevron_right, color: kMute),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocationDetailScreen(api: widget.api, id: l['id'] as int))),
    );
  }
}

class LocationDetailScreen extends StatefulWidget {
  final ApiClient api;
  final int id;
  const LocationDetailScreen({super.key, required this.api, required this.id});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.location(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'ОБЪЕКТ',
      FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return loading();
          if (snap.hasError) return errorState(snap.error!);
          final l = snap.data ?? {};
          final photo = '${l['photo'] ?? ''}';
          final photoUrl = photo.isEmpty ? '' : 'https://chzog.iniproject.ru$photo';
          final lat = l['lat'];
          final lng = l['lng'];
          final coords = (lat != null && lng != null) ? '$lat,$lng' : '';
          final mapUrl = coords.isEmpty
              ? '${l['coords_url'] ?? ''}'
              : 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng';
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (photoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebViewScreen(title: '${l['name']}', url: photoUrl))),
                    child: Container(
                      height: 220,
                      width: double.maxFinite,
                      color: kBg,
                      child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('Нет фото', style: kMuted))),
                    ),
                  ),
                ),
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['name']}', style: TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                infoRow('Тип', '${l['type'] ?? ''}'),
                infoRow('Состояние', '${l['status'] ?? ''}'),
                infoRow('Зоны', '${l['zones'] ?? ''}'),
                if (('${l['description'] ?? ''}').isNotEmpty) infoRow('Описание', '${l['description']}'),
              ])),
              if (mapUrl.isNotEmpty)
                card(Row(children: [
                  Icon(Icons.map_outlined, color: kAccent),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Координаты', style: kTitle)),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication),
                    child: Text('На карте', style: TextStyle(color: kAccent, fontFamily: 'monospace')),
                  ),
                ])),
              creditFooter(),
            ],
          );
        },
      ),
    );
  }
}
