import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() => runApp(const ChzogApp());

class ChzogApp extends StatelessWidget {
  const ChzogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ЧЗОГ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final summary = await _api.home();
      setState(() => _summary = summary);
    } catch (_) {
      setState(() => _summary = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
    }
    if (_summary == null) {
      return LoginScreen(api: _api, onLoggedIn: (_) => _check());
    }
    return HomeScreen(
      api: _api,
      summary: _summary!,
      onLogout: () async {
        await _api.logout();
        setState(() => _summary = null);
      },
    );
  }
}
