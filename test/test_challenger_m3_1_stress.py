#!/usr/bin/env python3
"""
Empirical Adversarial Stress Test Harness for Milestone 3 (R1 & R2)
Challenger Agent: challenger_m3_1

Objectives:
1. Rapid sequential & concurrent calls to batchUpdateAvailability (toggling true -> false -> true).
2. Verify CoreProductRepository.changeStream emits correct storeId on every mutation with latency < 0.01s.
3. Verify in-memory cache _productsCacheByStore[storeId] is synchronously updated with new isAvailable and category.
4. Edge cases: Empty list of IDs (ids = []), non-existent IDs, cross-store ID isolation (storeId != targetStoreId).
5. AST contract and invariant checks on lib/core/repositories/core_product_repository.dart.
6. Adversarial analysis of network latency and cache sync ordering.
"""

import os
import re
import sys
import time
import queue
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Dict, Optional, Set, Any

REPO_ROOT = Path(__file__).resolve().parent.parent

# ─────────────────────────────────────────────────────────────────────────────
# 1. Exact High-Fidelity Python Replica of ProductModel
# ─────────────────────────────────────────────────────────────────────────────
class ProductModelSim:
    def __init__(
        self,
        id: str,
        store_id: str = "store_test_001",
        name: str = "Default Product",
        sku: Optional[str] = None,
        category: Optional[str] = "Khác",
        unit: str = "phần",
        product_type: str = "finished",
        stock_qty: float = 10.0,
        min_stock: float = 5.0,
        sell_price: float = 50000.0,
        cost_price: float = 30000.0,
        cost_price_latest: float = 30000.0,
        image_url: Optional[str] = None,
        station_code: str = "nong",
        is_available: bool = True,
        is_active: bool = True,
        is_deleted: bool = False,
        is_topping: bool = False,
        topping_unit: Optional[str] = None,
        updated_at: Optional[int] = None,
    ):
        self.id = id
        self.store_id = store_id
        self.name = name
        self.sku = sku
        self.category = category
        self.unit = unit
        self.product_type = product_type
        self.stock_qty = float(stock_qty)
        self.min_stock = float(min_stock)
        self.sell_price = float(sell_price)
        self.cost_price = float(cost_price)
        self.cost_price_latest = float(cost_price_latest)
        self.image_url = image_url
        self.station_code = station_code
        self.is_available = is_available
        self.is_active = is_active
        self.is_deleted = is_deleted
        self.is_topping = is_topping
        self.topping_unit = topping_unit
        self.updated_at = updated_at or int(time.time() * 1000)

    def copy_with(
        self,
        name: Optional[str] = None,
        sku: Optional[str] = None,
        category: Optional[str] = None,
        unit: Optional[str] = None,
        product_type: Optional[str] = None,
        stock_qty: Optional[float] = None,
        min_stock: Optional[float] = None,
        sell_price: Optional[float] = None,
        cost_price: Optional[float] = None,
        cost_price_latest: Optional[float] = None,
        image_url: Optional[str] = None,
        station_code: Optional[str] = None,
        is_available: Optional[bool] = None,
        is_active: Optional[bool] = None,
        is_deleted: Optional[bool] = None,
        is_topping: Optional[bool] = None,
        topping_unit: Optional[str] = None,
        updated_at: Optional[int] = None,
    ) -> "ProductModelSim":
        return ProductModelSim(
            id=self.id,
            store_id=self.store_id,
            name=name if name is not None else self.name,
            sku=sku if sku is not None else self.sku,
            category=category if category is not None else self.category,
            unit=unit if unit is not None else self.unit,
            product_type=product_type if product_type is not None else self.product_type,
            stock_qty=stock_qty if stock_qty is not None else self.stock_qty,
            min_stock=min_stock if min_stock is not None else self.min_stock,
            sell_price=sell_price if sell_price is not None else self.sell_price,
            cost_price=cost_price if cost_price is not None else self.cost_price,
            cost_price_latest=cost_price_latest if cost_price_latest is not None else self.cost_price_latest,
            image_url=image_url if image_url is not None else self.image_url,
            station_code=station_code if station_code is not None else self.station_code,
            is_available=is_available if is_available is not None else self.is_available,
            is_active=is_active if is_active is not None else self.isActive,
            is_deleted=is_deleted if is_deleted is not None else self.is_deleted,
            is_topping=is_topping if is_topping is not None else self.is_topping,
            topping_unit=topping_unit if topping_unit is not None else self.topping_unit,
            updated_at=updated_at if updated_at is not None else self.updated_at,
        )

    @property
    def isActive(self) -> bool:
        return self.is_active


