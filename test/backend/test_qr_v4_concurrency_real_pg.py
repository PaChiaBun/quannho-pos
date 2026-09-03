#!/usr/bin/env python3
"""
Comprehensive Multi-Connection Real PostgreSQL Concurrency Test Harness for QR Order V4 (Quán Nhỏ POS)
Target: Real Staging PostgreSQL Database with 2+ Independent Client Connections & Synchronization Barrier.
Verifies all 10 Race Conditions & Zero Orphan Side-Effects for Losing Transactions across 13 Tables.
"""

import os
import sys
import unittest
import threading
import uuid
import hashlib
import json
import urllib.parse
from typing import Optional, Dict, Any, List

class TestQrV4RealPostgresConcurrency(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 1. ONLY read STAGING_DATABASE_URL (Strictly no fallback to DATABASE_URL)
        cls.db_url = os.environ.get("STAGING_DATABASE_URL")
        allow_mutation = os.environ.get("QR_V4_ALLOW_STAGING_MUTATION", "").strip().upper()

        if not cls.db_url or allow_mutation != "YES":
            raise unittest.SkipTest(
                "REAL_POSTGRES_CONCURRENCY: BLOCKED_NOT_EXECUTED\n"
                "To execute this test harness against a real staging PostgreSQL database, you must set:\n"
                "  export STAGING_DATABASE_URL=\"postgresql://user:pass@host:port/dbname\"\n"
                "  export QR_V4_ALLOW_STAGING_MUTATION=YES\n"
                "  python3 -m unittest test.backend.test_qr_v4_concurrency_real_pg"
            )

        # 2. Safety check: Block execution against production targets
        parsed = urllib.parse.urlparse(cls.db_url)
        host = parsed.hostname or ""
        dbname = parsed.path.lstrip("/")
        port = parsed.port or 5432

        # Sanitize target printout (NO credentials printed)
        sanitized_target = f"postgresql://***:***@{host}:{port}/{dbname}"
        print(f"\n[Real PG Test Harness] Target Database: {sanitized_target}")

        if any(prod_word in host.lower() or prod_word in dbname.lower() for prod_word in ["prod", "production", "quannho-db.lpm.vn"]):
            raise ValueError(f"FATAL: Target database {sanitized_target} appears to be PRODUCTION! Aborting.")

        try:
            import psycopg2
            import psycopg2.extras
            cls.psycopg2 = psycopg2
            cls.psycopg2_extras = psycopg2.extras
            # Test connectivity
            conn = psycopg2.connect(cls.db_url, connect_timeout=5)
            conn.close()
        except ImportError:
            raise unittest.SkipTest("REAL_POSTGRES_CONCURRENCY: BLOCKED_NOT_EXECUTED (psycopg2 module not installed in current python environment)")
        except Exception as e:
            raise unittest.SkipTest(f"REAL_POSTGRES_CONCURRENCY: BLOCKED_NOT_EXECUTED (Cannot connect to staging PostgreSQL: {e})")

        # Global Setup: Create isolated test store and fixtures with autocommit=True
        cls.store_id = str(uuid.uuid4())
        cls.owner_uid = str(uuid.uuid4())
        cls.cashier_uid = str(uuid.uuid4())
        cls.waiter_uid = str(uuid.uuid4())
        cls.customer_uid = str(uuid.uuid4())

        cls.prod_food_id = str(uuid.uuid4())
        cls.prod_drink_id = str(uuid.uuid4())
        cls.prod_topping_id = str(uuid.uuid4())

        conn = cls.psycopg2.connect(cls.db_url)
        conn.autocommit = True
        cur = conn.cursor()

        try:
            # 1. Store
            cur.execute(
                "INSERT INTO public.stores (id, name, created_at) VALUES (%s, %s, now());",
                (cls.store_id, f"Test Store Real PG {cls.store_id[:8]}")
            )

            # 2. Users & Members
            for uid, phone, name, role in [
                (cls.owner_uid, f"09{cls.owner_uid[:8]}", "Owner Real PG", "owner"),
                (cls.cashier_uid, f"09{cls.cashier_uid[:8]}", "Cashier Real PG", "cashier"),
                (cls.waiter_uid, f"09{cls.waiter_uid[:8]}", "Waiter Real PG", "waiter"),
            ]:
                cur.execute(
                    "INSERT INTO public.user_accounts (id, phone, display_name) VALUES (%s, %s, %s);",
                    (uid, phone, name)
                )
                cur.execute(
                    "INSERT INTO public.store_members (id, store_id, user_id, role, created_at) VALUES (%s, %s, %s, %s, now());",
                    (str(uuid.uuid4()), cls.store_id, uid, role)
                )

            # 3. App Settings
            cur.execute(
                "INSERT INTO public.app_settings (id, store_id, key, value) VALUES (%s, %s, %s, %s);",
                (str(uuid.uuid4()), cls.store_id, "action_perms_cashier", '["pos.checkout"]')
            )
            cur.execute(
                "INSERT INTO public.app_settings (id, store_id, key, value) VALUES (%s, %s, %s, %s);",
                (str(uuid.uuid4()), cls.store_id, "loyalty_rate", "10000")
            )
            cur.execute(
                "INSERT INTO public.app_settings (id, store_id, key, value) VALUES (%s, %s, %s, %s);",
                (str(uuid.uuid4()), cls.store_id, "loyalty_redeem_rate", "1000")
            )

            # 4. Customer
            cur.execute(
                "INSERT INTO public.customers (id, store_id, name, phone, loyalty_pts, total_spent, visit_count) VALUES (%s, %s, %s, %s, 10, 100000, 2);",
                (cls.customer_uid, cls.store_id, "Customer Test PG", f"08{cls.customer_uid[:8]}")
            )

            # 5. Products
            cur.execute(
                "INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);",
                (cls.prod_food_id, cls.store_id, "Mì Xào Bò", "Món Chính", 60000, 25000, 100, False, True, False)
            )
            cur.execute(
                "INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);",
                (cls.prod_drink_id, cls.store_id, "Trà Đào", "Đồ uống", 30000, 10000, 100, False, True, False)
            )
            cur.execute(
                "INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);",
                (cls.prod_topping_id, cls.store_id, "Thạch Đào", "Topping", 8000, 2000, 200, True, True, False)
            )
            cur.execute(
                "INSERT INTO public.product_topping_links (store_id, product_id, topping_id, created_at) VALUES (%s, %s, %s, now());",
                (cls.store_id, cls.prod_drink_id, cls.prod_topping_id)
            )

            # 6. Coupons
            cur.execute("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons');")
            if cur.fetchone()[0]:
                cur.execute(
                    "INSERT INTO public.coupons (id, store_id, code, discount_type, value, min_order_amount, is_active, created_at) VALUES (%s, %s, %s, %s, %s, %s, true, now());",
                    (str(uuid.uuid4()), cls.store_id, "VOUCHER20K", "fixed", 18000, 50000)
                )
        finally:
            cur.close()
            conn.close()

    @classmethod
    def tearDownClass(cls):
        if not hasattr(cls, "db_url") or not cls.db_url:
            return
        try:
            conn = cls.psycopg2.connect(cls.db_url)
            conn.autocommit = True
            cur = conn.cursor()
            # Clean up only store fixtures generated by this test
            cur.execute("DELETE FROM public.stores WHERE id = %s;", (cls.store_id,))
            for uid in [cls.owner_uid, cls.cashier_uid, cls.waiter_uid]:
                cur.execute("DELETE FROM public.user_accounts WHERE id = %s;", (uid,))
            cur.close()
            conn.close()
        except Exception as e:
            sys.stderr.write(f"[Teardown Warning] Failed to clean test fixtures: {e}\n")

    def get_fixture_conn(self, user_uid: Optional[str] = None):
        """Helper to create a dedicated fixture connection with autocommit=True and asserted auth.uid()."""
        conn = self.psycopg2.connect(self.db_url)
        conn.autocommit = True
        if user_uid:
            cur = conn.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (user_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            self.assertEqual(str(claim), str(user_uid), f"Session auth.uid() must match {user_uid}")
            cur.close()
        return conn

    def snapshot_counts(self, conn, store_id: str) -> Dict[str, int]:
        """Snapshot exact row counts across all 13 transaction and side-effect tables for zero-orphan assertions. Fails loudly on DB errors."""
        cur = conn.cursor()
        tables = [
            ('orders', 'store_id'),
            ('order_items', 'store_id'),
            ('qr_payment_idempotency', 'store_id'),
            ('qr_kitchen_idempotency', 'store_id'),
            ('kitchen_tickets', 'store_id'),
            ('kitchen_ticket_items', None),
            ('payment_settlements', 'store_id'),
            ('finance_records', 'store_id'),
            ('stock_movements', 'store_id'),
            ('loyalty_transactions', 'store_id'),
            ('qr_coupon_redemptions', 'store_id'),
            ('ban_session_orders', 'store_id'),
            ('ban_session_order_items', 'store_id'),
        ]
        counts = {}
        for tbl, store_col in tables:
            if store_col:
                cur.execute(f"SELECT count(*) FROM public.{tbl} WHERE {store_col} = %s;", (store_id,))
            else:
                cur.execute(f"SELECT count(*) FROM public.{tbl} kti JOIN public.kitchen_tickets kt ON kt.id = kti.ticket_id WHERE kt.store_id = %s;", (store_id,))
            counts[tbl] = cur.fetchone()[0]
        cur.close()
        return counts

    def test_00_smoke_environment_and_fixtures(self):
        """Smoke Test: Verify DB objects, function signatures, cross-connection reads, and auth.uid()."""
        conn1 = self.get_fixture_conn(self.owner_uid)
        conn2 = self.get_fixture_conn(self.waiter_uid)
        cur1 = conn1.cursor()
        cur2 = conn2.cursor()
        try:
            required_tables = [
                'qr_channels', 'qr_requests', 'qr_request_items', 'qr_handoff_tokens',
                'qr_audit_logs', 'product_topping_links', 'qr_payment_idempotency',
                'qr_kitchen_idempotency', 'ban_session_orders', 'ban_session_order_items',
                'payment_settlements', 'qr_coupon_redemptions'
            ]
            for tbl in required_tables:
                cur1.execute("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = %s);", (tbl,))
                self.assertTrue(cur1.fetchone()[0], f"Table {tbl} must exist in public schema")

            required_funcs = [
                'verify_staff_qr_membership_v4', 'get_qr_channel_info_v4', 'get_qr_menu_v4',
                'submit_qr_order_v4', 'get_qr_request_status_v4', 'regenerate_handoff_token_v4',
                'claim_qr_handoff_v4', 'get_qr_request_detail_v4', 'update_qr_order_items_v4',
                'assign_qr_order_table_v4', 'mark_qr_order_paid_v4', 'send_qr_order_to_kitchen_v4',
                'settle_ban_session_v4', 'cancel_qr_order_v4', 'manage_qr_channel_v4'
            ]
            for fn in required_funcs:
                cur1.execute("SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = %s);", (fn,))
                self.assertTrue(cur1.fetchone()[0], f"Function {fn} must exist in pg_proc")

            test_smoke_code = f"SMOKE_{uuid.uuid4().hex[:6]}"
            cur1.execute(
                "INSERT INTO public.qr_channels (id, store_id, type, channel_code, name, is_active) VALUES (%s, %s, 'TABLE_SHARED', %s, 'Smoke Chan', true);",
                (str(uuid.uuid4()), self.store_id, test_smoke_code)
            )
            cur2.execute("SELECT count(*) FROM public.qr_channels WHERE store_id = %s AND channel_code = %s;", (self.store_id, test_smoke_code))
            self.assertEqual(cur2.fetchone()[0], 1, "Connection 2 must read committed fixture from Connection 1")
            cur1.execute("DELETE FROM public.qr_channels WHERE store_id = %s AND channel_code = %s;", (self.store_id, test_smoke_code))

            cur2.execute("SELECT * FROM public.verify_staff_qr_membership_v4(%s);", (self.store_id,))
            staff_row = cur2.fetchone()
            self.assertIsNotNone(staff_row, "verify_staff_qr_membership_v4 must succeed with valid JWT claim")
        finally:
            cur1.close()
            conn1.close()
            cur2.close()
            conn2.close()

    def test_01_race_double_submit_same_hash(self):
        """Race 1: Double submit with same key + same hash across 2 independent DB connections."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        channel_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.close()
        conn_fix.close()

        key = f"race1_{uuid.uuid4().hex[:8]}"
        payload_hash = "1111111111111111111111111111111111111111111111111111111111111111"
        items_json = json.dumps([{"product_id": self.prod_drink_id, "quantity": 1}])

        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B01', %s, %s);", (channel_code, items_json, key, payload_hash))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0,))
        t2 = threading.Thread(target=worker, args=(1,))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        self.assertTrue(results[0]['success'])
        self.assertTrue(results[1]['success'])
        is_replay_flags = [results[0]['data']['is_replay'], results[1]['data']['is_replay']]
        self.assertIn(True, is_replay_flags)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.qr_requests WHERE store_id = %s AND idempotency_key = %s;", (self.store_id, key))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.close()
        conn_check.close()

    def test_02_race_double_submit_different_hash(self):
        """Race 2: Double submit with same key + different hash -> 1 PASS, 1 IDEMPOTENCY_CONFLICT with 0 orphan requests."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        channel_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.close()
        conn_fix.close()

        key = f"race2_{uuid.uuid4().hex[:8]}"
        hash1 = "2222222222222222222222222222222222222222222222222222222222222222"
        hash2 = "3333333333333333333333333333333333333333333333333333333333333333"

        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx, phash):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            barrier.wait(timeout=10)
            try:
                cur.execute(
                    "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B01', %s, %s);",
                    (channel_code, json.dumps([{"product_id": self.prod_drink_id, "quantity": 1}]), key, phash)
                )
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0, hash1))
        t2 = threading.Thread(target=worker, args=(1, hash2))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        conflicts = [r for r in results if r.get('error_code') == 'IDEMPOTENCY_CONFLICT']
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.qr_requests WHERE store_id = %s AND idempotency_key = %s;", (self.store_id, key))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.close()
        conn_check.close()

    def test_03_race_double_claim_same_token(self):
        """Race 3: Double claim with same handoff token -> 1 winner, 1 ALREADY_CLAIMED/TOKEN_ALREADY_USED."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        chan_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B01', %s, %s);",
            (chan_code, json.dumps([{"product_id": self.prod_food_id, "quantity": 1}]), f"claim_{uuid.uuid4().hex[:8]}", "4444444444444444444444444444444444444444444444444444444444444444")
        )
        sub_res = cur_fix.fetchone()[0]
        raw_token = sub_res['data']['raw_handoff_token']
        req_id = sub_res['data']['request_id']
        cur_fix.close()
        conn_fix.close()

        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.waiter_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.waiter_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.waiter_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.claim_qr_handoff_v4(%s, %s);", (raw_token, self.store_id))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0,))
        t2 = threading.Thread(target=worker, args=(1,))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        failures = [r for r in results if r.get('success') is False]
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(failures), 1)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.qr_handoff_tokens WHERE request_id = %s AND status = 'consumed';", (req_id,))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.close()
        conn_check.close()

    def test_04_race_double_mark_paid_same_request(self):
        """Race 4: Double mark paid for same counter request -> 1 initial success, 1 replay, 0 orphan orders."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'COUNTER_TAKEAWAY', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        ctr_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, NULL, %s, %s);",
            (ctr_code, json.dumps([{"product_id": self.prod_food_id, "quantity": 1}]), f"ctr_{uuid.uuid4().hex[:8]}", "5555555555555555555555555555555555555555555555555555555555555555")
        )
        req_id = cur_fix.fetchone()[0]['data']['request_id']
        cur_fix.close()
        conn_fix.close()

        pay_key = f"pay_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.cashier_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.cashier_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.cashier_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.mark_qr_order_paid_v4(%s, %s, 'cash', %s);", (req_id, self.store_id, pay_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0,))
        t2 = threading.Thread(target=worker, args=(1,))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        self.assertTrue(results[0]['success'])
        self.assertTrue(results[1]['success'])
        replays = [results[0]['data']['is_replay'], results[1]['data']['is_replay']]
        self.assertIn(True, replays)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.orders WHERE source_id = %s;", (req_id,))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.execute("SELECT count(*) FROM public.qr_payment_idempotency WHERE request_id = %s;", (req_id,))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.close()
        conn_check.close()

    def assert_exact_deltas(self, before: Dict[str, int], after: Dict[str, int], expected: Dict[str, int], context: str):
        """Strictly verify delta counts across all 13 tables for zero-orphan proof."""
        REQUIRED_TABLES = [
            'orders',
            'order_items',
            'qr_payment_idempotency',
            'qr_kitchen_idempotency',
            'kitchen_tickets',
            'kitchen_ticket_items',
            'payment_settlements',
            'finance_records',
            'stock_movements',
            'loyalty_transactions',
            'qr_coupon_redemptions',
            'ban_session_orders',
            'ban_session_order_items',
        ]
        self.assertEqual(len(REQUIRED_TABLES), 13, "Must check exactly 13 tables")
        for tbl in REQUIRED_TABLES:
            self.assertIn(tbl, expected, f"[{context}] Expected delta dictionary must contain table '{tbl}'")
            self.assertIn(tbl, before, f"[{context}] Before count dictionary missing table '{tbl}'")
            self.assertIn(tbl, after, f"[{context}] After count dictionary missing table '{tbl}'")

            exp = expected[tbl]
            actual = after[tbl] - before[tbl]
            self.assertEqual(
                actual, exp,
                f"[{context}] Table '{tbl}' delta mismatch: expected +{exp}, got +{actual} (before={before[tbl]}, after={after[tbl]})"
            )

    def test_05_race_same_payment_key_different_requests(self):
        """Race 5: Same payment key used across 2 different counter requests -> 1 winner, 1 IDEMPOTENCY_CONFLICT with ZERO orphan rows across all 13 tables."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'COUNTER_TAKEAWAY', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        ctr_code = cur_fix.fetchone()[0]['data']['channel_code']
        # Request A
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, NULL, %s, %s);",
            (ctr_code, json.dumps([{"product_id": self.prod_food_id, "quantity": 1}]), f"ctrA_{uuid.uuid4().hex[:8]}", "6666666666666666666666666666666666666666666666666666666666666666")
        )
        req_a = cur_fix.fetchone()[0]['data']['request_id']
        # Request B
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, NULL, %s, %s);",
            (ctr_code, json.dumps([{"product_id": self.prod_drink_id, "quantity": 1}]), f"ctrB_{uuid.uuid4().hex[:8]}", "7777777777777777777777777777777777777777777777777777777777777777")
        )
        req_b = cur_fix.fetchone()[0]['data']['request_id']

        # Zero-Orphan Snapshot Before Race
        before_counts = self.snapshot_counts(conn_fix, self.store_id)
        cur_fix.close()
        conn_fix.close()

        shared_key = f"shared_pay_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx, req_id):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.cashier_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.cashier_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.cashier_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.mark_qr_order_paid_v4(%s, %s, 'cash', %s);", (req_id, self.store_id, shared_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0, req_a))
        t2 = threading.Thread(target=worker, args=(1, req_b))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        conflicts = [r for r in results if r.get('error_code') == 'IDEMPOTENCY_CONFLICT']
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)

        # Zero-Orphan Snapshot After Race across all 13 tables
        conn_check = self.get_fixture_conn()
        after_counts = self.snapshot_counts(conn_check, self.store_id)

        expected_deltas_5 = {
            'orders': 1,
            'order_items': 1,
            'qr_payment_idempotency': 1,
            'qr_kitchen_idempotency': 0,
            'kitchen_tickets': 0,
            'kitchen_ticket_items': 0,
            'payment_settlements': 0,
            'finance_records': 1,
            'stock_movements': 1,
            'loyalty_transactions': 0,
            'qr_coupon_redemptions': 0,
            'ban_session_orders': 0,
            'ban_session_order_items': 0,
        }
        self.assert_exact_deltas(before_counts, after_counts, expected_deltas_5, "Race 5")

        # Specific loser isolation check
        winner_req = req_a if results[0].get('success') is True else req_b
        loser_req = req_b if winner_req == req_a else req_a
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.orders WHERE source_id = %s;", (loser_req,))
        self.assertEqual(cur_check.fetchone()[0], 0, "Losing request must produce exactly 0 orders")
        cur_check.execute("SELECT count(*) FROM public.qr_payment_idempotency WHERE request_id = %s;", (loser_req,))
        self.assertEqual(cur_check.fetchone()[0], 0, "Losing request must produce exactly 0 payment idempotency rows")
        cur_check.close()
        conn_check.close()

    def test_06_race_double_send_kitchen_same_request(self):
        """Race 6: Double send to kitchen with same request + same key -> 1 initial success, 1 replay, exactly 1 ticket."""
        table_id = str(uuid.uuid4())
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("INSERT INTO public.ban_dining_tables (id, store_id, label, is_active) VALUES (%s, %s, %s, true);", (table_id, self.store_id, f"Bàn Kitchen {table_id[:4]}"))
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        chan_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B02', %s, %s);",
            (chan_code, json.dumps([{"product_id": self.prod_drink_id, "quantity": 2}]), f"k_req_{uuid.uuid4().hex[:8]}", "8888888888888888888888888888888888888888888888888888888888888888")
        )
        req_id = cur_fix.fetchone()[0]['data']['request_id']
        cur_fix.execute("SELECT public.assign_qr_order_table_v4(%s, %s, %s);", (req_id, table_id, self.store_id))
        cur_fix.close()
        conn_fix.close()

        kitchen_key = f"k_key_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.waiter_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.waiter_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.waiter_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.send_qr_order_to_kitchen_v4(%s, %s, %s, 'Note');", (req_id, self.store_id, kitchen_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0,))
        t2 = threading.Thread(target=worker, args=(1,))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        self.assertTrue(results[0]['success'])
        self.assertTrue(results[1]['success'])
        replays = [results[0]['data']['is_replay'], results[1]['data']['is_replay']]
        self.assertIn(True, replays)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.qr_kitchen_idempotency WHERE request_id = %s;", (req_id,))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.close()
        conn_check.close()

    def test_07_race_same_kitchen_key_different_requests(self):
        """Race 7: Same kitchen idempotency key used across 2 different table requests -> 1 winner, 1 IDEMPOTENCY_CONFLICT with 0 orphan tickets across all 13 tables."""
        table_id = str(uuid.uuid4())
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("INSERT INTO public.ban_dining_tables (id, store_id, label, is_active) VALUES (%s, %s, %s, true);", (table_id, self.store_id, f"Bàn Kitchen 2 {table_id[:4]}"))
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        chan_code = cur_fix.fetchone()[0]['data']['channel_code']
        # Req 1
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B02', %s, %s);",
            (chan_code, json.dumps([{"product_id": self.prod_drink_id, "quantity": 1}]), f"k1_{uuid.uuid4().hex[:8]}", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        )
        req1 = cur_fix.fetchone()[0]['data']['request_id']
        cur_fix.execute("SELECT public.assign_qr_order_table_v4(%s, %s, %s);", (req1, table_id, self.store_id))
        # Req 2
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B02', %s, %s);",
            (chan_code, json.dumps([{"product_id": self.prod_food_id, "quantity": 1}]), f"k2_{uuid.uuid4().hex[:8]}", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        )
        req2 = cur_fix.fetchone()[0]['data']['request_id']
        cur_fix.execute("SELECT public.assign_qr_order_table_v4(%s, %s, %s);", (req2, table_id, self.store_id))

        before_counts = self.snapshot_counts(conn_fix, self.store_id)
        cur_fix.close()
        conn_fix.close()

        shared_k_key = f"shared_k_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx, req_id):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.waiter_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.waiter_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.waiter_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.send_qr_order_to_kitchen_v4(%s, %s, %s, 'Note');", (req_id, self.store_id, shared_k_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0, req1))
        t2 = threading.Thread(target=worker, args=(1, req2))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        conflicts = [r for r in results if r.get('error_code') == 'IDEMPOTENCY_CONFLICT']
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)

        conn_check = self.get_fixture_conn()
        after_counts = self.snapshot_counts(conn_check, self.store_id)

        expected_deltas_7 = {
            'orders': 1,
            'order_items': 1,
            'qr_payment_idempotency': 0,
            'qr_kitchen_idempotency': 1,
            'kitchen_tickets': 1,
            'kitchen_ticket_items': 1,
            'payment_settlements': 0,
            'finance_records': 0,
            'stock_movements': 0,
            'loyalty_transactions': 0,
            'qr_coupon_redemptions': 0,
            'ban_session_orders': 1,
            'ban_session_order_items': 1,
        }
        self.assert_exact_deltas(before_counts, after_counts, expected_deltas_7, "Race 7")

        # Specific loser isolation check
        winner_req = req1 if results[0].get('success') is True else req2
        loser_req = req2 if winner_req == req1 else req1
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.kitchen_tickets kt JOIN public.qr_requests qr ON qr.order_id = kt.order_id WHERE qr.id = %s;", (loser_req,))
        self.assertEqual(cur_check.fetchone()[0], 0, "Losing request must produce exactly 0 kitchen tickets")
        cur_check.execute("SELECT count(*) FROM public.qr_kitchen_idempotency WHERE request_id = %s;", (loser_req,))
        self.assertEqual(cur_check.fetchone()[0], 0, "Losing request must produce exactly 0 kitchen idempotency rows")
        cur_check.close()
        conn_check.close()

    def test_08_race_double_settle_same_session(self):
        """Race 8: Double settle on same dining session -> 1 initial success, 1 replay, exactly 1 finance record."""
        table_id = str(uuid.uuid4())
        session_id = str(uuid.uuid4())
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("INSERT INTO public.ban_dining_tables (id, store_id, label, is_active) VALUES (%s, %s, %s, true);", (table_id, self.store_id, f"Bàn Race {table_id[:4]}"))
        cur_fix.execute("INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count) VALUES (%s, %s, %s, 'open', now(), 60000, 1);", (session_id, self.store_id, table_id))
        cur_fix.execute("INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal, kitchen_status, added_at) VALUES (%s, %s, %s, %s, 'Mì Xào Bò', 60000, 60000, 1, 60000, 'da_gui', now());", (str(uuid.uuid4()), self.store_id, session_id, self.prod_food_id))
        cur_fix.close()
        conn_fix.close()

        settle_key = f"settle_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.cashier_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.cashier_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.cashier_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.settle_ban_session_v4(%s, %s, 'cash', %s);", (session_id, self.store_id, settle_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0,))
        t2 = threading.Thread(target=worker, args=(1,))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        self.assertTrue(results[0]['success'])
        self.assertTrue(results[1]['success'])
        replays = [results[0]['data']['is_replay'], results[1]['data']['is_replay']]
        self.assertIn(True, replays)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT count(*) FROM public.payment_settlements WHERE session_id = %s;", (session_id,))
        self.assertEqual(cur_check.fetchone()[0], 1)
        cur_check.execute(
            """
            SELECT count(*)
            FROM public.finance_records fr
            JOIN public.payment_settlements ps ON ps.id = fr.reference_id
            WHERE ps.session_id = %s
              AND ps.store_id = %s
              AND fr.store_id = %s;
            """,
            (session_id, self.store_id, self.store_id),
        )
        self.assertEqual(
            cur_check.fetchone()[0],
            1,
            "Settlement replay must create exactly 1 linked finance record",
        )
        cur_check.close()
        conn_check.close()

    def test_09_race_same_settlement_key_different_sessions(self):
        """Race 9: Same settlement key used across 2 different dining sessions -> 1 winner, 1 IDEMPOTENCY_CONFLICT with ZERO orphan side-effects across all 13 tables."""
        t1_id = str(uuid.uuid4())
        t2_id = str(uuid.uuid4())
        s1_id = str(uuid.uuid4())
        s2_id = str(uuid.uuid4())
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("INSERT INTO public.ban_dining_tables (id, store_id, label, is_active) VALUES (%s, %s, %s, true), (%s, %s, %s, true);", (t1_id, self.store_id, "T1", t2_id, self.store_id, "T2"))
        cur_fix.execute("INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count) VALUES (%s, %s, %s, 'open', now(), 30000, 1), (%s, %s, %s, 'open', now(), 60000, 1);", (s1_id, self.store_id, t1_id, s2_id, self.store_id, t2_id))
        cur_fix.execute("INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal, kitchen_status, added_at) VALUES (%s, %s, %s, %s, 'Trà Đào', 30000, 30000, 1, 30000, 'da_gui', now());", (str(uuid.uuid4()), self.store_id, s1_id, self.prod_drink_id))
        cur_fix.execute("INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal, kitchen_status, added_at) VALUES (%s, %s, %s, %s, 'Mì Xào', 60000, 60000, 1, 60000, 'da_gui', now());", (str(uuid.uuid4()), self.store_id, s2_id, self.prod_food_id))

        before_counts = self.snapshot_counts(conn_fix, self.store_id)
        cur_fix.close()
        conn_fix.close()

        shared_settle_key = f"shared_settle_{uuid.uuid4().hex[:8]}"
        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx, session_id):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.cashier_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.cashier_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.cashier_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.settle_ban_session_v4(%s, %s, 'cash', %s);", (session_id, self.store_id, shared_settle_key))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0, s1_id))
        t2 = threading.Thread(target=worker, args=(1, s2_id))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        conflicts = [r for r in results if r.get('error_code') == 'IDEMPOTENCY_CONFLICT']
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)

        conn_check = self.get_fixture_conn()
        after_counts = self.snapshot_counts(conn_check, self.store_id)

        expected_deltas_9 = {
            'orders': 1,
            'order_items': 1,
            'qr_payment_idempotency': 0,
            'qr_kitchen_idempotency': 0,
            'kitchen_tickets': 0,
            'kitchen_ticket_items': 0,
            'payment_settlements': 1,
            'finance_records': 1,
            'stock_movements': 1,
            'loyalty_transactions': 0,
            'qr_coupon_redemptions': 0,
            'ban_session_orders': 1,
            'ban_session_order_items': 1,
        }
        self.assert_exact_deltas(before_counts, after_counts, expected_deltas_9, "Race 9")

        # Specific winner & loser session state checks
        winner_sess = s1_id if results[0].get('success') is True else s2_id
        loser_sess = s2_id if winner_sess == s1_id else s1_id
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT status FROM public.ban_sessions WHERE id = %s;", (winner_sess,))
        self.assertEqual(cur_check.fetchone()[0], 'closed', "Winning session must be marked closed")
        cur_check.execute("SELECT status FROM public.ban_sessions WHERE id = %s;", (loser_sess,))
        self.assertEqual(cur_check.fetchone()[0], 'open', "Losing session must remain open")
        cur_check.execute("SELECT count(*) FROM public.payment_settlements WHERE session_id = %s;", (loser_sess,))
        self.assertEqual(cur_check.fetchone()[0], 0, "Losing session must have 0 settlements")
        cur_check.execute(
            """
            SELECT
              count(*) FILTER (WHERE ps.session_id = %s) AS winner_finance_count,
              count(*) FILTER (WHERE ps.session_id = %s) AS loser_finance_count
            FROM public.finance_records fr
            JOIN public.payment_settlements ps ON ps.id = fr.reference_id
            WHERE ps.store_id = %s
              AND fr.store_id = %s
              AND ps.session_id IN (%s, %s);
            """,
            (
                winner_sess,
                loser_sess,
                self.store_id,
                self.store_id,
                winner_sess,
                loser_sess,
            ),
        )
        winner_finance_count, loser_finance_count = cur_check.fetchone()
        self.assertEqual(
            winner_finance_count,
            1,
            "Winning session must create exactly 1 linked finance record",
        )
        self.assertEqual(
            loser_finance_count,
            0,
            "Losing session must create 0 linked finance records",
        )
        cur_check.close()
        conn_check.close()

    def test_10_race_optimistic_version_conflict(self):
        """Race 10: Concurrent item update with same expected_version -> 1 winner (version bumps), 1 VERSION_CONFLICT."""
        conn_fix = self.get_fixture_conn(self.owner_uid)
        cur_fix = conn_fix.cursor()
        cur_fix.execute("SELECT public.manage_qr_channel_v4(%s, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');", (self.store_id,))
        chan_code = cur_fix.fetchone()[0]['data']['channel_code']
        cur_fix.execute(
            "SELECT public.submit_qr_order_v4(%s, %s::jsonb, 'B03', %s, %s);",
            (chan_code, json.dumps([{"product_id": self.prod_food_id, "quantity": 1}]), f"edit_{uuid.uuid4().hex[:8]}", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
        )
        req_id = cur_fix.fetchone()[0]['data']['request_id']
        cur_fix.close()
        conn_fix.close()

        items_mod1 = json.dumps([{"product_id": self.prod_food_id, "quantity": 2}])
        items_mod2 = json.dumps([{"product_id": self.prod_drink_id, "quantity": 3}])

        barrier = threading.Barrier(2)
        results = [None, None]

        def worker(idx, items_json):
            c = self.psycopg2.connect(self.db_url)
            c.autocommit = False
            cur = c.cursor()
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (self.waiter_uid,))
            cur.execute("SELECT auth.uid();")
            claim = cur.fetchone()[0]
            if str(claim) != str(self.waiter_uid):
                raise AssertionError(f"Worker auth.uid() mismatch: expected {self.waiter_uid}, got {claim}")
            barrier.wait(timeout=10)
            try:
                cur.execute("SELECT public.update_qr_order_items_v4(%s, %s, 1, %s::jsonb);", (req_id, self.store_id, items_json))
                res = cur.fetchone()[0]
                c.commit()
                results[idx] = res
            except Exception as e:
                c.rollback()
                results[idx] = {"success": False, "error": str(e)}
            finally:
                cur.close()
                c.close()

        t1 = threading.Thread(target=worker, args=(0, items_mod1))
        t2 = threading.Thread(target=worker, args=(1, items_mod2))
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)
        self.assertFalse(t1.is_alive())
        self.assertFalse(t2.is_alive())

        successes = [r for r in results if r.get('success') is True]
        conflicts = [r for r in results if r.get('error_code') == 'VERSION_CONFLICT']
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)

        conn_check = self.get_fixture_conn()
        cur_check = conn_check.cursor()
        cur_check.execute("SELECT version FROM public.qr_requests WHERE id = %s;", (req_id,))
        self.assertEqual(cur_check.fetchone()[0], 2)
        cur_check.close()
        conn_check.close()

if __name__ == "__main__":
    unittest.main()
