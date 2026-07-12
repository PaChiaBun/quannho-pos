import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';

void main() {
  group('compareNatural tests', () {
    test('standard natural sorting of table names', () {
      expect(compareNatural('Bàn 2', 'Bàn 10'), lessThan(0));
      expect(compareNatural('Bàn 10', 'Bàn 2'), greaterThan(0));
      expect(compareNatural('Bàn 1', 'Bàn 1'), equals(0));
    });

    test('natural sorting with suffixes', () {
      expect(compareNatural('Bàn 2A', 'Bàn 2B'), lessThan(0));
      expect(compareNatural('Phòng VIP 1', 'Phòng VIP 2'), lessThan(0));
      expect(compareNatural('1', '10'), lessThan(0));
    });

    test('list sorting matches expectations', () {
      final list = ['Bàn 10', 'Bàn 2', 'Bàn 1', 'Bàn 11', 'Bàn 3'];
      list.sort(compareNatural);
      expect(list, equals(['Bàn 1', 'Bàn 2', 'Bàn 3', 'Bàn 10', 'Bàn 11']));
    });
  });
}
