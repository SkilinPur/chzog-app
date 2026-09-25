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
  String _roomId = '';
  List<_Msg> _messages = [];
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
      _roomId = t['general_room'] as String;
      await _sync();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _sync());
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Map<String, String> _headers() => {'Authorization': 'Bearer $_token'};

  Future<void> _sync() async {
    try {
      final r = await http.get(
        Uri.parse('$_hs/_matrix/client/v3/sync?timeout=0'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final join = d['rooms']?['join'] as Map<String, dynamic>?;
      final room = join?[_roomId] as Map<String, dynamic>?;
      final events = (room?['timeline']?['events'] as List?) ?? [];
      final msgs = <_Msg>[];
      for (final e in events) {
        if (e['type'] == 'm.room.message') {
          msgs.add(_Msg(e['sender']?.toString() ?? '', (e['content']?['body'] ?? '').toString()));
        }
      }
      if (mounted) setState(() => _messages = msgs);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    try {
      final txn = DateTime.now().millisecondsSinceEpoch.toString();
      final r = await http.put(
        Uri.parse('$_hs/_matrix/client/v3/rooms/${Uri.encodeComponent(_roomId)}/send/m.room.message/$txn'),
        headers: {..._headers(), 'Content-Type': 'application/json'},
        body: jsonEncode({'msgtype': 'm.text', 'body': text}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
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
    return screen(
      'ЧАТ',
      _err != null
          ? errorState(_err!)
          : (_roomId.isEmpty
              ? loading()
              : Column(children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[_messages.length - 1 - i];
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
