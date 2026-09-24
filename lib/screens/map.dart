import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api.dart';
import '../ui.dart';

class MapScreen extends StatefulWidget {
  final ApiClient api;
  const MapScreen({super.key, required this.api});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  WebViewController? _controller;
  String? _err;

  List<double>? _coords(Map<String, dynamic> l) {
    final lat = l['lat'], lng = l['lng'];
    if (lat is num && lng is num) return [lat.toDouble(), lng.toDouble()];
    final url = '${l['coords_url'] ?? ''}';
    if (url.isEmpty) return null;
    final m1 = RegExp(r'[?&]lat=([\d.\-]+)').firstMatch(url);
    final m2 = RegExp(r'[?&]lon=([\d.\-]+)').firstMatch(url);
    if (m1 != null && m2 != null) {
      final a = double.tryParse(m1.group(1)!);
      final b = double.tryParse(m2.group(1)!);
      if (a != null && b != null) return [a, b];
    }
    final f = RegExp(r'#map=\d+/([\d.\-]+)/([\d.\-]+)').firstMatch(url);
    if (f != null) {
      final a = double.tryParse(f.group(1)!);
      final b = double.tryParse(f.group(2)!);
      if (a != null && b != null) return [a, b];
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    try {
      final items = await widget.api.locations();
      final markers = items.where((l) => _coords(l) != null).toList();
      final js = markers.map((l) {
        final c = _coords(l)!;
        final name = jsonEncode('${l['name']}');
        final type = jsonEncode('${l['type'] ?? ''}');
        return 'var m = L.marker([${c[0]}, ${c[1]}]).addTo(map);\n'
            'm.bindPopup("<b>" + $name + "</b><br>" + $type);';
      }).join('\n');
      final center = markers.isNotEmpty
          ? 'map.fitBounds(L.latLngBounds([${markers.map((l) { final c = _coords(l)!; return '[${c[0]},${c[1]}]'; }).join(',')}]));'
          : "map.setView([69.35, 88.20], 11);";
      final html = '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>html,body,#map{height:100%;margin:0;background:#0b0e11}</style>
</head><body><div id="map"></div><script>
var map = L.map('map');
$center
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom:18}).addTo(map);
$js
</script></body></html>''';
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B0E11))
        ..loadHtmlString(html);
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'КАРТА ОБЪЕКТОВ',
      _err != null
          ? errorState(_err!)
          : (_controller == null
              ? loading()
              : WebViewWidget(controller: _controller!)),
    );
  }
}
