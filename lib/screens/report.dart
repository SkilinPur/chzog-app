import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../scan.dart';
import '../theme.dart';
import '../ui.dart';

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
  List<Map<String, dynamic>> _templates = [];
  int? _locId;
  String _kind = 'incident';
  String _severity = 'medium';
  String? _photoPath;
  String? _msg;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.api.locations().then((l) { if (mounted) setState(() => _locations = l); }).catchError((_) {});
    widget.api.incidentTemplates().then((t) { if (mounted) setState(() => _templates = t); }).catchError((_) {});
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
      if (mounted) setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'ИНЦИДЕНТ',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_templates.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('tpl-${_title.text}'),
              initialValue: null,
              isExpanded: true,
              dropdownColor: kPanel,
              decoration: const InputDecoration(labelText: 'Шаблон (заполнить)'),
              items: _templates.map((t) => DropdownMenuItem<String>(
                    value: '${t['title']}',
                    child: Text('${t['title']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13), overflow: TextOverflow.ellipsis),
                  )).toList(),
              onChanged: (v) {
                final t = _templates.firstWhere((x) => '${x['title']}' == v, orElse: () => {});
                if (t.isEmpty) return;
                setState(() {
                  _kind = t['kind']?.toString() ?? 'incident';
                  _severity = t['severity']?.toString() ?? 'medium';
                  _title.text = t['title']?.toString() ?? '';
                  _details.text = t['details']?.toString() ?? '';
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          const Text('ТИП', style: kSub),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: kIncidentKinds.entries.map((e) => _pick(e.key, _kind, e.value, (v) => setState(() => _kind = v))).toList()),
          const SizedBox(height: 14),
          const Text('ВАЖНОСТЬ', style: kSub),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: kSeverities.entries.map((e) => _pick(e.key, _severity, e.value, (v) => setState(() => _severity = v))).toList()),
          const SizedBox(height: 14),
          field('Заголовок', _title),
          field('Описание', _details, maxLines: 4),
          DropdownButtonFormField<int>(
            key: ValueKey('loc-$_locId'),
            initialValue: _locId,
            isExpanded: true,
            dropdownColor: kPanel,
            decoration: const InputDecoration(labelText: 'Объект'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('— не указан —', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
              ..._locations.map((l) => DropdownMenuItem<int>(value: l['id'] as int, child: Text('${l['name']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))),
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
            if (_photoPath != null) const Expanded(child: Text('снимок прикреплён', style: TextStyle(fontFamily: 'monospace', color: kAccent2, fontSize: 12))),
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