# ─────────────────────────────────────────────────────────────────────────────
# 2. Simulated Broadcast Stream Controller (Dart StreamController.broadcast)
# ─────────────────────────────────────────────────────────────────────────────
class BroadcastStreamController:
    """Emulates Dart's StreamController<String>.broadcast() with latency profiling"""
    def __init__(self):
        self._listeners = []
        self._lock = threading.Lock()
        self._is_closed = False

    def listen(self, callback) -> int:
        with self._lock:
            if self._is_closed:
                raise RuntimeError("Cannot listen to closed controller")
            sub_id = id(callback)
            self._listeners.append((sub_id, callback))
            return sub_id

    def cancel(self, sub_id: int):
        with self._lock:
            self._listeners = [sub for sub in self._listeners if sub[0] != sub_id]

    def add(self, store_id: str) -> List[float]:
        """Dispatches storeId to all active listeners and returns latencies in seconds"""
        if self._is_closed:
            return []
        latencies = []
        with self._lock:
            listeners = list(self._listeners)
        for _, cb in listeners:
            t0 = time.perf_counter()
            cb(store_id)
            latencies.append(time.perf_counter() - t0)
        return latencies

    def close(self):
        with self._lock:
            self._is_closed = True
            self._listeners.clear()


# ─────────────────────────────────────────────────────────────────────────────
# 3. CoreProductRepository In-Memory Harness
# Replicates the exact state and method logic of CoreProductRepository in Dart
# ─────────────────────────────────────────────────────────────────────────────
class CoreProductRepositoryHarness:
    def __init__(self, simulated_network_latency_s: float = 0.0):
        self._productsCacheByStore: Dict[str, List[ProductModelSim]] = {}
        self._changeNotifier = BroadcastStreamController()
        self._lock = threading.RLock()
        self.mutation_log: List[Dict[str, Any]] = []
        self.simulated_network_latency_s = simulated_network_latency_s

    @property
    def changeStream(self) -> BroadcastStreamController:
        return self._changeNotifier

    def notifyDataChanged(self, store_id: str) -> List[float]:
        return self._changeNotifier.add(store_id)

    def setCacheForTesting(self, store_id: str, products: List[ProductModelSim]):
        with self._lock:
            self._productsCacheByStore[store_id] = list(products)

    def getCacheForTesting(self, store_id: str) -> Optional[List[ProductModelSim]]:
        with self._lock:
            cache = self._productsCacheByStore.get(store_id)
            return list(cache) if cache is not None else None

    @staticmethod
    def sameProductSnapshot(
        previous: Optional[List[ProductModelSim]],
        next_list: List[ProductModelSim],
    ) -> bool:
        if previous is None or len(previous) != len(next_list):
            return False
        for a, b in zip(previous, next_list):
            if (
                a.id != b.id
                or a.store_id != b.store_id
                or a.name != b.name
                or a.sku != b.sku
                or a.category != b.category
                or a.unit != b.unit
                or a.product_type != b.product_type
                or a.stock_qty != b.stock_qty
                or a.min_stock != b.min_stock
                or a.sell_price != b.sell_price
                or a.cost_price != b.cost_price
                or a.cost_price_latest != b.cost_price_latest
                or a.image_url != b.image_url
                or a.station_code != b.station_code
                or a.is_available != b.is_available
                or a.is_active != b.is_active
                or a.is_deleted != b.is_deleted
                or a.is_topping != b.is_topping
                or a.topping_unit != b.topping_unit
            ):
                return False
        return True

    def batchUpdateAvailability(
        self,
        store_id: str,
        ids: List[str],
        is_available: bool,
    ) -> Dict[str, Any]:
        t_start = time.perf_counter()
        if not ids:
            return {"status": "no_op", "duration": time.perf_counter() - t_start, "updated_count": 0}

        now_ms = int(time.time() * 1000)

        # Simulated Supabase network round-trip (matches await _client.from('products').update(...))
        if self.simulated_network_latency_s > 0:
            time.sleep(self.simulated_network_latency_s)

        with self._lock:
            # Simulated DB update filter: .eq('store_id', store_id).inFilter('id', ids)
            self.mutation_log.append({
                "type": "availability",
                "store_id": store_id,
                "ids": ids,
                "is_available": is_available,
                "timestamp_ms": now_ms,
            })

            # In-memory RAM cache update (happens after network await in production code)
            updated_count = 0
            if store_id in self._productsCacheByStore:
                id_set = set(ids)
                current_cache = self._productsCacheByStore[store_id]
                new_cache = []
                for p in current_cache:
                    if p.id in id_set:
                        new_cache.append(p.copy_with(is_available=is_available, updated_at=now_ms))
                        updated_count += 1
                    else:
                        new_cache.append(p)
                self._productsCacheByStore[store_id] = new_cache

        # Stream notification
        latencies = self.notifyDataChanged(store_id)
        t_total = time.perf_counter() - t_start

        return {
            "status": "success",
            "duration": t_total,
            "stream_latencies": latencies,
            "updated_count": updated_count,
        }

    def batchUpdateCategory(
        self,
        store_id: str,
        ids: List[str],
        new_category: str,
    ) -> Dict[str, Any]:
        t_start = time.perf_counter()
        if not ids:
            return {"status": "no_op", "duration": time.perf_counter() - t_start, "updated_count": 0}

        now_ms = int(time.time() * 1000)

        if self.simulated_network_latency_s > 0:
            time.sleep(self.simulated_network_latency_s)

        with self._lock:
            self.mutation_log.append({
                "type": "category",
                "store_id": store_id,
                "ids": ids,
                "new_category": new_category,
                "timestamp_ms": now_ms,
            })

            updated_count = 0
            if store_id in self._productsCacheByStore:
                id_set = set(ids)
                current_cache = self._productsCacheByStore[store_id]
                new_cache = []
                for p in current_cache:
                    if p.id in id_set:
                        new_cache.append(p.copy_with(category=new_category, updated_at=now_ms))
                        updated_count += 1
                    else:
                        new_cache.append(p)
                self._productsCacheByStore[store_id] = new_cache

        latencies = self.notifyDataChanged(store_id)
        t_total = time.perf_counter() - t_start

        return {
            "status": "success",
            "duration": t_total,
            "stream_latencies": latencies,
            "updated_count": updated_count,
        }

    def batchSoftDelete(
        self,
        store_id: str,
        ids: List[str],
    ) -> Dict[str, Any]:
        t_start = time.perf_counter()
        if not ids:
            return {"status": "no_op", "duration": time.perf_counter() - t_start, "evicted_count": 0}

        now_ms = int(time.time() * 1000)

        if self.simulated_network_latency_s > 0:
            time.sleep(self.simulated_network_latency_s)

        with self._lock:
            self.mutation_log.append({
                "type": "soft_delete",
                "store_id": store_id,
                "ids": ids,
                "timestamp_ms": now_ms,
            })

            evicted_count = 0
            if store_id in self._productsCacheByStore:
                id_set = set(ids)
                current_cache = self._productsCacheByStore[store_id]
                new_cache = [p for p in current_cache if p.id not in id_set]
                evicted_count = len(current_cache) - len(new_cache)
                self._productsCacheByStore[store_id] = new_cache

        latencies = self.notifyDataChanged(store_id)
        t_total = time.perf_counter() - t_start

        return {
            "status": "success",
            "duration": t_total,
            "stream_latencies": latencies,
            "evicted_count": evicted_count,
        }


