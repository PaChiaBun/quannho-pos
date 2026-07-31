import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/repositories/ban_repository.dart';
import '../../services/qr_pdf_service.dart';
import '../table_qr_print_screen.dart';

class BatchTablePrintTab extends StatelessWidget {
  final bool loadingTables;
  final String? activeBaseUrl;
  final List<BanZoneModel> zones;
  final List<BanTableModel> tables;
  final String batchSelectMode;
  final ValueChanged<String> onBatchSelectModeChanged;
  final String batchSelectedZoneId;
  final ValueChanged<String> onBatchZoneIdChanged;
  final Set<String> selectedTableIds;
  final void Function(String, bool) onToggleTableSelected;

  final String decalPreset;
  final ValueChanged<String> onDecalPresetChanged;
  final TextEditingController decalWidthCtrl;
  final TextEditingController decalHeightCtrl;
  final double bleedMm;
  final ValueChanged<double> onBleedMmChanged;
  final bool showCropMarks;
  final ValueChanged<bool> onCropMarksChanged;

  final TextEditingController tplTitleCtrl;
  final TextEditingController tplInstructionCtrl;
  final TextEditingController tplConfirmNoteCtrl;
  final String storeName;
  final String? Function(BanTableModel) buildTableQrUrl;

  const BatchTablePrintTab({
    super.key,
    required this.loadingTables,
    required this.activeBaseUrl,
    required this.zones,
    required this.tables,
    required this.batchSelectMode,
    required this.onBatchSelectModeChanged,
    required this.batchSelectedZoneId,
    required this.onBatchZoneIdChanged,
    required this.selectedTableIds,
    required this.onToggleTableSelected,
    required this.decalPreset,
    required this.onDecalPresetChanged,
    required this.decalWidthCtrl,
    required this.decalHeightCtrl,
    required this.bleedMm,
    required this.onBleedMmChanged,
    required this.showCropMarks,
    required this.onCropMarksChanged,
    required this.tplTitleCtrl,
    required this.tplInstructionCtrl,
    required this.tplConfirmNoteCtrl,
    required this.storeName,
    required this.buildTableQrUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingTables) {
      return const Center(child: CircularProgressIndicator());
    }

    List<BanTableModel> targetTables = [];
    if (batchSelectMode == 'all') {
      targetTables = List.from(tables);
    } else if (batchSelectMode == 'zone') {
      targetTables = tables
          .where((t) => t.zoneId == batchSelectedZoneId)
          .toList();
    } else {
      targetTables = tables
          .where((t) => selectedTableIds.contains(t.id))
          .toList();
    }

    final validTargetTables = targetTables
        .where((t) => buildTableQrUrl(t) != null)
        .toList();

    final widthMm = double.tryParse(decalWidthCtrl.text.trim()) ?? 70.0;
    final heightMm = double.tryParse(decalHeightCtrl.text.trim()) ?? 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeBaseUrl == null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đã khóa tính năng in tem bàn do chưa cấu hình Tên miền Public hợp lệ (HTTPS). Vào Tab Thiết Lập để cài đặt.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Phạm Vi Chọn Bàn In Tem Decal:',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tất Cả Bàn'),
                      selected: batchSelectMode == 'all',
                      onSelected: (val) {
                        if (val) onBatchSelectModeChanged('all');
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Theo Khu Vực'),
                      selected: batchSelectMode == 'zone',
                      onSelected: (val) {
                        if (val) onBatchSelectModeChanged('zone');
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Từng Bàn Cụ Thể'),
                      selected: batchSelectMode == 'custom',
                      onSelected: (val) {
                        if (val) onBatchSelectModeChanged('custom');
                      },
                    ),
                  ],
                ),
                if (batchSelectMode == 'zone') ...[
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: batchSelectedZoneId,
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả khu'),
                      ),
                      ...zones.map(
                        (z) =>
                            DropdownMenuItem(value: z.id, child: Text(z.name)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) onBatchZoneIdChanged(val);
                    },
                  ),
                ],
                if (batchSelectMode == 'custom') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tables.map((t) {
                      final isSelected = selectedTableIds.contains(t.id);
                      return FilterChip(
                        label: Text(t.label),
                        selected: isSelected,
                        onSelected: (val) => onToggleTableSelected(t.id, val),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Cấu Hình Kích Thước Decal & Dấu Cắt (Vector Size):',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('60 x 90 mm'),
                      selected: decalPreset == '60x90',
                      onSelected: (val) {
                        if (val) {
                          onDecalPresetChanged('60x90');
                          decalWidthCtrl.text = '60';
                          decalHeightCtrl.text = '90';
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('70 x 100 mm (Chuẩn)'),
                      selected: decalPreset == '70x100',
                      onSelected: (val) {
                        if (val) {
                          onDecalPresetChanged('70x100');
                          decalWidthCtrl.text = '70';
                          decalHeightCtrl.text = '100';
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('80 x 120 mm'),
                      selected: decalPreset == '80x120',
                      onSelected: (val) {
                        if (val) {
                          onDecalPresetChanged('80x120');
                          decalWidthCtrl.text = '80';
                          decalHeightCtrl.text = '120';
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Custom mm'),
                      selected: decalPreset == 'custom',
                      onSelected: (val) {
                        if (val) onDecalPresetChanged('custom');
                      },
                    ),
                  ],
                ),
                if (decalPreset == 'custom') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: decalWidthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rộng (Width mm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: decalHeightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cao (Height mm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tràn lề Bleed: ',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<double>(
                          value: bleedMm,
                          items: const [
                            DropdownMenuItem(value: 0.0, child: Text('0 mm')),
                            DropdownMenuItem(
                              value: 2.0,
                              child: Text('2 mm (Khuyên dùng)'),
                            ),
                            DropdownMenuItem(
                              value: 3.0,
                              child: Text('3 mm nhà in'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) onBleedMmChanged(val);
                          },
                        ),
                      ],
                    ),
                    FilterChip(
                      label: const Text('Hiện Crop Marks (Dấu cắt)'),
                      selected: showCropMarks,
                      onSelected: onCropMarksChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. Tùy Chỉnh Mẫu Template Decal Dùng Chung:',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tplTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề chính (Title)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tplInstructionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lời hướng dẫn quét',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tplConfirmNoteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú xác nhận (Confirm Note)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'XEM TRƯỚC MẪU DECAL IN THỰC TẾ (${widthMm.toInt()}x${heightMm.toInt()} mm):',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: widthMm * 3.5,
              height: heightMm * 3.5,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade700, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        storeName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tplTitleCtrl.text,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      'BÀN A01',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 70,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    tplInstructionCtrl.text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      tplConfirmNoteCtrl.text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: GoogleFonts.outfit(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: validTargetTables.isNotEmpty
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                validTargetTables.isNotEmpty
                    ? 'XUẤT FILE PDF VECTOR GỬI NHÀ IN (${validTargetTables.length} TEM)'
                    : 'CHƯA SẴN SÀNG IN (CẦN CẤU HÌNH DOMAIN HTTPS & DB)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: validTargetTables.isNotEmpty
                  ? () {
                      final items = validTargetTables.map((t) {
                        final zone = zones.firstWhere(
                          (z) => z.id == t.zoneId,
                          orElse: () => BanZoneModel(
                            id: '',
                            storeId: '',
                            name: 'Khu chung',
                            colorValue: 0,
                            iconCode: 0,
                            sortOrder: 0,
                            isActive: true,
                          ),
                        );
                        return TableQrItemData(
                          title: t.label,
                          qrUrl: buildTableQrUrl(t)!,
                          zoneName: zone.name,
                          tableName: t.label,
                        );
                      }).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TableQrPrintScreen(
                            title: 'Hàng Loạt ${items.length} Tem',
                            qrUrl: items.first.qrUrl,
                            storeName: storeName,
                            batchItems: items,
                            widthMm: widthMm,
                            heightMm: heightMm,
                            bleedMm: bleedMm,
                            showCropMarks: showCropMarks,
                            headerTitle: tplTitleCtrl.text.trim(),
                            instructionText: tplInstructionCtrl.text.trim(),
                            confirmNote: tplConfirmNoteCtrl.text.trim(),
                          ),
                        ),
                      );
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không có bàn nào sẵn sàng để xuất PDF. Vui lòng kiểm tra Tên miền HTTPS và DB.',
                          ),
                          backgroundColor: Colors.orange,
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
