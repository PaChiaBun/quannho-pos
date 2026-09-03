import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/repositories/ban_repository.dart';
import '../../../core/services/vietqr_service.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../providers/qr_order_providers.dart';
import '../services/qr_sound_service.dart';

/// Sheet duyệt và chỉnh sửa món QR Order V4
/// Cho phép:
/// 1. Chỉnh sửa món thật (Tăng/giảm SL, xóa món, thêm món mới từ menu).
/// 2. Gán bàn thật từ danh sách bàn (Có gợi ý table_hint cho TABLE_SHARED).
/// 3. Cổng thanh toán COUNTER_TAKEAWAY (Yêu cầu thanh toán trước khi gửi bếp).
/// 4. Gửi bếp idempotent và cập nhật trạng thái.
class QrOrderReviewSheet extends ConsumerStatefulWidget {
  final QrRequestModel request;
  final VoidCallback onApproved;
  final VoidCallback onRejected;

  const QrOrderReviewSheet({
    super.key,
    required this.request,
    required this.onApproved,
    required this.onRejected,
  });

  @override
  ConsumerState<QrOrderReviewSheet> createState() => _QrOrderReviewSheetState();
}

class _QrOrderReviewSheetState extends ConsumerState<QrOrderReviewSheet> {
  final BanRepository _banRepo = BanRepository();
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  late List<QrRequestItemModel> _items;
  late String _paymentStatus;
  late int _version;
  String? _assignedTableId;
  String? _assignedTableName;
  late bool _isTableAssignmentPersisted;
  String _paymentMethod = 'cash';