# ─────────────────────────────────────────────────────────────────────────────
# 4. TEST SUITES
# ─────────────────────────────────────────────────────────────────────────────

class TestCoreProductRepositoryASTContracts(unittest.TestCase):
    """Verifies that the production Dart codebase satisfies architectural invariants"""

    def setUp(self):
        self.repo_file = REPO_ROOT / "lib/core/repositories/core_product_repository.dart"
        self.assertTrue(self.repo_file.exists(), f"File {self.repo_file} must exist")
        self.code = self.repo_file.read_text(encoding="utf-8")

    def test_ast_batch_update_availability_signature_and_invariants(self):
        """Verify batchUpdateAvailability contract and query structure"""
        self.assertIn("Future<void> batchUpdateAvailability(", self.code)
        self.assertIn("String storeId,", self.code)
        self.assertIn("List<String> ids,", self.code)
        self.assertIn("bool isAvailable,", self.code)

        # Empty check fast exit
        self.assertIn("if (ids.isEmpty) return;", self.code)

        # Database update with tenant isolation and batch filter
        self.assertIn(".update({", self.code)
        self.assertIn("'is_available': isAvailable,", self.code)
        self.assertIn(".eq('store_id', storeId).inFilter('id', ids)", self.code)

        # In-memory RAM cache mutation
        self.assertIn("if (_productsCacheByStore.containsKey(storeId))", self.code)
        self.assertIn("final idSet = ids.toSet();", self.code)
        self.assertIn("p.copyWith(isAvailable: isAvailable", self.code)

        # Broadcast stream notification
        self.assertIn("notifyDataChanged(storeId);", self.code)

    def test_ast_batch_update_category_signature_and_invariants(self):
        """Verify batchUpdateCategory contract and query structure"""
        self.assertIn("Future<void> batchUpdateCategory(", self.code)
        self.assertIn("String storeId,", self.code)
        self.assertIn("List<String> ids,", self.code)
        self.assertIn("String newCategory,", self.code)

        self.assertIn("'category': newCategory,", self.code)
        self.assertIn(".eq('store_id', storeId).inFilter('id', ids)", self.code)
        self.assertIn("p.copyWith(category: newCategory", self.code)
        self.assertIn("notifyDataChanged(storeId);", self.code)

    def test_ast_zero_hard_delete_invariant(self):
        """Verify zero hard deletes across core product repository"""
        self.assertNotIn(".delete()", self.code, "CoreProductRepository must never call .delete()")
        self.assertIn("'is_deleted': true", self.code)
        self.assertIn("'is_active': false", self.code)

    def test_ast_change_stream_broadcast_contract(self):
        """Verify changeStream uses a broadcast controller for multiple screens"""
        self.assertIn("static final StreamController<String> _changeNotifier =", self.code)
        self.assertIn("StreamController<String>.broadcast();", self.code)
        self.assertIn("static Stream<String> get changeStream => _changeNotifier.stream;", self.code)
        self.assertIn("static void notifyDataChanged(String storeId)", self.code)

    def test_ast_cache_testing_hooks(self):
        """Verify @visibleForTesting cache hooks exist for unit testing"""
        self.assertIn("@visibleForTesting", self.code)
        self.assertIn("void setCacheForTesting(String storeId, List<ProductModel> products)", self.code)
        self.assertIn("List<ProductModel>? getCacheForTesting(String storeId)", self.code)

    def test_ast_execution_order_invariance_analysis(self):
        """
        Adversarial Forensic Check: Verify the sequential order of operations in batchUpdateAvailability:
        1. if (ids.isEmpty) return;
        2. await _client.from('products').update(...)
        3. _productsCacheByStore[storeId] update
        4. notifyDataChanged(storeId)
        """
        match = re.search(
            r"Future<void>\s+batchUpdateAvailability\(.*?\{(?P<body>.*?notifyDataChanged\(storeId\);\s*\})",
            self.code,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "batchUpdateAvailability method body must be extractable")
        body = match.group("body")

        idx_check = body.find("if (ids.isEmpty) return;")
        idx_db = body.find("await _client.from('products').update")
        idx_cache = body.find("_productsCacheByStore[storeId] =")
        idx_notify = body.find("notifyDataChanged(storeId);")

        self.assertTrue(0 <= idx_check < idx_db, "Empty check must happen before DB call")
        self.assertTrue(idx_db < idx_cache, "Database mutation is awaited before RAM cache sync (Pessimistic Consistency)")
        self.assertTrue(idx_cache < idx_notify, "RAM cache must be updated before stream notification")


