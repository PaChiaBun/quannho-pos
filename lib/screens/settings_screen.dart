import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../core/repositories/module_repository.dart';
import '../core/providers/session_provider.dart';
import '../core/services/user_auth_service.dart';
import '../core/widgets/create_store_sheet.dart';
import '../features/backup/backup_screen.dart';
import 'bug_report_screen.dart';
import 'pin_lock_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modules/bill_printer/screens/printer_settings_screen.dart';
import '../core/services/auto_update_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN — Cài đặt Quán Nhỏ POS
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kGreen  = Color(0xFF2E7D32);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopNameAsync  = ref.watch(shopNameProvider);

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

          // ── Bảo mật ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.lock_rounded,
              title: 'Bảo mật',
              color: const Color(0xFF1565C0),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PinToggleTile(),
                _RecoveryEmailTile(),
                _QuickPinTile(),
              ]),
            ),
          ),

          // ── Thiết bị & In ấn ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.print_rounded,
              title: 'In ấn & Thiết bị',
              color: _kOrange,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsTile(
                  icon: Icons.print_rounded,
                  label: 'Cấu hình máy in & Tem nhãn',
                  subtitle: 'Phân trạm: Thu ngân, Bếp nóng, Bếp Bar, Stickers',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                  ),
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
                  subtitle: 'Xuất CSV — Đơn hàng, Lương, Tồn kho...',
                  color: _kGreen,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BackupScreen())),
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
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BugReportScreen())),
                ),
                _SettingsTile(
                  icon: Icons.system_update_rounded,
                  label: 'Kiểm tra cập nhật',
                  subtitle: 'Cập nhật phiên bản Windows tự động',
                  color: const Color(0xFFE85D20),
                  onTap: () => AutoUpdateService.checkForUpdates(context, showNoUpdateDialog: true),
                ),
              ]),
            ),
          ),

          // ── Tài khoản ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.account_circle_rounded,
              title: 'Tài khoản',
              color: const Color(0xFF1565C0),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _AccountTile(ref: ref),
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

  Widget _buildFooter() => FutureBuilder(
    future: _getVersionString(),
    builder: (context, snapshot) {
      final versionText = snapshot.data ?? 'Phiên bản ...';
      return Container(
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
            Text(versionText,
              style: const TextStyle(
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
    },
  );

  static Future<String> _getVersionString() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Phiên bản ${info.version} • Build ${info.buildNumber}';
    } catch (_) {
      return 'Phiên bản 1.0.0';
    }
  }

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

  void _showLoyaltySettings(BuildContext context, WidgetRef ref) {}
}


