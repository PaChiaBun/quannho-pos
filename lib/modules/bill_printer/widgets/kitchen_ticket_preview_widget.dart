import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/kitchen_ticket_template_provider.dart';

class KitchenTicketPreviewWidget extends StatelessWidget {
  final KitchenTicketTemplate tpl;
  const KitchenTicketPreviewWidget({super.key, required this.tpl});

  static const _sampleItems = [
    ('Phở Bò Đặc Biệt', 2, '+ Khúc Bạch, Dừa sợi\nGhi chú: Không hành, ít ớt'),
    ('Cơm Gà Xối Mỡ', 1, null),
    ('Bánh Mì Thịt', 3, 'Ghi chú: Không rau mùi'),
  ];

  @override
  Widget build(BuildContext context) {
    final widthFactor = tpl.paperSize == '58mm' ? 0.7 : 0.88;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Tiêu đề ──
                Text(
                  tpl.headerText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: tpl.headerFontSize.toDouble(),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),

                // ── Bàn + số đơn ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (tpl.showTableName)
                      Text(
                        'BÀN 5',
                        style: GoogleFonts.outfit(
                          fontSize: tpl.tableFontSize.toDouble(),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (tpl.showOrderNumber)
                      Text(
                        '#QN-018',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                if (tpl.showDateTime)
                  Text(
                    '14/05/2026  13:45',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                if (tpl.showWaiterName)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'NV Order: Thành Nghiệp',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                if (tpl.showDivider) ...[
                  const SizedBox(height: 6),
                  const Divider(thickness: 1, height: 8),
                ],
                const SizedBox(height: 4),

                // ── Danh sách món ──
                ..._sampleItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final hasNote = tpl.showNote && item.$3 != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.black, width: 3.5),
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: GoogleFonts.outfit(
                                      fontSize: tpl.itemFontSize.toDouble(),
                                      fontWeight: tpl.boldItemName ? FontWeight.w900 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'x${item.$2}',
                                  style: GoogleFonts.outfit(
                                      fontSize: tpl.qtyFontSize.toDouble(),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            if (hasNote)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: item.$3!.split('\n').map((line) {
                                    var displayLine = line;
                                    if (displayLine.startsWith('+ Thêm món: ')) {
                                      displayLine = '+ ${displayLine.substring('+ Thêm món: '.length)}';
                                    }
                                    return Text(
                                      '↳ $displayLine',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: Colors.blueGrey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (idx < _sampleItems.length - 1)
                        const Divider(thickness: 0.8, height: 12, color: Colors.black26),
                    ],
                  );
                }),

                if (tpl.showDivider) ...[
                  const SizedBox(height: 8),
                  const Divider(thickness: 1, height: 8),
                ],
                const SizedBox(height: 4),

                // Footer branding hoặc note chung
                Center(
                  child: Text(
                    'Quán Nhỏ POS',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
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
