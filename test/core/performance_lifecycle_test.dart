import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';
import 'package:quannho_pos/core/widgets/active_module_host.dart';
import 'package:quannho_pos/modules/pos/providers/pos_providers.dart';

void main() {
  group('ActiveModuleHost', () {
    testWidgets('chỉ mount module đang active và dispose module khi rời tab', (
      tester,
    ) async {
      final mounted = <int>[];
      final disposed = <int>[];
      final modules = [
        _LifecycleProbe(0, mounted: mounted, disposed: disposed),
        _LifecycleProbe(1, mounted: mounted, disposed: disposed),
      ];

      await tester.pumpWidget(
        MaterialApp(home: ActiveModuleHost(index: 0, modules: modules)),
      );
      expect(mounted, [0]);
      expect(find.text('module-1'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(home: ActiveModuleHost(index: 1, modules: modules)),
      );
      await tester.pump();

      expect(mounted, [0, 1]);
      expect(disposed, [0]);
      expect(find.text('module-0'), findsNothing);
      expect(find.text('module-1'), findsOneWidget);
    });
  });

  group('CoreProductRepository snapshot deduplication', () {
    test('snapshot giống nhau không bị xem là dữ liệu mới', () {
      final first = [_product(name: 'Cà phê')];
      final same = [_product(name: 'Cà phê')];

      expect(CoreProductRepository.sameProductSnapshot(first, same), isTrue);
    });

    test('thay đổi nghiệp vụ sản phẩm vẫn phát snapshot mới', () {
      final first = [_product(name: 'Cà phê', stockQty: 10)];
      final changed = [_product(name: 'Cà phê', stockQty: 9)];

      expect(
        CoreProductRepository.sameProductSnapshot(first, changed),
        isFalse,
      );
    });
  });

  group('POS kitchen session lifecycle', () {
    test('phiên bếp được giữ trong cart state và không bị ghi đè', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addKitchenSession('session-1');
      notifier.addKitchenSession('session-2');
      notifier.addKitchenSession('session-1');

      expect(
        container.read(cartProvider).kitchenSessionIds,
        {'session-1', 'session-2'},
      );
    });

    test('xóa giỏ hàng cũng xóa các phiên bếp đã gắn', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addKitchenSession('session-1');
      notifier.clearCart();

      expect(container.read(cartProvider).kitchenSessionIds, isEmpty);
    });
  });
}

ProductModel _product({required String name, double stockQty = 10}) {
  return ProductModel(
    id: 'product-1',
    storeId: 'store-1',
    name: name,
    unit: 'ly',
    productType: 'finished',
    stockQty: stockQty,
    minStock: 2,
    sellPrice: 25000,
    costPrice: 10000,
    stationCode: 'nuoc',
    isAvailable: true,
    isActive: true,
    isDeleted: false,
  );
}

class _LifecycleProbe extends StatefulWidget {
  final int id;
  final List<int> mounted;
  final List<int> disposed;

  const _LifecycleProbe(
    this.id, {
    required this.mounted,
    required this.disposed,
  });

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.mounted.add(widget.id);
  }

  @override
  void dispose() {
    widget.disposed.add(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('module-${widget.id}');
}
