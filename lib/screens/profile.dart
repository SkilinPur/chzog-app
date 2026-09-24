import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

const _title = TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold);
const _sub = TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11);
const _muted = TextStyle(color: kMute, fontFamily: 'monospace', fontSize: 11);

Widget _field(String label, TextEditingController c, {bool obscure = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
        decoration: InputDecoration(labelText: label),
      ),
    );

Widget _card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
      child: child,
    );

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(k, style: _muted)),
        Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12))),
      ]),
    );

void _toast(BuildContext context, String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'monospace')), backgroundColor: error ? kDanger : null));

class ProfileScreen extends StatefulWidget {
  final ApiClient api;
  const ProfileScreen({super.key, required this.api});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.api.profile();
  }

  void _reload() => setState(() => _f = widget.api.profile());

  Future<void> _password() async {
    final cur = TextEditingController();
    final nw = TextEditingController();
    final cf = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Смена пароля', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Текущий пароль', cur, obscure: true),
          _field('Новый пароль (мин. 8)', nw, obscure: true),
          _field('Повтор', cf, obscure: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сменить', style: TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (nw.text != cf.text) {
      if (mounted) _toast(context, 'Пароли не совпадают', error: true);
      return;
    }
    try {
      await widget.api.profilePassword(cur.text, nw.text);
      if (mounted) _toast(context, 'Пароль изменён');
    } catch (e) {
      if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  Future<void> _twofa(Map<String, dynamic> d) async {
    if (d['totp'] == true) {
      final pw = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kPanel,
          title: const Text('Отключить 2FA', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
          content: _field('Пароль', pw, obscure: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white, shape: const RoundedRectangleBorder()),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отключить', style: TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await widget.api.profile2fa('disable', password: pw.text);
        _reload();
      } catch (e) {
        if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
      }
      return;
    }
    final r = await widget.api.profile2fa('start');
    if (!mounted) return;
    final code = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Включить 2FA', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Добавьте секрет в приложение-аутентификатор:', style: _sub),
            const SizedBox(height: 6),
            SelectableText('${r['secret']}', style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
            const SizedBox(height: 6),
            SelectableText('${r['uri']}', style: _muted),
            const SizedBox(height: 10),
            _field('Код из приложения', code),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
            onPressed: () async {
              try {
                await widget.api.profile2fa('enable', code: code.text.trim());
                if (mounted) Navigator.pop(context);
                _reload();
              } catch (e) {
                if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
              }
            },
            child: const Text('Включить', style: TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Future<void> _timezone(Map<String, dynamic> d) async {
    final zones = (d['timezones'] as List? ?? []).cast<String>();
    var tz = '${d['timezone']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: const Text('Часовой пояс', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: DropdownButtonFormField<String>(
              key: ValueKey('tz-$tz'),
              initialValue: zones.contains(tz) ? tz : (zones.isNotEmpty ? zones.first : null),
              isExpanded: true,
              dropdownColor: kPanel,
              items: zones.map((z) => DropdownMenuItem(value: z, child: Text(z, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)))).toList(),
              onChanged: (v) => setD(() => tz = v ?? tz),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.profileTimezone(tz);
      _reload();
    } catch (e) {
      if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  Future<void> _reminder(Map<String, dynamic> d) async {
    var enabled = d['shift_reminder'] == true;
    var minutes = (d['shift_reminder_minutes'] ?? 30) as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
            backgroundColor: kPanel,
            title: const Text('Напоминание о смене', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Напоминать о смене', style: TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
                value: enabled,
                activeThumbColor: kAccent,
                onChanged: (v) => setD(() => enabled = v),
              ),
              DropdownButtonFormField<int>(
                key: ValueKey('rem-$minutes'),
                initialValue: minutes,
                dropdownColor: kPanel,
                decoration: const InputDecoration(labelText: 'За сколько'),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 минут', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                  DropdownMenuItem(value: 30, child: Text('30 минут', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                  DropdownMenuItem(value: 60, child: Text('1 час', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                  DropdownMenuItem(value: 120, child: Text('2 часа', style: TextStyle(fontFamily: 'monospace', fontSize: 13))),
                ],
                onChanged: (v) => setD(() => minutes = v ?? 30),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить', style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          )),
    );
    if (ok != true) return;
    try {
      await widget.api.profileReminder(enabled: enabled, minutes: minutes);
      _reload();
    } catch (e) {
      if (mounted) _toast(context, e is ApiException ? e.message : 'Ошибка', error: true);
    }
  }

  Future<void> _telegram(Map<String, dynamic> d) async {
    if (d['telegram'] == true) {
      await widget.api.profileUnlink();
      _reload();
      return;
    }
    final code = await widget.api.profileLinkCode();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Привязка Telegram', style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Отправьте боту команду:', style: _sub),
          const SizedBox(height: 6),
          SelectableText('/link $code', style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Код действует 15 минут.', style: _muted),
        ]),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ПРОФИЛЬ', style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: kAccent));
          if (snap.hasError) return Center(child: Text(snap.error is ApiException ? (snap.error as ApiException).message : 'Ошибка сети', style: const TextStyle(color: kDanger, fontFamily: 'monospace')));
          final d = snap.data ?? {};
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${d['avatar'] ?? '🧭'}', style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d['login']}', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('${d['role'] ?? ''}', style: _sub),
                  ])),
                ]),
                const SizedBox(height: 10),
                _kv('Дело', '${d['member'] ?? ''}'),
                _kv('Позывной', '${d['callsign'] ?? ''}'),
                _kv('Подразделение', '${d['department'] ?? ''}'),
                _kv('Допуск', '${d['clearance'] ?? '—'}'),
              ])),
              _card(Row(children: [
                const Icon(Icons.password, color: kAccent, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('Пароль', style: _title)),
                TextButton(onPressed: _password, child: const Text('Сменить', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
              ])),
              _card(Row(children: [
                Icon(d['totp'] == true ? Icons.verified_user : Icons.shield_outlined, color: d['totp'] == true ? kAccent2 : kSoft, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('2FA: ${d['totp'] == true ? 'включена' : 'выключена'}', style: _title)),
                TextButton(onPressed: () => _twofa(d), child: Text(d['totp'] == true ? 'Отключить' : 'Включить', style: const TextStyle(color: kAccent, fontFamily: 'monospace'))),
              ])),
              _card(Row(children: [
                const Icon(Icons.schedule, color: kAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Пояс: ${d['timezone'] ?? ''}', style: _title)),
                TextButton(onPressed: () => _timezone(d), child: const Text('Изменить', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
              ])),
              _card(Row(children: [
                const Icon(Icons.alarm, color: kAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Напоминание о смене', style: _title),
                  Text(d['shift_reminder'] == true ? 'за ${d['shift_reminder_minutes']} мин' : 'выключено', style: _sub),
                ])),
                TextButton(onPressed: () => _reminder(d), child: const Text('Настроить', style: TextStyle(color: kAccent, fontFamily: 'monospace'))),
              ])),
              _card(Row(children: [
                const Icon(Icons.send_outlined, color: kAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Telegram: ${d['telegram'] == true ? 'привязан' : 'нет'}', style: _title)),
                TextButton(onPressed: () => _telegram(d), child: Text(d['telegram'] == true ? 'Отвязать' : 'Привязать', style: const TextStyle(color: kAccent, fontFamily: 'monospace'))),
              ])),
            ],
          );
        },
      ),
    );
  }
}
