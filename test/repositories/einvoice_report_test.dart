import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/einvoice_repository.dart';

void main() {
  group('EinvoiceReport', () {
    test('parse đầy đủ các trường từ RPC', () {
      final r = EinvoiceReport.fromJson({
        'enabled': true,
        'issued_amount': 1500000,
        'issued_count': 12,
        'pending_amount': 200000.5,
        'pending_count': 2,
        'problem_amount': 50000,
        'problem_count': 1,
        'cancelled_amount': 0,
        'cancelled_count': 0,
      });
      expect(r.enabled, isTrue);
      expect(r.issuedAmount, 1500000);
      expect(r.issuedCount, 12);
      expect(r.pendingAmount, 200000.5);
      expect(r.problemCount, 1);
    });

    test('thiếu trường hoặc null thì về 0 và tắt, không văng lỗi', () {
      final r = EinvoiceReport.fromJson({'issued_amount': null});
      expect(r.enabled, isFalse);
      expect(r.issuedAmount, 0);
      expect(r.issuedCount, 0);
    });

    test('doanh thu chưa có hóa đơn không âm', () {
      const r = EinvoiceReport(issuedAmount: 500);
      expect(r.uninvoicedFrom(1500), 1000);
      expect(r.uninvoicedFrom(300), 0);
    });
  });
}
