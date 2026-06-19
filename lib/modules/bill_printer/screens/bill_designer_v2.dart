// lib/modules/bill_printer/screens/bill_designer_v2.dart
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bill_block.dart';
import '../models/bill_template_history.dart';
import '../providers/bill_template_provider.dart';
import '../widgets/bill_preview_widget.dart';
import 'bill_history_sheet.dart';
import 'block_config_sheet.dart';

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);

// ─── Icon map cho từng loại block (thay emoji) ─────────────────────────────
IconData _blockIcon(BillBlockType type) {
  switch (type) {
    case BillBlockType.shopHeader:    return Icons.storefront_rounded;
    case BillBlockType.shopLogo:      return Icons.image_rounded;
    case BillBlockType.shopAddress:   return Icons.location_on_rounded;
    case BillBlockType.shopPhone:     return Icons.phone_rounded;
    case BillBlockType.divider:       return Icons.horizontal_rule_rounded;
    case BillBlockType.orderInfo:     return Icons.receipt_long_rounded;
    case BillBlockType.tableInfo:     return Icons.table_restaurant_rounded;
    case BillBlockType.itemsList:     return Icons.format_list_bulleted_rounded;
    case BillBlockType.totals:        return Icons.calculate_rounded;
    case BillBlockType.paymentMethod: return Icons.payment_rounded;
    case BillBlockType.loyaltyPoints: return Icons.star_rounded;
    case BillBlockType.qrCode:        return Icons.qr_code_rounded;
    case BillBlockType.customText:    return Icons.text_fields_rounded;
    case BillBlockType.spacer:        return Icons.space_bar_rounded;
    case BillBlockType.footer:        return Icons.favorite_border_rounded;
    case BillBlockType.appBranding:   return Icons.rocket_launch_rounded;
  }
}

// Tên hiển thị rõ ràng không dùng emoji substring
String _blockLabel(BillBlockType type) {
  switch (type) {
    case BillBlockType.shopHeader:    return 'Tên quán';
    case BillBlockType.shopLogo:      return 'Logo quán';
    case BillBlockType.shopAddress:   return 'Địa chỉ';
    case BillBlockType.shopPhone:     return 'Số điện thoại';
    case BillBlockType.divider:       return 'Đường kẻ ngang';
    case BillBlockType.orderInfo:     return 'Thông tin đơn';
    case BillBlockType.tableInfo:     return 'Tên bàn';
    case BillBlockType.itemsList:     return 'Danh sách món';
    case BillBlockType.totals:        return 'Tổng tiền';
    case BillBlockType.paymentMethod: return 'Phương thức thanh toán';
    case BillBlockType.loyaltyPoints: return 'Điểm thưởng';
    case BillBlockType.qrCode:        return 'QR Code';
    case BillBlockType.customText:    return 'Văn bản tự do';
    case BillBlockType.spacer:        return 'Khoảng trắng';
    case BillBlockType.footer:        return 'Lời cảm ơn';
    case BillBlockType.appBranding:   return 'Quán Nhỏ POS';
  }
}

class BillDesignerV2 extends ConsumerStatefulWidget {
  const BillDesignerV2({super.key});
  @override
  ConsumerState<BillDesignerV2> createState() => _BillDesignerV2State();
}

class _BillDesignerV2State extends ConsumerState<BillDesignerV2>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Lưu vào lịch sử trước khi ghi đè
    final current = ref.read(billTemplateProvider).value;
    if (current != null) {
      await BillTemplateHistoryService.push(current);
    }
    await ref.read(billTemplateProvider.notifier).save();
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Đã lưu thiết kế hoá đơn',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: _kIndigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTpl = ref.watch(billTemplateProvider);
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: const Text('Thiết Kế Hoá Đơn', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          // Nút lịch sử
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
            tooltip: 'Lịch sử thiết kế',
            onPressed: () => showBillHistorySheet(context, ref),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
              label: Text('Lưu',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: _save,
            ),
        ],
        bottom: isWide ? null : TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kOrange,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Cấu hình'),
            Tab(icon: Icon(Icons.preview_rounded, size: 18), text: 'Xem trước'),
          ],
        ),
      ),
      body: asyncTpl.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (tpl) => isWide
            ? Row(children: [
                SizedBox(width: 420, child: _BlocksPanel(tpl: tpl)),
                const VerticalDivider(width: 1),
                Expanded(child: BillPreviewWidget(tpl: tpl)),
              ])
            : TabBarView(controller: _tab, children: [
                _BlocksPanel(tpl: tpl),
                BillPreviewWidget(tpl: tpl),
              ]),
      ),
    );
  }
}

// ─── Blocks Panel ─────────────────────────────────────────────────────────────
class _BlocksPanel extends ConsumerWidget {
  final dynamic tpl;
  const _BlocksPanel({required this.tpl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = (tpl.blocks as List<BillBlock>);

    return Column(children: [
      // Paper size selector
      _PaperSizeBar(current: tpl.paperSize),
      // Block list
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          onReorder: (o, n) => ref.read(billTemplateProvider.notifier).reorder(o, n),
          itemCount: blocks.length,
          buildDefaultDragHandles: false,
          itemBuilder: (ctx, i) {
            final block = blocks[i];
            return _BlockCard(key: ValueKey(block.id), block: block, index: i);
          },
        ),
      ),
      // Add block button
      _AddBlockBtn(),
    ]);
  }
}

