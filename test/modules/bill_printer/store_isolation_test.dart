import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/models/bill_block.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/utils/template_cache_policy.dart';

String tpl(String store, {String? mark}) => jsonEncode({
      'paper': '58mm',
      'blocks': [{'mark': mark ?? store}],
      if (store.isNotEmpty) 'store': store,
    });

void main() {
  group('resolveTemplateJson: không lấy nhầm mẫu của quán khác', () {
    test('server có mẫu của quán -> dùng bản server', () {
      final out = resolveTemplateJson(
        storeId: 'BO_DEN', cloudJson: '{"cloud":1}', cloudReachable: true, localJson: tpl('KAY'));
      expect(out, '{"cloud":1}');
    });

    test('ca lỗi gốc: quán mới chưa có mẫu trên server, máy còn mẫu của KAY -> mặc định (null)', () {
      expect(resolveTemplateJson(
        storeId: 'BO_DEN', cloudJson: null, cloudReachable: true, localJson: tpl('KAY')), isNull);
    });

    test('bản cũ chưa có nhãn quán, server truy vấn được mà không có mẫu -> bỏ (không biết của quán nào)', () {
      expect(resolveTemplateJson(
        storeId: 'BO_DEN', cloudJson: null, cloudReachable: true, localJson: tpl('')), isNull);
    });

    test('bản trên máy đúng quán, server không có -> giữ bản trên máy', () {
      final local = tpl('BO_DEN');
      expect(resolveTemplateJson(
        storeId: 'BO_DEN', cloudJson: null, cloudReachable: true, localJson: local), local);
    });

    test('mất mạng: bản đúng quán hoặc bản cũ không nhãn vẫn dùng được; bản quán khác thì bỏ', () {
      final own = tpl('KAY');
      final legacy = tpl('');
      expect(resolveTemplateJson(storeId: 'KAY', cloudReachable: false, localJson: own), own);
      expect(resolveTemplateJson(storeId: 'KAY', cloudReachable: false, localJson: legacy), legacy);
      expect(resolveTemplateJson(storeId: 'BO_DEN', cloudReachable: false, localJson: own), isNull);
    });

    test('không có bản lưu nào -> null', () {
      expect(resolveTemplateJson(storeId: 'X', cloudReachable: true), isNull);
      expect(resolveTemplateJson(storeId: 'X', cloudReachable: false), isNull);
    });
  });

  test('stampTemplateJson gắn nhãn quán và giữ nguyên nội dung', () {
    final stamped = stampTemplateJson(jsonEncode({'paper': '80mm', 'blocks': []}), 'KAY');
    final m = jsonDecode(stamped) as Map;
    expect(m['store'], 'KAY');
    expect(m['paper'], '80mm');
    expect(stampTemplateJson('không phải json', 'KAY'), 'không phải json');
  });

  test('profileJsonBelongsToOtherStore', () {
    expect(profileJsonBelongsToOtherStore(jsonEncode({'storeId': 'KAY'}), 'BO_DEN'), isTrue);
    expect(profileJsonBelongsToOtherStore(jsonEncode({'storeId': 'KAY'}), 'KAY'), isFalse);
    // bản cũ chưa có nhãn: tương thích ngược
    expect(profileJsonBelongsToOtherStore(jsonEncode({'cashier': {}}), 'KAY'), isFalse);
    expect(profileJsonBelongsToOtherStore('hỏng', 'KAY'), isFalse);
  });

  test('mẫu số / ký hiệu hóa đơn mặc định để trống (không dùng số của KAY)', () {
    final cfg = BillBlockType.taxInfo.defaultConfig;
    expect(cfg['invoicePattern'], '');
    expect(cfg['invoiceSerial'], '');
  });
}
