import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/kho/repository/kho_repository.dart';

void main() {
  group('PurchaseOrderModel & PurchaseItemModel Tests', () {
    test('fromMap reads total_amount when total_amount is present', () {
      final map = {
        'id': 'po-123',
        'po_number': 'PO-20261001-001',
        'supplier_id': 'sup-1',
        'supplier_name': 'Nha Cung Cap A',
        'status': 'received',
        'total_amount': 250000,
        'note': 'Ghi chu 1',
        'created_at': '2026-10-01T10:00:00Z',
        'invoice_image_url': 'https://example.com/inv.jpg',
      };

      final po = PurchaseOrderModel.fromMap(map);

      expect(po.id, 'po-123');
      expect(po.poNumber, 'PO-20261001-001');
      expect(po.supplierName, 'Nha Cung Cap A');
      expect(po.totalAmount, 250000.0);
      expect(po.invoiceImageUrl, 'https://example.com/inv.jpg');
    });

    test('fromMap falls back to total_cost when total_amount is null or absent (legacy DB schema)', () {
      final map = {
        'id': 'po-legacy-456',
        'po_number': 'PO-LEGACY-002',
        'supplier_id': 'sup-2',
        'supplier_name': 'Nha Cung Cap B',
        'status': 'received',
        'total_cost': 450000,
        'note': 'Phieu nhap cu',
        'created_at': '2026-09-01T10:00:00Z',
      };

      final po = PurchaseOrderModel.fromMap(map);

      expect(po.id, 'po-legacy-456');
      expect(po.totalAmount, 450000.0);
    });

    test('fromMap prioritizes total_amount over total_cost when both are present', () {
      final map = {
        'id': 'po-dual-789',
        'po_number': 'PO-DUAL-003',
        'total_cost': 300000,
        'total_amount': 350000,
      };

      final po = PurchaseOrderModel.fromMap(map);

      expect(po.totalAmount, 350000.0);
    });

    test('fromMap defaults to 0.0 when neither total_amount nor total_cost is provided', () {
      final map = {
        'id': 'po-empty-000',
      };

      final po = PurchaseOrderModel.fromMap(map);

      expect(po.totalAmount, 0.0);
    });

    test('fromMap parses prebuilt items correctly', () {
      final items = [
        const PurchaseItemModel(
          id: 'item-1',
          productId: 'prod-1',
          productName: 'Bo My',
          quantity: 5.0,
          unitCost: 100000.0,
          subtotal: 500000.0,
        ),
      ];

      final map = {
        'id': 'po-with-items',
        'total_amount': 500000,
        '__items': items,
      };

      final po = PurchaseOrderModel.fromMap(map);

      expect(po.items.length, 1);
      expect(po.items.first.productName, 'Bo My');
      expect(po.items.first.quantity, 5.0);
      expect(po.items.first.unitCost, 100000.0);
      expect(po.items.first.subtotal, 500000.0);
    });
  });
}
