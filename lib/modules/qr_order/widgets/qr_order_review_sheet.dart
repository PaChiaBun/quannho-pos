import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/repositories/ban_repository.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';
import '../services/qr_sound_service.dart';

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
  final BanRepository _banRepo = BanRepository();
  final _uuid = const Uuid();
  final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  late List<QrRequestItemModel> _editableItems;
  bool _isSubmitting = false;

  // Exact PosScreen Takeaway Constants
  static const String kSysPosTakeawayZoneId = '00000000-0000-0000-0001-000000000001';
  static const String kSysPosTakeawayTableId = '00000000-0000-0000-0001-000000000002';

  @override
  void initState() {
    super.initState();
    _editableItems = List.from(widget.request.items);
  }

  double get _totalAmount {
    double total = 0;
    for (final item in _editableItems) {
      total += item.unitPrice * item.quantity;
    }
    return total;
  }

  void _updateItemQty(int index, int delta) {
    setState(() {
      final current = _editableItems[index];
      final newQty = current.quantity + delta;
      if (newQty <= 0) {
        _editableItems.removeAt(index);
      } else {
        _editableItems[index] = current.copyWith(quantity: newQty);
      }
    });
  }

  Future<void> _ensureTakeawayZoneAndTable(SupabaseClient sb, String storeId) async {
    try {
      await sb.from('ban_zones').upsert({
        'id': kSysPosTakeawayZoneId,
        'store_id': storeId,
        'name': 'Mang đi',
        'color_value': 0xFF1C2151,
        'icon_code': 0,
        'sort_order': 999,
        'is_active': true,
      }, onConflict: 'id');

      await sb.from('ban_dining_tables').upsert({
        'id': kSysPosTakeawayTableId,
        'store_id': storeId,
        'zone_id': kSysPosTakeawayZoneId,
        'label': 'Mang đi',
        'seats': 1,
        'is_active': true,
      }, onConflict: 'id');
    } catch (_) {}
  }

  Future<void> _confirmAndSendToKitchen() async {
    if (_editableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Danh sách món trống!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Atomic Claim Guard (Checking store membership & status)
    final claimed = await _qrRepo.claimRequest(widget.request.id);
    if (!claimed) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn hàng này đã được xử lý bởi nhân viên khác hoặc bạn không có quyền!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    final sb = Supabase.instance.client;
    final createdSessionItemIds = <String>[];
    String? createdTicketId;
    bool isNewSessionCreated = false;
    String? targetSessionId;

    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'] as String? ?? widget.request.storeId;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final isTable = widget.request.type == 'table' && widget.request.tableId != null;
      final targetTableId = isTable ? widget.request.tableId! : kSysPosTakeawayTableId;

      if (!isTable) {
        await _ensureTakeawayZoneAndTable(sb, storeId);
      }

      // Check if session already open
      final existingSession = await sb
          .from('ban_sessions')
          .select('id')
          .eq('store_id', storeId)
          .eq('table_id', targetTableId)
          .eq('status', 'open')
          .maybeSingle();

      if (existingSession != null) {
        targetSessionId = existingSession['id'] as String;
      } else {
        final session = await _banRepo.openSession(targetTableId);
        targetSessionId = session.id;
        isNewSessionCreated = true;
      }

      // 2. Insert targeted session items with unique IDs
      for (final item in _editableItems) {
        final sItemId = _uuid.v4();
        createdSessionItemIds.add(sItemId);

        await sb.from('ban_session_items').insert({
          'id': sItemId,
          'session_id': targetSessionId,
          'store_id': storeId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.unitPrice,
          'quantity': item.quantity.toDouble(),
          'subtotal': item.unitPrice * item.quantity,
          'note': isTable ? item.note : 'Pickup ${widget.request.pickupCode ?? ""}: ${item.note ?? ""}',
          'modifiers_json': item.modifiersJson,
          'kitchen_status': 'chua_gui',
          'added_at': nowIso,
        });
      }

      // 3. Create Kitchen Ticket for EXACT session items
      final ticketId = _uuid.v4();
      createdTicketId = ticketId;

      final existingTickets = await sb
          .from('kitchen_tickets')
          .select('round')
          .eq('session_id', targetSessionId);
      final round = existingTickets.length + 1;

      await sb.from('kitchen_tickets').insert({
        'id': ticketId,
        'store_id': storeId,
        'session_id': targetSessionId,
        'table_id': targetTableId,
        'table_label': isTable ? (widget.request.tableName ?? 'Bàn QR') : 'Mang đi (${widget.request.pickupCode ?? "#Q01"})',
        'zone_label': isTable ? 'Khu Bàn' : 'Quầy Mang Đi',
        'round': round,
        'status': 'cho',
        'sent_at': nowIso,
        'created_at': nowIso,
      });

      final ticketItems = _editableItems.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        return {
          'id': _uuid.v4(),
          'store_id': storeId,
          'ticket_id': ticketId,
          'session_item_id': createdSessionItemIds[idx],
          'product_id': item.productId,
          'name': item.productName,
          'qty': item.quantity,
          'modifiers': item.modifiersJson,
          'free_note': item.note,
          'station_code': 'nong',
          'done': false,
        };
      }).toList();

      await sb.from('kitchen_ticket_items').insert(ticketItems);

      // Update targeted session items to 'da_gui'
      await sb
          .from('ban_session_items')
          .update({'kitchen_status': 'da_gui'})
          .inFilter('id', createdSessionItemIds);

      // ── COMMIT BOUNDARY SUCCESSFUL (Kitchen Ticket Created & Items Marked da_gui) ──
    } catch (e) {
      // PHASE 1 ROLLBACK: Clean up orphaned rows before kitchen commit
      try {
        if (createdTicketId != null) {
          await sb.from('kitchen_tickets').delete().eq('id', createdTicketId);
        }
        if (createdSessionItemIds.isNotEmpty) {
          await sb.from('ban_session_items').delete().inFilter('id', createdSessionItemIds);
        }
        if (isNewSessionCreated && targetSessionId != null) {
          final remaining = await sb.from('ban_session_items').select('id').eq('session_id', targetSessionId);
          if (remaining.isEmpty) {
            await sb.from('ban_sessions').delete().eq('id', targetSessionId);
          }
        }
      } catch (_) {}

      // Reset QR status back to pending_staff
      await _qrRepo.updateRequestStatus(widget.request.id, 'pending_staff');

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi bếp (đã dọn dẹp & khôi phục đơn chờ): $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // PHASE 2 POST-COMMIT STATUS SYNC (Retry loop on QR request status update)
    bool statusUpdated = false;
    for (int retry = 0; retry < 3; retry++) {
      try {
        await _qrRepo.updateRequestStatus(widget.request.id, 'sent_kitchen');
        statusUpdated = true;
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    await QrSoundService.playNotificationSound();

    if (mounted) {
      setState(() => _isSubmitting = false);
      widget.onApproved();
      Navigator.pop(context);

      if (statusUpdated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận & gửi bếp thành công!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi bếp thành công! (Cần kiểm tra đồng bộ trạng thái đơn QR)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest() async {
    final claimed = await _qrRepo.claimRequest(widget.request.id);
    if (!claimed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn hàng này đã được xử lý bởi nhân viên khác!')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      await _qrRepo.updateRequestStatus(widget.request.id, 'rejected');
      widget.onRejected();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      await _qrRepo.updateRequestStatus(widget.request.id, 'pending_staff');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi từ chối đơn: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleLabel = widget.request.type == 'table'
        ? widget.request.tableName ?? 'Bàn QR'
        : 'QUẦY THU NGÂN — ${widget.request.pickupCode ?? "#Q01"}';

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
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DUYỆT ĐƠN GỌI MÓN QR',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _editableItems.length,
              itemBuilder: (context, index) {
                final item = _editableItems[index];
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
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              currencyFmt.format(item.unitPrice),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.note != null && item.note!.isNotEmpty)
                              Text(
                                'Ghi chú: ${item.note}',
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.orange.shade800),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 22),
                            onPressed: () => _updateItemQty(index, -1),
                          ),
                          Text(
                            '${item.quantity}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 22),
                            onPressed: () => _updateItemQty(index, 1),
                          ),
                        ],
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
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                currencyFmt.format(_totalAmount),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _rejectRequest,
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
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    'XÁC NHẬN & GỬI BẾP',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: _isSubmitting ? null : _confirmAndSendToKitchen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
