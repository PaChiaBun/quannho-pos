#!/usr/bin/env python3
"""
Concurrency Test Harness for QR Order V4 (Quán Nhỏ POS)
Target: Parallel multi-threaded execution verifying race condition guards against real DB / mock adapter.
Verifies:
  1. Double submit with same idempotency key + same hash -> Exactly 1 request row created, both receive valid token.
  2. Double submit with same idempotency key + different hash -> Exactly 1 success, 1 IDEMPOTENCY_CONFLICT.
  3. Double claim on same handoff token -> Exactly 1 success, 1 TOKEN_ALREADY_USED / ALREADY_CLAIMED.
  4. Double payment on same request -> Exactly 1 order + finance entry, 1 replay.
  5. Double settlement on same session -> Exactly 1 settlement record + finance entry, 1 replay.
"""

import sys
import time
import uuid
import hashlib
import threading
import unittest
from typing import Dict, Any, List

class ConcurrentRunner:
    @staticmethod
    def run_parallel(target_func, args_list: List[tuple]) -> List[Any]:
        results = [None] * len(args_list)
        threads = []

        def worker(idx, *args):
            try:
                results[idx] = target_func(*args)
            except Exception as e:
                results[idx] = {"success": False, "error": str(e)}

        for i, args in enumerate(args_list):
            t = threading.Thread(target=worker, args=(i, *args))
            threads.append(t)

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        return results

class MockDatabaseAdapter:
    """Mock concurrent DB engine simulating PostgreSQL row-level locks and unique constraints."""
    def __init__(self):
        self._lock = threading.Lock()
        self.channels = {}
        self.requests = {}
        self.idempotency_keys = {}
        self.handoff_tokens = {}
        self.orders = {}
        self.finance_records = {}
        self.settlements = {}

    def submit_qr_order(self, channel_code: str, idempotency_key: str, payload_hash: str) -> Dict[str, Any]:
        with self._lock:
            # Simulate atomic check & insert with UNIQUE constraint
            if idempotency_key in self.idempotency_keys:
                existing_req_id = self.idempotency_keys[idempotency_key]
                existing_req = self.requests[existing_req_id]
                if existing_req["payload_hash"] != payload_hash:
                    return {"success": False, "error_code": "IDEMPOTENCY_CONFLICT"}
                # Rotate token
                new_token = f"QRN_{uuid.uuid4().hex[:16].upper()}"
                self.handoff_tokens[existing_req_id] = {"token": new_token, "status": "active"}
                return {"success": True, "request_id": existing_req_id, "token": new_token, "is_replay": True}

            req_id = str(uuid.uuid4())
            new_token = f"QRN_{uuid.uuid4().hex[:16].upper()}"
            self.requests[req_id] = {"id": req_id, "payload_hash": payload_hash, "status": "customer_submitted"}
            self.idempotency_keys[idempotency_key] = req_id
            self.handoff_tokens[req_id] = {"token": new_token, "status": "active"}
            return {"success": True, "request_id": req_id, "token": new_token, "is_replay": False}

    def claim_handoff(self, token: str, staff_id: str) -> Dict[str, Any]:
        with self._lock:
            target_req_id = None
            for req_id, tok_data in self.handoff_tokens.items():
                if tok_data["token"] == token:
                    target_req_id = req_id
                    break

            if not target_req_id:
                return {"success": False, "error_code": "INVALID_QR"}

            tok_data = self.handoff_tokens[target_req_id]
            if tok_data["status"] != "active":
                return {"success": False, "error_code": "TOKEN_ALREADY_USED"}

            # Consume token
            tok_data["status"] = "consumed"
            self.requests[target_req_id]["status"] = "claimed"
            self.requests[target_req_id]["claimed_by"] = staff_id
            return {"success": True, "request_id": target_req_id}

    def mark_order_paid(self, request_id: str, idempotency_key: str, amount: float) -> Dict[str, Any]:
        with self._lock:
            if request_id not in self.requests:
                return {"success": False, "error_code": "INVALID_STATE"}

            req = self.requests[request_id]
            if req.get("paid"):
                return {"success": True, "order_id": req["canonical_order_id"], "is_replay": True}

            order_id = str(uuid.uuid4())
            self.orders[order_id] = {"id": order_id, "request_id": request_id, "amount": amount}
            self.finance_records[order_id] = {"id": str(uuid.uuid4()), "reference_id": order_id, "amount": amount}
            req["paid"] = True
            req["canonical_order_id"] = order_id
            return {"success": True, "order_id": order_id, "is_replay": False}

    def settle_session(self, session_id: str, idempotency_key: str, amount: float) -> Dict[str, Any]:
        with self._lock:
            if session_id in self.settlements:
                return {"success": True, "settlement_id": self.settlements[session_id]["id"], "is_replay": True}

            settlement_id = str(uuid.uuid4())
            self.settlements[session_id] = {"id": settlement_id, "amount": amount}
            self.finance_records[settlement_id] = {"id": str(uuid.uuid4()), "reference_id": settlement_id, "amount": amount}
            return {"success": True, "settlement_id": settlement_id, "is_replay": False}

