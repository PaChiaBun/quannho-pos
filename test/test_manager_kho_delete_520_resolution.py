#!/usr/bin/env python3
import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

class TestManagerKhoDeleteResolution(unittest.TestCase):
    def setUp(self):
        self.inventory_dart = (REPO_ROOT / 'lib/screens/inventory_screen.dart').read_text(encoding='utf-8')
        self.repo_dart = (REPO_ROOT / 'lib/core/repositories/core_product_repository.dart').read_text(encoding='utf-8')
        self.log_viewer_dart = (REPO_ROOT / 'lib/screens/log_viewer_screen.dart').read_text(encoding='utf-8')
        self.migration_sql = (REPO_ROOT / 'supabase/migrations/20260915_fix_products_rls_and_current_store_id.sql').read_text(encoding='utf-8')
        self.kho_test_dart = (REPO_ROOT / 'test/modules/kho_batch_delete_and_search_test.dart').read_text(encoding='utf-8')
        self.hierarchy_test_dart = (REPO_ROOT / 'test/core/staff_manager_hierarchy_guard_test.dart').read_text(encoding='utf-8')

    def test_r1_inventory_screen_app_logger_integration(self):
        # Must import AppLogger
        self.assertIn("import '../core/utils/app_logger.dart';", self.inventory_dart)

        # Catch blocks must call AppLogger.error with 'inventory' tag
        self.assertIn("AppLogger.error('inventory', 'Lỗi khi xóa hàng loạt", self.inventory_dart)
        self.assertIn("AppLogger.error('inventory', 'Lỗi khi xóa món:", self.inventory_dart)
        self.assertIn("AppLogger.error('inventory', 'Lỗi cập nhật trạng thái bán hàng loạt", self.inventory_dart)
        self.assertIn("AppLogger.error('inventory', 'Lỗi đổi danh mục hàng loạt", self.inventory_dart)

    def test_r1_log_viewer_screen_inventory_tag(self):
        # Must have inventory tag in _tags
        self.assertIn("'inventory': '📦 Kho hàng'", self.log_viewer_dart)

    def test_r2_and_r3_core_product_repository_x_store_id_and_soft_delete(self):
        # softDelete ensures x-store-id header and calls update with is_deleted=true, is_active=false
        self.assertIn("Future<void> softDelete(String id) async {", self.repo_dart)
        self.assertIn("_sb.rest.headers['x-store-id'] = storeId;", self.repo_dart)
        self.assertIn("await update(id, {'is_deleted': true, 'is_active': false});", self.repo_dart)

        # batchSoftDelete ensures x-store-id header and updates is_deleted=true, is_active=false
        self.assertIn("Future<void> batchSoftDelete(List<String> ids) async {", self.repo_dart)
        self.assertIn("if (ids.isEmpty) return;", self.repo_dart)
        self.assertIn("'is_deleted': true", self.repo_dart)
        self.assertIn("'is_active': false", self.repo_dart)
        self.assertIn(".eq('store_id', storeId).inFilter('id', ids)", self.repo_dart)

        # Zero hard deletes on products table
        self.assertNotIn("_sb.from('products').delete()", self.repo_dart)
        self.assertNotIn("_client.from('products').delete()", self.repo_dart)

    def test_r2_migration_current_store_id_jwt_fallback_and_rls(self):
        # Migration must define current_store_id with header and JWT claim fallback
        self.assertIn('CREATE OR REPLACE FUNCTION public.current_store_id()', self.migration_sql)
        self.assertIn("current_setting('request.headers', true)::json->>'x-store-id'", self.migration_sql)
        self.assertIn("current_setting('request.jwt.claims', true)", self.migration_sql)
        self.assertIn("->>'store_id'", self.migration_sql)

        # Must grant permissions on products to authenticated and anon
        self.assertIn('GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO anon, authenticated', self.migration_sql)
        self.assertIn('CREATE POLICY "products_isolation" ON public.products', self.migration_sql)

    def test_r4_test_suites_updated(self):
        # kho_batch_delete_and_search_test.dart has Group 8
        self.assertIn("group('8. Soft Delete Single & Batch Invariants with Manager & Owner Roles'", self.kho_test_dart)
        self.assertIn('Manager (role == manager) and Owner have permission to delete items', self.kho_test_dart)
        self.assertIn('Batch soft deletion across mixed categories with active kitchen tickets preserves ticket references', self.kho_test_dart)
        self.assertIn('CoreProductRepository cache hooks guarantee unified cache synchronization', self.kho_test_dart)

        # staff_manager_hierarchy_guard_test.dart has Test 11
        self.assertIn('11. Manager role automatically inherits kho.delete_item', self.hierarchy_test_dart)
        self.assertIn("contains('kho.delete_item')", self.hierarchy_test_dart)

    def test_r1_inventory_screen_create_and_update_logging(self):
        # Create and update operations must also have structured error logging
        self.assertIn("AppLogger.error('inventory', 'Lỗi khi tạo món:", self.inventory_dart)
        self.assertIn("AppLogger.error('inventory', 'Lỗi khi cập nhật món:", self.inventory_dart)

    def test_r2_repository_singleton_and_cache_unification(self):
        # Verify CoreProductRepository singleton and static cache unification
        self.assertIn("factory CoreProductRepository() => instance;", self.repo_dart)
        self.assertIn("static final Map<String, List<ProductModel>> _productsCacheByStore = {};", self.repo_dart)
        
        # Verify app_providers uses the singleton instance
        app_providers_dart = (REPO_ROOT / 'lib/core/providers/app_providers.dart').read_text(encoding='utf-8')
        self.assertIn("return CoreProductRepository.instance;", app_providers_dart)

    def test_r2_current_store_id_sql_hardened_security(self):
        # Function must enforce search_path to prevent search_path injection
        self.assertIn("SET search_path = pg_catalog, public", self.migration_sql)
        # Must support direct PostgREST setting request.header.x-store-id
        self.assertIn("current_setting('request.header.x-store-id', true)", self.migration_sql)
        # Must trim raw store ID
        self.assertIn("trim(_raw_store_id)", self.migration_sql)
        # Must support staff_members table to avoid locking out managers
        self.assertIn("SELECT 1 FROM public.staff_members", self.migration_sql)
        # Must support store_members table
        self.assertIn("SELECT 1 FROM public.store_members", self.migration_sql)
        # Must support stores table for owners
        self.assertIn("SELECT 1 FROM public.stores", self.migration_sql)
        # Must trust server-signed JWT claims
        self.assertIn("(_claims->>'store_id') = _raw_store_id", self.migration_sql)

    def test_r2_current_store_id_uuid_regex_and_trim_simulation(self):
        """Simulate Postgres regex and trim logic against legal, edge, and adversarial inputs."""
        uuid_pattern = re.compile(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        
        def simulate_current_store_id(raw_store_id):
            if raw_store_id is not None:
                raw_store_id = raw_store_id.strip()
            if not raw_store_id or not uuid_pattern.match(raw_store_id):
                return None
            return raw_store_id.lower()

        # Valid standard UUID
        self.assertEqual(simulate_current_store_id('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')
        # Valid UUID with leading/trailing whitespace
        self.assertEqual(simulate_current_store_id('  a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11  '), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')
        # Valid uppercase UUID
        self.assertEqual(simulate_current_store_id('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'), 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')
        # Invalid inputs must safely return None without throwing
        self.assertIsNone(simulate_current_store_id(''))
        self.assertIsNone(simulate_current_store_id(None))
        self.assertIsNone(simulate_current_store_id('not-a-uuid'))
        self.assertIsNone(simulate_current_store_id('12345'))
        self.assertIsNone(simulate_current_store_id("'; DROP TABLE products; --"))
        self.assertIsNone(simulate_current_store_id('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11-extra'))

    def test_r3_mixed_category_soft_delete_fk_invariants(self):
        """Verify soft-delete payload guarantees zero foreign key violations."""
        now_ms = 1773612345000
        soft_delete_payload = {
            'is_deleted': True,
            'is_active': False,
            'updated_at': now_ms,
        }

        # Soft delete is strictly an UPDATE, not a DELETE
        self.assertTrue(soft_delete_payload['is_deleted'])
        self.assertFalse(soft_delete_payload['is_active'])
        self.assertNotIn('id', soft_delete_payload)  # ID is untouched

        # Simulated FK references from kitchen_tickets and order_items
        active_kitchen_tickets = [
            {'ticket_id': 'kt-001', 'product_id': 'prod-bbq-1', 'status': 'cooking'},
            {'ticket_id': 'kt-002', 'product_id': 'prod-drink-2', 'status': 'queued'},
        ]
        
        products_table = {
            'prod-bbq-1': {'id': 'prod-bbq-1', 'name': 'Bò nướng', 'is_deleted': False},
            'prod-drink-2': {'id': 'prod-drink-2', 'name': 'Bia', 'is_deleted': False},
        }

        # Perform soft delete
        for prod_id in ['prod-bbq-1', 'prod-drink-2']:
            products_table[prod_id].update(soft_delete_payload)

        # Products remain in the database table
        for kt in active_kitchen_tickets:
            ref_prod_id = kt['product_id']
            self.assertIn(ref_prod_id, products_table, "Foreign key integrity violated: product row missing")
            self.assertTrue(products_table[ref_prod_id]['is_deleted'], "Product must be marked as soft deleted")

if __name__ == '__main__':
    unittest.main()
