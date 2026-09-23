import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'theme.dart';

class Updater {
  static Future<void> check(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final resp = await http
          .get(Uri.parse('${ApiClient.base}/api/app/version'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final d = jsonDecode(resp.body) as Map<String, dynamic>;
      if (d['ok'] != true) return;
      final remote = (d['version'] ?? '').toString();
      if (remote.isEmpty || !_newer(remote, current)) return;
      if (!context.mounted) return;
      await _prompt(context, remote, ApiClient.base + (d['url'] as String));
    } catch (_) {}
  }

  static List<int> _parts(String v) =>
      v.split(RegExp(r'[^0-9]+')).where((e) => e.isNotEmpty).map(int.parse).toList();

  static bool _newer(String remote, String current) {
    final a = _parts(remote), b = _parts(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> _prompt(BuildContext context, String version, String url) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Доступно обновление',
            style: TextStyle(fontFamily: 'monospace', color: kAccent)),
        content: Text('Новая версия: $version\n\nСкачать и установить?',
            style: const TextStyle(fontFamily: 'monospace', color: kText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Позже', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('СКАЧАТЬ', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    await _downloadAndInstall(context, url);
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url) async {
    final progress = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Загрузка…', style: TextStyle(fontFamily: 'monospace', color: kText)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => LinearProgressIndicator(
              value: v <= 0 ? null : v, color: kAccent, backgroundColor: kLine),
        ),
      ),
    );
    try {
      final client = http.Client();
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      final total = resp.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chzog-update.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp.stream) {
        received += chunk.length;
        if (total > 0) progress.value = received / total;
        sink.add(chunk);
      }
      await sink.close();
      client.close();
      if (context.mounted) Navigator.of(context).pop();
      await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось скачать: $e', style: const TextStyle(fontFamily: 'monospace'))));
      }
    }
  }
}
