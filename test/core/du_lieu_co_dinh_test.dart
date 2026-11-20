// Bò Đen 12/11/2026: menu (38 món), ghi chú món, bàn (22), khu vực gần như không đổi nhưng bị
// tải lại 2.198 lần / 4 giờ tối (34 MB). Giờ tải một lần, máy chủ báo bảng đổi mới tải lại.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ban = File('lib/core/repositories/ban_repository.dart').readAsStringSync();
  final product = File('lib/core/repositories/core_product_repository.dart').readAsStringSync();
  final screen = File('lib/screens/ban_screen.dart').readAsStringSync();

  String body(String src, String start, String end) =>
      src.substring(src.indexOf(start), src.indexOf(end, src.indexOf(start)));

  test('khu vực và bàn: tải khi bảng đổi, không hỏi lại theo giờ', () {
    final zones = body(ban, 'Stream<List<BanZoneModel>> watchZones()', 'Future<List<BanZoneModel>> getZones()');
    expect(zones, contains("watchByRefetch(table: 'ban_zones'"));
    expect(zones, isNot(contains('Future.delayed')));
    final tables = body(ban, 'Stream<List<BanTableModel>> watchAllTables()', 'Future<void> upsertTable(');
    expect(tables, contains("table: 'ban_dining_tables'"));
    expect(tables, isNot(contains('Future.delayed')));
  });

  test('menu: tải khi bảng món đổi, bỏ vòng hỏi 15 giây', () {
    final watch = body(product, 'Stream<List<ProductModel>> watchAll()', 'static bool sameProductSnapshot(');
    expect(watch, contains("table: 'products'"));
    expect(watch, isNot(contains('Timer.periodic')));
  });

  test('ghi chú món: giữ suốt phiên, tải khi bảng đổi, có migration bật kênh đẩy', () {
    final p = body(screen, 'final storeModifiersProvider', 'Map<String, List<Map<String, dynamic>>> groupModifiersByProduct');
    expect(p, contains('StreamProvider<Map<String, List<Map<String, dynamic>>>>'));
    expect(p, isNot(contains('autoDispose')));
    expect(p, contains("table: 'product_modifiers'"));
    expect(
      File('supabase/migrations/20261113_realtime_product_modifiers.sql').readAsStringSync(),
      contains('ALTER PUBLICATION supabase_realtime ADD TABLE public.product_modifiers'),
    );
  });

  test('mở bàn: mã nhân viên tra 1 lần rồi nhớ, không tra lại mỗi lần mở bàn', () {
    final open = body(ban, 'Future<BanSessionModel> openSession(', "await _sb.from('ban_sessions').insert(");
    final hit = open.indexOf('waiterRecordId = _waiterIdCache[cacheKey];');
    expect(hit, greaterThan(-1));
    expect(hit, lessThan(open.indexOf(".from('staff_members')")));
    expect(open, contains('&& waiterRecordId == null'));
    expect(open, contains('_waiterIdCache[cacheKey] = waiterRecordId;'));
  });
}
