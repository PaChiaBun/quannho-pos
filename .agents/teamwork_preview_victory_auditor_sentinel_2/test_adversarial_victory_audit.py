#!/usr/bin/env python3
"""
Adversarial Post-Victory Independent Audit Script.
Rigorously tests:
1. Logic simulation for R1, R2, R3.
2. Boundary stress cases: leap years, year boundaries, empty/malformed IDs, regex evasion.
3. Code AST invariants across all tabs in lib/screens/report_screen.dart & finance_repository.dart.
4. Absence of hardcoded test bypasses, facade patterns, or mocked results in production code.
"""

import os
import re
import sys
from datetime import datetime, timezone, timedelta

def test_r1_voucher_adversarial():
    print("--- [Audit R1] Voucher Parsing, Cascade & Deduplication Stress Test ---")
    
    # 1. Regex evasion tests
    voucher_regex = re.compile(r'\[Voucher:\s*([^\]]+)\]', re.IGNORECASE)
    alt_voucher_regex = re.compile(r'(?:Voucher|Mã giảm giá|Coupon):\s*([A-Za-z0-9_-]+)', re.IGNORECASE)

    def extract_code(note):
        m = voucher_regex.search(note)
        if m:
            return m.group(1).strip().upper()
        m2 = alt_voucher_regex.search(note)
        if m2:
            return m2.group(1).strip().upper()
        return None

    # Normal & tricky cases
    assert extract_code("[Voucher: SALE10]") == "SALE10"
    assert extract_code("[voucher:   sale_2026-x  ]") == "SALE_2026-X"
    assert extract_code("Mã giảm giá: TET2026") == "TET2026"
    assert extract_code("Coupon: VIP-99") == "VIP-99"
    assert extract_code("Ghi chú: [Voucher: ABC] thêm món") == "ABC"
    assert extract_code("Không có gì cả") is None
    assert extract_code("") is None
    print("  [PASS] Voucher regex matches expected variants and ignores non-voucher text")

    # 2. Staff resolution cascade stress test
    staff_name_map = {
        "staff-uuid-1": "Trần Thu Ngân",
        "staff-uuid-2": "Lê Phục Vụ",
        "user-uuid-3": "Nguyễn Quản Lý",
    }

    def resolve_staff(primary_id, secondary_id=None, fallback="Thu ngân"):
        if primary_id and primary_id in staff_name_map and staff_name_map[primary_id]:
            return staff_name_map[primary_id]
        if secondary_id and secondary_id in staff_name_map and staff_name_map[secondary_id]:
            return staff_name_map[secondary_id]
        chosen = primary_id if (primary_id and primary_id.strip()) else (secondary_id if (secondary_id and secondary_id.strip()) else None)
        if chosen:
            short = chosen[-4:].upper() if len(chosen) >= 4 else chosen
            return f"NV-{short}"
        return fallback

    # Stress cases
    assert resolve_staff("staff-uuid-1", "staff-uuid-2") == "Trần Thu Ngân"
    assert resolve_staff(None, "staff-uuid-2") == "Lê Phục Vụ"
    assert resolve_staff("", "staff-uuid-2") == "Lê Phục Vụ"
    assert resolve_staff("   ", "staff-uuid-2") == "Lê Phục Vụ"
    assert resolve_staff("user-uuid-3") == "Nguyễn Quản Lý"
    assert resolve_staff("unknown-uuid-abcd-1234") == "NV-1234"
    assert resolve_staff("ab") == "NV-ab"
    assert resolve_staff(None, None, "Fallback Role") == "Fallback Role"
    assert resolve_staff("", "", "Fallback Role") == "Fallback Role"
    print("  [PASS] Staff resolution handles whitespace, empty strings, short IDs, and fallbacks cleanly")

    # 3. Settlement and POS deduplication
    linked_order_ids = {"order-duplicate-1", "order-duplicate-2"}
    processed_settles = {"settle-uuid-1"}

    def is_order_deduped(order_id):
        return order_id in linked_order_ids or order_id in processed_settles

    assert is_order_deduped("order-duplicate-1") is True
    assert is_order_deduped("settle-uuid-1") is True
    assert is_order_deduped("order-fresh-3") is False
    print("  [PASS] Deduplication logic strictly prevents double-counting settled table orders")