  List<BanTableModel> _tables = [];
  bool _loadingTables = true;
  bool _isSubmitting = false;
  bool _isDirty = false; // Có thay đổi món cần lưu trước khi gửi bếp
  String _storeId = '';
  late final String _paymentIdempotencyKey = const Uuid().v4();
  late final String _sendKitchenIdempotencyKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.request.items);
    _paymentStatus = widget.request.paymentStatus;
    _version = widget.request.version;
    _assignedTableId = widget.request.assignedTableId;
    _assignedTableName = widget.request.assignedTableName;
    _isTableAssignmentPersisted = widget.request.assignedTableId != null;
    _loadTables();
  }

  Future<void> _loadTables() async {
    final info = await StoreAuthService.getStoreInfo();
    _storeId = info['store_id'] ?? widget.request.storeId;

    if (widget.request.isTable) {
      try {
        final tables = await _banRepo.getAllTables();
        if (mounted) {
          setState(() {
            _tables = tables;
            _loadingTables = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingTables = false);
      }
    } else {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  double get _currentTotal {
    return _items.fold<double>(
      0.0,
      (sum, it) => sum + (it.unitPrice * it.quantity),
    );
  }

  // Chỉnh sửa số lượng món
  void _updateItemQuantity(int index, int delta) {
    setState(() {
      final item = _items[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _items.removeAt(index);
      } else if (newQty <= 99) {
        _items[index] = item.copyWith(
          quantity: newQty,
          subtotal: item.unitPrice * newQty,
        );
      }
      _isDirty = true;
    });
  }

  // Thêm món mới từ Menu
  Future<void> _openAddProductPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerSheet(storeId: _storeId),
    );

    if (selected != null && mounted) {
      setState(() {
        final pId = selected['id'] as String;
        final pName = selected['name'] as String;
        final pPrice = (selected['sell_price'] as num).toDouble();

        // Kiểm tra xem món đã có trong danh sách chưa
        final existingIdx = _items.indexWhere((it) => it.productId == pId);
        if (existingIdx != -1) {
          final ext = _items[existingIdx];
          _items[existingIdx] = ext.copyWith(
            quantity: ext.quantity + 1,
            subtotal: ext.unitPrice * (ext.quantity + 1),
          );
        } else {
          _items.add(
            QrRequestItemModel(
              id: '',
              requestId: widget.request.id,
              productId: pId,
              productName: pName,
              unitPrice: pPrice,
              quantity: 1,
              subtotal: pPrice,
            ),
          );
        }
        _isDirty = true;
      });
    }
  }

  // Lưu chỉnh sửa món (RPC `update_qr_order_items_v4`)
  Future<bool> _saveEditedItems() async {
    if (!_isDirty) return true;

    final repo = ref.read(qrOrderRepoProvider);
    final itemsPayload = _items
        .map(
          (it) => {
            'product_id': it.productId,
            'quantity': it.quantity,
            'modifiers_json': it.modifiersJson,
            'note': it.note,
          },
        )
        .toList();

    final res = await repo.updateOrderItems(
      requestId: widget.request.id,
      storeId: _storeId,
      expectedVersion: _version,
      items: itemsPayload,
    );

    if (res.isSuccess && res.data != null) {
      setState(() {
        _version = (res.data!['version'] as int?) ?? (_version + 1);
        _isDirty = false;
      });
      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Cập nhật danh sách món thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // Gán bàn (RPC `assign_qr_order_table_v4`)
  Future<bool> _handleAssignTable(String tableId) async {
    final repo = ref.read(qrOrderRepoProvider);
    final res = await repo.assignTable(
      requestId: widget.request.id,
      storeId: _storeId,
      tableId: tableId,
    );

    if (res.isSuccess && res.data != null) {
      setState(() {
        _assignedTableId = tableId;
        _assignedTableName = res.data!['assigned_table_name'] as String?;
        _isTableAssignmentPersisted = true;
      });
      ref.invalidate(qrActivePipelineStreamProvider);
      ref.invalidate(pendingTableQrRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã gán đơn vào ${_assignedTableName ?? "bàn"}. Đơn đã hiển thị trên module Bàn.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Gán bàn thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // Xác nhận thanh toán cho COUNTER (RPC `mark_qr_order_paid_v4`)
  Future<void> _handleMarkPaid() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Lưu món trước nếu có sửa
    if (_isDirty) {
      final saved = await _saveEditedItems();
      if (!mounted) return;
      if (!saved) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final repo = ref.read(qrOrderRepoProvider);
    final res = await repo.markOrderPaid(
      requestId: widget.request.id,
      storeId: _storeId,
      paymentMethod: _paymentMethod,
      idempotencyKey: _paymentIdempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      setState(() {
        _paymentStatus = 'paid';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận thanh toán thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Xác nhận thanh toán thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Gửi Bếp (RPC `send_qr_order_to_kitchen_v4`)
  Future<void> _handleSendToKitchen() async {
    if (_isSubmitting) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đơn hàng không có món nào để gửi bếp!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Kiểm tra gán bàn cho TABLE
    if (widget.request.isTable) {
      if (_assignedTableId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn bàn trước khi gửi bếp!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // 1. Lưu các chỉnh sửa món nếu có
    if (_isDirty) {
      final saved = await _saveEditedItems();
      if (!mounted) return;
      if (!saved) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    // 2. TABLE phải được gán và hiển thị trên module Bàn trước khi gửi Bếp.
    if (widget.request.isTable && !_isTableAssignmentPersisted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy xác nhận gán bàn trước khi gửi Bếp.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Gửi bếp
    final repo = ref.read(qrOrderRepoProvider);
    final res = await repo.sendToKitchen(
      requestId: widget.request.id,
      storeId: _storeId,
      idempotencyKey: _sendKitchenIdempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      await QrSoundService.playNotificationSound();
      ref.invalidate(qrActivePipelineStreamProvider);
      ref.invalidate(activeCounterQrRequestsProvider);
      ref.invalidate(pendingTableQrRequestsProvider);
      widget.onApproved();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.request.isTable
                ? 'Đã chuyển đơn vào ${_assignedTableName ?? "bàn"} và gửi bếp thành công!'
                : 'Đã gửi bếp đơn mang đi (${widget.request.displayPickupCode})!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Gửi bếp thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Từ chối / Hủy đơn (RPC `cancel_qr_order_v4`)
  Future<void> _handleReject() async {
    if (_isSubmitting) return;

    final reasonCtrl = TextEditingController(text: 'Khách đổi ý / Hết món');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Từ chối đơn gọi món',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vui lòng nhập lý do từ chối đơn QR này:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Lý do từ chối...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ chối đơn'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(qrOrderRepoProvider);
    final res = await repo.cancelOrder(
      requestId: widget.request.id,
      storeId: _storeId,
      reason: reasonCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      ref.invalidate(qrActivePipelineStreamProvider);
      ref.invalidate(activeCounterQrRequestsProvider);
      ref.invalidate(pendingTableQrRequestsProvider);
      widget.onRejected();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối đơn hàng!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Từ chối đơn thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 20),
          if (widget.request.isTable) _buildTableSelector(),
          if (widget.request.isCounter) _buildCounterBadge(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh Sách Món (${_items.length} món):',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              TextButton.icon(
                onPressed: _openAddProductPicker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm món'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildItemsList()),
          const Divider(height: 20),
          _buildTotalSection(),
          const SizedBox(height: 14),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF8B5CF6),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.request.isTable
                    ? 'DUYỆT ĐƠN GỌI MÓN TẠI BÀN'
                    : 'DUYỆT ĐƠN MANG ĐI TẠI QUẦY',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                widget.request.displayTitle,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTableSelector() {
    if (_loadingTables) {
      return const LinearProgressIndicator();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_restaurant_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Gán Vào Bàn Chính Thức:',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.purple.shade900,
                ),
              ),
              if (_isTableAssignmentPersisted) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ĐÃ GÁN BÀN',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _assignedTableId,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              hintText: 'Chọn bàn để chuyển món...',
            ),
            items: _tables.map((t) {
              return DropdownMenuItem<String>(
                value: t.id,
                child: Text(
                  t.label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final selected = _tables.firstWhere((t) => t.id == val);
                setState(() {
                  _assignedTableId = val;
                  _assignedTableName = selected.label;
                  _isTableAssignmentPersisted =
                      val == widget.request.assignedTableId;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTableAssignmentPersisted
                    ? Colors.green.shade700
                    : const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: _assignedTableId == null || _isTableAssignmentPersisted
                  ? null
                  : () => _handleAssignTable(_assignedTableId!),
              icon: Icon(
                _isTableAssignmentPersisted
                    ? Icons.check_circle_rounded
                    : Icons.table_restaurant_rounded,
              ),
              label: Text(
                _isTableAssignmentPersisted
                    ? 'ĐÃ XÁC NHẬN BÀN'
                    : 'XÁC NHẬN GÁN BÀN',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge() {
    final isPaid = _paymentStatus == 'paid';
    final settings = ref.watch(qrOrderSettingsProvider).asData?.value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPaid
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    color: isPaid
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đơn Mang Đi: ${widget.request.displayPickupCode}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isPaid ? 'ĐÃ THANH TOÁN TOÀN BỘ' : 'CHƯA THANH TOÁN',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isPaid)
                Text(
                  _paymentMethod == 'transfer' ? 'CHUYỂN KHOẢN' : 'TIỀN MẶT',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade900,
                  ),
                ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'cash',
                  icon: Icon(Icons.payments_rounded),
                  label: Text('Tiền mặt'),
                ),
                ButtonSegment(
                  value: 'transfer',
                  icon: Icon(Icons.qr_code_rounded),
                  label: Text('Chuyển khoản'),
                ),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (selected) {
                setState(() => _paymentMethod = selected.first);
              },
            ),
            if (_paymentMethod == 'transfer') ...[
              const SizedBox(height: 12),
              _buildTransferQr(settings),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: Text(
                _paymentMethod == 'transfer'
                    ? 'XÁC NHẬN TIỀN ĐÃ VÀO'
                    : 'XÁC NHẬN ĐÃ THU TIỀN MẶT',
              ),
              onPressed:
                  _paymentMethod == 'transfer' &&
                      (settings == null ||
                          settings.transferAccountNo.trim().isEmpty)
                  ? null
                  : _handleMarkPaid,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferQr(QrOrderSettingsModel? settings) {
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (settings.transferAccountNo.trim().isEmpty) {
      return Text(
        'Chưa cấu hình tài khoản VietQR trong tab Thiết Lập của module QR.',
        style: GoogleFonts.outfit(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }

    final qrUrl = VietQrService.generateUrl(
      bankBin: settings.transferBankBin,
      accountNo: settings.transferAccountNo.trim(),
      accountName: settings.transferAccountName.trim(),
      amount: _currentTotal,
      addInfo: 'QR ${widget.request.displayPickupCode}',
    );
    final bankName =
        VietQrService.findByBin(settings.transferBankBin)?.shortName ??
        'Ngân hàng';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Image.network(
            qrUrl,
            width: 170,
            height: 170,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.qr_code_2_rounded,
              size: 100,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$bankName • ${settings.transferAccountNo}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          ),
          if (settings.transferAccountName.isNotEmpty)
            Text(
              settings.transferAccountName,
              style: GoogleFonts.outfit(fontSize: 12),
            ),
          const SizedBox(height: 6),
          Text(
            'VietQR chỉ hỗ trợ chuyển khoản. Thu ngân phải kiểm tra tiền đã vào trước khi xác nhận.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_shopping_cart_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Đơn hàng đang trống. Hãy bấm "Thêm món" ở trên.',
              style: GoogleFonts.outfit(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final hasNote = item.note.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (item.modifiersJson.isNotEmpty)
                      Text(
                        '+ ${item.modifiersJson.map((m) => "${m['name'] ?? 'Topping'} (x${m['quantity'] ?? 1})").join(", ")}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF6D28D9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      currencyFmt.format(item.unitPrice),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasNote)
                      Text(
                        'Ghi chú: ${item.note}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 22,
                      color: Colors.red,
                    ),
                    onPressed: () => _updateItemQuantity(index, -1),
                  ),
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 22,
                      color: Colors.green,
                    ),
                    onPressed: () => _updateItemQuantity(index, 1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng tiền đơn:',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            if (_isDirty)
              Text(
                '* Đã chỉnh sửa món',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        Text(
          currencyFmt.format(_currentTotal),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  bool get _canSendKitchen {
    if (widget.request.isTable) {
      return _assignedTableId != null && _isTableAssignmentPersisted;
    }
    // Mọi đơn mang đi đều phải được Thu ngân xác nhận thanh toán trước Bếp.
    return _paymentStatus == 'paid';
  }

  Widget _buildActionButtons() {
    if (_isSubmitting) {
      return const Center(child: CircularProgressIndicator());
    }

    final canSendKitchen = _canSendKitchen;

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _handleReject,
            child: Text(
              'Từ chối',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSendKitchen ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.restaurant_rounded),
            label: Text(
              widget.request.isTable
                  ? (_isTableAssignmentPersisted
                        ? 'GỬI BẾP'
                        : 'CẦN XÁC NHẬN BÀN')
                  : (canSendKitchen ? 'GỬI BẾP' : 'CẦN THANH TOÁN TRƯỚC'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            onPressed: canSendKitchen ? _handleSendToKitchen : null,
          ),
        ),
      ],
    );
  }
}

/// Sheet chọn món từ thực đơn quán để thêm vào đơn review
class _ProductPickerSheet extends StatefulWidget {
  final String storeId;

  const _ProductPickerSheet({required this.storeId});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('store_id', widget.storeId)
          .eq('is_active', true)
          .eq('is_deleted', false)
          .order('name');

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      return _search.isEmpty || name.contains(_search.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chọn Món Thêm Vào Đơn',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm món...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final price =
                          (p['sell_price'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        leading: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFF8B5CF6),
                        ),
                        title: Text(
                          p['name'] as String? ?? '',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          currencyFmt.format(price),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.green,
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
