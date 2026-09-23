import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(Map<String, dynamic> user) onLoggedIn;

  const LoginScreen({super.key, required this.api, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  String? _pending;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_pending == null) {
        final data = await widget.api.login(_login.text.trim(), _password.text);
        if (data['need_2fa'] == true) {
          setState(() => _pending = data['token'] as String);
        } else {
          widget.onLoggedIn(data['user'] as Map<String, dynamic>);
        }
      } else {
        final data = await widget.api.login2fa(_pending!, _code.text.trim());
        widget.onLoggedIn(data['user'] as Map<String, dynamic>);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Сеть недоступна');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final twoFa = _pending != null;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontFamily: 'monospace', fontSize: 34, letterSpacing: 6, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: 'Ч', style: TextStyle(color: kText)),
                      TextSpan(text: 'З', style: TextStyle(color: kAccent)),
                      TextSpan(text: 'ОГ', style: TextStyle(color: kText)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('// ВХОД В КОНТУР',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
                const SizedBox(height: 32),
                if (!twoFa) ...[
                  TextField(
                    controller: _login,
                    decoration: const InputDecoration(labelText: 'Логин'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                ] else ...[
                  const Text('Введите код из приложения 2FA',
                      style: TextStyle(color: kSoft, fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Код 2FA'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: kDanger, fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kBg,
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kBg))
                        : Text(twoFa ? 'ПОДТВЕРДИТЬ' : 'ВОЙТИ',
                            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (twoFa)
                  TextButton(
                    onPressed: () => setState(() {
                      _pending = null;
                      _error = null;
                    }),
                    child: const Text('← назад', style: TextStyle(color: kSoft, fontFamily: 'monospace')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
