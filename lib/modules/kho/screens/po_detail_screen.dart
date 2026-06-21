import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/kho_theme.dart';
import '../repository/kho_repository.dart';
import '../providers/kho_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PO DETAIL SCREEN — xem chi tiết + huỷ phiếu nhập
// ─────────────────────────────────────────────────────────────────────────────
class PoDetailScreen extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  const PoDetailScreen({super.key, required this.po});

  @override
  ConsumerState<PoDetailScreen> createState() => _PoDetailScreenState();
}

class _PoDetailScreenState extends ConsumerState<PoDetailScreen> {
  late PurchaseOrderModel _po;
  List<PurchaseItemModel> _items = [];
  bool _loadingItems = true;
  bool _cancelling   = false;
  bool _saving       = false;

  // ── helpers
  static const _kNavy   = Color(0xFF1C2151);
  static const _kViolet = Color(0xFF7C3AED);
  static const _kGreen  = Color(0xFF16A34A);
  static const _kRed    = Color(0xFFDC2626);
  static const _kInk    = Color(0xFF1F2937);
  static const _kMuted  = Color(0xFF6B7280);
  static const _kBg     = Color(0xFFF8F6FF);
  static const _kCard   = Colors.white;
  static const _kBorder = Color(0xFFE5E7EB);

