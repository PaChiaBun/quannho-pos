import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/repositories/ban_repository.dart';
import '../../models/qr_order_model.dart';
import '../table_qr_print_screen.dart';

class TableQrListTab extends StatelessWidget {
  final bool loadingTables;
  final String? activeBaseUrl;
  final List<BanZoneModel> zones;
  final List<BanTableModel> tables;
  final Map<String, QrChannelModel?> channelsByTableId;
  final TextEditingController tableSearchCtrl;
  final ValueChanged<String>? onSearchChanged;
  final String selectedZoneFilter;
  final ValueChanged<String> onZoneFilterChanged;
  final String storeName;
  final String? Function(BanTableModel) buildTableQrUrl;
  final void Function(BuildContext, BanTableModel, String?) showQrPreviewDialog;

  const TableQrListTab({
    super.key,
    required this.loadingTables,
    required this.activeBaseUrl,
    required this.zones,
    required this.tables,
    required this.channelsByTableId,
    required this.tableSearchCtrl,
    this.onSearchChanged,
    required this.selectedZoneFilter,
    required this.onZoneFilterChanged,
    required this.storeName,
    required this.buildTableQrUrl,
    required this.showQrPreviewDialog,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingTables) {
      return const Center(child: CircularProgressIndicator());
    }

    final search = tableSearchCtrl.text.trim().toLowerCase();
    final filteredTables = tables.where((t) {
      final matchesSearch =
          search.isEmpty || t.label.toLowerCase().contains(search);
      final matchesZone =
          selectedZoneFilter == 'all' || t.zoneId == selectedZoneFilter;
      return matchesSearch && matchesZone;
    }).toList();

    return Column(
      children: [
        if (activeBaseUrl == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã khóa xuất mã QR do chưa cấu hình Tên miền Public hợp lệ (HTTPS). Vào Tab Thiết Lập để cài đặt.',
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tableSearchCtrl,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên bàn...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedZoneFilter,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Tất cả khu'),
                          ),
                          ...zones.map(
                            (z) => DropdownMenuItem(
                              value: z.id,
                              child: Text(z.name),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) onZoneFilterChanged(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredTables.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy bàn phù hợp',
                    style: GoogleFonts.outfit(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: zones.length,
                  itemBuilder: (context, zoneIndex) {
                    final zone = zones[zoneIndex];
                    final tablesInZone = filteredTables
                        .where((t) => t.zoneId == zone.id)
                        .toList();
                    if (tablesInZone.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(
                              zone.colorValue,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(
                                zone.colorValue,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Color(zone.colorValue),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${zone.name} (${tablesInZone.length} bàn)',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(zone.colorValue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...tablesInZone.map((table) {
                          final url = buildTableQrUrl(table);
                          final ch = channelsByTableId[table.id];

                          final String statusText;
                          final Color statusColor;
                          final IconData statusIcon;

                          if (url != null) {
                            statusText = 'Sẵn sàng';
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle_rounded;
                          } else if (activeBaseUrl == null) {
                            statusText = '🔒 Chưa có Domain HTTPS';
                            statusColor = Colors.amber.shade900;
                            statusIcon = Icons.lock_rounded;
                          } else {
                            statusText = '⚠️ Chưa khởi tạo DB';
                            statusColor = Colors.red;
                            statusIcon = Icons.warning_amber_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      zone.colorValue,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.table_restaurant_rounded,
                                    color: Color(zone.colorValue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            table.label,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  statusIcon,
                                                  size: 12,
                                                  color: statusColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  statusText,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${table.seats} ghế • Code: ${ch?.channelCode ?? "CTR_CHUA_MIGRATE"}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message: 'Xem trước mã QR bàn',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                    onPressed: () => showQrPreviewDialog(
                                      context,
                                      table,
                                      url,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: url != null
                                      ? 'Sao chép link QR'
                                      : (activeBaseUrl == null
                                            ? 'Nút bị khóa: Chưa cấu hình tên miền HTTPS'
                                            : 'Nút bị khóa: Chưa khởi tạo DB Supabase'),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.copy_rounded,
                                      color: url != null
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                    ),
                                    onPressed: url != null
                                        ? () {
                                            Clipboard.setData(
                                              ClipboardData(text: url),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Đã sao chép link QR cho ${table.label}!',
                                                ),
                                              ),
                                            );
                                          }
                                        : () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  activeBaseUrl == null
                                                      ? 'Vui lòng cấu hình Tên miền HTTPS tại Tab Thiết Lập để kích hoạt nút sao chép.'
                                                      : 'Vui lòng chạy migration SQL để khởi tạo DB.',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          },
                                  ),
                                ),
                                Tooltip(
                                  message: url != null
                                      ? 'In thẻ QR bàn'
                                      : (activeBaseUrl == null
                                            ? 'Nút bị khóa: Chưa cấu hình tên miền HTTPS'
                                            : 'Nút bị khóa: Chưa khởi tạo DB Supabase'),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: url != null
                                          ? const Color(0xFF8B5CF6)
                                          : Colors.grey.shade300,
                                      foregroundColor: url != null
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      elevation: url != null ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.print_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'In Lẻ',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: url != null
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    TableQrPrintScreen(
                                                      title: table.label,
                                                      qrUrl: url,
                                                      storeName: storeName,
                                                    ),
                                              ),
                                            );
                                          }
                                        : () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  activeBaseUrl == null
                                                      ? 'Vui lòng cấu hình Tên miền HTTPS tại Tab Thiết Lập để mở khóa nút in.'
                                                      : 'Vui lòng chạy migration SQL để khởi tạo DB.',
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
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
