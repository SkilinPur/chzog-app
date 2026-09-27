import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../api.dart';
import '../fcm.dart';
import '../theme.dart';
import '../ui.dart';

class _Room {
  final int id;
  final String name;
  _Room(this.id, this.name);
}

class ChatScreen extends StatefulWidget {
  final ApiClient api;
  const ChatScreen({super.key, required this.api});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = InMemoryChatController();
  final List<_Room> _rooms = [];
  List<Map<String, dynamic>> _members = [];
  final Map<String, String> _names = {};
  int _me = 0;
  int _selected = 0;
  String? _err;

  Client? _client;
  final Map<int, Subscription> _subs = {};

  @override
  void initState() {
    super.initState();
    _init();
    chatEvents.stream.listen(_onChatEvent);
  }

  @override
  void dispose() {
    currentChatRoom.value = 0;
    for (final s in _subs.values) {
      s.unsubscribe();
    }
    _client?.disconnect();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final r = await widget.api.chatRooms();
      _me = (r['me'] ?? 0) as int;
      _members = (r['members'] as List? ?? []).cast<Map<String, dynamic>>();
      _names.clear();
      for (final m in _members) {
        _names['${m['id']}'] = '${m['name']}';
      }
      final rooms = (r['rooms'] as List? ?? []).cast<Map<String, dynamic>>();
      _rooms.clear();
      _rooms.addAll(rooms.map((x) => _Room(x['id'] as int, x['name']?.toString() ?? '')));
      if (_rooms.isNotEmpty) {
        _selected = _rooms.first.id;
        currentChatRoom.value = _selected;
      }
      await _loadHistory();
      _connectRealtime(r['rt']);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _connectRealtime(Map<String, dynamic>? rt) async {
    if (rt == null || (rt['token'] ?? '').toString().isEmpty) return;
    final url = rt['url']?.toString() ?? '';
    final token = rt['token']?.toString() ?? '';
    if (url.isEmpty || token.isEmpty) return;
    try {
      final c = createClient(url, ClientConfig(token: token));
      _client = c;
      c.error.listen((_) {});
      for (final room in _rooms) {
        final sub = c.newSubscription('chat${room.id}');
        _subs[room.id] = sub;
        sub.publication.listen((e) => _onPub(room.id, e));
        sub.subscribe();
      }
      await c.connect();
    } catch (_) {}
  }

  void _onPub(int room, PublicationEvent e) {
    try {
      final d = jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>;
      if ((d['room'] ?? 0) != room) return;
      _upsert(room, d);
    } catch (_) {}
  }

  void _onChatEvent(Map<String, dynamic> e) {
    final room = int.tryParse('${e['room'] ?? ''}') ?? 0;
    if (room == 0) return;
    if (room == _selected) {
      _upsert(room, e);
    } else if (!_rooms.any((x) => x.id == room)) {
      _init();
    }
  }

  void _upsert(int room, Map<String, dynamic> d) {
    final id = '${d['id'] ?? ''}';
    if (id.isEmpty) return;
    if (room != _selected) return;
    final existing = _controller.messages.any((m) => m.id == id);
    if (existing) return;
    _controller.insertMessage(
      TextMessage(
        id: id,
        authorId: '${d['sender_id'] ?? 0}',
        createdAt: DateTime.tryParse('${d['at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        text: '${d['body'] ?? ''}',
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (_selected == 0) return;
    final items = await widget.api.chatMessages(_selected);
    _controller.setMessages(items.map((e) {
      final senderId = '${e['sender_id'] ?? 0}';
      _names[senderId] = e['sender']?.toString() ?? _names[senderId] ?? '';
      return TextMessage(
        id: '${e['id']}',
        authorId: senderId,
        createdAt: DateTime.tryParse('${e['at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        text: e['body']?.toString() ?? '',
      );
    }).toList());
  }

  Future<void> _selectRoom(int id) async {
    if (id == _selected) return;
    setState(() {
      _selected = id;
      currentChatRoom.value = id;
    });
    await _loadHistory();
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _selected == 0) return;
    final res = await widget.api.chatSend(_selected, body);
    final id = res['id'];
    if (id != null) {
      _controller.insertMessage(
        TextMessage(
          id: '$id',
          authorId: '$_me',
          createdAt: DateTime.now(),
          text: body,
        ),
      );
    }
  }

  Future<void> _openDm(Map<String, dynamic> m) async {
    try {
      final room = await widget.api.chatDm(m['id'] as int);
      if (room == 0) return;
      if (!_rooms.any((r) => r.id == room)) {
        _rooms.add(_Room(room, '${m['name']}'));
        final sub = _client?.newSubscription('chat$room');
        if (sub != null) {
          _subs[room] = sub;
          sub.publication.listen((e) => _onPub(room, e));
          sub.subscribe();
        }
      }
      await _selectRoom(room);
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
                              onTap: () => _selectRoom(r.id),
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
                    child: Chat(
                      chatController: _controller,
                      currentUserId: '$_me',
                      theme: ChatTheme.dark(fontFamily: 'monospace'),
                      onMessageSend: (text) => _send(text),
                      resolveUser: (id) async => User(id: id, name: _names[id] ?? 'Участник'),
                    ),
                  ),
                ])),
    );
  }
}