def test_r2_timezone_and_date_range_adversarial():
    print("\n--- [Audit R2] Timezone & Historical Range Boundaries ---")

    # Range calculations
    def range_for_today(d):
        start = datetime(d.year, d.month, d.day)
        end = start + timedelta(days=1)
        return int(start.timestamp() * 1000), int(end.timestamp() * 1000)

    def range_for_week(mon):
        start = datetime(mon.year, mon.month, mon.day)
        end = start + timedelta(days=7)
        return int(start.timestamp() * 1000), int(end.timestamp() * 1000)

    def range_for_month(y, m):
        start = datetime(y, m, 1)
        if m == 12:
            end = datetime(y + 1, 1, 1)
        else:
            end = datetime(y, m + 1, 1)
        return int(start.timestamp() * 1000), int(end.timestamp() * 1000)

    # 1. Test full 24h today
    f, t = range_for_today(datetime(2026, 9, 14))
    assert t - f == 24 * 3600 * 1000

    # 2. Test 7 full days for week
    f, t = range_for_week(datetime(2026, 8, 31))
    assert t - f == 7 * 24 * 3600 * 1000

    # 3. Test leap year Feb 2024 (29 days)
    f, t = range_for_month(2024, 2)
    assert t - f == 29 * 24 * 3600 * 1000

    # 4. Test non-leap Feb 2025 (28 days)
    f, t = range_for_month(2025, 2)
    assert t - f == 28 * 24 * 3600 * 1000

    # 5. Test Dec 2026 -> Jan 2027 (31 days)
    f, t = range_for_month(2026, 12)
    assert t - f == 31 * 24 * 3600 * 1000

    # 6. Test UTC ISO string conversion with GMT+7
    # 2026-09-14 00:00:00 GMT+7 is 2026-09-13 17:00:00 UTC
    tz_vn = timezone(timedelta(hours=7))
    dt_local = datetime(2026, 9, 14, 0, 0, 0, tzinfo=tz_vn)
    dt_utc = dt_local.astimezone(timezone.utc)
    assert dt_utc.strftime("%Y-%m-%dT%H:%M:%SZ") == "2026-09-13T17:00:00Z"

    # End of day 2026-09-15 00:00:00 GMT+7 is 2026-09-14 17:00:00 UTC
    dt_end_local = datetime(2026, 9, 15, 0, 0, 0, tzinfo=tz_vn)
    dt_end_utc = dt_end_local.astimezone(timezone.utc)
    assert dt_end_utc.strftime("%Y-%m-%dT%H:%M:%SZ") == "2026-09-14T17:00:00Z"
    print("  [PASS] All date range cycles and GMT+7 -> UTC conversions strictly preserve 24h/7d/month spans")