// ─────────────────────────────────────────────────────────────────────────────
// SHOP INFO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ShopInfoCard extends ConsumerWidget {
  final String shopName;
  const _ShopInfoCard({required this.shopName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Column(
      children: [
        // ── Profile card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar gradient với chữ cái đầu
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1C5E), Color(0xFFE85D20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E1C5E).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    shopName.isEmpty ? '?' : shopName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26, fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session?.storeName ?? shopName,
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1207),
                        letterSpacing: -0.4,
                      )),
                    const SizedBox(height: 3),
                    if ((session?.displayName ?? '').isNotEmpty)
                      Text(session!.displayName!,
                        style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF7A6E66),
                          fontWeight: FontWeight.w500)),
                    if ((session?.phone ?? '').isNotEmpty)
                      Text(session!.phone!,
                        style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9085))),
                  ],
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () => _openEditShop(context, ref, shopName),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded,
                    color: Color(0xFFE85D20), size: 18),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Mã kết nối nhân viên ─────────────────────────────────────
        if (session?.storeCode != null) ...[
          _StoreCodeCard(storeCode: session!.storeCode!),
        ] else ...[
          // Chưa có quán
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0D8CC)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                    size: 28, color: Color(0xFFE85D20)),
                ),
                const SizedBox(height: 12),
                const Text('Bạn chưa tạo quán',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1207))),
                const SizedBox(height: 4),
                const Text('Tạo quán để bắt đầu quản lý nhân viên,\ndoanh thu và kết nối đội nhóm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5, color: Color(0xFF9E9085), height: 1.4)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showCreateStoreSheet(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tạo quán ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85D20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORE CODE CARD — Mã kết nối nhân viên với giải thích rõ ràng
// ─────────────────────────────────────────────────────────────────────────────
class _StoreCodeCard extends StatelessWidget {
  final String storeCode;
  const _StoreCodeCard({required this.storeCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header gradient ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1C5E), Color(0xFF2D2B8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_add_rounded,
                    color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã kết nối nhân viên',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('Chia sẻ mã này để thêm thành viên vào quán',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Code display ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE85D20).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_rounded,
                        size: 18, color: Color(0xFFE85D20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(storeCode,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900,
                            color: Color(0xFFE85D20),
                            letterSpacing: 3,
                          )),
                      ),
                      // Copy button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: storeCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Đã copy mã quán'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF2E7D32),
                              duration: Duration(seconds: 2),
                            ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1C5E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded,
                                size: 14, color: Colors.white),
                              SizedBox(width: 5),
                              Text('Copy',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Hướng dẫn 3 bước ────────────────────────────────
                const Text('Cách nhân viên kết nối vào quán:',
                  style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800,
                    color: Color(0xFF5A5260))),
                const SizedBox(height: 10),

                _buildStep(
                  step: '1',
                  icon: Icons.download_rounded,
                  color: const Color(0xFF1565C0),
                  title: 'Tải app Quán Nhỏ',
                  desc: 'Nhân viên cài đặt ứng dụng trên điện thoại',
                ),
                _buildStep(
                  step: '2',
                  icon: Icons.input_rounded,
                  color: const Color(0xFFE85D20),
                  title: 'Nhập mã quán',
                  desc: 'Vào màn hình "Kết nối quán" → nhập mã $storeCode',
                ),
                _buildStep(
                  step: '3',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF2E7D32),
                  title: 'Bắt đầu làm việc',
                  desc: 'Nhân viên được thêm vào quán tự động',
                  isLast: true,
                ),

                const SizedBox(height: 14),

                // ── Share button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(
                        text: 'Tải app Quán Nhỏ POS và nhập mã quán: $storeCode để vào làm nhé! 🏪'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Đã copy lời mời — dán vào Zalo/Messenger gửi nhân viên!'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ));
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Sao chép lời mời gửi nhân viên'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E1C5E),
                      side: const BorderSide(color: Color(0xFF1E1C5E), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String step,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator + connector line
          Column(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.40), width: 1.5),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: const Color(0xFFE0D8CC),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(title,
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1207))),
                  const SizedBox(height: 2),
                  Text(desc,
                    style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF9E9085),
                      height: 1.4)),
                ],
              ),
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
          activeThumbColor: color,
          activeTrackColor: color.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY SETTINGS SHEET — Đầy đủ: preset + custom + save
// ─────────────────────────────────────────────────────────────────────────────
class _LoyaltySettingsSheet extends ConsumerStatefulWidget {
  const _LoyaltySettingsSheet();

  @override
  ConsumerState<_LoyaltySettingsSheet> createState() =>
      _LoyaltySettingsSheetState();
}

