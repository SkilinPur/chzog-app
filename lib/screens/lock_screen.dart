import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  final bool allowBiometric;
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.allowBiometric, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.allowBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    final ok = await AppLock.biometric();
    if (ok && mounted) widget.onUnlocked();
  }

  void _tap(String d) {
    if (_busy) return;
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) _check();
  }

  void _del() {
    if (_busy) return;
    setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1));
  }

  Future<void> _check() async {
    setState(() { _busy = true; _err = null; });
    final ok = await AppLock.verifyPin(_pin);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() { _pin = ''; _busy = false; _err = 'Неверный PIN'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text('ЧЗОГ', style: TextStyle(fontFamily: 'monospace', fontSize: 34, fontWeight: FontWeight.bold, color: kText)),
            const SizedBox(height: 6),
            Text('// ПОДТВЕРДИТЕ ВХОД', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: kAccent, letterSpacing: 2)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? kAccent : Colors.transparent,
                    border: Border.all(color: filled ? kAccent : kSoft, width: 2),
                  ),
                );
              }),
            ),
            if (_err != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: Text(_err!, style: const TextStyle(color: kDanger, fontFamily: 'monospace', fontSize: 12))),
            const Spacer(),
            _pad(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _pad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'bio', '0', 'del'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: keys.map((k) {
          if (k == 'bio') {
            if (!widget.allowBiometric) return const SizedBox();
            return _key(Icons.fingerprint, () => _bio());
          }
          if (k == 'del') return _key(Icons.backspace_outlined, _del);
          return _key(null, () => _tap(k), label: k);
        }).toList(),
      ),
    );
  }

  Widget _key(IconData? icon, VoidCallback onTap, {String? label}) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: kPanel, border: Border.all(color: kLine)),
          child: icon != null
              ? Icon(icon, color: kText, size: 26)
              : Text(label!, style: const TextStyle(fontFamily: 'monospace', fontSize: 24, color: kText, fontWeight: FontWeight.bold)),
        ),
      );
}
