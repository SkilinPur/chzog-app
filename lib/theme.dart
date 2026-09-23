import 'package:flutter/material.dart';

const kBg = Color(0xFF0B0E11);
const kPanel = Color(0xFF12161B);
const kPanel2 = Color(0xFF171C22);
const kLine = Color(0xFF232A33);
const kLine2 = Color(0xFF2E3742);
const kText = Color(0xFFD6DDE5);
const kSoft = Color(0xFF8B96A3);
const kMute = Color(0xFF5B6572);
const kAccent = Color(0xFFF0B429);
const kAccent2 = Color(0xFF2DD4BF);
const kDanger = Color(0xFFE5484D);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      secondary: kAccent2,
      surface: kPanel,
      error: kDanger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0D1116),
      labelStyle: const TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 13),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kLine2),
        borderRadius: BorderRadius.zero,
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kAccent),
        borderRadius: BorderRadius.zero,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: kText,
      displayColor: kText,
      fontFamily: 'monospace',
    ),
  );
}
