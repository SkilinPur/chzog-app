import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class _Msg {
  final String sender;
  final String text;
  _Msg(this.sender, this.text);
}

class _Room {
  final String name;
  final String id;
  _Room(this.name, this.id);
}

class ChatScreen extends StatefulWidget {
  final ApiClient api;
  const ChatScreen({super.key, required this.api});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _hs = '';
  String _token = '';
  String _userId = '';
  final List<_Room> _rooms = [];
  final Map<String, List<_Msg>> _msgs = {};
  List<Map<String, dynamic>> _members = [];
  String _selected = '';
  String? _err;
  Timer? _timer;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final t = await widget.api.chatToken();
      _hs = t['homeserver'] as String;
      _token = t['access_token'] as String;
      _userId = t['user_id'] as String;
      final r = await widget.api.chatRooms();
      final general = (r['general'] ?? '') as String;
      final dept = (r['department'] ?? '') as String;
      _members = (r['members'] as List? ?? []).cast<Map<String, dynamic>>();
      if (general.isNotEmpty) _rooms.add(_Room('ОБЩИЙ', general));
      if (dept.isNotEmpty) _rooms.add(_Room('ОТДЕЛ', dept));
      if (_rooms.isNotEmpty) _selected = _rooms.first.id;
      await _sync();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _sync());
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _sync() async {
    try {
      final resp = await http.get(
        Uri.parse('$_hs/_matrix/client/v3/sync?timeout=0'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final d = jsonDecode(resp.body) as Map<String, dynamic>;
      final join = d['rooms']?['join'] as Map<String, dynamic>?;
      if (join == null) return;
      final map = <String, List<_Msg>>{};
      for (final e in _rooms) {
        final room = join[e.id] as Map<String, dynamic>?;
        final events = (room?['timeline']?['events'] as List?) ?? [];
        final list = <_Msg>[];
        for (final ev in events) {
          if (ev['type'] == 'm.room.message') {
            list.add(_Msg(ev['sender']?.toString() ?? '', (ev['content']?['body'] ?? '').toString()));
          }
        }
        map[e.id] = list;
      }
      if (mounted) setState(() => _msgs..clear()..addAll(map));
    } catch (_) {}
  }

  Future<void> _openDm(Map<String, dynamic> m) async {
    try {
      final roomId = await widget.api.chatDm(m['id'] as int);
      if (roomId.isEmpty) return;
      if (!_rooms.any((r) => r.id == roomId)) {
        _rooms.add(_Room('${m['name']}', roomId));
      }
      setState(() => _selected = roomId);
      await _sync();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _pickDm() async {
    if (_members.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text('Личный чат', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView(
            children: _members.map((m) => ListTile(
                  dense: true,
                  title: Text('${m['name']}', style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
                  onTap: () { Navigator.pop(context); _openDm(m); },
                )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _selected.isEmpty) return;
    try {
      final txn = DateTime.now().millisecondsSinceEpoch.toString();
      final resp = await http.put(
        Uri.parse('$_hs/_matrix/client/v3/rooms/${Uri.encodeComponent(_selected)}/send/m.room.message/$txn'),
        headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
        body: jsonEncode({'msgtype': 'm.text', 'body': text}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _input.clear();
        await _sync();
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  String _name(String sender) {
    if (sender == _userId) return 'вы';
    final local = sender.split(':').first;
    return local.startsWith('@') ? local.substring(1) : local;
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _msgs[_selected] ?? [];
    return screen(
      'ЧАТ',
      _err != null
          ? errorState(_err!)
          : (_rooms.isEmpty
              ? loading()
              : Column(children: [
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        for (final r in _rooms)
                          Padding(
                            padding: const EdgeInsets.only(right: 6, top: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = r.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selected == r.id ? kAccent : kPanel,
                                  border: Border.all(color: _selected == r.id ? kAccent : kLine),
                                ),
                                child: Text(r.name, style: TextStyle(color: _selected == r.id ? kBg : kSoft, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 6),
                          child: IconButton(
                            tooltip: 'Личный чат',
                            onPressed: _pickDm,
                            icon: Icon(Icons.person_add_alt_1, color: kAccent, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[msgs.length - 1 - i];
                        final mine = m.sender == _userId;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: mine ? kAccent.withValues(alpha: 0.2) : kPanel,
                              border: Border.all(color: mine ? kAccent : kLine),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(m.text, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(_name(m.sender), style: kMuted),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
                          decoration: const InputDecoration(labelText: 'Сообщение', isDense: true),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: _send, icon: Icon(Icons.send, color: kAccent)),
                    ]),
                  ),
                ])),
    );
  }
}
