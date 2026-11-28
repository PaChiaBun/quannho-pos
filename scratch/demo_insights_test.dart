// Công cụ tạm: chạy engine nhận xét trên JSON THẬT lấy từ bản sao DB (xem db-fix/demo_chuoi_stage.sh query).
// Chạy: flutter test scratch/demo_insights_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/core/utils/chain_compare.dart';
import 'package:quannho_pos/core/utils/chain_insights.dart';

const _dir = '/private/tmp/claude-501/-Users-banhbao-Quan-Nho/df98e5d3-74fa-4f4d-ba97-04d7b7626014/scratchpad/fixtures';

ChainReport _load(String key) => ChainReport.fromJson(jsonDecode(File('$_dir/$key.json').readAsStringSync()) as Map);

void main() {
  test('nhận xét trên dữ liệu thật của bản sao', () {
    final out = StringBuffer();
    for (final p in ChainPeriod.values) {
      for (final off in [0, -1]) {
        final w = windowFor(p, off);
        final cur = _load('${p.name}_${off}_cur');
        final prev = File('$_dir/${p.name}_${off}_cmp.json').existsSync() ? _load('${p.name}_${off}_cmp') : null;
        final rows = buildRows(cur, prev);
        final an = analyzeStores(rows, cur, prev, w);
        final tot = prev == null ? null : analyzeChainTotals(an, prev);
        out.writeln('════ ${p.label} · ${w.label}  (so với ${w.compareLabel}${w.compareIsPartial ? ", cùng khoảng đã trôi" : ""})');
        out.writeln('  Tổng: ${cur.totals.orders} đơn, ${cur.totals.revenue.round()} đ'
            '${tot == null ? "" : "  → chip DT: ${tot.revenue.verdict.name} raw=${tot.revenue.rawPct?.toStringAsFixed(1)} band=${tot.revenue.band.toStringAsFixed(1)} loại=${tot.excludedNames.length} quán mới"}');
        for (final a in an) {
          out.writeln('  - ${a.row.name}: ${a.row.cur.orders} đơn, ngày bán ${a.activeDays}/${a.compareActiveDays}'
              ' → DT ${a.revenue.verdict.name} raw=${a.revenue.rawPct?.toStringAsFixed(1)} perDay=${a.revenue.perDayPct?.toStringAsFixed(1)} band=${a.revenue.band.toStringAsFixed(1)}'
              '${a.isNew ? " [QUÁN MỚI]" : ""}');
        }
        final ins = buildInsights(rows, cur, prev, w);
        if (ins.isEmpty) out.writeln('  (không có nhận xét)');
        for (final i in ins) {
          out.writeln('  [${i.kind.name}] ${i.text}');
          if (i.detail != null) out.writeln('        ↳ ${i.detail}');
        }
        out.writeln('');
      }
    }
    File('$_dir/insights_report.txt').writeAsStringSync(out.toString());
  });
}
