import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN — Cài đặt Quán Nhỏ POS
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kGreen  = Color(0xFF2E7D32);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopNameAsync  = ref.watch(shopNameProvider);
    final modulesAsync   = ref.watch(allModulesProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient AppBar ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _kNavy,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: const Text('Cài đặt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                )),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kNavy, _kNavyL],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // ── Shop Info Card ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _ShopInfoCard(
                shopName: shopNameAsync.value ?? 'Quán Nhỏ',
              ),
            ),
          ),

          // ── Modules Toggle ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.extension_rounded,
              title: 'Modules',
              color: _kOrange,
            ),
          ),
          modulesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (modules) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final m = modules[i];
                    return _ModuleTile(
                      module: m,
                      onToggle: (v) {
                      final repo = ref.read(moduleRepositoryProvider);
                      if (v) {
                        repo.activate(m.id);
                      } else {
                        repo.deactivate(m.id);
                      }
                    },
                    );
                  },
                  childCount: modules.length,
                ),
              ),
            ),
          ),

          // ── Tài khoản & Quản lý ────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.manage_accounts_rounded,
              title: 'Quản lý',
              color: _kNavy,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsTile(
                  icon: Icons.people_rounded,
                  label: 'Nhân viên',
                  subtitle: 'Quản lý ca và quyền truy cập',
                  color: _kNavy,
                  onTap: () => _comingSoon(context),
                ),
                _SettingsTile(
                  icon: Icons.loyalty_rounded,
                  label: 'Điểm thưởng',
                  subtitle: 'Tỷ lệ quy đổi & quà tặng',
                  color: const Color(0xFF7B1FA2),
                  onTap: () => _showLoyaltySettings(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'In hoá đơn',
                  subtitle: 'Máy in Bluetooth & nhiệt',
                  color: _kGreen,
                  onTap: () => _comingSoon(context),
                ),
              ]),
            ),
          ),

          // ── Dữ liệu ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.storage_rounded,
              title: 'Dữ liệu',
              color: _kGreen,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsTile(
                  icon: Icons.backup_rounded,
                  label: 'Sao lưu',
                  subtitle: 'Google Drive & file cục bộ',
                  color: _kGreen,
                  onTap: () => _comingSoon(context),
                ),
                _SettingsTile(
                  icon: Icons.restore_rounded,
                  label: 'Khôi phục',
                  subtitle: 'Từ bản sao dự phòng',
                  color: _kOrange,
                  onTap: () => _comingSoon(context),
                ),
                _SettingsTile(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Xoá dữ liệu',
                  subtitle: 'Reset toàn bộ — không thể hoàn tác',
                  color: const Color(0xFFC62828),
                  onTap: () => _confirmReset(context, ref),
                ),
              ]),
            ),
          ),

          // ── Về ứng dụng ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.info_rounded,
              title: 'Về ứng dụng',
              color: _kMuted,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsTile(
                  icon: Icons.smart_toy_rounded,
                  label: 'Trợ lý AI',
                  subtitle: 'Gemini • Tích hợp sẵn',
                  color: const Color(0xFF1565C0),
                  onTap: () => _comingSoon(context),
                ),
                _SettingsTile(
                  icon: Icons.bug_report_rounded,
                  label: 'Gửi phản hồi',
                  subtitle: 'Báo lỗi & đề xuất tính năng',
                  color: _kMuted,
                  onTap: () => _comingSoon(context),
                ),
              ]),
            ),
          ),

          // ── App Footer ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() => Container(
    margin: const EdgeInsets.fromLTRB(16, 24, 16, 40),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_kNavy, _kNavyL],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.store_rounded,
            color: Colors.white, size: 30),
        ),
        const SizedBox(height: 12),
        const Text('Quán Nhỏ POS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18, fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          )),
        const SizedBox(height: 4),
        const Text('Phiên bản 1.0.0 • Build 2026',
          style: TextStyle(
            color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('Made with ❤️ by LPM Digital',
            style: TextStyle(
              color: Colors.white70, fontSize: 12,
              fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );

  void _comingSoon(BuildContext context) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💡 Tính năng đang phát triển — sắp ra mắt!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Xoá toàn bộ dữ liệu?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
          'Thao tác này sẽ xoá tất cả đơn hàng, kho hàng, và thu chi. Không thể hoàn tác.',
          style: TextStyle(color: Color(0xFF9E9085))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _comingSoon(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoá tất cả'),
          ),
        ],
      ),
    );
  }

  void _showLoyaltySettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LoyaltySettingsSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOP INFO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ShopInfoCard extends ConsumerWidget {
  final String shopName;
  const _ShopInfoCard({required this.shopName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar gradient
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1C5E), Color(0xFFE85D20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                shopName.isEmpty ? '?' : shopName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24, fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1207),
                    letterSpacing: -0.3,
                  )),
                const SizedBox(height: 2),
                const Text('123 Nguyễn Huệ, Q.1, TP.HCM',
                  style: TextStyle(
                    fontSize: 12, color: Color(0xFF9E9085))),
                const Text('0901 234 567',
                  style: TextStyle(
                    fontSize: 12, color: Color(0xFF9E9085))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded,
              color: Color(0xFFE85D20), size: 20),
            onPressed: () => _openEditShop(context, ref, shopName),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFF3E0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULE TILE — Toggle bật/tắt module
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleTile extends StatelessWidget {
  final ModuleConfig module;
  final void Function(bool) onToggle;

  const _ModuleTile({required this.module, required this.onToggle});

  static final _moduleInfo = {
    'pos':     (Icons.shopping_cart_rounded,  'Bán hàng',  Color(0xFF1E1C5E)),
    'kho':     (Icons.inventory_2_rounded,    'Kho hàng',  Color(0xFF2E7D32)),
    'finance': (Icons.account_balance_wallet_rounded, 'Thu Chi', Color(0xFFE85D20)),
    'loyalty': (Icons.loyalty_rounded,        'Điểm thưởng', Color(0xFF7B1FA2)),
    'report':  (Icons.bar_chart_rounded,      'Báo cáo',   Color(0xFF1565C0)),
  };

  @override
  Widget build(BuildContext context) {
    final info = _moduleInfo[module.id];
    final icon  = info?.$1 ?? Icons.extension_rounded;
    final label = info?.$2 ?? module.id;
    final color = info?.$3 ?? const Color(0xFF9E9085);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8CC)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: Color(0xFF1A1207))),
        subtitle: Text(
          module.isActive ? 'Đang bật' : 'Đang tắt',
          style: TextStyle(
            fontSize: 12,
            color: module.isActive
                ? const Color(0xFF2E7D32)
                : const Color(0xFF9E9085),
          )),
        trailing: Switch.adaptive(
          value: module.isActive,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onToggle(v);
          },
          activeColor: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY SETTINGS SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _LoyaltySettingsSheet extends ConsumerWidget {
  const _LoyaltySettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyRate = ref.watch(loyaltyRateProvider).value ?? 0.01;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D8CC),
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Cài đặt điểm thưởng',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1207))),
          const SizedBox(height: 20),

          // Rate info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.loyalty_rounded,
                  color: Color(0xFF7B1FA2), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tỷ lệ tích điểm hiện tại',
                        style: TextStyle(
                          fontSize: 13, color: Color(0xFF7B1FA2),
                          fontWeight: FontWeight.w600)),
                      Text(
                        '${(loyaltyRate * 100).toStringAsFixed(0)}đ = 1 điểm',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: Color(0xFF7B1FA2))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Cài đặt chi tiết sẽ được mở trong bản cập nhật tiếp theo.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9085))),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Đóng',
                style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title,
    required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.5,
          )),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0D8CC)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
        style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: Color(0xFF1A1207))),
      subtitle: Text(subtitle,
        style: const TextStyle(
          fontSize: 12, color: Color(0xFF9E9085))),
      trailing: const Icon(Icons.chevron_right_rounded,
        color: Color(0xFF9E9085), size: 20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OPEN EDIT SHOP
// ─────────────────────────────────────────────────────────────────────────────
void _openEditShop(BuildContext context, WidgetRef ref, String currentName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditShopSheet(
      currentName: currentName,
      onSaved: (name) async {
        await ref.read(settingsRepositoryProvider).set(
          'shop_name', name);
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT SHOP SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EditShopSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String name) onSaved;
  const _EditShopSheet({required this.currentName, required this.onSaved});

  @override
  State<_EditShopSheet> createState() => _EditShopSheetState();
}

class _EditShopSheetState extends State<_EditShopSheet> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded,
                    color: _kOrange, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Thông tin quán',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: _kNavy)),
              ],
            ),
            const SizedBox(height: 20),

            // Shop name field
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tên quán *',
                labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.storefront_rounded,
                  color: _kOrange, size: 18),
                filled: true, fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kOrange, width: 2)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Tên quán hiển thị trên Dashboard và hoá đơn.',
              style: TextStyle(fontSize: 12, color: _kMuted)),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSaved(name);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã lưu tên quán'),
          behavior: SnackBarBehavior.floating),
      );
    }
  }
}
