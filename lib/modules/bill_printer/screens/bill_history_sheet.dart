// lib/modules/bill_printer/screens/bill_history_sheet.dart
// Bottom sheet hiện danh sách các bản lưu cũ — xem và khôi phục
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bill_template_history.dart';
import '../providers/bill_template_provider.dart';
import '../widgets/bill_preview_widget.dart';

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);

// ─── Hàm mở sheet ────────────────────────────────────────────────────────────
Future<void> showBillHistorySheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BillHistorySheet(parentRef: ref),
  );
}

// ─── Sheet Widget (StatefulWidget + FutureBuilder) ────────────────────────────
class _BillHistorySheet extends StatefulWidget {
  final WidgetRef parentRef;
  const _BillHistorySheet({required this.parentRef});
  @override
  State<_BillHistorySheet> createState() => _BillHistorySheetState();
}

class _BillHistorySheetState extends State<_BillHistorySheet> {
  String? _previewId;
  late Future<List<BillTemplateSnapshot>> _future;

  @override
  void initState() {
    super.initState();
    _future = BillTemplateHistoryService.load();
  }

  void _reload() => setState(() { _future = BillTemplateHistoryService.load(); });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0F2F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.history_rounded, color: _kIndigo, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Lịch Sử Thiết Kế',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w800, color: _kIndigo))),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Bấm vào bản để xem trước • Chọn "Khôi phục" để dùng lại',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
          ),
          const SizedBox(height: 8),

          // Body
          Expanded(
            child: FutureBuilder<List<BillTemplateSnapshot>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
                final list = snap.data ?? [];
                if (list.isEmpty) return _emptyState();
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final isOpen = _previewId == s.id;
                    return _HistoryCard(
                      snapshot: s,
                      isOpen: isOpen,
                      onTap: () => setState(() => _previewId = isOpen ? null : s.id),
                      onRestore: () => _restore(s),
                      onDelete: () => _delete(s),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_rounded, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Chưa có lịch sử',
            style: GoogleFonts.outfit(fontSize: 16,
                fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
        const SizedBox(height: 4),
        Text('Bấm "Lưu" trong Thiết Kế Hoá Đơn để tạo bản lưu đầu tiên',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400)),
      ]),
    ),
  );

  Future<void> _restore(BillTemplateSnapshot snap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Khôi phục bản lưu?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'Thiết kế hiện tại sẽ bị thay thế bằng "${snap.label}".\nBản hiện tại sẽ tự lưu vào lịch sử trước.',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kIndigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Khôi phục',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Lưu bản hiện tại vào lịch sử trước
    final currentTpl = widget.parentRef.read(billTemplateProvider).value;
    if (currentTpl != null) {
      await BillTemplateHistoryService.push(currentTpl,
          customLabel: 'Trước khôi phục ${_fmt(DateTime.now())}');
    }

    // Áp dụng bản cũ
    await widget.parentRef
        .read(billTemplateProvider.notifier)
        .applyPreset(snap.template);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Đã khôi phục "${snap.label}"',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: _kIndigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _delete(BillTemplateSnapshot snap) async {
    await BillTemplateHistoryService.delete(snap.id);
    setState(() { if (_previewId == snap.id) _previewId = null; });
    _reload();
  }

  String _fmt(DateTime dt) =>
      '${_p(dt.day)}/${_p(dt.month)} ${_p(dt.hour)}:${_p(dt.minute)}';
  String _p(int v) => v.toString().padLeft(2, '0');
}

// ─── History Card ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final BillTemplateSnapshot snapshot;
  final bool isOpen;
  final VoidCallback onTap, onRestore, onDelete;

  const _HistoryCard({
    required this.snapshot, required this.isOpen,
    required this.onTap, required this.onRestore, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? _kIndigo : Colors.transparent, width: isOpen ? 1.5 : 0),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header hàng — tap để expand
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded,
                    color: _kIndigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot.label,
                      style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _kIndigo)),
                  const SizedBox(height: 2),
                  Row(children: [
                    _chip(snapshot.paperSize.toUpperCase(), _kOrange),
                    const SizedBox(width: 6),
                    _chip('${snapshot.blockCount} blocks', Colors.grey.shade500),
                  ]),
                ],
              )),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded,
                    color: Colors.grey, size: 22),
              ),
            ]),
          ),
        ),

        // Expanded: preview + actions
        if (isOpen) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          SizedBox(
            height: 340,
            child: BillPreviewWidget(tpl: snapshot.template),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.red),
                label: Text('Xoá',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onDelete,
              ),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.restore_rounded,
                    size: 16, color: Colors.white),
                label: Text('Khôi phục mẫu này',
                    style: GoogleFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kIndigo,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                onPressed: onRestore,
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text,
        style: GoogleFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
