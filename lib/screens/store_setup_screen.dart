// lib/screens/store_setup_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Store Setup Screen — Màn hình lần đầu thiết bị kết nối vào quán
// Nhân viên nhập mã quán (VD: QN-A3F7) để đồng bộ data
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/store_auth_service.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen>
    with TickerProviderStateMixin {
  // Tab: 0 = Nhập mã quán, 1 = Tạo quán mới
  int _tab = 0;

  // Join tab
  final _codeCtrl       = TextEditingController();
  final _deviceNameCtrl = TextEditingController();
  String _deviceRole    = 'waiter';

  // Create tab
  final _storeNameCtrl  = TextEditingController();

  bool   _loading = false;
  String _error   = '';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const _navy   = Color(0xFF1E1C5E);
  static const _orange = Color(0xFFFF6B35);
  static const _bg     = Color(0xFF131128);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _deviceNameCtrl.text = 'Thiết bị của tôi';
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _codeCtrl.dispose();
    _deviceNameCtrl.dispose();
    _storeNameCtrl.dispose();
    super.dispose();
  }

  // ── Join Store ────────────────────────────────────────────────────────────
  Future<void> _joinStore() async {
    setState(() { _loading = true; _error = ''; });
    HapticFeedback.lightImpact();

    final result = await StoreAuthService.joinStore(
      storeCode:  _codeCtrl.text,
      deviceName: 'Thiết bị di động',   // mặc định, chỉnh trong Cài đặt
      deviceRole: 'staff',              // mặc định, xác định qua login NV
    );

    if (!mounted) return;
    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      _goToApp(result.storeName ?? 'Quán Nhỏ');
    } else {
      setState(() {
        _loading = false;
        _error   = result.errorMessage ?? 'Có lỗi xảy ra';
      });
    }
  }

  // ── Create Store ──────────────────────────────────────────────────────────
  Future<void> _createStore() async {
    if (_storeNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên quán');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    HapticFeedback.lightImpact();

    final result = await StoreAuthService.createStore(
      storeName: _storeNameCtrl.text.trim(),
    );

    if (!mounted) return;
    if (result.isSuccess) {
      HapticFeedback.heavyImpact();
      _showCreatedDialog(result.storeCode!);
    } else {
      setState(() {
        _loading = false;
        _error   = result.errorMessage ?? 'Có lỗi xảy ra';
      });
    }
  }

  void _showCreatedDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🎉', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('Quán đã được tạo!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gửi mã này cho nhân viên để họ đăng nhập:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    )),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Đã copy mã quán')));
                    },
                    child: const Icon(Icons.copy_rounded,
                      color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goToApp(_storeNameCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Vào app →'),
          ),
        ],
      ),
    );
  }

  void _goToApp(String storeName) {
    if (!mounted) return;
    // Sau khi setup xong → vào staff login
    Navigator.of(context).pushReplacementNamed('/staff_login');
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.store_rounded,
                      color: _orange, size: 32),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text('Kết nối vào quán',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Thiết bị này chưa được kết nối vào quán nào',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Tab selector ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TabBtn(
                        label: 'Nhập mã quán',
                        icon: Icons.login_rounded,
                        active: _tab == 0,
                        onTap: () => setState(() { _tab = 0; _error = ''; }),
                      ),
                      _TabBtn(
                        label: 'Tạo quán mới',
                        icon: Icons.add_business_rounded,
                        active: _tab == 1,
                        onTap: () => setState(() { _tab = 1; _error = ''; }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Tab content ───────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _tab == 0
                      ? _buildJoinForm()
                      : _buildCreateForm(),
                ),

                // ── Error ─────────────────────────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error,
                            style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Form: Nhập mã quán ────────────────────────────────────────────────────
  Widget _buildJoinForm() {
    return Column(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Mã quán'),
        const SizedBox(height: 8),
        _Input(
          controller: _codeCtrl,
          hint: 'VD: QN-A3F7',
          icon: Icons.qr_code_rounded,
          caps: true,
          onChanged: (v) {
            if (v.length == 2 && !v.contains('-')) {
              _codeCtrl.text = '$v-';
              _codeCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _codeCtrl.text.length));
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Nhập mã quán do chủ quán cung cấp để kết nối thiết bị này.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        _ActionButton(
          label: 'Kết nối vào quán',
          icon: Icons.link_rounded,
          loading: _loading,
          onTap: _joinStore,
        ),
      ],
    );
  }

  // ── Form: Tạo quán mới ────────────────────────────────────────────────────
  Widget _buildCreateForm() {
    return Column(
      key: const ValueKey('create'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _orange.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _orange, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dùng khi bạn là chủ quán và muốn setup quán lần đầu trên thiết bị này.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Label('Tên quán'),
        const SizedBox(height: 8),
        _Input(
          controller: _storeNameCtrl,
          hint: 'VD: Quán Nhỏ - Bình Thạnh',
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: 28),
        _ActionButton(
          label: 'Tạo quán & lấy mã',
          icon: Icons.add_circle_outline_rounded,
          loading: _loading,
          onTap: _createStore,
          color: const Color(0xFF2D8CFF),
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
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.icon,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF6B35) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                color: active ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.white : Colors.white38,
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: const TextStyle(
        color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600));
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool caps;
  final void Function(String)? onChanged;

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.caps = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.words,
      style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 0),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B35), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _RoleSelector({required this.value, required this.onChanged});

  static const _roles = [
    ('waiter',  'Phục vụ',  Icons.room_service_rounded),
    ('cashier', 'Thu ngân', Icons.point_of_sale_rounded),
    ('kitchen', 'Bếp',      Icons.local_fire_department_rounded),
    ('manager', 'Quản lý',  Icons.manage_accounts_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _roles.map((r) {
        final active = value == r.$1;
        return GestureDetector(
          onTap: () => onChanged(r.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? const Color(0xFFFF6B35).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r.$3, size: 15,
                  color: active ? const Color(0xFFFF6B35) : Colors.white38),
                const SizedBox(width: 6),
                Text(r.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? Colors.white : Colors.white38,
                  )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.color = const Color(0xFFFF6B35),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(loading ? 'Đang kết nối...' : label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