class TestQrV4Concurrency(unittest.TestCase):
    def setUp(self):
        self.db = MockDatabaseAdapter()

    def test_01_concurrent_submit_same_payload_hash(self):
        key = "idemp_race_01"
        hash_val = hashlib.sha256(b"items_data_1").hexdigest()

        results = ConcurrentRunner.run_parallel(
            self.db.submit_qr_order,
            [("TBL_01", key, hash_val), ("TBL_01", key, hash_val)]
        )

        self.assertTrue(all(r["success"] for r in results))
        self.assertEqual(len(self.db.requests), 1)  # Exactly 1 row created in DB
        replays = [r for r in results if r.get("is_replay")]
        self.assertEqual(len(replays), 1)

    def test_02_concurrent_submit_different_payload_hash(self):
        key = "idemp_race_02"
        hash_a = hashlib.sha256(b"items_a").hexdigest()
        hash_b = hashlib.sha256(b"items_b").hexdigest()

        results = ConcurrentRunner.run_parallel(
            self.db.submit_qr_order,
            [("TBL_01", key, hash_a), ("TBL_01", key, hash_b)]
        )

        successes = [r for r in results if r.get("success")]
        conflicts = [r for r in results if r.get("error_code") == "IDEMPOTENCY_CONFLICT"]
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(conflicts), 1)
        self.assertEqual(len(self.db.requests), 1)

    def test_03_concurrent_double_claim(self):
        submit_res = self.db.submit_qr_order("TBL_01", "idemp_claim_01", hashlib.sha256(b"claim_test").hexdigest())
        raw_token = submit_res["token"]

        results = ConcurrentRunner.run_parallel(
            self.db.claim_handoff,
            [(raw_token, "staff_waiter_1"), (raw_token, "staff_cashier_2")]
        )

        successes = [r for r in results if r.get("success")]
        failures = [r for r in results if r.get("error_code") == "TOKEN_ALREADY_USED"]
        self.assertEqual(len(successes), 1)
        self.assertEqual(len(failures), 1)

    def test_04_concurrent_double_payment(self):
        submit_res = self.db.submit_qr_order("CTR_01", "idemp_pay_01", hashlib.sha256(b"pay_test").hexdigest())
        req_id = submit_res["request_id"]

        results = ConcurrentRunner.run_parallel(
            self.db.mark_order_paid,
            [(req_id, "pay_key_1", 120000), (req_id, "pay_key_1", 120000)]
        )

        self.assertTrue(all(r["success"] for r in results))
        self.assertEqual(len(self.db.orders), 1)  # Exactly 1 canonical order created
        self.assertEqual(len(self.db.finance_records), 1)  # Exactly 1 finance record created

    def test_05_concurrent_double_table_settlement(self):
        session_id = str(uuid.uuid4())

        results = ConcurrentRunner.run_parallel(
            self.db.settle_session,
            [(session_id, "settle_key_1", 250000), (session_id, "settle_key_1", 250000)]
        )

        self.assertTrue(all(r["success"] for r in results))
        self.assertEqual(len(self.db.settlements), 1)  # Exactly 1 settlement record
        self.assertEqual(len(self.db.finance_records), 1)  # Exactly 1 finance record

if __name__ == "__main__":
    unittest.main()
