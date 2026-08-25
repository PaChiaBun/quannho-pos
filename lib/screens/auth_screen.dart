// lib/screens/auth_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Auth Screen — Đăng nhập / Đăng ký bằng Số điện thoại + Mật khẩu
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_auth_service.dart';
import '../core/providers/session_provider.dart';
import '../core/widgets/create_store_sheet.dart';
import '../core/widgets/join_store_sheet.dart';
import 'store_picker_screen.dart';

String routeAfterSuccessfulLogin(AuthResult result) =>
    result.selectedStore != null ? '/home' : '/store_picker';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  // Tab: 0 = Đăng nhập, 1 = Đăng ký
  int _tab = 0;

  // Login
  final _loginPhoneCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Register
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regPass2Ctrl = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  String _error = '';

  static const _navy = Color(0xFF1E1C5E);
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFF131128);

  @override
  void dispose() {
    _loginPhoneCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regPass2Ctrl.dispose();
    super.dispose();
  }

  // ── ĐĂNG NHẬP ───────────────────────────────────────────────────────────────
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    HapticFeedback.lightImpact();

    final result = await UserAuthService.login(
      phone: _loginPhoneCtrl.text,
      password: _loginPassCtrl.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      ref
          .read(sessionProvider.notifier)
          .setSession(
            SessionData(
              userId: result.userId!,
              phone: result.phone!,
              displayName: result.displayName!,
              storeId: result.selectedStore?.storeId,
              storeName: result.selectedStore?.storeName,
              storeCode: result.selectedStore?.storeCode,
              role: result.selectedStore?.role ?? '',
              isOwner: result.selectedStore?.isOwner ?? false,
            ),
          );

      final destination = routeAfterSuccessfulLogin(result);
      if (destination == '/home') {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed(
          '/store_picker',
          arguments: {
            'stores': result.stores,
            'userId': result.userId,
            'name': result.displayName,
            storePickerPostLoginKey: result.stores.isNotEmpty,
          },
        );
      }
    } else {
      setState(() {
        _loading = false;
        _error = result.errorMessage!;
      });
    }
  }

  // ── ĐĂNG KÝ ─────────────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (_regPassCtrl.text != _regPass2Ctrl.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    HapticFeedback.lightImpact();

    final result = await UserAuthService.register(
      phone: _regPhoneCtrl.text,
      password: _regPassCtrl.text,
      displayName: _regNameCtrl.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      ref
          .read(sessionProvider.notifier)
          .setSession(
            SessionData(
              userId: result.userId!,
              phone: result.phone!,
              displayName: result.displayName!,
              role: '',
              isOwner: false,
            ),
          );

      // Vào màn hình Store Picker để chọn tạo quán hoặc kết nối quán
      Navigator.of(context).pushReplacementNamed(
        '/store_picker',
        arguments: {
          'stores': <StoreMembership>[],
          'userId': result.userId,
          'name': result.displayName,
        },
      );
    } else {
      setState(() {
        _loading = false;
        _error = result.errorMessage!;
      });
    }
  }

  void _showStoreCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mã quán của bạn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gửi mã này cho nhân viên để họ kết nối vào quán:',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Đã copy mã quán')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.copy_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Vào app →'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Logo ────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Quán Nhỏ POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Tab selector ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TabBtn(
                      label: 'Đăng nhập',
                      active: _tab == 0,
                      onTap: () => setState(() {
                        _tab = 0;
                        _error = '';
                      }),
                    ),
                    _TabBtn(
                      label: 'Đăng ký',
                      active: _tab == 1,
                      onTap: () => setState(() {
                        _tab = 1;
                        _error = '';
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Form ─────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _tab == 0 ? _buildLoginForm() : _buildRegisterForm(),
              ),

              // ── Error ────────────────────────────────────────────────────
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Login Form ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          controller: _loginPhoneCtrl,
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _loginPassCtrl,
          label: 'Mật khẩu',
          hint: '••••••',
          icon: Icons.lock_rounded,
          obscure: !_showPass,
          suffix: IconButton(
            icon: Icon(
              _showPass ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
              size: 18,
            ),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
        ),
        const SizedBox(height: 28),
        _ActionBtn(label: 'Đăng nhập', loading: _loading, onTap: _login),
      ],
    );
  }

  // ── Register Form ─────────────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          controller: _regNameCtrl,
          label: 'Tên của bạn',
          hint: 'Nguyễn Văn A',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _regPhoneCtrl,
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _regPassCtrl,
          label: 'Mật khẩu',
          hint: 'Tối thiểu 6 ký tự',
          icon: Icons.lock_rounded,
          obscure: !_showPass,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _regPass2Ctrl,
          label: 'Xác nhận mật khẩu',
          hint: 'Nhập lại mật khẩu',
          icon: Icons.lock_outline_rounded,
          obscure: !_showPass,
          suffix: IconButton(
            icon: Icon(
              _showPass ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
              size: 18,
            ),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
        ),
        const SizedBox(height: 28),
        _ActionBtn(
          label: 'Tạo tài khoản',
          loading: _loading,
          onTap: _register,
          color: const Color(0xFF2D8CFF),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: _orange, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _orange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF6B35) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn({
    required this.label,
    required this.loading,
    required this.onTap,
    this.color = const Color(0xFFFF6B35),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
