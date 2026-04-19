// lib/screens/forgot_pin_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PIN SCREEN — 3 bước:
//   Step 1: Nhập email khôi phục (hoặc lấy từ settings)
//   Step 2: Nhập mã OTP 6 số gửi qua email
//   Step 3: Đặt PIN mới
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/providers/app_providers.dart';
import '../core/services/otp_service.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const _kBg      = Color(0xFF0F0E1A);
  static const _kCard    = Color(0xFF1A1930);
  static const _kNavy    = Color(0xFF2D2B8A);
  static const _kAccent  = Color(0xFF4F9EFF);
  static const _kGreen   = Color(0xFF2ECC71);
  static const _kMuted   = Color(0xFF8B8FA8);
  static const _kBorder  = Color(0xFF2A2840);
  static const _kRed     = Color(0xFFE74C3C);

  // ── State ─────────────────────────────────────────────────────────────────
  int  _step = 0; // 0=email, 1=otp, 2=newPin, 3=success
  bool _loading = false;
  String _errorMsg = '';

  // ── Step 0: Email ─────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();

  // ── Step 1: OTP ───────────────────────────────────────────────────────────
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  Timer?   _countdownTimer;
  int      _countdown = 300; // 5 phút

  // ── Step 2: New PIN ───────────────────────────────────────────────────────
  String _newPin     = '';
  String _confirmPin = '';
  bool   _enteringConfirm = false;

  final _otpService = OtpService();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final repo  = ref.read(settingsRepositoryProvider);
    final email = await repo.get('recovery_email');
    if (email != null && email.isNotEmpty) {
      _emailCtrl.text = email;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
        ),
        title: Text(
          _step == 0 ? 'Quên mã PIN'
            : _step == 1 ? 'Nhập mã xác nhận'
            : _step == 2 ? 'Đặt PIN mới'
            : 'Hoàn tất',
          style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: 300.ms,
          child: switch (_step) {
            0 => _buildEmailStep(),
            1 => _buildOtpStep(),
            2 => _buildNewPinStep(),
            _ => _buildSuccessStep(),
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 0 — NHẬP EMAIL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle),
            child: const Icon(Icons.mail_outline_rounded,
              color: _kAccent, size: 32),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),

          const Text('Khôi phục PIN qua email',
            style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
              letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Nhập email đã đăng ký khi bật khoá PIN.\nChúng tôi sẽ gửi mã 6 số để xác nhận.',
            style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),

          // Email input
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder)),
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: TextStyle(color: _kMuted),
                prefixIcon: Icon(Icons.email_rounded, color: _kAccent, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              ),
            ),
          ),

          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ErrorBanner(_errorMsg),
          ],

          const SizedBox(height: 24),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Gửi mã xác nhận',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — NHẬP OTP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    final mins = (_countdown ~/ 60).toString().padLeft(2, '0');
    final secs = (_countdown % 60).toString().padLeft(2, '0');

    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_rounded,
              color: _kGreen, size: 32),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),

          const Text('Kiểm tra hòm thư!',
            style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Mã 6 số đã được gửi đến\n'),
                TextSpan(
                  text: _emailCtrl.text,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _OtpBox(
              controller: _otpCtrls[i],
              focusNode:  _otpFocus[i],
              onChanged:  (v) => _onOtpDigit(v, i),
            )),
          ),
          const SizedBox(height: 20),

          // Countdown
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded,
                    color: _countdown < 60 ? _kRed : _kMuted, size: 16),
                  const SizedBox(width: 6),
                  Text('$mins:$secs',
                    style: TextStyle(
                      color: _countdown < 60 ? _kRed : Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('còn lại',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMsg.isNotEmpty) _ErrorBanner(_errorMsg),
          const SizedBox(height: 16),

          // Resend
          Center(
            child: TextButton(
              onPressed: _countdown <= 0 ? _sendOtp : null,
              child: Text(
                'Gửi lại mã',
                style: TextStyle(
                  color: _countdown <= 0 ? _kAccent : _kMuted,
                  fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 8),

          // Verify button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                  : const Text('Xác nhận mã',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — ĐẶT PIN MỚI (numpad)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNewPinStep() {
    final currentPin = _enteringConfirm ? _confirmPin : _newPin;

    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            _enteringConfirm ? 'Nhập lại PIN để xác nhận' : 'Đặt mã PIN mới',
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            _enteringConfirm
                ? 'Nhập lại PIN vừa đặt'
                : 'PIN gồm 4 chữ số',
            style: TextStyle(color: _kMuted, fontSize: 13)),
          const SizedBox(height: 28),

          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < currentPin.length
                    ? _kAccent
                    : _kBorder,
                border: Border.all(
                  color: i < currentPin.length ? _kAccent : _kMuted,
                  width: 2),
              ),
            )),
          ),

          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ErrorBanner(_errorMsg),
          ],

          const Spacer(),

          // Numpad
          _buildNumpad(currentPin),
        ],
      ),
    );
  }

  Widget _buildNumpad(String currentPin) {
    return Column(
      children: [
        for (final row in [
          ['1','2','3'],
          ['4','5','6'],
          ['7','8','9'],
          ['','0','⌫'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((digit) {
              if (digit.isEmpty) return const SizedBox(width: 80, height: 80);
              return _NumKey(
                label:    digit,
                onTap:    () => _onPinDigit(digit),
                color:    _kCard,
                border:   _kBorder,
              );
            }).toList(),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — SUCCESS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessStep() {
    return Center(
      key: const ValueKey(3),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle),
              child: const Icon(Icons.lock_open_rounded,
                color: _kGreen, size: 48),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  duration: 500.ms,
                  curve: Curves.elasticOut),
            const SizedBox(height: 24),
            const Text('PIN đã được đặt lại!',
              style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Mã PIN mới đã được lưu.\nBạn có thể dùng ngay.',
              style: TextStyle(color: _kMuted, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Đăng nhập ngay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Email không hợp lệ');
      return;
    }

    // Kiểm tra email có khớp email đã lưu không
    final repo        = ref.read(settingsRepositoryProvider);
    final savedEmail  = await repo.get('recovery_email') ?? '';
    if (savedEmail.isNotEmpty &&
        email.toLowerCase() != savedEmail.toLowerCase()) {
      setState(() =>
        _errorMsg = 'Email không khớp với email đã đăng ký');
      return;
    }

    setState(() { _loading = true; _errorMsg = ''; });

    // Lấy tên chủ quán từ SharedPreferences (lưu lúc onboarding)
    final prefs    = await SharedPreferences.getInstance();
    final ownerName = prefs.getString('owner_name') ?? 'Bạn';
    final result   = await _otpService.sendOtp(
      toEmail: email,
      toName:  ownerName,
    );

    setState(() => _loading = false);

    switch (result) {
      case OtpResult.success:
        _startCountdown();
        setState(() => _step = 1);
        Future.delayed(200.ms, () {
          if (mounted) _otpFocus[0].requestFocus();
        });
      case OtpResult.notConfigured:
        setState(() =>
          _errorMsg = 'Chức năng email chưa được cấu hình.\nLiên hệ admin để hỗ trợ.');
      case OtpResult.sendFailed:
        setState(() =>
          _errorMsg = 'Gửi email thất bại. Vui lòng thử lại.');
      case OtpResult.networkError:
        setState(() =>
          _errorMsg = 'Không có internet. Kiểm tra kết nối và thử lại.');
    }
  }

  void _startCountdown() {
    _countdown = 300;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  void _onOtpDigit(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _errorMsg = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }

    setState(() { _loading = true; _errorMsg = ''; });
    final result = await _otpService.verifyOtp(otp);
    setState(() => _loading = false);

    switch (result) {
      case OtpVerifyResult.valid:
        HapticFeedback.heavyImpact();
        setState(() { _step = 2; _newPin = ''; _confirmPin = ''; });
      case OtpVerifyResult.invalid:
        HapticFeedback.vibrate();
        setState(() => _errorMsg = 'Mã không đúng. Vui lòng kiểm tra lại.');
      case OtpVerifyResult.expired:
        setState(() => _errorMsg = 'Mã đã hết hạn. Nhấn "Gửi lại mã" để lấy mã mới.');
      case OtpVerifyResult.noOtpPending:
        setState(() => _errorMsg = 'Phiên xác thực đã hết. Quay lại và gửi lại mã.');
    }
  }

  void _onPinDigit(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      _errorMsg = '';
      if (!_enteringConfirm) {
        // Nhập PIN 1
        if (digit == '⌫') {
          if (_newPin.isNotEmpty) _newPin = _newPin.substring(0, _newPin.length - 1);
        } else if (_newPin.length < 4) {
          _newPin += digit;
          if (_newPin.length == 4) {
            // Chuyển sang confirm
            Future.delayed(200.ms, () {
              if (mounted) setState(() => _enteringConfirm = true);
            });
          }
        }
      } else {
        // Nhập confirm PIN
        if (digit == '⌫') {
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
        } else if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) {
            _saveNewPin();
          }
        }
      }
    });
  }

  Future<void> _saveNewPin() async {
    if (_newPin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMsg    = 'PIN không khớp. Nhập lại từ đầu.';
        _newPin      = '';
        _confirmPin  = '';
        _enteringConfirm = false;
      });
      return;
    }

    final repo = ref.read(settingsRepositoryProvider);
    await repo.set('app_pin',     _newPin);
    await repo.set('pin_enabled', 'true');
    ref.invalidate(pinEnabledProvider);

    HapticFeedback.heavyImpact();
    setState(() => _step = 3);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 56,
      child: TextField(
        controller:  controller,
        focusNode:   focusNode,
        onChanged:   onChanged,
        maxLength:   1,
        textAlign:   TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled:      true,
          fillColor:   const Color(0xFF1A1930),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2840))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF4F9EFF), width: 2)),
        ),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String           label;
  final VoidCallback     onTap;
  final Color            color;
  final Color            border;

  const _NumKey({
    required this.label,
    required this.onTap,
    required this.color,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isBack = label == '⌫';
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: isBack
            ? const Color(0xFF1A1930)
            : color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap:         onTap,
          borderRadius:  BorderRadius.circular(16),
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border)),
            alignment: Alignment.center,
            child: isBack
                ? const Icon(Icons.backspace_rounded,
                    color: Colors.white60, size: 22)
                : Text(label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3))),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
          color: Color(0xFFE74C3C), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
            style: const TextStyle(
              color: Color(0xFFE74C3C), fontSize: 12, height: 1.4))),
      ]),
    );
  }
}