  String _fmtMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} Tr Đ';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} K Đ';
    return '${v.toStringAsFixed(0)} Đ';
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) { return iso; }
  }

  @override
  void initState() {
    super.initState();
    _po = widget.po;
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      // Fetch PO tươi từ DB + items song song (tránh timing của realtime stream)
      final results = await Future.wait([
        ref.read(khoRepositoryProvider).fetchPurchaseOrderById(_po.id),
        ref.read(khoRepositoryProvider).getPurchaseItems(_po.id),
      ]);
      final freshPo    = results[0] as PurchaseOrderModel?;
      final freshItems = results[1] as List<PurchaseItemModel>;
      if (mounted) {
        setState(() {
          _items = freshItems;
          _loadingItems = false;
          // Cập nhật toàn bộ PO từ DB (gồm invoice_image_url mới nhất)
          if (freshPo != null) _po = freshPo;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _confirmCancel() async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Huỷ phiếu nhập?',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800, color: _kInk)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phiếu ${_po.poNumber}',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, color: _kViolet)),
              const SizedBox(height: 8),
              Text(
                'Hàng sẽ được hoàn kho tự động. '
                'Thao tác này không thể khôi phục.',
                style: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
              ),
              const SizedBox(height: 16),
              // ── Ô nhập lý do ───────────────────────────────────
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Lý do huỷ (không bắt buộc)...',
                  hintStyle: GoogleFonts.outfit(
                      fontSize: 13, color: _kMuted),
                  filled: true,
                  fillColor: const Color(0xFFF9F9F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kRed, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  counterStyle: GoogleFonts.outfit(
                      fontSize: 10, color: _kMuted),
                ),
                style: GoogleFonts.outfit(fontSize: 13, color: _kInk),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Không', style: GoogleFonts.outfit(color: _kMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _kRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Huỷ phiếu',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(khoRepositoryProvider).cancelPurchaseOrder(
        _po.id,
        cancelReason: reason.isNotEmpty ? reason : null,
        cancelledBy:  'Nhân viên kho', // TODO: lấy từ auth user sau
      );
      if (mounted) {
        setState(() {
          _po = PurchaseOrderModel(
            id: _po.id, poNumber: _po.poNumber,
            supplierId: _po.supplierId, supplierName: _po.supplierName,
            status: 'cancelled', totalAmount: _po.totalAmount,
            note: _po.note, createdAt: _po.createdAt,
            invoiceImageUrl: _po.invoiceImageUrl, items: _items,
          );
          _cancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reason.isNotEmpty
              ? 'Đã huỷ phiếu và hoàn kho · Lý do: $reason'
              : 'Đã huỷ phiếu và hoàn kho'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Edit Sheet ────────────────────────────────────────────────────────────
  Future<void> _showEditSheet() async {
    final noteCtrl = TextEditingController(text: _po.note ?? '');

    // Load danh sách NCC
    List<SupplierModel> suppliers = [];
    try {
      suppliers = await ref.read(khoRepositoryProvider).fetchSuppliers();
    } catch (_) {}

    // ‼️ FIX: mounted check sau await — tránh crash khi widget dispose trong lúc load
    if (!mounted) return;

    String selectedSupplierName = _po.supplierName ?? '';
    final supplierFallbackCtrl = TextEditingController(text: _po.supplierName ?? '');

    String? newImagePath;          // đường dẫn ảnh mới chọn
    String? previewUrl = _po.invoiceImageUrl; // URL hiện tại

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Chỉnh sửa phiếu',
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: _kNavy)),
                Text('Chỉ sửa thông tin — kho & tài chính không thay đổi',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: _kMuted)),
                const SizedBox(height: 20),

                // Ghi chú
                Text('Ghi chú', style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kInk)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ghi chú cho phiếu nhập...',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kViolet, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.outfit(fontSize: 13, color: _kInk),
                ),
                const SizedBox(height: 16),

                // Nhà cung cấp
                Text('Nhà cung cấp', style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kInk)),
                const SizedBox(height: 8),
                if (suppliers.isEmpty)
                  // Nếu chưa có NCC nào → text field thường
                  TextField(
                    controller: supplierFallbackCtrl,
                    onChanged: (v) => selectedSupplierName = v,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhà cung cấp...',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
                      prefixIcon: const Icon(Icons.store_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kViolet, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: GoogleFonts.outfit(fontSize: 13, color: _kInk),
                  )
                else
                  // Chips nhà cung cấp
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Chip "Không rõ"
                      GestureDetector(
                        onTap: () => setS(() => selectedSupplierName = ''),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selectedSupplierName.isEmpty
                                ? _kNavy : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedSupplierName.isEmpty
                                  ? _kNavy : _kBorder,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.store_outlined, size: 13,
                                color: selectedSupplierName.isEmpty
                                    ? Colors.white : _kMuted),
                            const SizedBox(width: 4),
                            Text('Không rõ', style: GoogleFonts.outfit(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selectedSupplierName.isEmpty
                                    ? Colors.white : _kMuted)),
                          ]),
                        ),
                      ),
                      ...suppliers.map((s) {
                        final isSelected = selectedSupplierName == s.name;
                        return GestureDetector(
                          onTap: () => setS(() => selectedSupplierName = s.name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? _kViolet : const Color(0xFFF9F7FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? _kViolet : const Color(0xFFEDE7FE),
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.store_rounded, size: 13,
                                  color: isSelected ? Colors.white : _kViolet),
                              const SizedBox(width: 4),
                              Text(s.name, style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : _kViolet)),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                const SizedBox(height: 16),

                // Ảnh hoá đơn
                Text('Ảnh hoá đơn', style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kInk)),
                const SizedBox(height: 8),

                // Preview ảnh (nếu có)
                if (newImagePath != null || previewUrl != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: newImagePath != null
                            ? Image.file(
                                File(newImagePath!),
                                height: 150, width: double.infinity, fit: BoxFit.cover,
                              )
                            : Image.network(
                                previewUrl!,
                                height: 150, width: double.infinity, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 80,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF))),
                              ),
                      ),
                      // Nút xoá ảnh
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setS(() {
                            newImagePath = null;
                            previewUrl = null;
                          }),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626), shape: BoxShape.circle),
                            padding: const EdgeInsets.all(5),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Nút Camera & Thư viện — luôn hiển thị
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final file = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80, maxWidth: 1200);
                      if (file != null) setS(() {
                        newImagePath = file.path;
                        previewUrl = null;
                      });
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.camera_alt_rounded, color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 6),
                        Text('Chụp ảnh', style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final file = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80, maxWidth: 1200);
                      if (file != null) setS(() {
                        newImagePath = file.path;
                        previewUrl = null;
                      });
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEDE7FE)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.photo_library_rounded, color: _kViolet, size: 18),
                        const SizedBox(width: 6),
                        Text('Thư viện', style: GoogleFonts.outfit(
                            fontSize: 12, color: _kViolet,
                            fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 24),

                // Nút lưu
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _saving = true);
                      try {
                        final newInvoiceUrl = await ref.read(khoRepositoryProvider).updatePurchaseOrderInfo(
                          _po.id,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          supplierName: selectedSupplierName.trim(),
                          newInvoiceImagePath: newImagePath,
                          existingInvoiceImageUrl: previewUrl,
                        );
                        if (mounted) {
                          // Evict old image from Flutter cache
                          if (_po.invoiceImageUrl != null) {
                            PaintingBinding.instance.imageCache
                                .evict(NetworkImage(_po.invoiceImageUrl!));
                          }
                          setState(() {
                            _po = PurchaseOrderModel(
                              id: _po.id, poNumber: _po.poNumber,
                              supplierId: _po.supplierId,
                              supplierName: selectedSupplierName.trim().isEmpty
                                  ? null : selectedSupplierName.trim(),
                              status: _po.status,
                              totalAmount: _po.totalAmount,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null : noteCtrl.text.trim(),
                              createdAt: _po.createdAt,
                              invoiceImageUrl: newInvoiceUrl,
                              items: _items,
                            );
                            _saving = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Đã cập nhật phiếu ${_po.poNumber}'),
                            backgroundColor: _kGreen,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Lỗi: $e'),
                            backgroundColor: _kRed,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text('Lưu thay đổi',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kViolet,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Đợi animation đóng sheet hoàn tất mới dispose
    // (dispose ngay sẽ crash vì animation vẫn rebuild widget)
    Future.delayed(const Duration(milliseconds: 500), () {
      noteCtrl.dispose();
      supplierFallbackCtrl.dispose();
    });
  }


  @override
  Widget build(BuildContext context) {
    final isCancelled = _po.status == 'cancelled';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_po.poNumber,
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(_fmtDate(_po.createdAt),
                style: GoogleFonts.outfit(
                    fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          _buildStatusChip(isCancelled),
          if (!isCancelled) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: _saving ? null : () => _showEditSheet(),
              icon: const Icon(Icons.edit_rounded, size: 20),
              tooltip: 'Chỉnh sửa phiếu',
              color: Colors.white,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Tổng tiền ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCancelled
                      ? [Colors.grey.shade200, Colors.grey.shade100]
                      : [_kViolet.withValues(alpha: 0.12), _kViolet.withValues(alpha: 0.06)],
                ),
                borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
                border: Border.all(
                    color: isCancelled
                        ? Colors.grey.shade300
                        : _kViolet.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tổng giá trị phiếu',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: isCancelled ? _kMuted : _kViolet,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_fmtMoney(_po.totalAmount),
                      style: GoogleFonts.outfit(
                          fontSize: 28, fontWeight: FontWeight.w900,
                          color: isCancelled ? _kMuted : _kNavy)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Nhà cung cấp ────────────────────────────────────────────
            if (_po.supplierName != null && _po.supplierName!.isNotEmpty)
              _buildInfoRow(Icons.store_rounded, 'Nhà cung cấp',
                  _po.supplierName!),

            // ── Ghi chú ──────────────────────────────────────────────────
            if (_po.note != null && _po.note!.isNotEmpty)
              _buildInfoRow(Icons.notes_rounded, 'Ghi chú', _po.note!),

            const SizedBox(height: 8),

            // ── Danh sách sản phẩm ───────────────────────────────────────
            _buildSectionHeader('Sản phẩm nhập', Icons.inventory_2_rounded),
            const SizedBox(height: 8),
            _buildItemsList(),
            const SizedBox(height: 16),

            // ── Ảnh hoá đơn ──────────────────────────────────────────────
            if (_po.invoiceImageUrl != null) ...[
              _buildSectionHeader('Ảnh hoá đơn', Icons.receipt_long_rounded),
              const SizedBox(height: 8),
              _buildInvoiceImage(),
              const SizedBox(height: 16),
            ],

            // ── Nút Huỷ phiếu ────────────────────────────────────────────
            if (!isCancelled) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _confirmCancel,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(_cancelling ? 'Đang huỷ...' : 'Huỷ phiếu nhập',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: const BorderSide(color: _kRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildStatusChip(bool isCancelled) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isCancelled
          ? Colors.grey.withValues(alpha: 0.25)
          : _kGreen.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isCancelled ? 'Đã huỷ' : 'Đã nhập',
      style: GoogleFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isCancelled ? Colors.grey.shade700 : _kGreen),
    ),
  );

  Widget _buildSectionHeader(String label, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: _kViolet),
    const SizedBox(width: 6),
    Text(label,
        style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
  ]);

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: _kMuted),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.outfit(fontSize: 10, color: _kMuted)),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
        ]),
      ]),
    ),
  );

  Widget _buildItemsList() {
    if (_loadingItems) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('Không có sản phẩm',
            style: GoogleFonts.outfit(color: _kMuted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isLast = i == _items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kViolet.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: _kViolet)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: _kInk)),
                    Text(
                      '${item.quantity.toStringAsFixed(0)} × '
                      '${NumberFormat('#,###').format(item.unitCost.toInt())}đ',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: _kMuted),
                    ),
                  ],
                )),
                Text(_fmtMoney(item.subtotal),
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: _kNavy)),
              ]),
            ),
            if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
          ]);
        }),
      ),
    );
  }

  Widget _buildInvoiceImage() => Container(
    key: ValueKey(_po.invoiceImageUrl),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.04),
      borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
      border: Border.all(color: _kBorder),
    ),
    clipBehavior: Clip.hardEdge,
    child: Image.network(
      _po.invoiceImageUrl!,
      width: double.infinity,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator())),
      errorBuilder: (_, __, ___) => const SizedBox(
          height: 80,
          child: Center(child: Icon(Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF)))),
    ),
  );
}
