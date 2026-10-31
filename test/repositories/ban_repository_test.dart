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

    test('BanZoneModel reordering maintains sort order integrity', () {
      final zoneA = BanZoneModel(
        id: 'z-a',
        storeId: 's1',
        name: 'Khu A',
        colorValue: 0xFF112233,
        iconCode: 0xe123,
        sortOrder: 2,
        isActive: true,
      );
      final zoneB = BanZoneModel(
        id: 'z-b',
        storeId: 's1',
        name: 'Khu B',
        colorValue: 0xFF445566,
        iconCode: 0xe124,
        sortOrder: 1,
        isActive: true,
      );
      final zoneC = BanZoneModel(
        id: 'z-c',
        storeId: 's1',
        name: 'Khu C',
        colorValue: 0xFF778899,
        iconCode: 0xe125,
        sortOrder: 0,
        isActive: true,
      );

      final zones = [zoneA, zoneB, zoneC];
      // Initial sort: Khu C (0), Khu B (1), Khu A (2)
      zones.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(zones.map((z) => z.name).toList(), ['Khu C', 'Khu B', 'Khu A']);

      // Reorder: Move Khu C to position 2
      final reordered = List<BanZoneModel>.from(zones);
      final moved = reordered.removeAt(0);
      reordered.insert(2, moved);
      expect(reordered.map((z) => z.name).toList(), ['Khu B', 'Khu A', 'Khu C']);
    });
  });
}
