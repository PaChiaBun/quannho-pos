#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import unittest

class TestBatchSoftDeleteRpc(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
        cls.migration_path = os.path.join(cls.repo_root, 'supabase/migrations/20260920_batch_soft_delete_products_rpc.sql')
        cls.repo_path = os.path.join(cls.repo_root, 'lib/core/repositories/core_product_repository.dart')
        cls.screen_path = os.path.join(cls.repo_root, 'lib/screens/inventory_screen.dart')

        with open(cls.migration_path, 'r', encoding='utf-8') as f:
            cls.migration_sql = f.read()

        with open(cls.repo_path, 'r', encoding='utf-8') as f:
            cls.repo_dart = f.read()

        with open(cls.screen_path, 'r', encoding='utf-8') as f:
            cls.screen_dart = f.read()

    def test_01_migration_file_structure(self):
        self.assertTrue(self.migration_sql.endswith('\n'), 'Migration must end with newline')
        dollars = self.migration_sql.count('66316')
        self.assertEqual(dollars % 2, 0, f'Unbalanced 66316: {dollars}')
        self.assertIn('CREATE OR REPLACE FUNCTION public.batch_soft_delete_products_v1', self.migration_sql)
        self.assertIn('p_store_id uuid', self.migration_sql)
        self.assertIn('p_product_ids uuid[]', self.migration_sql)
        self.assertIn('SECURITY DEFINER', self.migration_sql)
        self.assertIn('GRANT EXECUTE ON FUNCTION public.batch_soft_delete_products_v1', self.migration_sql)

    def test_02_migration_soft_delete_invariants(self):
        # Must be soft delete only: set is_deleted = true, is_active = false
        self.assertIn('is_deleted = true', self.migration_sql)
        self.assertIn('is_active = false', self.migration_sql)
        self.assertNotIn('DELETE FROM public.products', self.migration_sql)
        self.assertIn('id = ANY(p_product_ids)', self.migration_sql)
        self.assertIn('app_logs', self.migration_sql)

    def test_03_repository_rpc_and_chunking_fallback(self):
        # CoreProductRepository must call RPC first
        self.assertIn('batch_soft_delete_products_v1', self.repo_dart)
        self.assertIn('chunkSize = 15', self.repo_dart)
        self.assertIn(".inFilter('id', chunk)", self.repo_dart)

    def test_04_inventory_screen_sanitization(self):
        self.assertIn('_sanitizeErrorMessage', self.screen_dart)
        self.assertIn('<!DOCTYPE html>', self.screen_dart)
        self.assertIn('520', self.screen_dart)
        self.assertIn('Cloudflare', self.screen_dart)

if __name__ == '__main__':
    unittest.main()
