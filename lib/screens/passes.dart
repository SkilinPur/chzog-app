import 'package:flutter/material.dart';

import '../api.dart';
import '../queue.dart';
import '../scan.dart';
import '../theme.dart';
import '../ui.dart';

class PassesScreen extends StatefulWidget {
  final ApiClient api;
  const PassesScreen({super.key, required this.api});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  late Future<List<Map<String, dynamic>>> _passes;
  List<Map<String, dynamic>> _locations = [];
  int? _locId;
  String? _msg;
  bool _onSite = false;
  String _stateLoc = '';
  String _stateSince = '';
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _passes = widget.api.passes();
    widget.api.locations().then((l) {
      OfflineQueue.cacheLocations(l);
      if (mounted) {
        setState(() {
          _locations = l;
          _locId = l.isNotEmpty ? l.first['id'] as int : null;
        });
      }
    }).catchError((_) async {
      final cached = await OfflineQueue.cachedLocations();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _locations = cached;
          _locId = cached.first['id'] as int;
        });
      }
    });
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final st = await widget.api.passState();
      if (mounted) {
        setState(() {
          _onSite = st['on_site'] == true;
          _stateLoc = st['location']?.toString() ?? '';
          _stateSince = st['since']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  String _sinceLocal() {
    final d = DateTime.tryParse(_stateSince);
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _duration() {
    final d = DateTime.tryParse(_stateSince);
    if (d == null) return '';
    final diff = DateTime.now().toUtc().difference(d.toUtc());
    if (diff.isNegative) return '';
    final h = diff.inHours, m = diff.inMinutes % 60;
    return h > 0 ? '$h ч $m м' : '$m м';
  }

  Future<void> _checkin() async {
    final locName = (_onSite && _stateLoc.isNotEmpty)
        ? _stateLoc
        : _locations.firstWhere((l) => l['id'] == _locId, orElse: () => {'name': 'КПП-1'})['name'] as String;
    final pos = await currentPosition();
    try {
      final dir = await widget.api.checkin(locName, lat: pos?.latitude, lng: pos?.longitude, accuracy: pos?.accuracy);
      if (!mounted) return;
      setState(() => _msg = (dir == 'out' ? 'Отмечен выход' : 'Отмечен вход') + (pos != null ? ' · GPS' : ''));
      setState(() => _passes = widget.api.passes());
      await _loadStatus();
    } catch (e) {
      if (isOffline(e)) {
        await OfflineQueue.add(PendingAction('checkin_loc', {
          'location': locName,
          'lat': pos?.latitude, 'lng': pos?.longitude, 'accuracy': pos?.accuracy,
        }));
        if (!mounted) return;
        setState(() => _msg = 'Нет сети — сохранено, отправим позже');
      } else {
        setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
      }
    }
  }

  Future<void> _checkinQr() async {
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (raw == null || !mounted) return;
    final token = qrToken(raw);
    if (token == null) {
      setState(() => _msg = 'Неверный QR-код');
      return;
    }
    setState(() => _msg = 'Определяю геопозицию…');
    final pos = await currentPosition();
    try {
      final dir = await widget.api.checkinQr(token, lat: pos?.latitude, lng: pos?.longitude, accuracy: pos?.accuracy);
      if (!mounted) return;
      setState(() => _msg = (dir == 'out' ? 'Отмечен выход' : 'Отмечен вход') + ' · QR' + (pos != null ? ' · GPS' : ''));
      setState(() => _passes = widget.api.passes());
      await _loadStatus();
    } catch (e) {
      if (isOffline(e)) {
        await OfflineQueue.add(PendingAction('checkin', {
          'qr': token,
          'lat': pos?.latitude, 'lng': pos?.longitude, 'accuracy': pos?.accuracy,
        }));
        if (!mounted) return;
        setState(() => _msg = 'Нет сети — сохранено, отправим позже');
      } else {
        setState(() => _msg = e is ApiException ? e.message : 'Ошибка');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return screen(
      'ПРОХОДЫ',
      Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: card(
            border: _onSite ? kAccent2 : kLine,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_onSite ? Icons.login : Icons.logout, color: _onSite ? kAccent2 : kSoft),
                const SizedBox(width: 10),
                Text(_onSite ? 'НА ОБЪЕКТЕ' : 'НЕ НА ОБЪЕКТЕ',
                    style: TextStyle(color: _onSite ? kAccent2 : kSoft, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
              ]),
              if (_onSite && _stateLoc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('$_stateLoc · с ${_sinceLocal()}${_duration().isEmpty ? '' : ' · ${_duration()}'}',
                      style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('loc-$_locId'),
                    initialValue: _locId,
                    isExpanded: true,
                    dropdownColor: kPanel,
                    decoration: const InputDecoration(labelText: 'Объект', isDense: true),
                    items: _locations.map((l) => DropdownMenuItem<int>(value: l['id'] as int, child: Text('${l['name']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _locId = v),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: kAccent2, side: const BorderSide(color: kAccent2), shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
                  onPressed: _checkinQr,
                  child: const Text('QR', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
                  onPressed: _locations.isEmpty ? null : _checkin,
                  child: Text(_onSite ? 'ВЫЙТИ' : 'ВОЙТИ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ]),
              if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: kAccent2, fontFamily: 'monospace', fontSize: 12))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            chip('ВСЕ', _filter == 0, () => setState(() => _filter = 0)),
            const SizedBox(width: 4),
            chip('ВХОДЫ', _filter == 1, () => setState(() => _filter = 1)),
            const SizedBox(width: 4),
            chip('ВЫХОДЫ', _filter == 2, () => setState(() => _filter = 2)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _passes,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return loading();
              if (snap.hasError) return errorState(snap.error!);
              final items = (snap.data ?? []).where((p) {
                if (_filter == 1) return p['direction'] == 'in';
                if (_filter == 2) return p['direction'] == 'out';
                return true;
              }).toList();
              if (items.isEmpty) return empty('Проходов нет');
              return RefreshIndicator(
                color: kAccent,
                onRefresh: () async {
                  setState(() => _passes = widget.api.passes());
                  await _loadStatus();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: items.map((p) {
                    final out = p['direction'] == 'out';
                    return card(Row(children: [
                      Icon(out ? Icons.logout : Icons.login, color: out ? kAccent : kAccent2, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${out ? 'Выход' : 'Вход'} · ${p['location'] ?? ''}', style: kTitle),
                        Text(fmtDateTime(p['at']), style: kSub),
                      ])),
                    ]));
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
