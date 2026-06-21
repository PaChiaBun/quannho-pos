// lib/features/backup/backup_screen.dart
// Xuất dữ liệu quán dưới dạng CSV — không cần thêm dependency
// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/store_auth_service.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
final _fileFmt = DateFormat('yyyyMMdd_HHmm');

// ─── Backup entry definition ──────────────────────────────────────────────────

class _BackupTarget {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Future<String> Function(String storeId) exportFn;

  const _BackupTarget({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.exportFn,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _exporting = <String, bool>{};
  String? _lastExport;

  static final _db = Supabase.instance.client;

  // ─── Backup targets ─────────────────────────────────────────────────────────

  late final List<_BackupTarget> _targets = [
    _BackupTarget(
      id: 'orders',
      label: 'Đơn hàng',
      description: 'Toàn bộ đơn hàng (orders + items)',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF1565C0),
      exportFn: _exportOrders,
    ),
    _BackupTarget(
      id: 'finance',
      label: 'Thu Chi',
      description: 'Lịch sử thu chi tài chính',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF2E7D32),
      exportFn: _exportFinance,
    ),
    _BackupTarget(
      id: 'payroll',
      label: 'Tính Lương',
      description: 'Kỳ lương + phiếu lương nhân viên',
      icon: Icons.payments_rounded,
      color: const Color(0xFF6A1B9A),
      exportFn: _exportPayroll,
    ),
    _BackupTarget(
      id: 'inventory',
      label: 'Tồn Kho',
      description: 'Danh sách sản phẩm + tồn kho hiện tại',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFFE65100),
      exportFn: _exportInventory,
    ),
    _BackupTarget(
      id: 'staff',
      label: 'Nhân Viên',
      description: 'Danh sách nhân viên + ca làm việc',
      icon: Icons.people_rounded,
      color: const Color(0xFF00695C),
      exportFn: _exportStaff,
    ),
  ];

  // ─── Export functions ────────────────────────────────────────────────────────

  static String _csvRow(List<dynamic> row) {
    return row.map((cell) {
      final s = (cell ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }).join(',');
  }

  static Future<String> _exportOrders(String storeId) async {
    final rows = await _db.from('orders').select(
        'id, order_number, created_at, status, total_amount, payment_method, source_type, source_id, customer_name, note'
    ).eq('store_id', storeId).order('created_at', ascending: false);

    final buf = StringBuffer();
    buf.writeln(_csvRow(['ID', 'Số đơn', 'Thời gian', 'Trạng thái',
        'Tổng tiền', 'Thanh toán', 'Kênh', 'Bàn/Ref', 'Khách', 'Ghi chú']));
    for (final r in rows as List) {
      buf.writeln(_csvRow([r['id'], r['order_number'],
        _fmtTs(r['created_at']), r['status'],
        r['total_amount'], r['payment_method'],
        r['source_type'], r['source_id'],
        r['customer_name'], r['note']]));
    }
    return buf.toString();
  }

  static Future<String> _exportFinance(String storeId) async {
    final rows = await _db.from('finance_records').select(
        'id, type, amount, description, is_auto, recorded_at'
    ).eq('store_id', storeId).order('recorded_at', ascending: false);

    final buf = StringBuffer();
    buf.writeln(_csvRow(['ID', 'Loại', 'Số tiền', 'Mô tả', 'Tự động', 'Thời gian']));
    for (final r in rows as List) {
      buf.writeln(_csvRow([r['id'], r['type'], r['amount'],
        r['description'], r['is_auto'], _fmtTs(r['recorded_at'])]));
    }
    return buf.toString();
  }

  static Future<String> _exportPayroll(String storeId) async {
    final periods = await _db.from('payroll_periods').select(
        'id, name, from_date, to_date, status, total_amount'
    ).eq('store_id', storeId).order('from_date', ascending: false);

    final records = await _db.from('payroll_records').select(
        'id, period_id, staff_name, salary_mode, total_hours, net_pay, payment_status'
    ).eq('store_id', storeId).order('created_at', ascending: false);

    // Map period name
    final periodMap = {for (final p in periods as List) p['id'] as String : p['name'] as String};

    final buf = StringBuffer();
    buf.writeln(_csvRow(['Kỳ lương', 'Nhân viên', 'Chế độ', 'Tổng giờ',
        'Thực lĩnh', 'Trạng thái thanh toán']));
    for (final r in records as List) {
      buf.writeln(_csvRow([
        periodMap[r['period_id']] ?? r['period_id'],
        r['staff_name'], r['salary_mode'],
        r['total_hours'], r['net_pay'], r['payment_status']
      ]));
    }
    return buf.toString();
  }

  static Future<String> _exportInventory(String storeId) async {
    final rows = await _db.from('products').select(
        'id, name, sku, sell_price, cost_price, stock_qty, unit, category, product_type, is_active'
    ).eq('store_id', storeId).eq('is_deleted', false).order('name');

    final buf = StringBuffer();
    buf.writeln(_csvRow(['ID', 'Tên sản phẩm', 'SKU', 'Giá bán', 'Giá vốn',
        'Tồn kho', 'Đơn vị', 'Danh mục', 'Loại', 'Hoạt động']));
    for (final r in rows as List) {
      buf.writeln(_csvRow([r['id'], r['name'], r['sku'] ?? '', r['sell_price'],
        r['cost_price'] ?? '', r['stock_qty'], r['unit'],
        r['category'], r['product_type'], r['is_active']]));
    }
    return buf.toString();
  }

  static Future<String> _exportStaff(String storeId) async {
    final rows = await _db.from('store_members').select(
        'user_id, role, created_at, user_accounts(display_name, phone)'
    ).eq('store_id', storeId);

    final buf = StringBuffer();
    buf.writeln(_csvRow(['Tên', 'SĐT', 'Vai trò', 'Ngày thêm']));
    for (final r in rows as List) {
      // user_accounts có thể là Map (FK 1-1) hoặc null nếu orphan
      final raw = r['user_accounts'];
      final acc = raw is Map<String, dynamic> ? raw
                : (raw is List && raw.isNotEmpty ? raw.first as Map<String, dynamic> : <String, dynamic>{});
      buf.writeln(_csvRow([acc['display_name'], acc['phone'],
        r['role'], _fmtTs(r['created_at'])]));
    }
    return buf.toString();
  }

  static String _fmtTs(dynamic ts) {
    if (ts == null) return '';
    try { return _dateFmt.format(DateTime.parse(ts.toString()).toLocal()); }
    catch (_) { return ts.toString(); }
  }

  // ─── Export & Share ──────────────────────────────────────────────────────────

  Future<void> _export(_BackupTarget target) async {
    setState(() => _exporting[target.id] = true);
    try {
      final info    = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'] as String?;
      if (storeId == null) throw 'Không lấy được store_id';

      final csv      = await target.exportFn(storeId);
      final dir      = await getTemporaryDirectory();
      final stamp    = _fileFmt.format(DateTime.now());
      final filename = 'quannho_${target.id}_$stamp.csv';
      final file     = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          text:  'Xuất dữ liệu ${target.label} — Quán Nhỏ POS',
          files: [XFile(file.path, mimeType: 'text/csv', name: filename)],
        ),
      );

      setState(() => _lastExport = '${target.label} ($stamp)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi xuất ${target.label}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting[target.id] = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 110,
          pinned: true,
          backgroundColor: const Color(0xFF1E1C5E),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            title: const Text('Sao Lưu Dữ Liệu',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 18)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1C5E), Color(0xFF2D2B8A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Xuất dữ liệu dưới dạng file CSV — có thể mở bằng Excel, Google Sheets. '
                  'Dữ liệu được lấy trực tiếp từ Supabase theo thời gian thực.',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            if (_lastExport != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Đã xuất: $_lastExport',
                      style: TextStyle(color: Colors.green.shade800, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Chọn dữ liệu cần xuất',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 15, color: Color(0xFF1A1207))),
            const SizedBox(height: 12),

            ..._targets.map((t) => _BackupCard(
              target: t,
              isLoading: _exporting[t.id] ?? false,
              onExport: () => _export(t),
            )),

            const SizedBox(height: 20),

            // Backup all
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1C5E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _exporting.values.any((v) => v)
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                label: const Text('Xuất Tất Cả',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                onPressed: _exporting.values.any((v) => v)
                    ? null
                    : () async {
                        for (final t in _targets) {
                          await _export(t);
                        }
                      },
              ),
            ),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }
}

// ─── Backup Card ──────────────────────────────────────────────────────────────

class _BackupCard extends StatelessWidget {
  final _BackupTarget target;
  final bool isLoading;
  final VoidCallback onExport;
  const _BackupCard({required this.target, required this.isLoading, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        onTap: isLoading ? null : onExport,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: target.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(target.icon, color: target.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(target.label,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 15, color: Color(0xFF1A1207))),
              const SizedBox(height: 2),
              Text(target.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
            ])),
            const SizedBox(width: 8),
            if (isLoading)
              SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: target.color))
            else
              Icon(Icons.ios_share_rounded, color: target.color, size: 22),
          ]),
        ),
      ),
    );
  }
}