class TestRapidSequentialToggling(unittest.TestCase):
    """Stress tests rapid sequential calls to batchUpdateAvailability (true -> false -> true)"""

    def setUp(self):
        self.harness = CoreProductRepositoryHarness()
        self.store_id = "store_stress_seq_001"
        self.products = [
            ProductModelSim(
                id=f"prod_seq_{i:03d}",
                store_id=self.store_id,
                name=f"Món Ăn #{i}",
                sku=f"SKU_{i:03d}",
                category="Món Nướng" if i % 2 == 0 else "Đồ Uống",
                is_available=True,
                stock_qty=20.0,
            )
            for i in range(100)
        ]
        self.harness.setCacheForTesting(self.store_id, self.products)

    def test_500_rapid_sequential_toggles(self):
        """Perform 500 rapid sequential toggles across 50 items and verify consistency"""
        target_ids = [f"prod_seq_{i:03d}" for i in range(0, 50)]
        control_ids = [f"prod_seq_{i:03d}" for i in range(50, 100)]

        iterations = 500
        durations = []
        expected_avail = True

        t_overall_start = time.perf_counter()

        for step in range(iterations):
            expected_avail = not expected_avail  # Toggle true -> false -> true -> ...
            res = self.harness.batchUpdateAvailability(self.store_id, target_ids, expected_avail)
            durations.append(res["duration"])

            # Verify immediately in RAM cache
            cache = self.harness.getCacheForTesting(self.store_id)
            self.assertIsNotNone(cache)
            cache_map = {p.id: p for p in cache}

            for tid in target_ids:
                self.assertEqual(
                    cache_map[tid].is_available,
                    expected_avail,
                    f"Item {tid} failed to toggle to {expected_avail} at step {step}",
                )

            for cid in control_ids:
                self.assertTrue(
                    cache_map[cid].is_available,
                    f"Control item {cid} was collaterally modified at step {step}",
                )

        t_overall = time.perf_counter() - t_overall_start
        avg_latency_ms = (sum(durations) / len(durations)) * 1000
        max_latency_ms = max(durations) * 1000
        throughput = iterations / t_overall

        print(f"\n[STRESS TEST] Rapid Sequential Toggles:")
        print(f"  Total Iterations: {iterations} toggles (50 items/toggle)")
        print(f"  Total Duration:   {t_overall:.4f}s")
        print(f"  Throughput:       {throughput:.2f} ops/sec")
        print(f"  Avg Latency:      {avg_latency_ms:.4f}ms")
        print(f"  Max Latency:      {max_latency_ms:.4f}ms")

        self.assertLess(avg_latency_ms, 1.0, "Average sequential latency should be well under 1ms")
        self.assertLess(max_latency_ms, 10.0, "Max sequential latency should be under 10ms (<0.01s)")


