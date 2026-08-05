import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';
import '../services/qr_sound_service.dart';

/// Sheet duyệt đơn QR 4 bước độc lập (Architecture V3)
/// Option A: Loại bỏ các nút chỉnh món giả. Nhân viên đọc và xác nhận chính xác các món khách đã đặt.
/// Luồng trạng thái: pending_staff -> processing (Nhận đơn) -> confirmed (Xác nhận) -> sent_kitchen (Gửi bếp)
class QrOrderReviewSheet extends StatefulWidget {
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
  State<QrOrderReviewSheet> createState() => _QrOrderReviewSheetState();
}

class _QrOrderReviewSheetState extends State<QrOrderReviewSheet> {
  final QrOrderRepository _qrRepo = QrOrderRepository();
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  late String _currentStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.request.status;
  }

  // Bước 1: Nhận đơn (pending_staff -> processing)
  Future<void> _handleClaim() async {
    if (_isSubmitting) return; // Chống bấm lặp
    setState(() => _isSubmitting = true);

    final res = await _qrRepo.claimRequestV3(widget.request.id);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() {
        _currentStatus = 'processing';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã nhận đơn! Vui lòng đọc lại món với khách và bấm "Xác nhận".',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Đơn hàng này đã được nhận bởi nhân viên khác!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  // Bước 2: Xác nhận với khách (processing -> confirmed)
  Future<void> _handleConfirm() async {
    if (_isSubmitting) return; // Chống bấm lặp
    setState(() => _isSubmitting = true);

    final res = await _qrRepo.confirmRequestV3(widget.request.id);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() {
        _currentStatus = 'confirmed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã xác nhận đơn với khách! Bấm "Gửi bếp" để nạp vé bếp chế biến.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Xác nhận đơn thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Bước 3: Gửi bếp (confirmed -> sent_kitchen)
  Future<void> _handleSendToKitchen() async {
    if (_isSubmitting) return; // Chống bấm lặp
    setState(() => _isSubmitting = true);

    final res = await _qrRepo.sendToKitchenV3(widget.request.id);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      setState(() {
        _currentStatus = 'sent_kitchen';
      });
      await QrSoundService.playNotificationSound();
      widget.onApproved();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi vé bếp thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ??
                'Gửi bếp thất bại (Đơn chưa được xác nhận hoặc đã gửi)',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Bước Từ Chối (pending_staff / processing / confirmed -> rejected)
  Future<void> _handleReject() async {
    if (_isSubmitting) return; // Chống bấm lặp

    final reasonCtrl = TextEditingController(text: 'Khách đổi ý / hết món');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Xác nhận từ chối đơn',
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
                hintText: 'Lý do...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
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
    final res = await _qrRepo.rejectRequestV3(
      widget.request.id,
      reason: reasonCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      widget.onRejected();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối đơn hàng!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Từ chối đơn thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleLabel = widget.request.type == 'table'
        ? (widget.request.tableName.isNotEmpty
              ? widget.request.tableName
              : 'Bàn QR')
        : 'QUẦY THU NGÂN — ${widget.request.displayPickupCode}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(_currentStatus).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _statusColor(_currentStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DUYỆT ĐƠN GỌI MÓN QR',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              _currentStatus,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusLabel(_currentStatus),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(_currentStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      titleLabel,
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
          ),
          const Divider(height: 24),
          Text(
            'Danh Sách Món Khách Chọn:',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.request.items.length,
              itemBuilder: (context, index) {
                final item = widget.request.items[index];
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
                      Text(
                        'x${item.quantity}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng tiền:',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                currencyFmt.format(widget.request.totalAmount),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isSubmitting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentStatus == 'pending_staff') {
      // Bước 1: Nhận đơn
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.touch_app_rounded),
              label: Text(
                '1. NHẬN ĐƠN',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              onPressed: _handleClaim,
            ),
          ),
        ],
      );
    }

    if (_currentStatus == 'processing') {
      // Bước 2: Xác nhận đơn với khách
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
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                '2. XÁC NHẬN VỚI KHÁCH',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              onPressed: _handleConfirm,
            ),
          ),
        ],
      );
    }

    if (_currentStatus == 'confirmed') {
      // Bước 3: Gửi bếp
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
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.restaurant_rounded),
              label: Text(
                '3. GỬI BẾP',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              onPressed: _handleSendToKitchen,
            ),
          ),
        ],
      );
    }

    // Đã sent_kitchen hoặc rejected
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Đóng',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_staff':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'confirmed':
        return Colors.amber.shade900;
      case 'sent_kitchen':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_staff':
        return 'Chờ nhận';
      case 'processing':
        return 'Đang kiểm';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'sent_kitchen':
        return 'Đã gửi bếp';
      case 'rejected':
        return 'Đã từ chối';
      default:
        return status;
    }
  }
}
