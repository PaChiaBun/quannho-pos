// lib/modules/tinhluong/screens/dispute_sheet.dart
// Bottom sheet để nhân viên gửi phản hồi / khiếu nại phiếu lương
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/user_auth_service.dart';
import '../repository/tinhluong_repository.dart';

class DisputeSheet extends StatefulWidget {
  final PayrollRecordModel record;
  final VoidCallback onSubmitted;
  const DisputeSheet({super.key, required this.record, required this.onSubmitted});

  @override
  State<DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<DisputeSheet> {
  String _field   = 'other';
  final _msgCtrl  = TextEditingController();
  bool  _loading  = false;
  bool  _success  = false;

  static const _fields = [
    ('total_hours', Icons.schedule_rounded,    'Giờ làm sai',     Color(0xFF1565C0)),
    ('overtime',    Icons.trending_up_rounded, 'Tăng ca sai',     Color(0xFF6A1B9A)),
    ('deduction',   Icons.remove_circle_rounded,'Khấu trừ sai',   Color(0xFFC62828)),
    ('other',       Icons.help_outline_rounded, 'Vấn đề khác',    Color(0xFF9E9085)),
  ];

  Future<void> _submit() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;

    setState(() => _loading = true);
    try {
      final db      = Supabase.instance.client;
      final info    = await StoreAuthService.getStoreInfo();
      final session = await UserAuthService.getCurrentSession();
      await db.from('payroll_disputes').insert({
        'store_id':   info['store_id'],
        'record_id':  widget.record.id,
        'user_id':    session?.userId,   // ✅ custom auth
        'staff_name': widget.record.staffName,
        'field':      _field,
        'message':    msg,
      });
      setState(() { _success = true; _loading = false; });
      await Future.delayed(const Duration(milliseconds: 1200));
      widget.onSubmitted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi khiếu nại: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flag_rounded, color: Color(0xFFC62828), size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gửi Phản Hồi / Khiếu Nại',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2151))),
            Text(widget.record.staffName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
          ]),
        ]),
        const SizedBox(height: 20),

        if (_success)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 12),
              const Text('Khiếu nại đã gửi thành công!',
                  style: TextStyle(color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          )
        else ...[
          // Field selector
          const Align(alignment: Alignment.centerLeft,
            child: Text('Vấn đề là gì?',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 13, color: Color(0xFF1C2151)))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: _fields.map((f) {
              final selected = _field == f.$1;
              return GestureDetector(
                onTap: () => setState(() => _field = f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? f.$4.withValues(alpha: 0.12) : const Color(0xFFF5F0EA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? f.$4 : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.$2, size: 16, color: selected ? f.$4 : const Color(0xFF9E9085)),
                    const SizedBox(width: 6),
                    Text(f.$3, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? f.$4 : const Color(0xFF9E9085))),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Message
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Mô tả chi tiết vấn đề...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: Text(_loading ? 'Đang gửi...' : 'Gửi khiếu nại',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }
}