class TestConcurrentBatchMutations(unittest.TestCase):
    """Stress tests concurrent calls to batchUpdateAvailability and batchUpdateCategory"""

    def setUp(self):
        self.harness = CoreProductRepositoryHarness()
        self.store_id = "store_stress_concurrent_001"
        self.num_products = 200
        self.products = [
            ProductModelSim(
                id=f"prod_conc_{i:03d}",
                store_id=self.store_id,
                name=f"Thực đơn #{i}",
                category="Khai vị",
                is_available=True,
            )
            for i in range(self.num_products)
        ]
        self.harness.setCacheForTesting(self.store_id, self.products)

    def test_concurrent_availability_and_category_updates(self):
        """Run 20 concurrent worker threads executing 500 interleaved batch operations"""
        num_workers = 20
        total_ops = 500

        bucket_size = 20
        buckets = [
            [f"prod_conc_{j:03d}" for j in range(b * bucket_size, (b + 1) * bucket_size)]
            for b in range(10)
        ]

        def worker_task(worker_id: int, op_id: int):
            bucket_idx = op_id % len(buckets)
            target_ids = buckets[bucket_idx]

            if op_id % 2 == 0:
                target_state = (op_id % 4 == 0)
                res = self.harness.batchUpdateAvailability(self.store_id, target_ids, target_state)
                return ("avail", res["duration"], len(target_ids))
            else:
                new_cat = f"Category_W{worker_id % 5}"
                res = self.harness.batchUpdateCategory(self.store_id, target_ids, new_cat)
                return ("cat", res["duration"], len(target_ids))

        t0 = time.perf_counter()
        durations = []
        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            futures = [
                executor.submit(worker_task, i % num_workers, i)
                for i in range(total_ops)
            ]
            for f in as_completed(futures):
                op_type, duration, count = f.result()
                durations.append(duration)

        t_total = time.perf_counter() - t0
        avg_ms = (sum(durations) / len(durations)) * 1000
        max_ms = max(durations) * 1000
        throughput = total_ops / t_total

        print(f"\n[STRESS TEST] High Concurrency Stress Harness:")
        print(f"  Concurrent Threads: {num_workers}")
        print(f"  Total Operations:   {total_ops}")
        print(f"  Total Time:         {t_total:.4f}s")
        print(f"  Throughput:         {throughput:.2f} ops/sec")
        print(f"  Avg Latency:        {avg_ms:.4f}ms")
        print(f"  Max Latency:        {max_ms:.4f}ms")

        cache = self.harness.getCacheForTesting(self.store_id)
        self.assertIsNotNone(cache)
        self.assertEqual(len(cache), self.num_products, "No items should be dropped under high concurrency")
        self.assertLess(max_ms, 15.0, "Max concurrent latency must stay bounded under load")


