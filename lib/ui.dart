import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

const kTitle = TextStyle(color: kText, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold);
const kSub = TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11);
const kMuted = TextStyle(color: kMute, fontFamily: 'monospace', fontSize: 11);

const kKindLabels = {
  'bug': 'Баг',
  'idea': 'Идея',
  'access': 'Доступ',
  'equipment': 'Снаряжение',
  'transport': 'Транспорт',
  'repair': 'Ремонт',
  'other': 'Прочее',
};
String kindLabel(String k) => kKindLabels[k] ?? k;

const kShiftStatus = {
  'planned': 'план',
  'on_shift': 'на смене',
  'done': 'отработана',
  'absent': 'неявка',
  'leave': 'отпуск',
};
Color shiftColor(String s) => switch (s) {
      'on_shift' => kAccent2,
      'done' => kAccent2,
      'absent' => kDanger,
      'leave' => kSoft,
      _ => kAccent,
    };

const kIncidentKinds = {'incident': 'Инцидент', 'report': 'Рапорт', 'violation': 'Нарушение'};
const kSeverities = {'low': 'Низкая', 'medium': 'Средняя', 'high': 'Высокая', 'critical': 'Критично'};
Color sevColor(String s) => switch (s) {
      'critical' => kDanger,
      'high' => kAccent,
      'medium' => kAccent2,
      _ => kSoft,
    };

String fmtDate(Object? iso) {
  final s = iso?.toString() ?? '';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

String fmtTime(Object? iso) {
  final s = iso?.toString() ?? '';
  if (s.length < 16) return '';
  final d = DateTime.tryParse(s);
  if (d == null) return s.substring(11, 16);
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String fmtDateTime(Object? iso) {
  final s = iso?.toString() ?? '';
  if (s.length < 16) return s;
  final d = DateTime.tryParse(s);
  if (d == null) return '${s.substring(0, 10)} ${s.substring(11, 16)}';
  final l = d.toLocal();
  String p(int v) => v.toString().padLeft(2, '0');
  return '${p(l.day)}.${p(l.month)}.${l.year} ${p(l.hour)}:${p(l.minute)}';
}

String fmtSize(int b) => b > 1048576 ? '${(b / 1048576).toStringAsFixed(1)} МБ' : '${(b / 1024).toStringAsFixed(0)} КБ';

Widget screen(String title, Widget body, {List<Widget> actions = const []}) => Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: actions,
      ),
      body: body,
    );

Widget card(Widget child, {Color border = kLine, VoidCallback? onTap}) {
  final box = Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: kPanel, border: Border.all(color: border)),
    child: child,
  );
  return onTap == null ? box : InkWell(onTap: onTap, child: box);
}

Widget tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(text, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 10)),
    );

Widget chip(String label, bool selected, VoidCallback onTap, {int flex = 1}) => Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kAccent : kPanel,
            border: Border.all(color: selected ? kAccent : kLine),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? kBg : kSoft,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );

Widget searchBox(TextEditingController c, {String hint = 'Поиск', VoidCallback? onSubmit}) => TextField(
      controller: c,
      style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
      decoration: InputDecoration(labelText: hint, isDense: true),
      onSubmitted: (_) => onSubmit?.call(),
    );

Widget loading() => const Center(child: CircularProgressIndicator(color: kAccent));

Widget empty(String t) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(t, textAlign: TextAlign.center, style: kMuted),
      ),
    );

Widget errorState(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(e is ApiException ? e.message : 'Ошибка сети',
            textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontFamily: 'monospace')),
      ),
    );

Widget groupHeader(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(children: [
        Text(text, style: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: kLine)),
      ]),
    );

Widget field(String label, TextEditingController c, {bool obscure = false, String? hint, int maxLines = 1}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );

Widget dateField(BuildContext context, String label, TextEditingController c, {VoidCallback? onChanged}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: kSoft, size: 18),
            onPressed: () async {
              final now = DateTime.now();
              final cur = DateTime.tryParse(c.text.trim()) ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: cur,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                c.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                onChanged?.call();
              }
            },
          ),
        ),
      ),
    );

Widget infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: kMuted)),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: kText, fontFamily: 'monospace', fontSize: 12))),
      ]),
    );

Widget creditFooter() => const Padding(
      padding: EdgeInsets.only(top: 24, bottom: 10),
      child: Center(
        child: Text('App by InIProject - SkilinPur',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: kMute)),
      ),
    );

Future<bool> confirmDialog(BuildContext context, String text, {String ok = 'Да'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        content: Text(text, style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: kSoft, fontFamily: 'monospace'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(ok, style: const TextStyle(color: kDanger, fontFamily: 'monospace'))),
        ],
      ),
    ) ??
    false;

void toast(BuildContext context, String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'monospace')), backgroundColor: error ? kDanger : null));
