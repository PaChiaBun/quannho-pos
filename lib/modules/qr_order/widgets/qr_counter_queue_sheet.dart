import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/qr_order_providers.dart';

/// Sheet hiển thị Hàng Chờ Đơn QR Quầy (Counter QR Orders Queue)
/// Cho phép nhân viên xem danh sách toàn bộ các đơn quầy đang chờ hoặc đang xử lý,
/// lọc theo trạng thái và chọn từng đơn cụ thể để duyệt thay vì chỉ mở đơn đầu tiên!
class QrCounterQueueSheet extends ConsumerWidget {
  const QrCounterQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCounterReqs = ref.watch(activeCounterQrRequestsProvider);
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HÀNG CHỜ GỌI MÓN TẠI QUẦY',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Danh Sách Đơn Quầy (${activeCounterReqs.length} đơn)',
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
          const Divider(height: 20),
          if (activeCounterReqs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không có đơn QR quầy nào đang chờ',
                      style: GoogleFonts.outfit(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: activeCounterReqs.length,
                itemBuilder: (context, index) {
                  final req = activeCounterReqs[index];
                  final pickupCode = req.displayPickupCode;
                  final itemCount = req.items.fold<int>(
                    0,
                    (sum, i) => sum + i.quantity,
                  );

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            req.status,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pickupCode,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: _statusColor(req.status),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Đơn $pickupCode',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
                                req.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(req.status),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(req.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '$itemCount món • ${currencyFmt.format(req.totalAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _statusColor(req.status),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Trả về QrRequestModel được chọn cho màn hình POS caller
                          Navigator.pop(context, req);
                        },
                        child: Text(
                          'Duyệt đơn',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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
      default:
        return status;
    }
  }
}