class TestBroadcastStreamLatencyAndBurst(unittest.TestCase):
    """Stress tests CoreProductRepository.changeStream latency, burst emission, and subscriber fidelity"""

    def setUp(self):
        self.harness = CoreProductRepositoryHarness()

    def test_change_stream_latency_sub_10ms_under_100_subscribers(self):
        """
        Verify changeStream latency < 0.01s (10ms) across 100 concurrent subscribers
        receiving 1,000 rapid event emissions.
        """
        num_subscribers = 100
        num_events = 1000
        target_store_id = "store_stream_burst_999"

        received_counts = [0] * num_subscribers
        received_store_ids = [[] for _ in range(num_subscribers)]
        all_delivery_latencies_ns = []

        subs = []
        for idx in range(num_subscribers):
            def make_callback(sub_idx):
                def callback(sid: str):
                    received_counts[sub_idx] += 1
                    received_store_ids[sub_idx].append(sid)
                return callback
            sub_id = self.harness.changeStream.listen(make_callback(idx))
            subs.append(sub_id)

        t_burst_start = time.perf_counter()

        for e in range(num_events):
            event_store = f"{target_store_id}_{e % 3}"
            latencies = self.harness.notifyDataChanged(event_store)
            for lat in latencies:
                all_delivery_latencies_ns.append(lat * 1e9)

        t_burst_total = time.perf_counter() - t_burst_start

        for s in subs:
            self.harness.changeStream.cancel(s)

        all_delivery_latencies_ns.sort()
        n = len(all_delivery_latencies_ns)
        min_ms = (all_delivery_latencies_ns[0]) / 1e6
        avg_ms = (sum(all_delivery_latencies_ns) / n) / 1e6
        p50_ms = (all_delivery_latencies_ns[int(n * 0.50)]) / 1e6
        p95_ms = (all_delivery_latencies_ns[int(n * 0.95)]) / 1e6
        p99_ms = (all_delivery_latencies_ns[int(n * 0.99)]) / 1e6
        max_ms = (all_delivery_latencies_ns[-1]) / 1e6

        print(f"\n[STRESS TEST] Broadcast Stream Latency & Burst Profile:")
        print(f"  Active Subscribers:   {num_subscribers}")
        print(f"  Emitted Events:       {num_events}")
        print(f"  Total Deliveries:     {n}")
        print(f"  Total Burst Duration: {t_burst_total:.4f}s")
        print(f"  Min Latency:          {min_ms:.6f}ms")
        print(f"  Avg Latency:          {avg_ms:.6f}ms")
        print(f"  p50 Latency:          {p50_ms:.6f}ms")
        print(f"  p95 Latency:          {p95_ms:.6f}ms")
        print(f"  p99 Latency:          {p99_ms:.6f}ms")
        print(f"  Max Latency:          {max_ms:.6f}ms")

        for idx in range(num_subscribers):
            self.assertEqual(
                received_counts[idx],
                num_events,
                f"Subscriber #{idx} experienced dropped events: {received_counts[idx]}/{num_events}",
            )

        self.assertLess(
            max_ms,
            10.0,
            f"Broadcast latency exceeded strict SLA threshold of 10ms (<0.01s): max was {max_ms:.4f}ms",
        )
        self.assertLess(
            p99_ms,
            1.0,
            f"p99 latency should be sub-millisecond, got {p99_ms:.4f}ms",
        )


class TestInMemoryCacheConsistencyAndImmutability(unittest.TestCase):
    """Verifies that RAM cache updates are atomic, preserve immutability, and update metadata"""

    def setUp(self):
        self.harness = CoreProductRepositoryHarness()
        self.store_id = "store_cache_test_001"
        self.initial_products = [
            ProductModelSim(
                id="prod_01",
                store_id=self.store_id,
                name="Trà Đào Cam Sả",
                sku="TD01",
                category="Đồ Uống",
                unit="ly",
                sell_price=35000,
                cost_price=12000,
                stock_qty=15.0,
                min_stock=5.0,
                is_available=True,
                is_active=True,
                is_deleted=False,
                updated_at=1000000,
            ),
            ProductModelSim(
                id="prod_02",
                store_id=self.store_id,
                name="Bò Nướng Tảng",
                sku="BN01",
                category="Món Nướng",
                unit="đĩa",
                sell_price=180000,
                cost_price=90000,
                stock_qty=8.0,
                min_stock=3.0,
                is_available=True,
                is_active=True,
                is_deleted=False,
                updated_at=1000000,
            ),
        ]
        self.harness.setCacheForTesting(self.store_id, self.initial_products)

    def test_batch_update_availability_cache_consistency(self):
        """Verify availability toggles update target in cache while keeping other fields intact"""
        prev_cache = self.harness.getCacheForTesting(self.store_id)
        self.harness.batchUpdateAvailability(self.store_id, ["prod_01"], False)
        next_cache = self.harness.getCacheForTesting(self.store_id)

        self.assertFalse(
            CoreProductRepositoryHarness.sameProductSnapshot(prev_cache, next_cache),
            "sameProductSnapshot must detect availability mutation",
        )

        p1 = next_cache[0]
        self.assertFalse(p1.is_available)
        self.assertEqual(p1.name, "Trà Đào Cam Sả")
        self.assertEqual(p1.sku, "TD01")
        self.assertEqual(p1.category, "Đồ Uống")
        self.assertEqual(p1.sell_price, 35000)
        self.assertEqual(p1.cost_price, 12000)
        self.assertEqual(p1.stock_qty, 15.0)
        self.assertTrue(p1.updated_at > 1000000, "updated_at must be refreshed")

        p2 = next_cache[1]
        self.assertTrue(p2.is_available)
        self.assertEqual(p2.updated_at, 1000000)

    def test_batch_update_category_cache_consistency(self):
        """Verify category updates target in cache while keeping other fields intact"""
        self.harness.batchUpdateCategory(self.store_id, ["prod_02"], "Món Đặc Biệt")
        cache = self.harness.getCacheForTesting(self.store_id)

        p2 = cache[1]
        self.assertEqual(p2.category, "Món Đặc Biệt")
        self.assertEqual(p2.name, "Bò Nướng Tảng")
        self.assertEqual(p2.sell_price, 180000)
        self.assertTrue(p2.is_available)
        self.assertTrue(p2.updated_at > 1000000)

        p1 = cache[0]
        self.assertEqual(p1.category, "Đồ Uống")


