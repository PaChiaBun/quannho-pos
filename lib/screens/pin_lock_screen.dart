// lib/screens/pin_lock_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// PIN LOCK SCREEN — Màn hình khoá ứng dụng bằng PIN 4 số
// Mode: 'verify' = nhập PIN để vào app
//       'set'    = đặt PIN mới (từ Settings)
//       'change' = đổi PIN (xác minh cũ → nhập mới)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import 'forgot_pin_screen.dart';

enum PinMode { verify, set, change }

class PinLockScreen extends ConsumerStatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;

  const PinLockScreen({
    super.key,
    this.mode = PinMode.verify,
    this.onSuccess,
  });

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with TickerProviderStateMixin {
  String _input    = '';
  String _firstPin = '';
  int    _step     = 0;
  String _topLabel = '';
  int    _failCount = 0;
  bool   _saving   = false;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFF131128);
  static const _kDot    = Color(0xFF3D3A7A);

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _updateLabel();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _updateLabel() {
    switch (widget.mode) {
      case PinMode.verify:
        _topLabel = 'Nhập mã PIN';
        break;
      case PinMode.set:
        _topLabel = _step == 0 ? 'Tạo PIN mới' : 'Xác nhận PIN';
        break;
      case PinMode.change:
        _topLabel = _step == 0
            ? 'Nhập PIN hiện tại'
            : _step == 1
                ? 'Tạo PIN mới'
                : 'Xác nhận PIN mới';
        break;
    }
  }

  void _onDigit(String d) {
    if (_input.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _input += d);
    if (_input.length == 4) {
      Future.delayed(const Duration(milliseconds: 120), _handleComplete);
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _handleComplete() async {
    final settings = ref.read(settingsRepositoryProvider);
    switch (widget.mode) {
      case PinMode.verify:
        await _handleVerify(settings);
        break;
      case PinMode.set:
        await _handleSet();
        break;
      case PinMode.change:
        await _handleChange(settings);
        break;
    }
  }

  Future<void> _handleVerify(dynamic settings) async {
    final savedPin = await settings.get('app_pin') ?? '';
    if (_input == savedPin) {
      HapticFeedback.heavyImpact();
      widget.onSuccess?.call();
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _failCount++;
      await _shakeCtrl.forward(from: 0);
      if (mounted) {
        setState(() => _input = '');
        if (_failCount >= 5) {
          _showFailedDialog();
        }
      }
    }
  }

  Future<void> _handleSet() async {
    if (_step == 0) {
      setState(() {
        _firstPin = _input;
        _input    = '';
        _step     = 1;
        _updateLabel();
      });
    } else {
      if (_input == _firstPin) {
        setState(() => _saving = true);
        final settings = ref.read(settingsRepositoryProvider);
        await settings.set('app_pin',     _input);
        await settings.set('pin_enabled', 'true');
        ref.invalidate(pinEnabledProvider);
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã đặt PIN thành công!'),
              behavior: SnackBarBehavior.floating));
          // Nhắc user đặt recovery email ngay sau khi set PIN
          _promptRecoveryEmail();
        }
      } else {
        await _shakeCtrl.forward(from: 0);
        if (mounted) setState(() {
          _input    = '';
          _step     = 0;
          _firstPin = '';
          _updateLabel();
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN không khớp, vui lòng thử lại'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _handleChange(dynamic settings) async {
    if (_step == 0) {
      final savedPin = await settings.get('app_pin') ?? '';
      if (_input == savedPin) {
        setState(() { _input = ''; _step = 1; _updateLabel(); });
      } else {
        await _shakeCtrl.forward(from: 0);
        if (mounted) setState(() => _input = '');
      }
    } else if (_step == 1) {
      setState(() { _firstPin = _input; _input = ''; _step = 2; _updateLabel(); });
    } else {
      if (_input == _firstPin) {
        await settings.set('app_pin', _input);
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã đổi PIN thành công!'),
              behavior: SnackBarBehavior.floating));
        }
      } else {
        await _shakeCtrl.forward(from: 0);
        if (mounted) setState(() {
          _input = ''; _step = 1; _firstPin = ''; _updateLabel();
        });
      }
    }
  }

  void _showFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quá nhiều lần sai',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Bạn đã nhập sai PIN 5 lần. Vui lòng thử lại sau 30 giây.',
          style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { _failCount = 0; _input = ''; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  /// Sau khi set PIN xong → nhắc nhở đặt email khôi phục
  void _promptRecoveryEmail() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final emailCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.mail_outline_rounded,
              color: Color(0xFF4F9EFF), size: 20),
            SizedBox(width: 8),
            Text('Đặt email khôi phục',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thêm email để lấy lại PIN khi quên.\n(Bạn có thể bỏ qua và đặt sau trong Cài đặt)',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.email_rounded,
                    color: Color(0xFF4F9EFF), size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bỏ qua',
                style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  final repo = ref.read(settingsRepositoryProvider);
                  await repo.set('recovery_email', email);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Email khôi phục đã lưu'),
                      behavior: SnackBarBehavior.floating));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F9EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
              child: const Text('Lưu email'),
            ),
          ],
        );
      },
    );
  }

  void _goToForgotPin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPinScreen()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Logo & Label ─────────────────────────────────────────
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kNavy, _kNavyL]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kNavy.withValues(alpha: 0.5),
                    blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/branding/app_icon.png',
                  fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Quán Nhỏ POS',
              style: TextStyle(
                color: Colors.white70, fontSize: 14,
                fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(_topLabel,
                key: ValueKey(_topLabel),
                style: const TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ),

            const Spacer(),

            // ── PIN Dots ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  _shakeAnim.value * 12 * (1 - 2 * (_shakeAnim.value.floor() % 2)),
                  0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _input.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 20 : 16,
                    height: filled ? 20 : 16,
                    decoration: BoxDecoration(
                      color: filled ? _kOrange : _kDot,
                      shape: BoxShape.circle,
                      boxShadow: filled ? [
                        BoxShadow(
                          color: _kOrange.withValues(alpha: 0.5),
                          blurRadius: 10),
                      ] : [],
                    ),
                  );
                }),
              ),
            ),

            const Spacer(),

            // ── Numpad ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (final row in [
                    ['1','2','3'],
                    ['4','5','6'],
                    ['7','8','9'],
                    ['','0','⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: row.map((key) {
                          if (key.isEmpty) return const SizedBox(width: 80);
                          return _NumKey(
                            label: key,
                            onTap: key == '⌫'
                                ? _onDelete
                                : () => _onDigit(key),
                            isDelete: key == '⌫',
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // Quên PIN (chỉ trong mode verify)
            if (widget.mode == PinMode.verify) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _goToForgotPin,
                child: Text('Quên PIN?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMPAD KEY
// ─────────────────────────────────────────────────────────────────────────────
class _NumKey extends StatefulWidget {
  final String       label;
  final VoidCallback onTap;
  final bool         isDelete;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child),
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: widget.isDelete
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: widget.isDelete
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1),
          ),
          child: Center(
            child: widget.isDelete
                ? Icon(Icons.backspace_rounded,
                    color: Colors.white.withValues(alpha: 0.6), size: 24)
                : Text(widget.label,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