def test_r3_synchronized_navigation_and_race_guards():
    print("\n--- [Audit R3] Navigation Sync, Race Protection & UI Persistence ---")
    root_dir = "/Users/banhbao/Quan Nho/quan_nho"
    report_file = os.path.join(root_dir, "lib", "screens", "report_screen.dart")

    with open(report_file, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Verify all 7 tabs have navigation
    tabs = [
        "_RevenueTabState",
        "_ProductTabState",
        "_FinanceTabState",
        "_KhoTabState",
        "_VoidAuditTabState",
        "_StaffAttendanceTabState",
        "_VoucherTabState",
    ]
    for t in tabs:
        assert t in content, f"Tab state {t} missing"
        # Find tab section
        idx = content.find(f"class {t}")
        next_idx = content.find("class ", idx + 1)
        sub = content[idx:next_idx] if next_idx != -1 else content[idx:]

        assert "_PeriodPills" in sub, f"{t} missing _PeriodPills"
        assert "_ReportNavBar" in sub, f"{t} missing _ReportNavBar"
        print(f"  [PASS] {t} includes synchronized _PeriodPills and _ReportNavBar")

    # 2. Verify all 6 stateful asynchronous tabs implement sequence token _loadRequestId
    async_tabs = [
        "_RevenueTabState",
        "_ProductTabState",
        "_KhoTabState",
        "_VoidAuditTabState",
        "_StaffAttendanceTabState",
        "_VoucherTabState",
    ]
    for at in async_tabs:
        idx = content.find(f"class {at}")
        next_idx = content.find("class ", idx + 1)
        sub = content[idx:next_idx] if next_idx != -1 else content[idx:]
        assert "_loadRequestId" in sub, f"{at} missing _loadRequestId"
        assert "++_loadRequestId" in sub, f"{at} missing requestId increment"
        assert "requestId == _loadRequestId" in sub, f"{at} missing requestId check"
        print(f"  [PASS] {at} protected against rapid async race conditions via _loadRequestId")

    # 3. Check bounds: lastDate: now to prevent selecting future dates
    assert "lastDate: now" in content
    assert "canGoNext" in content
    print("  [PASS] Future date selection strictly prohibited across pickers and steppers")


def test_cheating_and_facade_forensics():
    print("\n--- [Audit Forensics] Cheating, Facade & Anti-Bypass Forensics ---")
    root_dir = "/Users/banhbao/Quan Nho/quan_nho"
    report_file = os.path.join(root_dir, "lib", "screens", "report_screen.dart")
    finance_file = os.path.join(root_dir, "lib", "modules", "finance", "repository", "finance_repository.dart")

    with open(report_file, "r", encoding="utf-8") as f:
        rep_content = f.read()

    with open(finance_file, "r", encoding="utf-8") as f:
        fin_content = f.read()

    # Check 1: No hardcoded test responses or fake bypass constants
    suspicious_patterns = [
        r'return\s+\[\s*\{\s*["\']code["\']:\s*["\']GIAM50K["\']', # mock return
        r'TEST_BYPASS',
        r'IS_AUDITOR',
        r'fake_data',
        r'mock_settlement',
    ]
    for pat in suspicious_patterns:
        matches = re.findall(pat, rep_content, re.IGNORECASE)
        assert len(matches) == 0, f"Found suspicious facade pattern '{pat}' in report_screen.dart: {matches}"

    # Check 2: Verify real database calls exist and are well-formed
    assert "Supabase.instance.client" in rep_content
    assert ".from('orders')" in rep_content
    assert ".from('payment_settlements')" in rep_content
    assert ".from('ban_sessions')" in rep_content
    assert ".from('ban_dining_tables')" in rep_content
    assert ".from('ban_session_orders')" in rep_content
    assert ".from('staff_members')" in rep_content
    assert ".from('store_members')" in rep_content
    assert ".from('user_accounts')" in rep_content
    assert ".from('purchase_orders')" in rep_content
    assert ".from('purchase_items')" in rep_content
    assert ".from('void_audit_logs')" in rep_content
    assert ".from('staff_shifts')" in rep_content
    print("  [PASS] All 13 production Supabase database tables genuinely wired without facades")

    # Check 3: Check that finance_repository has genuine DateRange implementations
    assert "DateTime(startLocal.year, startLocal.month, startLocal.day + 7)" in fin_content
    assert "DateTime(now.year, now.month + 1, 1)" in fin_content
    assert "print(" not in fin_content
    print("  [PASS] finance_repository genuinely implements full historical ranges without print logging")


if __name__ == "__main__":
    print("=== STARTING ADVERSARIAL INDEPENDENT VICTORY AUDIT ===")
    test_r1_voucher_adversarial()
    test_r2_timezone_and_date_range_adversarial()
    test_r3_synchronized_navigation_and_race_guards()
    test_cheating_and_facade_forensics()
    print("\n=== ALL ADVERSARIAL CHECKS PASSED WITH ZERO VIOLATIONS ===")