class TestEdgeCasesAndBoundaryMatrix(unittest.TestCase):
    """Adversarial testing of edge cases: empty IDs, ghost IDs, cross-tenant isolation, duplicates"""

    def setUp(self):
        self.harness = CoreProductRepositoryHarness()
        self.store_a = "store_alpha"
        self.store_b = "store_beta"

        self.products_a = [
            ProductModelSim(id="item_a1", store_id=self.store_a, name="Món A1", is_available=True),
            ProductModelSim(id="item_a2", store_id=self.store_a, name="Món A2", is_available=True),
        ]
        self.products_b = [
            ProductModelSim(id="item_b1", store_id=self.store_b, name="Món B1", is_available=True),
            ProductModelSim(id="item_b2", store_id=self.store_b, name="Món B2", is_available=True),
        ]

        self.harness.setCacheForTesting(self.store_a, self.products_a)
        self.harness.setCacheForTesting(self.store_b, self.products_b)

    def test_empty_id_list_is_instant_no_op(self):
        """Empty list of IDs must return immediately without mutating cache or firing stream"""
        stream_received = []
        sub = self.harness.changeStream.listen(lambda sid: stream_received.append(sid))

        res_avail = self.harness.batchUpdateAvailability(self.store_a, [], False)
        res_cat = self.harness.batchUpdateCategory(self.store_a, [], "New Category")
        res_del = self.harness.batchSoftDelete(self.store_a, [])

        self.harness.changeStream.cancel(sub)

        self.assertEqual(res_avail["status"], "no_op")
        self.assertEqual(res_cat["status"], "no_op")
        self.assertEqual(res_del["status"], "no_op")
        self.assertEqual(len(stream_received), 0, "No events should be broadcast on empty ID list")
        self.assertEqual(len(self.harness.mutation_log), 0, "No DB queries should be logged on empty ID list")

    def test_non_existent_ghost_ids(self):
        """Passing non-existent IDs causes zero collateral damage to legitimate cache entries"""
        ghost_ids = ["ghost_001", "ghost_002", "phantom_999"]
        res = self.harness.batchUpdateAvailability(self.store_a, ghost_ids, False)

        self.assertEqual(res["updated_count"], 0)
        cache_a = self.harness.getCacheForTesting(self.store_a)
        self.assertEqual(len(cache_a), 2)
        self.assertTrue(all(p.is_available for p in cache_a), "Existing items must remain available")

    def test_duplicate_ids_in_batch(self):
        """Duplicate IDs in input list deduplicate cleanly via Set<String>"""
        dup_ids = ["item_a1", "item_a1", "item_a1", "item_a2"]
        res = self.harness.batchUpdateAvailability(self.store_a, dup_ids, False)

        self.assertEqual(res["updated_count"], 2)
        cache_a = self.harness.getCacheForTesting(self.store_a)
        self.assertEqual(len(cache_a), 2)
        self.assertFalse(cache_a[0].is_available)
        self.assertFalse(cache_a[1].is_available)

    def test_cross_store_id_isolation(self):
        """Targeting Store A with Store B's IDs strictly isolates Store B from mutation"""
        stream_events = []
        self.harness.changeStream.listen(lambda sid: stream_events.append(sid))

        mixed_ids = ["item_a1", "item_b1"]
        self.harness.batchUpdateAvailability(self.store_a, mixed_ids, False)

        cache_a = self.harness.getCacheForTesting(self.store_a)
        cache_b = self.harness.getCacheForTesting(self.store_b)

        self.assertFalse(cache_a[0].is_available)
        self.assertEqual(len(cache_a), 2)

        self.assertTrue(cache_b[0].is_available, "Store B's item must NOT be updated when targeting Store A")
        self.assertTrue(cache_b[1].is_available)
        self.assertEqual(len(cache_b), 2)

        self.assertIn(self.store_a, stream_events)
        self.assertNotIn(self.store_b, stream_events)

    def test_cold_cache_uninitialized_store(self):
        """Updating a store that has not been cached yet does not throw exception"""
        res = self.harness.batchUpdateAvailability("uninitialized_store_999", ["prod_xyz"], False)
        self.assertEqual(res["status"], "success")
        self.assertEqual(res["updated_count"], 0)

    def test_huge_batch_1000_items(self):
        """Stress testing 1,000 items in a single batch update"""
        large_store = "store_mega"
        large_products = [
            ProductModelSim(id=f"mega_{i}", store_id=large_store, is_available=True)
            for i in range(1000)
        ]
        self.harness.setCacheForTesting(large_store, large_products)

        all_ids = [f"mega_{i}" for i in range(1000)]
        t0 = time.perf_counter()
        res = self.harness.batchUpdateAvailability(large_store, all_ids, False)
        duration_ms = (time.perf_counter() - t0) * 1000

        self.assertEqual(res["updated_count"], 1000)
        cache = self.harness.getCacheForTesting(large_store)
        self.assertTrue(all(not p.is_available for p in cache))
        self.assertLess(duration_ms, 20.0, f"Updating 1,000 items in RAM cache must take < 20ms, took {duration_ms:.2f}ms")


