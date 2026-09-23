import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chzog_app/theme.dart';

void main() {
  test('тема контура собирается', () {
    final theme = buildTheme();
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0E11));
    expect(theme.colorScheme.primary, const Color(0xFFF0B429));
  });
}
