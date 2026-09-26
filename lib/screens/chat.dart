import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class _Room {
  final int id;
  final String name;
  _Room(this.id, this.name);
}

class _Msg {
  final String sender;
  final String body;
  final bool mine;
  _Msg(this.sender, this.body, this.mine);
}

class ChatScreen extends StatefulWidget {
  final ApiClient api;
  const ChatScreen({super.key, required this.api});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Room> _rooms = [];
  List<Map<String, dynamic>> _members = [];
  int _me = 0;
  int _selected = 0;
  List<_Msg> _msgs = [];
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
      final r = await widget.api.chatRooms();
      _me = (r['me'] ?? 0) as int;
      _members = (r['members'] as List? ?? []).cast<Map<String, dynamic>>();
      final rooms = (r['rooms'] as List? ?? []).cast<Map<String, dynamic>>();
      _rooms.clear();
      _rooms.addAll(rooms.map((x) => _Room(x['id'] as int, x['name']?.toString() ?? '')));
      if (_rooms.isNotEmpty) _selected = _rooms.first.id;
      await _sync();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _sync());
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _sync() async {
    if (_selected == 0) return;
    try {
      final items = await widget.api.chatMessages(_selected);
      if (mounted) {
        setState(() => _msgs = items
            .map((e) => _Msg(e['sender']?.toString() ?? '', e['body']?.toString() ?? '', (e['sender_id'] ?? 0) == _me))
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _openDm(Map<String, dynamic> m) async {
    try {
      final room = await widget.api.chatDm(m['id'] as int);
      if (room == 0) return;
      if (!_rooms.any((r) => r.id == room)) {
        _rooms.add(_Room(room, '${m['name']}'));
      }
      setState(() => _selected = room);
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
    if (text.isEmpty || _selected == 0) return;
    try {
      await widget.api.chatSend(_selected, text);
      _input.clear();
      await _sync();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              onTap: () { setState(() => _selected = r.id); _sync(); },
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
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[_msgs.length - 1 - i];
                        return Align(
                          alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: m.mine ? kAccent.withValues(alpha: 0.2) : kPanel,
                              border: Border.all(color: m.mine ? kAccent : kLine),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(m.body, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(m.mine ? 'вы' : m.sender, style: kMuted),
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
