import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/coupon_model.dart';
import '../repository/pos_repository.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/app_providers.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream = Color(0xFFFFF8F0);
const _kMuted = Color(0xFF8A90A6);

class DiscountManagementScreen extends ConsumerStatefulWidget {
  final bool isTab;
  const DiscountManagementScreen({super.key, this.isTab = false});

  @override
  ConsumerState<DiscountManagementScreen> createState() => _DiscountManagementScreenState();
}

class _DiscountManagementScreenState extends ConsumerState<DiscountManagementScreen> {
  List<CouponModel> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadCoupons());
  }

  Future<void> _loadCoupons() async {
    setState(() => _loading = true);
    final repo = ref.read(posRepositoryProvider);
    final list = await repo.getCoupons();
    if (mounted) {
      setState(() {
        _coupons = list;
        _loading = false;
      });
    }
  }

  String _fmtVnd(double amount) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return format.format(amount).replaceAll(',00', '');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isAuthorized = session?.isOwner == true ||
        session?.role == 'owner' ||
        session?.role == 'manager' ||
        session?.role.toLowerCase() == 'quản lý';

    if (!isAuthorized) {
      if (widget.isTab) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: _kMuted),
              const SizedBox(height: 16),
              Text(
                'Quyền truy cập bị từ chối',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ Chủ quán hoặc Quản lý mới có quyền thiết lập voucher.',
                style: GoogleFonts.outfit(color: _kMuted),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text('Khuyến mãi & Voucher', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: _kNavy,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: _kMuted),
              const SizedBox(height: 16),
              Text(
                'Quyền truy cập bị từ chối',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ Chủ quán hoặc Quản lý mới có quyền thiết lập voucher.',
                style: GoogleFonts.outfit(color: _kMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kCream,
      appBar: widget.isTab
          ? null
          : AppBar(
              title: Text('Khuyến mãi & Voucher', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadCoupons,
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _coupons.isEmpty
              ? _buildEmptyState()
              : _buildCouponsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCouponForm(),
        backgroundColor: _kOrange,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Thêm mã mới', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_outlined, size: 64, color: _kOrange),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có mã giảm giá nào',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _kNavy),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tạo các chương trình khuyến mãi theo % hoặc số tiền cố định để thu hút khách hàng.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: _kMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _coupons.length,
      itemBuilder: (context, index) {
        final item = _coupons[index];
        final isExpired = item.endDate != null && item.endDate!.isBefore(DateTime.now());

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kNavy.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
              color: item.isActive && !isExpired ? _kOrange.withOpacity(0.2) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Dải màu bên trái
                  Container(
                    width: 12,
                    color: item.isActive && !isExpired ? _kOrange : _kMuted,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (item.isActive && !isExpired ? _kOrange : _kMuted).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.code,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: item.isActive && !isExpired ? _kOrange : _kNavy,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Switch(
                                value: item.isActive,
                                activeColor: _kOrange,
                                onChanged: (val) => _toggleActive(item, val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (item.description != null && item.description!.isNotEmpty) ...[
                            Text(
                              item.description!,
                              style: GoogleFonts.outfit(fontSize: 13, color: _kNavy.withOpacity(0.75)),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, size: 16, color: _kOrange),
                              const SizedBox(width: 6),
                              Text(
                                item.discountType == 'percent'
                                    ? 'Giảm ${item.value.toInt()}%'
                                    : 'Giảm ${_fmtVnd(item.value)}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _kNavy,
                                ),
                              ),
                              if (item.maxDiscountAmount != null && item.maxDiscountAmount! > 0) ...[
                                Text(
                                  ' (Tối đa ${_fmtVnd(item.maxDiscountAmount!)})',
                                  style: GoogleFonts.outfit(fontSize: 12, color: _kMuted),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đơn tối thiểu: ${_fmtVnd(item.minOrderAmount)}',
                            style: GoogleFonts.outfit(fontSize: 12, color: _kMuted),
                          ),
                          if (item.endDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Hạn dùng: ${DateFormat('dd/MM/yyyy HH:mm').format(item.endDate!.toLocal())}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isExpired ? Colors.red : _kMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Nút xóa
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleActive(CouponModel item, bool active) async {
    final updated = CouponModel(
      id: item.id,
      storeId: item.storeId,
      code: item.code,
      description: item.description,
      discountType: item.discountType,
      value: item.value,
      minOrderAmount: item.minOrderAmount,
      maxDiscountAmount: item.maxDiscountAmount,
      isActive: active,
      startDate: item.startDate,
      endDate: item.endDate,
      createdAt: item.createdAt,
    );
    try {
      await ref.read(posRepositoryProvider).upsertCoupon(updated);
      _loadCoupons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _confirmDelete(CouponModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa mã giảm giá', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa mã "${item.code}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(posRepositoryProvider).deleteCoupon(item.id);
        _loadCoupons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _showCouponForm([CouponModel? item]) {
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final valCtrl = TextEditingController(text: item?.value.toInt().toString() ?? '');
    final minCtrl = TextEditingController(text: item?.minOrderAmount.toInt().toString() ?? '0');
    final maxCtrl = TextEditingController(text: item?.maxDiscountAmount?.toInt().toString() ?? '');

    String discountType = item?.discountType ?? 'percent';
    DateTime? endDate = item?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item == null ? 'Thêm mã giảm giá mới' : 'Chỉnh sửa mã',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mã Voucher (Viết liền không dấu)',
                    labelStyle: GoogleFonts.outfit(color: _kMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Mô tả ngắn gọn',
                    labelStyle: GoogleFonts.outfit(color: _kMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Loại giảm giá', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _kNavy)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Phần trăm (%)'),
                        value: 'percent',
                        groupValue: discountType,
                        onChanged: (val) => setLocalState(() => discountType = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Tiền mặt (đ)'),
                        value: 'fixed',
                        groupValue: discountType,
                        onChanged: (val) => setLocalState(() => discountType = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: discountType == 'percent' ? 'Mức giảm (%)' : 'Mức giảm (đ)',
                          labelStyle: GoogleFonts.outfit(color: _kMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Đơn tối thiểu (đ)',
                          labelStyle: GoogleFonts.outfit(color: _kMuted),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (discountType == 'percent') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Mức giảm tối đa (đ) - Để trống nếu không giới hạn',
                      labelStyle: GoogleFonts.outfit(color: _kMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      endDate == null
                          ? 'Chưa chọn ngày hết hạn'
                          : 'Hạn dùng: ${DateFormat('dd/MM/yyyy HH:mm').format(endDate!.toLocal())}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _kNavy),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, color: _kOrange),
                      label: const Text('Chọn ngày', style: TextStyle(color: _kOrange)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setLocalState(() {
                              endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      final desc = descCtrl.text.trim();
                      final val = double.tryParse(valCtrl.text.trim()) ?? 0;
                      final minAmt = double.tryParse(minCtrl.text.trim()) ?? 0;
                      final maxAmt = double.tryParse(maxCtrl.text.trim());

                      if (code.isEmpty || val <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }

                      final session = ref.read(sessionProvider);
                      final storeId = session?.storeId;
                      if (storeId == null) return;

                      final coupon = CouponModel(
                        id: item?.id ?? const Uuid().v4(),
                        storeId: storeId,
                        code: code,
                        description: desc.isNotEmpty ? desc : null,
                        discountType: discountType,
                        value: val,
                        minOrderAmount: minAmt,
                        maxDiscountAmount: discountType == 'percent' ? maxAmt : null,
                        isActive: item?.isActive ?? true,
                        startDate: item?.startDate,
                        endDate: endDate,
                        createdAt: item?.createdAt ?? DateTime.now(),
                      );

                      try {
                        await ref.read(posRepositoryProvider).upsertCoupon(coupon);
                        Navigator.pop(ctx);
                        _loadCoupons();
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Lưu Voucher', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
