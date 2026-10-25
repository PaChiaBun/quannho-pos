import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/ops_providers.dart';
import '../repository/ops_repository.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kMuted = Color(0xFF9E9085);

/// Có gì để hiện không — bàn giao trống (không ghi chú, không việc tồn) thì ẩn.
bool opsHandoverHasContent(OpsShiftHandoverModel h) =>
    (h.issues?.trim().isNotEmpty ?? false) ||
    (h.notes?.trim().isNotEmpty ?? false) ||
    h.pendingTasks.isNotEmpty;

/// Thẻ "Bàn giao ca gần nhất" — dùng ở màn nhân viên và Tổng Quan của quản lý.
class OpsHandoverCard extends ConsumerWidget {
  const OpsHandoverCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(opsLatestHandoverProvider).value;
    if (h == null || !opsHandoverHasContent(h)) return const SizedBox.shrink();

    final at = DateTime.tryParse(h.createdAt)?.toLocal();
    final when = at == null ? '' : ' · ${DateFormat('HH:mm dd/MM').format(at)}';
    final issues = h.issues?.trim() ?? '';
    final notes = h.notes?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kNavy.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: _kNavy, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bàn giao ca gần nhất',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${h.createdByName.isEmpty ? 'Nhân viên' : h.createdByName}$when',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kMuted),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ $issues',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kNavy),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '📝 $notes',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kNavy),
            ),
          ],
          if (h.pendingTasks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${h.pendingTasks.length} việc chưa xong lúc bàn giao',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _kOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
