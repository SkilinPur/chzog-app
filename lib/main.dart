import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'fcm.dart';
import 'scan.dart';
import 'security.dart';
import 'screens/lock_screen.dart';
import 'queue.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.load();
  runApp(const ChzogApp());
}

class ChzogApp extends StatelessWidget {
  const ChzogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: ThemeService.accent,
      builder: (_, c, __) => MaterialApp(
        title: 'ЧЗОГ',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  final _api = ApiClient();
  bool _loading = true;
  bool _locked = false;
  bool _allowBio = false;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updater.check(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _relockIfNeeded();
    }
  }

  Future<void> _relockIfNeeded() async {
    if (mounted && !_locked && _summary != null) {
      final mode = await AppLock.mode();
      final mins = await AppLock.timeoutMinutes();
      if (mode != 'off' && await AppLock.isSet() && mins > 0) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _start() async {
    final mode = await AppLock.mode();
    if (mode != 'off' && await AppLock.isSet()) {
      setState(() {
        _locked = true;
        _allowBio = mode == 'bio' ? true : false;
      });
    }
    _check();
  }

  void _unlock() => setState(() => _locked = false);

  Future<void> _check() async {
    try {
      final summary = await _api.home();
      setState(() => _summary = summary);
      OfflineQueue.flush(_api);
      _maybeBroadcast();
      initFcm(_api);
      reportPosition(_api);
    } catch (_) {
      setState(() => _summary = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybeBroadcast() async {
    try {
      final b = await _api.broadcast();
      if (b == null || !mounted) return;
      final sp = await SharedPreferences.getInstance();
      final id = (b['id'] ?? 0) as int;
      if (id <= (sp.getInt('broadcast_seen') ?? 0)) return;
      if (!mounted) return;
      final title = (b['title'] ?? '').toString();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kPanel,
          title: Text(title.isEmpty ? 'Уведомление' : title,
              style: TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 16)),
          content: SingleChildScrollView(
            child: Text('${b['body']}', style: const TextStyle(fontFamily: 'monospace', color: kText, fontSize: 13)),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg, shape: RoundedRectangleBorder()),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ПОНЯТНО', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      await sp.setInt('broadcast_seen', id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
    }
    if (_locked) {
      return LockScreen(allowBiometric: _allowBio, onUnlocked: _unlock);
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