class _LoyaltySettingsSheetState
    extends ConsumerState<_LoyaltySettingsSheet> {
  static const _kPurple = Color(0xFF7B1FA2);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kInk    = Color(0xFF1A1207);

  // Các preset tỷ lệ phổ biến (VND = 1 điểm)
  static const _presets = [5000.0, 10000.0, 20000.0, 50000.0];

  late TextEditingController _customCtrl;
  double? _selectedRate; // null = dùng custom input
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _customCtrl = TextEditingController();
    // Load rate hiện tại
    ref.read(loyaltyRateProvider.future).then((rate) {
      if (!mounted) return;
      if (_presets.contains(rate)) {
        setState(() => _selectedRate = rate);
      } else {
        setState(() {
          _selectedRate = null;
          _customCtrl.text = rate.toStringAsFixed(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  double get _effectiveRate {
    if (_selectedRate != null) return _selectedRate!;
    return double.tryParse(_customCtrl.text) ?? 10000;
  }

  String _fmtRate(double rate) {
    if (rate >= 1000000) return '${(rate / 1000000).toStringAsFixed(1)}Tr';
    if (rate >= 1000) return '${(rate / 1000).toStringAsFixed(0)}K';
    return rate.toStringAsFixed(0);
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

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.loyalty_rounded,
                    color: _kPurple, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Cài đặt điểm thưởng',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      color: _kInk)),
            ]),
            const SizedBox(height: 20),

            // Preview box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.stars_rounded, color: _kPurple, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tỷ lệ hiện tại',
                        style: TextStyle(fontSize: 12,
                            color: _kPurple, fontWeight: FontWeight.w600)),
                    Text(
                      '${_fmtRate(_effectiveRate)}đ = 1 điểm',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: _kPurple),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ví dụ: đơn 200,000đ → ${(200000 / _effectiveRate).floor()} điểm',
                      style: TextStyle(fontSize: 11,
                          color: _kPurple.withValues(alpha: 0.7)),
                    ),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // Preset chips
            const Text('Chọn nhanh:',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((rate) {
                final isSelected = _selectedRate == rate;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedRate = rate;
                    _customCtrl.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _kPurple : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _kPurple : _kBorder,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: _kPurple.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 3)),
                      ] : [],
                    ),
                    child: Text(
                      '${_fmtRate(rate)}đ = 1đ',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : _kInk),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom input
            const Text('Hoặc nhập thủ công:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kMuted)),
            const SizedBox(height: 8),
            TextField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, color: _kInk),
              onChanged: (_) => setState(() => _selectedRate = null),
              decoration: InputDecoration(
                hintText: 'Ví dụ: 15000 (15.000đ = 1 điểm)',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                suffixText: 'đ = 1 điểm',
                suffixStyle: const TextStyle(color: _kMuted, fontSize: 13),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kPurple, width: 2)),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _saving ? 'Đang lưu...' : 'Lưu cài đặt',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final rate = _effectiveRate;
    if (rate <= 0) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider)
          .set('loyalty_rate', rate.toStringAsFixed(0));
      ref.invalidate(loyaltyRateProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đã lưu: ${_fmtRate(rate)}đ = 1 điểm',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: _kPurple,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT TILE — Thông tin tài khoản + Đăng xuất
// ─────────────────────────────────────────────────────────────────────────────
class _AccountTile extends ConsumerWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AccountTile({required WidgetRef ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8CC)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.person_rounded,
                color: Color(0xFF1565C0), size: 20),
            ),
            title: Text(session?.displayName ?? 'Người dùng',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFF1A1207))),
            subtitle: Text(session?.phone ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.logout_rounded,
                color: Color(0xFFC62828), size: 20),
            ),
            title: const Text('Đăng xuất',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFFC62828))),
            subtitle: const Text('Quay về màn hình đăng nhập',
              style: TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('Bạn sẽ cần đăng nhập lại để vào app.',
          style: TextStyle(color: Color(0xFF9E9085))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserAuthService.logout();
              ref.read(sessionProvider.notifier).clear();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Đăng xuất'),
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
        await ref.read(settingsRepositoryProvider).set('shop_name', name);
        ref.invalidate(shopNameProvider);
      },
    ),
  );
}

// ignore: unused_element
void _openBillSettings(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BillSettingsSheet(ref: ref),
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

// ─────────────────────────────────────────────────────────────────────────────
// BILL SETTINGS SHEET — SĐT, địa chỉ, footer hoá đơn
// ─────────────────────────────────────────────────────────────────────────────
class _BillSettingsSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  // ignore: use_super_parameters
  const _BillSettingsSheet({required this.ref});

  @override
  ConsumerState<_BillSettingsSheet> createState() => _BillSettingsSheetState();
}

