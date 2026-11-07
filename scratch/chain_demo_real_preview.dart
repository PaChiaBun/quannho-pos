// Bản xem thử màn Báo cáo chuỗi với JSON THẬT của RPC chạy trên bản sao DB demo (không nối Supabase, không đăng nhập).
// Tạo dữ liệu: db-fix/demo_chuoi_stage.sh up|query → scratch/demo_fixtures.dart. Chạy:
//   flutter run -d web-server --web-port 8093 -t scratch/chain_demo_real_preview.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/screens/chain_report_screen.dart';

import 'demo_fixtures.dart';

void main() {
  ChainRepository.rpcOverride = (fn, p) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (fn == 'list_my_chains_v1') return jsonDecode(kDemoList);
    if (fn == 'get_chain_report_v1') {
      // Khớp theo p_from rồi lấy bản có p_to gần nhất (p_to của kỳ đang diễn ra phụ thuộc giờ bấm).
      final list = kDemoReports[p['p_from']];
      if (list == null) return {'success': false, 'error': 'INVALID_RANGE'}; // ngoài các kỳ đã lấy mẫu
      final want = DateTime.parse(p['p_to'] as String);
      final best = ([...list]..sort((a, b) => DateTime.parse(a.$1).difference(want).abs().compareTo(DateTime.parse(b.$1).difference(want).abs()))).first;
      final raw = best.$2;
      return jsonDecode(raw);
    }
    return {'success': false, 'error': 'UNKNOWN'};
  };
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: ChainReportScreen(repository: ChainRepository())));
}
