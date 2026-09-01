#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Real PostgreSQL Concurrency Test Harness for Settlement V5 & Daily Order Counters
Target: Staging PostgreSQL Database with 50+ Concurrent Workers
"""

import os
import sys
import unittest
import threading
import uuid
import json
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

class TestSettlementV5RealPostgresConcurrency(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db_url = os.environ.get("STAGING_DATABASE_URL")
        allow_mutation = os.environ.get("SETTLE_V5_ALLOW_STAGING_MUTATION", "").strip().upper()

        if not cls.db_url or allow_mutation != "YES":
            raise unittest.SkipTest(
                "REAL_POSTGRES_CONCURRENCY: BLOCKED_NOT_EXECUTED\n"
                "To execute this test harness against a real staging PostgreSQL database, set:\n"
                "  export STAGING_DATABASE_URL=\"postgresql://user:pass@host:port/dbname\"\n"
                "  export SETTLE_V5_ALLOW_STAGING_MUTATION=YES\n"
                "  python3 -m unittest test.backend.test_settlement_v5_concurrency_real_pg"
            )

        parsed = urllib.parse.urlparse(cls.db_url)
        host = parsed.hostname or ""
        dbname = parsed.path.lstrip("/")
        port = parsed.port or 5432
        sanitized_target = f"postgresql://***:***@{host}:{port}/{dbname}"

        if any(prod_word in host.lower() or prod_word in dbname.lower() for prod_word in ["prod", "production", "quannho-db.lpm.vn"]):
            raise ValueError(f"FATAL: Target database {sanitized_target} appears to be PRODUCTION! Aborting.")

        try:
            import psycopg2
            import psycopg2.extras
            cls.psycopg2 = psycopg2
            cls.psycopg2_extras = psycopg2.extras
            conn = psycopg2.connect(cls.db_url, connect_timeout=5)
            conn.close()
        except ImportError:
            raise unittest.SkipTest("psycopg2 module not installed in current environment")
        except Exception as e:
            raise unittest.SkipTest(f"Cannot connect to staging database: {e}")

        # Setup global fixtures
        cls.store_id = str(uuid.uuid4())
        cls.cashier_uid = str(uuid.uuid4())
        cls.waiter_uid = str(uuid.uuid4())
        cls.customer_id = str(uuid.uuid4())
        cls.table_id = str(uuid.uuid4())
        cls.prod_id = str(uuid.uuid4())
        cls.coupon_valid_id = str(uuid.uuid4())

        conn = cls.psycopg2.connect(cls.db_url)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("INSERT INTO public.stores (id, name) VALUES (%s, %s);", (cls.store_id, "Staging Test Settle V5"))
            cur.execute("INSERT INTO public.user_accounts (id, phone, display_name) VALUES (%s, %s, %s), (%s, %s, %s);",
                        (cls.cashier_uid, "0988111222", "Thu Ngan Staging", cls.waiter_uid, "0988111333", "Phuc Vu Staging"))
            cur.execute("INSERT INTO public.store_members (id, store_id, user_id, role) VALUES (%s, %s, %s, %s), (%s, %s, %s, %s);",
                        (str(uuid.uuid4()), cls.store_id, cls.cashier_uid, "cashier", str(uuid.uuid4()), cls.store_id, cls.waiter_uid, "waiter"))
            cur.execute("INSERT INTO public.app_settings (id, store_id, key, value) VALUES (%s, %s, %s, %s), (%s, %s, %s, %s), (%s, %s, %s, %s);",
                        (str(uuid.uuid4()), cls.store_id, "action_perms_cashier", json.dumps(["pos.checkout"]),
                         str(uuid.uuid4()), cls.store_id, "loyalty_rate", "10000",
                         str(uuid.uuid4()), cls.store_id, "loyalty_redeem_rate", "1000"))
            cur.execute("INSERT INTO public.customers (id, store_id, name, phone, loyalty_pts, total_spent) VALUES (%s, %s, %s, %s, %s, %s);",
                        (cls.customer_id, cls.store_id, "Khach Test Staging", "0909090909", 50, 200000))
            cur.execute("INSERT INTO public.ban_dining_tables (id, store_id, label, is_active, status) VALUES (%s, %s, %s, %s, %s);",
                        (cls.table_id, cls.store_id, "Ban S01", True, "empty"))
            cur.execute("INSERT INTO public.products (id, store_id, name, sell_price, cost_price_latest, stock_qty) VALUES (%s, %s, %s, %s, %s, %s);",
                        (cls.prod_id, cls.store_id, "Mon Test Settle", 50000, 25000, 500))
            
            # Coupon fixture
            cur.execute("""
                SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons';
            """)
            if cur.fetchone():
                cur.execute("""
                    INSERT INTO public.coupons (id, store_id, code, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount)
                    VALUES (%s, %s, 'VOUCHER50', true, now() - interval '1 day', now() + interval '30 days', 'fixed', 50000, 50000, 50000);
                """, (cls.coupon_valid_id, cls.store_id))
        conn.close()

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, "store_id") and hasattr(cls, "psycopg2"):
            try:
                conn = cls.psycopg2.connect(cls.db_url)
                conn.autocommit = True
                with conn.cursor() as cur:
                    cur.execute("DELETE FROM public.stores WHERE id = %s;", (cls.store_id,))
                conn.close()
            except Exception:
                pass

    def test_01_daily_order_counter_concurrency_50_workers(self):
        """Verify 50 concurrent workers with Barrier generate 50 strictly unique sequential order numbers without gaps"""
        results = []
        errors = []
        barrier = threading.Barrier(50)

        def worker():
            try:
                conn = self.psycopg2.connect(self.db_url)
                conn.autocommit = True
                barrier.wait()  # Synchronize 50 workers to start at the exact same instant
                with conn.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (self.cashier_uid,))
                    cur.execute("SELECT public.generate_daily_order_number_v1(%s, %s);", (self.store_id, "QN"))
                    num = cur.fetchone()[0]
                    results.append(num)
                conn.close()
            except Exception as e:
                errors.append(str(e))

        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(worker) for _ in range(50)]
            for f in futures:
                f.result()

        self.assertEqual(len(errors), 0, f"Errors during counter generation: {errors}")
        self.assertEqual(len(results), 50, "Expected 50 counter results")
        self.assertEqual(len(set(results)), 50, "Detected duplicate order numbers under 50 concurrent workers!")

        # Verify sequential range
        seqs = sorted([int(r.split('-')[-1]) for r in results])
        expected_range = list(range(seqs[0], seqs[0] + 50))
        self.assertEqual(seqs, expected_range, "Sequences must be continuous without gaps")

    def test_02_settle_v5_same_idempotency_key_50_workers(self):
        """Verify 50 concurrent requests with the SAME idempotency key create exactly 1 settlement and 49 replays"""
        session_id = str(uuid.uuid4())
        idemp_key = f"same-key-{uuid.uuid4()}"

        conn = self.psycopg2.connect(self.db_url)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (%s, %s, %s, %s);",
                        (session_id, self.store_id, self.table_id, "open"))
            cur.execute("INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, quantity, unit_price, subtotal) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);",
                        (str(uuid.uuid4()), self.store_id, session_id, self.prod_id, "Mon Test Settle", 2, 50000, 100000))
        conn.close()

        success_first = []
        success_replay = []
        errors = []
        barrier = threading.Barrier(50)

        def worker():
            try:
                c = self.psycopg2.connect(self.db_url)
                c.autocommit = True
                barrier.wait()
                with c.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (self.cashier_uid,))
                    cur.execute("""
                        SELECT public.settle_ban_session_v5(
                            p_session_id => %s::uuid,
                            p_store_id => %s::uuid,
                            p_payment_method => 'cash',
                            p_idempotency_key => %s,
                            p_customer_id => %s::uuid
                        );
                    """, (session_id, self.store_id, idemp_key, self.customer_id))
                    res = cur.fetchone()[0]
                    if isinstance(res, str):
                        res = json.loads(res)

                    if res.get("success"):
                        if res.get("data", {}).get("is_replay"):
                            success_replay.append(res)
                        else:
                            success_first.append(res)
                    else:
                        errors.append(res)
                c.close()
            except Exception as e:
                errors.append(str(e))

        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(worker) for _ in range(50)]
            for f in futures:
                f.result()

        self.assertEqual(len(errors), 0, f"Unexpected errors during same key settle: {errors}")
        self.assertEqual(len(success_first), 1, f"Expected exactly 1 first settlement commit, got: {len(success_first)}")
        self.assertEqual(len(success_replay), 49, f"Expected exactly 49 replay responses, got: {len(success_replay)}")

        # Database Assertions
        settlement_id = success_first[0]["data"]["settlement_id"]
        conn = self.psycopg2.connect(self.db_url)
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM public.payment_settlements WHERE session_id = %s;", (session_id,))
            self.assertEqual(cur.fetchone()[0], 1, "Expected exactly 1 payment_settlements row")

            cur.execute("SELECT count(*) FROM public.finance_records WHERE reference_id = %s AND is_auto = true;", (settlement_id,))
            self.assertEqual(cur.fetchone()[0], 1, "Expected exactly 1 auto-income finance_records row")

            cur.execute("SELECT count(*) FROM public.stock_movements WHERE reference_id = %s;", (settlement_id,))
            self.assertEqual(cur.fetchone()[0], 1, "Expected exactly 1 stock_movements row")

            cur.execute("SELECT status FROM public.ban_sessions WHERE id = %s;", (session_id,))
            self.assertEqual(cur.fetchone()[0], "closed", "Session must be closed")
        conn.close()

    def test_03_settle_v5_different_keys_same_session_50_workers(self):
        """Verify 50 concurrent requests with DIFFERENT keys on the same session result in 1 success and 49 SESSION_ALREADY_SETTLED"""
        session_id = str(uuid.uuid4())

        conn = self.psycopg2.connect(self.db_url)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (%s, %s, %s, %s);",
                        (session_id, self.store_id, self.table_id, "open"))
            cur.execute("INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, quantity, unit_price, subtotal) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);",
                        (str(uuid.uuid4()), self.store_id, session_id, self.prod_id, "Mon Test Settle", 1, 50000, 50000))
        conn.close()

        success_count = []
        already_settled_count = []
        other_errors = []
        barrier = threading.Barrier(50)

        def worker(w_idx):
            idemp_key = f"diff-key-{w_idx}-{uuid.uuid4()}"
            try:
                c = self.psycopg2.connect(self.db_url)
                c.autocommit = True
                barrier.wait()
                with c.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (self.cashier_uid,))
                    cur.execute("""
                        SELECT public.settle_ban_session_v5(
                            p_session_id => %s::uuid,
                            p_store_id => %s::uuid,
                            p_payment_method => 'cash',
                            p_idempotency_key => %s
                        );
                    """, (session_id, self.store_id, idemp_key))
                    res = cur.fetchone()[0]
                    if isinstance(res, str):
                        res = json.loads(res)

                    if res.get("success"):
                        success_count.append(res)
                    elif res.get("error_code") in ["SESSION_ALREADY_SETTLED", "SESSION_NOT_OPEN"]:
                        already_settled_count.append(res)
                    else:
                        other_errors.append(res)
                c.close()
            except Exception as e:
                other_errors.append(str(e))

        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = [executor.submit(worker, i) for i in range(50)]
            for f in futures:
                f.result()

        self.assertEqual(len(other_errors), 0, f"Unexpected errors during diff keys settle: {other_errors}")
        self.assertEqual(len(success_count), 1, f"Expected exactly 1 settlement to win, got: {len(success_count)}")
        self.assertEqual(len(already_settled_count), 49, f"Expected exactly 49 rejections, got: {len(already_settled_count)}")

    def test_04_pos_sale_v1_fail_closed_validation(self):
        """Verify complete_pos_sale_v1 fails closed on invalid quantities, points, and changed cart"""
        conn = self.psycopg2.connect(self.db_url)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (self.cashier_uid,))

            # 1. Negative quantity must fail
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => %s::jsonb
                );
            """, (self.store_id, f"fail-pos-1-{uuid.uuid4()}", json.dumps([{"product_id": self.prod_id, "quantity": -2}])))
            res = cur.fetchone()[0]
            if isinstance(res, str): res = json.loads(res)
            self.assertFalse(res.get("success"), "Negative quantity must fail")
            self.assertEqual(res.get("error_code"), "INVALID_QUANTITY")

            # 2. Invalid points must fail
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => %s::jsonb,
                    p_customer_id => %s::uuid,
                    p_loyalty_pts_used => -10
                );
            """, (self.store_id, f"fail-pos-2-{uuid.uuid4()}", json.dumps([{"product_id": self.prod_id, "quantity": 1}]), self.customer_id))
            res = cur.fetchone()[0]
            if isinstance(res, str): res = json.loads(res)
            self.assertFalse(res.get("success"), "Negative points must fail")
            self.assertEqual(res.get("error_code"), "INVALID_POINTS")

            # 3. Successful POS sale and 7-table snapshot Replay verification
            pos_key = f"pos-succ-{uuid.uuid4()}"
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => %s::jsonb
                );
            """, (self.store_id, pos_key, json.dumps([{"product_id": self.prod_id, "quantity": 1}])))
            res1 = cur.fetchone()[0]
            if isinstance(res1, str): res1 = json.loads(res1)
            self.assertTrue(res1.get("success"), f"First POS sale failed: {res1}")
            self.assertFalse(res1.get("data", {}).get("is_replay"))

            # Snapshot 7 tables
            cur.execute("SELECT count(*) FROM public.orders WHERE store_id = %s;", (self.store_id,))
            cnt_orders_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.order_items WHERE store_id = %s;", (self.store_id,))
            cnt_items_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.finance_records WHERE store_id = %s;", (self.store_id,))
            cnt_fin_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.stock_movements WHERE store_id = %s;", (self.store_id,))
            cnt_stock_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.loyalty_transactions WHERE store_id = %s;", (self.store_id,))
            cnt_loy_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.pos_coupon_redemptions WHERE store_id = %s;", (self.store_id,))
            cnt_coup_before = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM public.pos_idempotency_operations WHERE store_id = %s;", (self.store_id,))
            cnt_idemp_before = cur.fetchone()[0]

            # Replay with same key
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => %s::jsonb
                );
            """, (self.store_id, pos_key, json.dumps([{"product_id": self.prod_id, "quantity": 1}])))
            res2 = cur.fetchone()[0]
            if isinstance(res2, str): res2 = json.loads(res2)
            self.assertTrue(res2.get("success"), f"POS replay failed: {res2}")
            self.assertTrue(res2.get("data", {}).get("is_replay"))

            # Snapshot after replay
            cur.execute("SELECT count(*) FROM public.orders WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_orders_before, "Orders increased during replay")
            cur.execute("SELECT count(*) FROM public.order_items WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_items_before, "Order items increased during replay")
            cur.execute("SELECT count(*) FROM public.finance_records WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_fin_before, "Finance records increased during replay")
            cur.execute("SELECT count(*) FROM public.stock_movements WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_stock_before, "Stock movements increased during replay")
            cur.execute("SELECT count(*) FROM public.loyalty_transactions WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_loy_before, "Loyalty transactions increased during replay")
            cur.execute("SELECT count(*) FROM public.pos_coupon_redemptions WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_coup_before, "Coupon redemptions increased during replay")
            cur.execute("SELECT count(*) FROM public.pos_idempotency_operations WHERE store_id = %s;", (self.store_id,))
            self.assertEqual(cur.fetchone()[0], cnt_idemp_before, "Idempotency operations increased during replay")

            # Conflict with same key but different cart
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => %s::jsonb
                );
            """, (self.store_id, pos_key, json.dumps([{"product_id": self.prod_id, "quantity": 2}])))
            res3 = cur.fetchone()[0]
            if isinstance(res3, str): res3 = json.loads(res3)
            self.assertFalse(res3.get("success"), "POS conflict must fail")
            self.assertEqual(res3.get("error_code"), "IDEMPOTENCY_CONFLICT")
        conn.close()

    def test_05_wallet_distinct_keys_cannot_overspend(self):
        """Ten simultaneous 50k debits against a 50k wallet: exactly one sale."""
        with self.psycopg2.connect(self.db_url) as conn:
            with conn.cursor() as cur:
                cur.execute('UPDATE customers SET real_balance=50000, bonus_balance=0 WHERE id=%s', (self.customer_id,))
        barrier = threading.Barrier(10, timeout=15)
        def worker(i):
            conn = self.psycopg2.connect(self.db_url)
            try:
                conn.autocommit = True
                with conn.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false)", (self.cashier_uid,))
                    barrier.wait()
                    cur.execute("""SELECT complete_pos_sale_v1(%s, %s, %s::jsonb,
                        p_payment_method=>'wallet', p_customer_id=>%s)""",
                        (self.store_id, 'wallet-race-'+str(i), json.dumps([{'product_id': self.prod_id, 'quantity': 1}]), self.customer_id))
                    return cur.fetchone()[0]
            finally:
                conn.close()
        with ThreadPoolExecutor(max_workers=10) as pool:
            results = list(pool.map(worker, range(10)))
        self.assertEqual(sum(r['success'] for r in results), 1, results)
        self.assertEqual(sum(r.get('error_code') == 'INSUFFICIENT_WALLET' for r in results), 9, results)
        with self.psycopg2.connect(self.db_url) as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT real_balance FROM customers WHERE id=%s', (self.customer_id,))
                self.assertEqual(cur.fetchone()[0], 0)

    def test_06_pos_and_table_race_share_one_payment(self):
        """POS and Ban competing for one kitchen batch commit only one payment."""
        sid = str(uuid.uuid4())
        with self.psycopg2.connect(self.db_url) as conn:
            with conn.cursor() as cur:
                cur.execute('INSERT INTO ban_sessions(id,store_id,table_id) VALUES(%s,%s,%s)', (sid,self.store_id,self.table_id))
                cur.execute("""INSERT INTO ban_session_items(store_id,session_id,product_id,product_name,quantity,unit_price,subtotal)
                    VALUES(%s,%s,%s,'Race',1,50000,50000)""", (self.store_id,sid,self.prod_id))
                cur.execute('SELECT count(*) FROM finance_records WHERE store_id=%s', (self.store_id,))
                before = cur.fetchone()[0]
        barrier = threading.Barrier(2, timeout=15)
        def worker(is_pos):
            conn = self.psycopg2.connect(self.db_url)
            try:
                conn.autocommit=True
                with conn.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub',%s,false)",(self.cashier_uid,))
                    barrier.wait()
                    if is_pos:
                        cur.execute("""SELECT complete_pos_sale_v1(%s,%s,%s::jsonb,p_kitchen_session_ids=>ARRAY[%s::uuid])""",
                            (self.store_id,'pos-vs-ban',json.dumps([{'product_id':self.prod_id,'quantity':1}]),sid))
                    else:
                        cur.execute('SELECT settle_ban_session_v5(%s,%s,%s,%s)',(sid,self.store_id,'cash','ban-vs-pos'))
                    return cur.fetchone()[0]
            finally:
                conn.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(worker,[True,False]))
        self.assertEqual(sum(r['success'] for r in results),1,results)
        with self.psycopg2.connect(self.db_url) as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT count(*) FROM finance_records WHERE store_id=%s',(self.store_id,))
                self.assertEqual(cur.fetchone()[0],before+1)

    def test_07_checkout_rejects_waiter_and_wrong_store(self):
        for uid, store in [(self.waiter_uid,self.store_id),(self.cashier_uid,str(uuid.uuid4()))]:
            conn=self.psycopg2.connect(self.db_url)
            try:
                conn.autocommit=True
                with conn.cursor() as cur:
                    cur.execute("SELECT set_config('request.jwt.claim.sub',%s,false)",(uid,))
                    with self.assertRaises(self.psycopg2.errors.InsufficientPrivilege):
                        cur.execute('SELECT complete_pos_sale_v1(%s,%s,%s::jsonb)',(store,'unauthorized',json.dumps([{'product_id':self.prod_id,'quantity':1}])))
            finally:
                conn.close()

if __name__ == "__main__":
    unittest.main()
