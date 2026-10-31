import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/qr_order_providers.dart';

/// Hàng chờ CHUNG đơn QR (TABLE + COUNTER). Bấm một đơn để đóng sheet và
/// trả đơn đó cho nơi gọi (nơi gọi mở sheet duyệt).
class QrCounterQueueSheet extends ConsumerWidget {
  const QrCounterQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(activeQrRequestsProvider);
    final stale = ref.watch(qrPipelineErrorProvider) != null;
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
              Expanded(
                child: Text(
                  'Đơn gọi món QR (${requests.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (stale)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mất kết nối - danh sách có thể chưa mới nhất.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Divider(height: 12),
          if (requests.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Chưa có đơn QR nào đang chờ',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final qty = req.items.fold<int>(0, (s, i) => s + i.quantity);
                  final color = req.isSubmitted ? Colors.orange : Colors.blue;
                  final wait = req.createdAt == null
                      ? ''
                      : ' • chờ ${DateTime.now().difference(req.createdAt!).inMinutes} phút';
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.pop(context, req),
                      leading: Icon(
                        req.isTable
                            ? Icons.table_restaurant_rounded
                            : Icons.shopping_bag_rounded,
                        color: color,
                      ),
                      title: Text(
                        req.isTable ? 'Tại bàn • ${req.displayTitle}' : req.displayTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '$qty món • ${currencyFmt.format(req.totalAmount)}$wait'
                        '${req.isSubmitted ? "" : " • đang xử lý"}',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
