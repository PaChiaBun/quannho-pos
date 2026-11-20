// Bản xem thử màn Báo cáo chuỗi với DỮ LIỆU GIẢ (không nối Supabase, không đăng nhập).
// Chạy: flutter run -d web-server --web-port 8092 -t scratch/chain_report_preview.dart
import 'package:flutter/material.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/screens/chain_report_screen.dart';

const _stores = {
  'a1': ('KAY Rạch Giá', 'KAY1', 1.0),
  'a2': ('KAY Phú Quốc', 'KAY2', 0.62),
  'a3': ('KAY Cần Thơ', 'KAY3', 0.35),
};

String? _chainId;
final Set<String> _members = {};

Map<String, dynamic> _list() => {
  'success': true,
  'chains': _chainId == null
      ? []
      : [
          {
            'id': _chainId,
            'name': 'Chuỗi KAY',
            'stores': [
              for (final id in _members)
                {'store_id': id, 'name': _stores[id]!.$1, 'store_code': _stores[id]!.$2},
            ],
          },
        ],
  'owned_stores': [
    for (final e in _stores.entries)
      {
        'store_id': e.key,
        'name': e.value.$1,
        'store_code': e.value.$2,
        'chain_id': _members.contains(e.key) ? _chainId : null,
      },
  ],
};

// Tình huống mô phỏng (dữ liệu GIẢ) để xem các nhận xét hoạt động:
//  a1 Rạch Giá: quán chính, ổn định.  a2 Phú Quốc: nghỉ bán 2 ngày trong kỳ này + hủy món nhiều.
//  a3 Cần Thơ: quán mới mở cách đây 5 ngày.
final _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
final _firstOrder = {
  'a1': DateTime(2026, 6, 22, 8),
  'a2': DateTime(2026, 8, 1, 8),
  'a3': _today.subtract(const Duration(days: 5)).add(const Duration(hours: 9)),
};

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _report(DateTime from, DateTime to) {
  final isCurrent = to.isAfter(DateTime.now());
  final stores = <Map<String, dynamic>>[];
  final daily = <Map<String, dynamic>>[];
  double tRev = 0, tGross = 0, tCash = 0, tTr = 0, tCard = 0, tDisc = 0, tVoid = 0, tWallet = 0;
  int tOrders = 0, tVoidN = 0;
  for (final id in _members) {
    final s = _stores[id]!;
    double rev = 0, disc = 0;
    int orders = 0;
    final start = DateTime(from.year, from.month, from.day);
    for (var d = start; d.isBefore(to) && !d.isAfter(_today); d = DateTime(d.year, d.month, d.day + 1)) {
      final idx = d.difference(start).inDays;
      final first = _firstOrder[id]!;
      if (d.isBefore(DateTime(first.year, first.month, first.day))) continue; // chưa mở bán
      if (isCurrent && id == 'a2' && (idx == 2 || idx == 4) && d.isBefore(_today)) continue; // nghỉ bán
      final dow = d.weekday >= 6 ? 1.25 : 0.9;
      final wave = 0.9 + 0.2 * (((d.day * 37) + id.codeUnitAt(1) * 11) % 10) / 10;
      final base = id == 'a1' ? 110 : (id == 'a2' ? 62 : 22);
      final o = (base * dow * wave).round();
      final ticket = id == 'a1' ? 97000 : (id == 'a2' ? 88000 : 91000);
      final r = (o * ticket).toDouble();
      rev += r;
      orders += o;
      disc += r * (id == 'a3' ? 0.03 : 0.015);
      daily.add({'date': _ymd(d), 'store_id': id, 'orders': o, 'revenue': r});
    }
    final voidRate = id == 'a2' ? 0.075 : 0.028;
    final vAmt = (rev * voidRate).roundToDouble();
    final vN = orders == 0 ? 0 : (vAmt / 52000).round();
    final cash = rev * (id == 'a2' ? 0.3 : 0.5), card = rev * 0.05, wallet = rev * 0.01, tr = rev - cash - card - wallet;
    stores.add({
      'store_id': id, 'name': s.$1, 'store_code': s.$2, 'orders': orders, 'revenue': rev.roundToDouble(),
      'gross_revenue': (rev + disc).roundToDouble(),
      'avg_order_value': orders > 0 ? (rev / orders).roundToDouble() : 0,
      'cash_revenue': cash.roundToDouble(), 'transfer_revenue': tr.roundToDouble(),
      'card_revenue': card.roundToDouble(), 'wallet_revenue': wallet.roundToDouble(),
      'discount': disc.roundToDouble(), 'void_count': vN, 'void_amount': vAmt,
      'first_order_at': _firstOrder[id]!.toUtc().toIso8601String(),
    });
    tRev += rev; tGross += rev + disc; tCash += cash; tTr += tr; tCard += card; tWallet += wallet; tDisc += disc;
    tOrders += orders; tVoid += vAmt; tVoidN += vN;
  }
  stores.sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  return {
    'success': true,
    'chain': {'id': _chainId, 'name': 'Chuỗi KAY'},
    'stores': stores,
    'totals': {
      'orders': tOrders, 'revenue': tRev.roundToDouble(), 'gross_revenue': tGross.roundToDouble(),
      'avg_order_value': tOrders > 0 ? (tRev / tOrders).roundToDouble() : 0,
      'cash_revenue': tCash.roundToDouble(), 'transfer_revenue': tTr.roundToDouble(),
      'card_revenue': tCard.roundToDouble(), 'wallet_revenue': tWallet.roundToDouble(),
      'discount': tDisc.roundToDouble(), 'void_count': tVoidN, 'void_amount': tVoid,
      'store_count': _members.length,
    },
    'daily': daily,
    'excluded_stores': [],
  };
}

void main() {
  _chainId = 'c1';
  _members.addAll({'a1', 'a2', 'a3'});
  ChainRepository.rpcOverride = (fn, p) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    switch (fn) {
      case 'list_my_chains_v1':
        return _list();
      case 'create_store_chain_v1':
        _chainId = 'c2';
        return {'success': true, 'chain_id': _chainId};
      case 'add_store_to_chain_v1':
        _members.add(p['p_store'] as String);
        return {'success': true};
      case 'remove_store_from_chain_v1':
        _members.remove(p['p_store'] as String);
        return {'success': true};
      case 'get_chain_report_v1':
        return _report(DateTime.parse(p['p_from'] as String).toLocal(), DateTime.parse(p['p_to'] as String).toLocal());
    }
    return {'success': false, 'error': 'UNKNOWN'};
  };
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: ChainReportScreen(repository: ChainRepository())));
}
