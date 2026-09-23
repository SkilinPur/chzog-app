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
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final user = await _api.me();
      setState(() => _user = user);
    } catch (_) {
      setState(() => _user = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
    }
    if (_user == null) {
      return LoginScreen(api: _api, onLoggedIn: (u) => setState(() => _user = u));
    }
    return HomeScreen(
      api: _api,
      user: _user!,
      onLogout: () async {
        await _api.logout();
        setState(() => _user = null);
      },
    );
  }
}