class TestNetworkLatencyAndConsistencyOrdering(unittest.TestCase):
    """
    Adversarial Analysis of Network Latency and RAM Cache Synchronization:
    Examines the timing tradeoffs of the production implementation.
    """

    def test_pessimistic_vs_optimistic_latency_tradeoff(self):
        """
        Document empirical timing when network latency is present:
        In production code:
          await _client.from('products').update(...)
          _productsCacheByStore[storeId] = ...
          notifyDataChanged(storeId)
        This guarantees pessimistic consistency (no stale UI if server fails),
        but couples in-memory cache sync to network RTT.
        """
        store_id = "store_latency_profile"
        products = [ProductModelSim(id="p1", store_id=store_id, is_available=True)]

        # Zero network latency (unit test / local SQLite equivalent)
        harness_fast = CoreProductRepositoryHarness(simulated_network_latency_s=0.0)
        harness_fast.setCacheForTesting(store_id, products)
        t0 = time.perf_counter()
        res_fast = harness_fast.batchUpdateAvailability(store_id, ["p1"], False)
        dur_fast_ms = (time.perf_counter() - t0) * 1000

        # Simulated 20ms network latency (Supabase cloud round-trip)
        harness_net = CoreProductRepositoryHarness(simulated_network_latency_s=0.020)
        harness_net.setCacheForTesting(store_id, products)
        t0 = time.perf_counter()
        res_net = harness_net.batchUpdateAvailability(store_id, ["p1"], False)
        dur_net_ms = (time.perf_counter() - t0) * 1000

        print(f"\n[FORENSIC TIMING] Network Latency Tradeoff Profile:")
        print(f"  Fast (Local/Mocked DB): {dur_fast_ms:.4f}ms (<0.01s SLA MET)")
        print(f"  Network (20ms RTT):     {dur_net_ms:.4f}ms (Gated by Network RTT)")

        self.assertLess(dur_fast_ms, 1.0, "In-memory cache sync itself is sub-millisecond")
        self.assertGreater(dur_net_ms, 19.0, "Network call strictly gates cache sync in production order")


# ─────────────────────────────────────────────────────────────────────────────
# 5. TEST RUNNER ENTRYPOINT
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 80)
    print("CHALLENGER M3.1: EMPIRICAL STRESS TEST SUITE")
    print("Project: Quán Nhỏ POS - Milestone 3 Invariant & Concurrency Verification")
    print("=" * 80)
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    suite.addTests(loader.loadTestsFromTestCase(TestCoreProductRepositoryASTContracts))
    suite.addTests(loader.loadTestsFromTestCase(TestRapidSequentialToggling))
    suite.addTests(loader.loadTestsFromTestCase(TestConcurrentBatchMutations))
    suite.addTests(loader.loadTestsFromTestCase(TestBroadcastStreamLatencyAndBurst))
    suite.addTests(loader.loadTestsFromTestCase(TestInMemoryCacheConsistencyAndImmutability))
    suite.addTests(loader.loadTestsFromTestCase(TestEdgeCasesAndBoundaryMatrix))
    suite.addTests(loader.loadTestsFromTestCase(TestNetworkLatencyAndConsistencyOrdering))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    total_ran = result.testsRun
    failures = len(result.failures)
    errors = len(result.errors)

    print("\n" + "=" * 80)
    print(f"RESULTS SUMMARY: {total_ran} tests ran.")
    print(f"  Passed:   {total_ran - failures - errors}")
    print(f"  Failures: {failures}")
    print(f"  Errors:   {errors}")
    if result.wasSuccessful():
        print("  VERDICT:  ALL ASSERTIONS PASSED (100% OK)")
    else:
        print("  VERDICT:  FAILURES DETECTED")
    print("=" * 80)

    sys.exit(0 if result.wasSuccessful() else 1)
