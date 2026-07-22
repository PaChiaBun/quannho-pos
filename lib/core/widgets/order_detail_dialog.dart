import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kNavy = Color(0xFF1C2151);
const _kInk = Color(0xFF1A1207);
const _kMuted = Color(0xFF9E9085);
const _kBg = Color(0xFFFFF8F0);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);

String _fmtVnd(double amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)} đ';
}

String _formatPayMethod(String? method) {
  if (method == null || method.isEmpty) return 'Không rõ';
  switch (method.toLowerCase()) {
    case 'cash':
      return 'Tiền mặt';
    case 'transfer':
      return 'Chuyển khoản';
    case 'card':
      return 'Thẻ POS';
    default:
      return method;
  }
}

/// Helper trích xuất mã đơn hàng QN-... từ mô tả giao dịch
String? extractOrderNumber(String? text) {
  if (text == null || text.isEmpty) return null;
  final regExp = RegExp(r'QN-\d{8}-\d+');
  final match = regExp.firstMatch(text);
  if (match != null) {
    return match.group(0);
  }
  if (text.startsWith('QN-')) {
    return text.trim();
  }
  return null;
}

/// Hiển thị popup Chi Tiết Đơn Hàng từ Order Number
Future<void> showOrderDetailDialog(BuildContext context, String orderNumber) async {
  try {
    final sb = Supabase.instance.client;
    final orderRows = await sb
        .from('orders')
        .select('*')
        .eq('order_number', orderNumber)
        .limit(1);

    if (orderRows.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tìm thấy đơn hàng "$orderNumber"', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    final order = orderRows.first;
    final orderId = order['id'] as String;

    // Fetch order items
    final items = await sb
        .from('order_items')
        .select('name, qty, quantity, unit_price, subtotal')
        .eq('order_id', orderId);

    String? staffName;

    // 1. Direct name string fields from order record
    for (final key in ['waiter_name', 'staff_name', 'created_by_name', 'cashier_name']) {
      final val = order[key] as String?;
      if (val != null && val.trim().isNotEmpty) {
        staffName = val.trim();
        break;
      }
    }

    // 2. Resolve via IDs explicitly recorded on this order
    if (staffName == null || staffName.isEmpty) {
      final candidateIds = <String>[];
      for (final key in ['waiter_id', 'staff_id', 'created_by', 'cashier_id', 'user_id']) {
        final val = order[key] as String?;
        if (val != null && val.trim().isNotEmpty && !candidateIds.contains(val)) {
          candidateIds.add(val.trim());
        }
      }

      for (final id in candidateIds) {
        if (staffName != null && staffName.isNotEmpty) break;

        // a. store_members by id
        try {
          final memberRow = await sb
              .from('store_members')
              .select('display_name, user_accounts(display_name)')
              .eq('id', id)
              .maybeSingle();
          if (memberRow != null) {
            final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
            staffName = userAcc?['display_name'] as String? ?? memberRow['display_name'] as String?;
          }
        } catch (_) {}

        // b. store_members by user_id
        if (staffName == null || staffName.isEmpty) {
          try {
            final memberRow = await sb
                .from('store_members')
                .select('display_name, user_accounts(display_name)')
                .eq('user_id', id)
                .maybeSingle();
            if (memberRow != null) {
              final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
              staffName = userAcc?['display_name'] as String? ?? memberRow['display_name'] as String?;
            }
          } catch (_) {}
        }

        // c. staff_members
        if (staffName == null || staffName.isEmpty) {
          try {
            final staffRow = await sb
                .from('staff_members')
                .select('name')
                .eq('id', id)
                .maybeSingle();
            if (staffRow != null) {
              staffName = staffRow['name'] as String?;
            }
          } catch (_) {}
        }

        // d. user_accounts
        if (staffName == null || staffName.isEmpty) {
          try {
            final userRow = await sb
                .from('user_accounts')
                .select('display_name')
                .eq('id', id)
                .maybeSingle();
            if (userRow != null) {
              staffName = userRow['display_name'] as String?;
            }
          } catch (_) {}
        }
      }
    }

    // 3. If order didn't have staff ID, check the SINGLE session for this table
    if (staffName == null || staffName.isEmpty) {
      final sourceId = order['source_id'] as String?;
      if (sourceId != null && sourceId.isNotEmpty) {
        try {
          final sessionRow = await sb
              .from('ban_sessions')
              .select('id, waiter_id')
              .eq('table_id', sourceId)
              .order('opened_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (sessionRow != null) {
            final waiterId = sessionRow['waiter_id'] as String?;
            if (waiterId != null && waiterId.isNotEmpty) {
              try {
                final memberRow = await sb
                    .from('store_members')
                    .select('display_name, user_accounts(display_name)')
                    .eq('id', waiterId)
                    .maybeSingle();
                if (memberRow != null) {
                  final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
                  staffName = userAcc?['display_name'] as String? ?? memberRow['display_name'] as String?;
                }
              } catch (_) {}

              if (staffName == null || staffName.isEmpty) {
                try {
                  final staffRow = await sb
                      .from('staff_members')
                      .select('name')
                      .eq('id', waiterId)
                      .maybeSingle();
                  if (staffRow != null) {
                    staffName = staffRow['name'] as String?;
                  }
                } catch (_) {}
              }
            }

            if (staffName == null || staffName.isEmpty) {
              final sessionId = sessionRow['id'] as String;
              final sessionItems = await sb
                  .from('ban_session_items')
                  .select('added_by')
                  .eq('session_id', sessionId);
              final names = sessionItems
                  .map((i) => i['added_by'] as String?)
                  .where((name) => name != null && name.trim().isNotEmpty)
                  .toSet();
              if (names.isNotEmpty) {
                staffName = names.first; // Pick single primary staff name
              }
            }
          }
        } catch (e) {
          debugPrint('[OrderDetail] session lookup err: $e');
        }
      }
    }

    // 4. Fallback to store member or owner name if IDs were not attached to order
    if (staffName == null || staffName.isEmpty) {
      try {
        final storeId = order['store_id'] as String?;
        if (storeId != null && storeId.isNotEmpty) {
          final memberRows = await sb
              .from('store_members')
              .select('display_name, role, user_accounts(display_name)')
              .eq('store_id', storeId)
              .limit(5);
          for (final m in memberRows) {
            final userAcc = m['user_accounts'] as Map<String, dynamic>?;
            final name = userAcc?['display_name'] as String? ?? m['display_name'] as String?;
            if (name != null && name.isNotEmpty) {
              staffName = name;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[OrderDetail] fallback owner err: $e');
      }
    }

    staffName ??= 'Thu ngân';

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 600;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: isDesktop ? 36 : 24,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chi tiết đơn hàng',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: isDesktop ? 18 : 16, color: _kNavy),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 520 : 400,
            maxHeight: screenHeight * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Box
                Container(
                  padding: EdgeInsets.all(isDesktop ? 16 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8E2DA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Số đơn:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order['order_number'] as String,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.outfit(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thời gian:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(order['created_at'] as String)),
                              textAlign: TextAlign.end,
                              style: GoogleFonts.outfit(fontSize: 12, color: _kInk, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nhân viên bấm đơn:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              staffName ?? 'Chưa ghi nhận',
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (order['customer_name'] != null && (order['customer_name'] as String).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Khách hàng:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['customer_name'] as String,
                                textAlign: TextAlign.end,
                                style: GoogleFonts.outfit(fontSize: 12, color: _kInk, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hình thức:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatPayMethod(order['payment_method'] as String?),
                              textAlign: TextAlign.end,
                              style: GoogleFonts.outfit(fontSize: 12, color: _kInk, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Danh sách món:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: _kNavy)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: isDesktop ? screenHeight * 0.45 : screenHeight * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: items.map((item) {
                        final name = item['name'] as String? ?? '';
                        final qty = (item['quantity'] as num?)?.toDouble() ?? (item['qty'] as num?)?.toDouble() ?? 1;
                        final sub = (item['subtotal'] as num?)?.toDouble() ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF2ECE4), width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _kInk))),
                              const SizedBox(width: 8),
                              Text('x${qty.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: _kNavy)),
                              const SizedBox(width: 16),
                              Text(_fmtVnd(sub), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: _kNavy)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tạm tính:', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
                    Text(_fmtVnd((order['subtotal'] as num?)?.toDouble() ?? 0), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: _kInk)),
                  ],
                ),
                if (order['discount'] != null && (order['discount'] as num).toDouble() > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Giảm giá:', style: GoogleFonts.outfit(fontSize: 12, color: _kRed)),
                      Text('-${_fmtVnd((order['discount'] as num).toDouble())}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: _kRed)),
                    ],
                  ),
                ],
                const Divider(height: 20, color: Color(0xFFE8E2DA)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng thanh toán:', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
                    Text(_fmtVnd((order['total'] as num?)?.toDouble() ?? 0), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _kGreen)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E2DA)),
                  ),
                  width: double.infinity,
                  child: Text(
                    (order['note'] != null && (order['note'] as String).trim().isNotEmpty)
                        ? 'Ghi chú: ${order['note']}'
                        : 'Ghi chú: Không có ghi chú',
                    style: GoogleFonts.outfit(fontSize: 11, fontStyle: FontStyle.italic, color: _kMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải chi tiết đơn hàng: $e', style: GoogleFonts.outfit()),
          backgroundColor: _kRed,
        ),
      );
    }
  }
}