// ─── Paper Size Bar ───────────────────────────────────────────────────────────
// Thông tin mô tả khổ giấy — giúp chủ quán hiểu để chọn đúng
const _kPaperInfo = {
  '58mm': '58mm — Khổ nhỏ | Máy in cầm tay, bill nhỏ gọn. Phù hợp quán take-away hoặc khu vực bếp.',
  '80mm': '80mm — Khổ phổ biến nhất | Máy in quầy thu ngân thông thường. Đa số quán ăn, cà phê, nhà hàng dùng khổ này.',
  'a4':   'A4 — Khổ lớn | In trên máy in văn phòng. Phù hợp nhà hàng cao cấp, in hóa đơn VAT.',
};

class _PaperSizeBar extends ConsumerWidget {
  final String current;
  const _PaperSizeBar({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khổ giấy',
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kIndigo)),
          const SizedBox(height: 8),
          Row(children: [
            _PaperChip(label: '58mm', value: '58mm', selected: current.toLowerCase() == '58mm',
                onTap: () => ref.read(billTemplateProvider.notifier).setPaperSize('58mm')),
            const SizedBox(width: 8),
            _PaperChip(label: '80mm', value: '80mm', selected: current.toLowerCase() == '80mm',
                onTap: () => ref.read(billTemplateProvider.notifier).setPaperSize('80mm')),
            const SizedBox(width: 8),
            _PaperChip(label: 'A4', value: 'a4', selected: current.toLowerCase() == 'a4',
                onTap: () => ref.read(billTemplateProvider.notifier).setPaperSize('a4')),
          ]),
          // Mô tả khổ giấy đang chọn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _kIndigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kIndigo.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded,
                    size: 16, color: _kIndigo.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _kPaperInfo[current.toLowerCase()] ??
                      _kPaperInfo['80mm']!,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _kIndigo,
                      fontWeight: FontWeight.w500,
                      height: 1.5),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Chip chọn khổ giấy
class _PaperChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _PaperChip({
    required this.label, required this.value,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _kIndigo : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected ? _kIndigo : Colors.grey.shade300),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey.shade700)),
    ),
  );
}

// ─── Block Card ───────────────────────────────────────────────────────────────
class _BlockCard extends ConsumerWidget {
  final BillBlock block;
  final int index;
  const _BlockCard({super.key, required this.block, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = block.locked;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: block.enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked ? _kOrange.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: isLocked ? 1.5 : 1,
        ),
        boxShadow: block.enabled
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded,
              color: isLocked ? _kOrange.withValues(alpha: 0.5) : Colors.grey.shade400,
              size: 22),
          ),
          const SizedBox(width: 10),
          // Block icon — dùng Icon Flutter thay emoji (tránh bug substring)
          Icon(
            _blockIcon(block.type),
            size: 20,
            color: block.enabled
                ? (isLocked ? _kOrange : _kIndigo.withValues(alpha: 0.7))
                : Colors.grey.shade400,
          ),
        ]),
        title: Text(
          _blockLabel(block.type), // tên rõ ràng, không dùng emoji.substring
          style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: block.enabled ? _kIndigo : Colors.grey.shade400,
          ),
        ),
        subtitle: isLocked
            ? const Text('Bắt buộc', style: TextStyle(fontSize: 11, color: _kOrange))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          // Config button
          if (!isLocked)
            IconButton(
              icon: Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade600),
              tooltip: 'Cài đặt',
              onPressed: () => _openConfig(context, ref),
            ),
          // Delete or lock icon
          if (isLocked)
            const Tooltip(
              message: 'Block bắt buộc, không thể xóa',
              child: Icon(Icons.lock_rounded, size: 18, color: _kOrange),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
              tooltip: 'Xóa block',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ]),
        onTap: isLocked ? null : () => _openConfig(context, ref),
      ),
    );
  }

  void _openConfig(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlockConfigSheet(block: block),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa ${block.type.label}?'),
        content: const Text('Block này sẽ bị xóa khỏi hoá đơn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              ref.read(billTemplateProvider.notifier).removeBlock(block.id);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Add Block Button ─────────────────────────────────────────────────────────
class _AddBlockBtn extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded, color: _kIndigo),
          label: const Text('Thêm block', style: TextStyle(color: _kIndigo, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kIndigo),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => _showBlockPicker(context, ref),
        ),
      ),
    );
  }

  void _showBlockPicker(BuildContext context, WidgetRef ref) {
    final tpl = ref.read(billTemplateProvider).value;
    final existing = tpl?.blocks.map((b) => b.type).toSet() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Chọn block thêm vào', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 16),
                children: BillBlockType.values.map((type) {
                  final alreadyAdded = existing.contains(type) && !type.isMultiAllowed;
                  return ListTile(
                    leading: Icon(_blockIcon(type), size: 20, color: _kIndigo.withValues(alpha: 0.7)),
                    title: Text(_blockLabel(type),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    subtitle: type.isLocked ? const Text('Bắt buộc') :
                              type.isMultiAllowed ? const Text('Có thể thêm nhiều lần') : null,
                    trailing: alreadyAdded
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                        : const Icon(Icons.add_circle_outline, color: _kIndigo, size: 18),
                    enabled: !alreadyAdded || type.isMultiAllowed,
                    onTap: alreadyAdded && !type.isMultiAllowed ? null : () {
                      ref.read(billTemplateProvider.notifier).addBlock(type);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