class _BillSettingsSheetState extends ConsumerState<_BillSettingsSheet> {
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _footerCtrl  = TextEditingController();
  bool _loading = true;
  bool _saving  = false;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kGreen  = Color(0xFF2E7D32);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final repo = ref.read(settingsRepositoryProvider);
    _phoneCtrl.text   = await repo.shopPhone;
    _addressCtrl.text = await repo.shopAddress;
    _footerCtrl.text  = await repo.billFooter;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
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
        child: _loading
            ? const SizedBox(height: 160,
                child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: _kGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Thông tin hoá đơn',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: _kNavy)),
                  ]),
                  const SizedBox(height: 20),

                  _field(_phoneCtrl,   'SĐT quán',   Icons.phone_rounded,   TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_addressCtrl, 'Địa chỉ',    Icons.location_on_rounded, TextInputType.streetAddress),
                  const SizedBox(height: 12),
                  _field(_footerCtrl,  'Lời cuối hoá đơn',
                      Icons.format_quote_rounded, TextInputType.text,
                      hint: 'Cảm ơn quý khách!'),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 Thông tin này sẽ in lên đầu/cuối mỗi hoá đơn.',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu cài đặt',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      TextInputType type, {String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: _kGreen, size: 18),
        filled: true, fillColor: _kBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kGreen, width: 2)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.set('shop_phone',   _phoneCtrl.text.trim());
      await repo.set('shop_address', _addressCtrl.text.trim());
      await repo.set('bill_footer',  _footerCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Đã lưu thông tin hoá đơn'),
          behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN TOGGLE TILE — Bật/Tắt khoá PIN trong Settings
// ─────────────────────────────────────────────────────────────────────────────
class _PinToggleTile extends ConsumerWidget {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBlue   = Color(0xFF1565C0);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBorder = Color(0xFFE0D8CC);

  const _PinToggleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinAsync  = ref.watch(pinEnabledProvider);
    final enabled   = pinAsync.value ?? false;
    final settingsRepo = ref.read(settingsRepositoryProvider);

    return Column(children: [
      // ── Toggle ─────────────────────────────────────────────────────
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.lock_rounded, color: _kBlue, size: 20),
          ),
          title: const Text('Khoá bằng PIN',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
          subtitle: Text(
            enabled ? 'Yêu cầu PIN khi mở ứng dụng' : 'Tắt — không cần PIN khi mở app',
            style: const TextStyle(fontSize: 12, color: _kMuted)),
          value: enabled,
          activeColor: _kBlue,  // ignore: deprecated_member_use
          onChanged: (v) async {
            HapticFeedback.selectionClick();
            if (v) {
              // Bật PIN → mở màn hình đặt PIN
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const PinLockScreen(mode: PinMode.set),
                ),
              );
            } else {
              // Tắt PIN
              await settingsRepo.set('pin_enabled', 'false');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔓 Đã tắt khoá PIN'),
                    behavior: SnackBarBehavior.floating));
              }
            }
            // Reactive: invalidate để rebuild
            ref.invalidate(pinEnabledProvider);
          },
        ),
      ),

      // ── Đổi PIN (chỉ hiện khi bật) ─────────────────────────────────
      if (enabled)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_rounded, color: _kBlue, size: 20),
            ),
            title: const Text('Đổi mã PIN',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
            subtitle: const Text('Thay đổi mã PIN hiện tại',
              style: TextStyle(fontSize: 12, color: _kMuted)),
            trailing: const Icon(Icons.chevron_right_rounded, color: _kMuted),
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const PinLockScreen(mode: PinMode.change),
                ),
              );
              ref.invalidate(pinEnabledProvider);
            },
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOVERY EMAIL TILE — Hiển thị + chỉnh sửa email khôi phục PIN
// ─────────────────────────────────────────────────────────────────────────────
class _RecoveryEmailTile extends ConsumerWidget {
  const _RecoveryEmailTile();

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kBlue   = Color(0xFF4F9EFF);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBorder = Color(0xFFE0D8CC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(settingsRepositoryProvider).get('recovery_email'),
      builder: (_, snapshot) {
        final email = snapshot.data ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _kBorder)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: const Icon(Icons.mail_outline_rounded,
                color: _kBlue, size: 20),
            ),
            title: const Text('Email khôi phục PIN',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: _kNavy)),
            subtitle: Text(
              email.isEmpty ? 'Chưa đặt — Nhấn để thêm' : email,
              style: TextStyle(
                fontSize: 12,
                color: email.isEmpty ? _kMuted : _kBlue,
                fontStyle: email.isEmpty
                    ? FontStyle.italic : FontStyle.normal)),
            trailing: const Icon(Icons.edit_rounded,
              color: _kMuted, size: 18),
            onTap: () => _showEditDialog(context, ref, email),
          ),
        );
      },
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, String currentEmail) {
    final ctrl = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        title: const Text('Email khôi phục PIN',
          style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dùng để nhận mã OTP khi quên PIN.\nNên dùng email bạn thường xuyên kiểm tra.',
              style: TextStyle(fontSize: 13, color: Colors.black54,
                height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                hintText: 'your@email.com',
                prefixIcon: const Icon(Icons.email_rounded,
                  color: _kBlue, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBlue, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy',
              style: TextStyle(color: _kMuted))),
          ElevatedButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty || email.contains('@')) {
                await ref.read(settingsRepositoryProvider)
                    .set('recovery_email', email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(email.isEmpty
                        ? '✅ Đã xóa email khôi phục'
                        : '✅ Email khôi phục: $email'),
                    behavior: SnackBarBehavior.floating));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK PIN TILE — Cấu hình mã PIN duyệt nhanh 4 số
// ─────────────────────────────────────────────────────────────────────────────
class _QuickPinTile extends ConsumerWidget {
  const _QuickPinTile();

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBorder = Color(0xFFE0D8CC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isManager = session?.isOwner == true ||
        session?.role == 'owner' || session?.role == 'manager';

    if (!isManager) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: UserAuthService.hasQuickPin(),
      builder: (context, snapshot) {
        final hasPin = snapshot.data ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.offline_pin_rounded, color: _kOrange, size: 20),
            ),
            title: const Text('Mã PIN duyệt nhanh',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
            subtitle: Text(
              hasPin
                  ? 'Đã thiết lập — Nhấp để thay đổi'
                  : 'PIN 4 số duyệt hủy bàn, hủy món tại chỗ',
              style: TextStyle(
                fontSize: 12,
                color: hasPin ? const Color(0xFF4CAF50) : _kMuted,
                fontWeight: hasPin ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: _kMuted),
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _QuickPinSheet(hasPin: hasPin),
              );
              // Force rebuild when sheet returns to show updated status
              if (context.mounted) {
                (context as Element).markNeedsBuild();
              }
            },
          ),
        );
      }
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK PIN SHEET — Giao diện thiết lập PIN duyệt nhanh
// ─────────────────────────────────────────────────────────────────────────────
class _QuickPinSheet extends ConsumerStatefulWidget {
  final bool hasPin;
  const _QuickPinSheet({required this.hasPin});

