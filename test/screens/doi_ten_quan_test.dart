// Đổi tên quán (04/11/2026): bút chì ở Cài đặt chỉ ghi shop_name nên Trang chủ không đổi; hoá đơn bàn đọc khoá
// info['name'] không tồn tại nên luôn in "QUÁN NHỎ POS"; quán chưa sửa tên thì hoá đơn quầy in "Quán Nhỏ".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';

void main() {
  test('tên trên hoá đơn: tên đã sửa → tên quán → mặc định', () {
    expect(chonTenQuan('Quán Cây', 'KAY'), 'Quán Cây');
    expect(chonTenQuan(null, 'KAY'), 'KAY');
    expect(chonTenQuan('  ', 'KAY'), 'KAY');
    expect(chonTenQuan(null, null), 'Quán Nhỏ');
    expect(chonTenQuan('', ' '), 'Quán Nhỏ');
  });

  test('hoá đơn bàn đọc đúng khoá getStoreInfo', () {
    final s = File('lib/screens/ban_screen.dart').readAsStringSync();
    expect(RegExp(r"[iI]nfo\['name'\]").hasMatch(s), isFalse);
    expect("info['store_name']".allMatches(s).length, greaterThanOrEqualTo(2));
    expect("storeInfo['store_name']".allMatches(s).length, greaterThanOrEqualTo(2));
    expect(
      File('lib/core/services/store_auth_service.dart').readAsStringSync(),
      contains("'store_name': storeName"),
    );
  });

  test('bút chì đổi cả bảng quán, kiểm có dòng được ghi, chỉ Chủ quán thấy', () {
    final repo = File('lib/core/repositories/module_repository.dart').readAsStringSync();
    expect(repo, contains(".from('stores')\n        .update({'name': name})"));
    expect(repo, contains('rows.isEmpty'));
    final st = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(st, contains('renameStore(name)'));
    expect(st, contains('updateStoreName(name)'));
    expect(st, contains("if (session?.isOwner == true) ...["));
    expect(st, isNot(contains(".set('shop_name', name)")));
  });
}
