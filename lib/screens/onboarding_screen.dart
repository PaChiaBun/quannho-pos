// lib/screens/onboarding_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN — Hiển thị lần đầu cài app
// Page 1: Welcome hero
// Page 2: Thông tin quán (name, owner, phone, email, city)
// Page 3: Hoàn tất → sync Supabase + email chào mừng
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/brevo_service.dart';
import '../core/services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFF0F0E1A);
  static const _kCard   = Color(0xFF1A1930);
  static const _kMuted  = Color(0xFF8B8FA8);
  static const _kBorder = Color(0xFF2A2840);

  final _pageCtrl      = PageController();
  int  _currentPage    = 0;
  bool _loading        = false;
  bool _done           = false;

  final _shopNameCtrl  = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _formKey       = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage == 0)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text('Bỏ qua',
                      style: TextStyle(color: _kMuted, fontSize: 13)),
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildFormPage(),
                  _buildSuccessPage(),
                ],
              ),
            ),
            if (!_done) _buildBottomBar(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kNavy, _kNavyL],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: _kNavy.withValues(alpha: 0.6),
                  blurRadius: 40, offset: const Offset(0, 16)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset('assets/branding/app_icon.png',
                fit: BoxFit.cover),
            ),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 36),
          const Text('Quán Nhỏ POS',
            style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900,
              letterSpacing: -1))
              .animate()
              .slideY(begin: 0.3, duration: 500.ms, delay: 200.ms)
              .fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            'Quản lý quán café, trà sữa, quán ăn\nđơn giản — đẹp — hiệu quả',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kMuted, fontSize: 15, height: 1.6))
              .animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: 48),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10, runSpacing: 10,
            children: const [
              _FeaturePill('🛒 Bán hàng offline'),
              _FeaturePill('📦 Quản lý kho'),
              _FeaturePill('⭐ Loyalty points'),
              _FeaturePill('📊 Báo cáo'),
              _FeaturePill('💰 Thu chi'),
            ],
          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildFormPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin quán của bạn',
              style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Điền để chúng tôi hỗ trợ bạn tốt hơn',
              style: TextStyle(color: _kMuted, fontSize: 13)),
            const SizedBox(height: 24),
            _buildField(ctrl: _shopNameCtrl, label: 'Tên quán *',
              hint: 'VD: Café Góc Phố', icon: Icons.store_rounded,
              color: const Color(0xFF4F9EFF),
              validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập tên quán' : null),
            const SizedBox(height: 14),
            _buildField(ctrl: _ownerNameCtrl, label: 'Tên chủ quán *',
              hint: 'Họ và tên của bạn', icon: Icons.person_rounded,
              color: const Color(0xFF7C4DFF),
              validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập tên' : null),
            const SizedBox(height: 14),
            _buildField(ctrl: _phoneCtrl, label: 'Số điện thoại *',
              hint: '0901 234 567', icon: Icons.phone_rounded,
              color: const Color(0xFF00BCD4),
              keyboard: TextInputType.phone,
              validator: (v) =>
                  v!.trim().length < 9 ? 'Số điện thoại không hợp lệ' : null),
            const SizedBox(height: 14),
            _buildField(ctrl: _emailCtrl,
              label: 'Email (nhận thông báo & khôi phục PIN)',
              hint: 'your@email.com', icon: Icons.mail_outline_rounded,
              color: const Color(0xFF66BB6A),
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v!.trim().isEmpty) return null;
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              }),
            const SizedBox(height: 14),
            _buildField(ctrl: _cityCtrl, label: 'Tỉnh / Thành phố',
              hint: 'VD: Hồ Chí Minh', icon: Icons.location_city_rounded,
              color: const Color(0xFFF9A825)),
            const SizedBox(height: 8),
            Text('* Bắt buộc', style: TextStyle(color: _kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF2ECC71), size: 56),
            )
                .animate()
                .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 600.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            const Text('Thiết lập thành công! 🎉',
              style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center)
                .animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Email chào mừng đã được gửi.\nBạn đã sẵn sàng sử dụng Quán Nhỏ POS!',
              style: TextStyle(color: _kMuted, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center)
                .animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _enterApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                  elevation: 0),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Vào ứng dụng',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, delay: 700.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Row(
            children: List.generate(3, (i) => AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.only(right: 6),
              width: i == _currentPage ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _currentPage ? _kOrange : _kBorder,
                borderRadius: BorderRadius.circular(4)),
            )),
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28)),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                  : Row(children: [
                      Text(
                        _currentPage == 0 ? 'Bắt đầu' : 'Hoàn tất',
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    HapticFeedback.lightImpact();
    if (_currentPage == 0) {
      _pageCtrl.animateToPage(1, duration: 400.ms, curve: Curves.easeInOut);
    } else {
      _submitForm();
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_name',  _shopNameCtrl.text.trim());
      await prefs.setString('owner_name', _ownerNameCtrl.text.trim());
      await prefs.setString('shop_phone', _phoneCtrl.text.trim());
      await prefs.setString('shop_email', _emailCtrl.text.trim());
      await prefs.setString('shop_city',  _cityCtrl.text.trim());
      await prefs.setBool  ('onboarding_complete', true);

      // Email làm recovery PIN luôn
      if (_emailCtrl.text.trim().isNotEmpty) {
        await prefs.setString('recovery_email', _emailCtrl.text.trim());
      }

      // Sync Supabase (best effort)
      await SupabaseService.registerShop(
        shopName:  _shopNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        city:      _cityCtrl.text.trim(),
        appVersion: '1.0.0',
      );

      // Email chào mừng (best effort)
      if (_emailCtrl.text.trim().isNotEmpty) {
        await BrevoService.sendWelcomeEmail(
          toEmail:  _emailCtrl.text.trim(),
          toName:   _ownerNameCtrl.text.trim(),
          shopName: _shopNameCtrl.text.trim(),
        );
      }

      setState(() { _loading = false; _done = true; });
      _pageCtrl.animateToPage(2, duration: 400.ms, curve: Curves.easeInOut);
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi, vui lòng thử lại')));
    }
  }

  Future<void> _enterApp() async {
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: TextStyle(
            color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _kMuted.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, color: color, size: 20),
            filled: true, fillColor: _kCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 2)),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE74C3C))),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1930),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2840))),
      child: Text(label,
        style: const TextStyle(
          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