  @override
  ConsumerState<_QuickPinSheet> createState() => _QuickPinSheetState();
}

class _QuickPinSheetState extends ConsumerState<_QuickPinSheet> {
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.offline_pin_rounded,
                      color: _kOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Text(widget.hasPin ? 'Đổi mã PIN duyệt nhanh 4 số' : 'Mã PIN duyệt nhanh 4 số',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: _kNavy)),
              ]),
              const SizedBox(height: 16),

              // Card giải thích công dụng mã PIN
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded, color: _kOrange, size: 16),
                      const SizedBox(width: 6),
                      Text('MÃ PIN DUYỆT NHANH DÙNG LÀM GÌ?',
                          style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w800, color: _kOrange)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Đây là mã PIN 4 chữ số được sử dụng để Quản lý hoặc Chủ quán phê duyệt nhanh tại chỗ khi nhân viên phục vụ thực hiện các thao tác nhạy cảm như Hủy bàn hoặc Hủy món đã gửi bếp.\n\nSử dụng mã PIN này giúp bảo vệ doanh thu quán của bạn khỏi thất thoát, gian lận mà không cần phải tiết lộ mật khẩu tài khoản đăng nhập chính.',
                      style: GoogleFonts.outfit(
                        fontSize: 12, color: _kNavy.withValues(alpha: 0.75), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mật khẩu PIN mới
              TextField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: widget.hasPin ? 'Mã PIN mới (4 chữ số)' : 'Mã PIN mới (4 chữ số)',
                  labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _kOrange, size: 18),
                  filled: true, fillColor: _kBg,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kOrange, width: 2)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Xác nhận PIN mới
              TextField(
                controller: _confirmPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: widget.hasPin ? 'Xác nhận mã PIN mới' : 'Xác nhận mã PIN mới',
                  labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: _kOrange, size: 18),
                  filled: true, fillColor: _kBg,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kOrange, width: 2)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Đang lưu...' : (widget.hasPin ? 'Cập nhật mã PIN' : 'Lưu mã PIN'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = '❌ Mã PIN phải là 4 chữ số');
      return;
    }

    if (pin != confirm) {
      setState(() => _error = '❌ Mã PIN xác nhận không khớp');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ok = await UserAuthService.updateQuickPin(pin);
      if (ok && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.hasPin
              ? '✅ Đã cập nhật mã PIN duyệt nhanh thành công!'
              : '✅ Đã lưu mã PIN duyệt nhanh thành công!'),
          behavior: SnackBarBehavior.floating));
      } else {
        setState(() => _error = '❌ Không lưu được PIN. Lỗi kết nối.');
      }
    } catch (e) {
      setState(() => _error = '❌ Lỗi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

