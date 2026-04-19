import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN — Wizard lần đầu mở app
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  // Step 2 — Tên quán
  final _shopNameCtrl = TextEditingController(text: 'Quán Nhỏ');

  // Step 3 — Modules
  final _selectedModules = <String>{
    'pos', 'kho', 'finance', 'loyalty', 'report'
  };

  bool _saving = false;

  // Colors
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  @override
  void dispose() {
    _pageCtrl.dispose();
    _shopNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background gradient blob
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kNavy.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withValues(alpha: 0.06),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 56),

              // ── Progress dots ──────────────────────────────────────
              _buildProgressDots(),

              // ── Pages ─────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _buildPage0(),
                    _buildPage1(),
                    _buildPage2(),
                    _buildPage3(),
                  ],
                ),
              ),

              // ── Bottom action ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                            : Text(
                                _page == 3
                                    ? '🚀 Bắt đầu dùng app!'
                                    : _page == 0
                                        ? 'Bắt đầu thiết lập'
                                        : 'Tiếp theo   →',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                    if (_page > 0 && _page < 3) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _prevPage,
                        child: Text('← Quay lại',
                          style: TextStyle(
                            color: _kMuted, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRESS DOTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _page == i ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _page == i ? _kNavy : _kBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        )),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 0 — Welcome
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPage0() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo + glow
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kNavy, _kNavyL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: _kNavy.withValues(alpha: 0.3),
                  blurRadius: 32, offset: const Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset('assets/branding/app_icon.png',
                fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 36),

          const Text('Chào mừng đến',
            style: TextStyle(
              fontSize: 16, color: _kMuted,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5)),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(text: 'Quán Nhỏ',
                  style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w900,
                    color: _kNavy, letterSpacing: -0.5)),
                TextSpan(text: ' POS',
                  style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w900,
                    color: _kOrange, letterSpacing: -0.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hệ thống quản lý cửa hàng\nđơn giản, mạnh mẽ, offline-first.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, color: _kMuted, height: 1.5)),
          const SizedBox(height: 40),

          // Feature pills
          _FeaturePill(
            emoji: '⚡', text: 'Bán hàng cực nhanh'),
          const SizedBox(height: 10),
          _FeaturePill(
            emoji: '📦', text: 'Quản lý kho thông minh'),
          const SizedBox(height: 10),
          _FeaturePill(
            emoji: '💰', text: 'Theo dõi thu chi tự động'),
          const SizedBox(height: 10),
          _FeaturePill(
            emoji: '🏅', text: 'Chương trình điểm thưởng'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 1 — Tên quán
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.storefront_rounded,
              color: _kOrange, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('Quán của bạn\ntên là gì?',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: _kNavy, height: 1.2, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            'Tên này sẽ xuất hiện trên màn hình chính và hoá đơn.',
            style: const TextStyle(fontSize: 15, color: _kMuted, height: 1.4)),
          const SizedBox(height: 32),

          // Shop name field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color: _kNavy.withValues(alpha: 0.06),
                  blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: TextField(
              controller: _shopNameCtrl,
              autofocus: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: _kNavy, letterSpacing: -0.3),
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Snack Trà Sữa 88',
                hintStyle: TextStyle(
                  fontSize: 16, color: _kMuted,
                  fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick presets
          const Text('Gợi ý nhanh:',
            style: TextStyle(fontSize: 12, color: _kMuted,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              'Quán Nhỏ', 'Trà Sữa Nhà Làm',
              'Snack Corner', 'Coffee & More', 'Bếp Nhà Mình',
            ].map((name) => GestureDetector(
              onTap: () {
                _shopNameCtrl.text = name;
                _shopNameCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: name.length));
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(name,
                  style: const TextStyle(
                    fontSize: 13, color: _kNavy,
                    fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 2 — Chọn modules
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPage2() {
    final modules = [
      _ModuleInfo('pos',     '🛒', 'Bán hàng',     'POS nhanh, giỏ hàng, thanh toán', required: true),
      _ModuleInfo('kho',     '📦', 'Kho hàng',     'Theo dõi tồn kho, nhập xuất'),
      _ModuleInfo('finance', '💰', 'Thu Chi',       'Ghi thu, ghi chi, báo cáo lợi nhuận'),
      _ModuleInfo('loyalty', '🏅', 'Điểm thưởng',  'Tích điểm, đổi thưởng cho khách'),
      _ModuleInfo('report',  '📊', 'Báo cáo',      'Biểu đồ doanh thu, top sản phẩm'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.extension_rounded,
              color: _kNavy, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('Chọn tính năng\nbạn muốn dùng',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: _kNavy, height: 1.2, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text(
            'Có thể bật/tắt bất kỳ lúc nào trong Cài đặt.',
            style: TextStyle(fontSize: 15, color: _kMuted)),
          const SizedBox(height: 24),

          ...modules.map((m) {
            final selected = _selectedModules.contains(m.id);
            return GestureDetector(
              onTap: () {
                if (m.required) return; // POS luôn bật
                HapticFeedback.selectionClick();
                setState(() {
                  if (selected) {
                    _selectedModules.remove(m.id);
                  } else {
                    _selectedModules.add(m.id);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? _kNavy : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _kNavy : _kBorder,
                    width: selected ? 0 : 1),
                  boxShadow: selected ? [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.2),
                      blurRadius: 12, offset: const Offset(0, 4)),
                  ] : [],
                ),
                child: Row(
                  children: [
                    Text(m.emoji,
                      style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m.name,
                                style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : _kNavy)),
                              if (m.required) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6)),
                                  child: Text('Bắt buộc',
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white70
                                          : _kNavy.withValues(alpha: 0.5))),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(m.desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white70
                                  : _kMuted)),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : _kBorder.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: _kNavy)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 3 — Tất cả xong!
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Checkmark container
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                  blurRadius: 32, offset: const Offset(0, 12)),
              ],
            ),
            child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 64),
          ),
          const SizedBox(height: 32),

          const Text('Sẵn sàng rồi! 🎉',
            style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w900,
              color: _kNavy, letterSpacing: -0.5)),
          const SizedBox(height: 12),

          // Shop name display
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: BorderRadius.circular(14)),
            child: Text(
              _shopNameCtrl.text.isEmpty
                  ? 'Quán Nhỏ' : _shopNameCtrl.text,
              style: const TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),

          const Text(
            'Đã thiết lập xong! Bạn có thể\nbắt đầu bán hàng ngay bây giờ.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, color: _kMuted, height: 1.5)),
          const SizedBox(height: 32),

          // Summary chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 8,
            children: _selectedModules.map((id) {
              final info = {
                'pos': '🛒 Bán hàng',
                'kho': '📦 Kho hàng',
                'finance': '💰 Thu Chi',
                'loyalty': '🏅 Điểm thưởng',
                'report': '📊 Báo cáo',
              }[id] ?? id;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(info,
                  style: const TextStyle(
                    fontSize: 13, color: _kNavy,
                    fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────
  void _nextPage() async {
    if (_page < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else if (_page == 2) {
      // Trang summary
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      // Trang cuối — lưu và vào app
      await _finishSetup();
    }
  }

  void _prevPage() {
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishSetup() async {
    setState(() => _saving = true);
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final moduleRepo = ref.read(moduleRepositoryProvider);

      // Lưu tên quán
      final name = _shopNameCtrl.text.trim();
      await settings.set('shop_name', name.isEmpty ? 'Quán Nhỏ' : name);

      // Đánh dấu onboarding done
      await settings.set('onboarding_done', 'true');

      // Bật/tắt modules theo lựa chọn
      final allModules = await moduleRepo.getAll();
      for (final m in allModules) {
        if (_selectedModules.contains(m.id)) {
          await moduleRepo.activate(m.id);
        } else {
          await moduleRepo.deactivate(m.id);
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final String emoji, text;
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBorder = Color(0xFFE0D8CC);

  const _FeaturePill({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(text,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: _kNavy)),
      ],
    ),
  );
}

class _ModuleInfo {
  final String id, emoji, name, desc;
  final bool required;
  const _ModuleInfo(this.id, this.emoji, this.name, this.desc,
      {this.required = false});
}
