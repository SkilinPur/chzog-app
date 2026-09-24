import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'theme.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    _controller.stop();
    Navigator.of(context).pop(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('СКАНЕР QR', style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
      ),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(10),
            color: kBg.withValues(alpha: 0.75),
            child: const Text('Наведите камеру на QR-код объекта',
                style: TextStyle(fontFamily: 'monospace', color: kText, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

Future<void> reportPosition(dynamic api) async {
  final pos = await currentPosition();
  if (pos == null) return;
  try {
    await api.position(pos.latitude, pos.longitude);
  } catch (_) {}
}

String? qrToken(String raw) {
  const prefix = 'CHZOG-LOC:';
  final t = raw.trim();
  if (t.startsWith(prefix)) {
    final v = t.substring(prefix.length).trim();
    return v.isEmpty ? null : v;
  }
  return t.isEmpty ? null : t;
}

Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  } catch (_) {
    return null;
  }
}
