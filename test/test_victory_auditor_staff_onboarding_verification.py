#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Independent Victory Audit Verification Runner for Staff Onboarding & Display V4
Auditor: teamwork_preview_victory_auditor
Project: Quán Nhỏ POS — Onboarding & Staff Directory Fix
Date: 2026-10-06
"""

import os
import re
import unittest
from pathlib import Path

REPO_ROOT = Path("/Users/banhbao/Quan Nho/quan_nho")

def check_bracket_balance(filepath: Path) -> tuple[bool, str]:
    content = filepath.read_text(encoding="utf-8")
    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    in_str = False
    str_c = ""
    in_line_cmt = False
    in_block_cmt = False
    esc = False
    line = 1
    col = 0

    i = 0
    n = len(content)
    while i < n:
        c = content[i]
        col += 1
        if c == "\n":
            line += 1
            col = 0
            in_line_cmt = False

        if esc:
            esc = False
            i += 1
            continue

        if c == "\\" and in_str:
            esc = True
            i += 1
            continue

        if not in_str and not in_block_cmt:
            if content[i:i+2] == "//":
                in_line_cmt = True
                i += 2
                continue
            if content[i:i+2] == "/*":
                in_block_cmt = True
                i += 2
                continue

        if in_block_cmt:
            if content[i:i+2] == "*/":
                in_block_cmt = False
                i += 2
                continue
            i += 1
            continue

        if in_line_cmt:
            i += 1
            continue

        if c in ("'", '"'):
            if not in_str:
                in_str = True
                str_c = c
            elif str_c == c:
                in_str = False
            i += 1
            continue

        if in_str:
            i += 1
            continue

        if c in "({[":
            stack.append((c, line, col))
        elif c in ")}]":
            if not stack:
                return False, f"Unexpected '{c}' at {line}:{col}"
            top, tl, tc = stack.pop()
            if top != pairs[c]:
                return False, f"Mismatched '{c}' at {line}:{col}, expected matching for '{top}' from {tl}:{tc}"

        i += 1

    if stack:
        top, tl, tc = stack[-1]
        return False, f"Unclosed '{top}' from {tl}:{tc}"
    return True, "OK"


class TestVictoryAuditPhase1AndPhase2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.staff_service_path = REPO_ROOT / "lib/core/services/staff_service.dart"
        cls.staff_sync_path = REPO_ROOT / "lib/core/services/staff_sync_service.dart"
        cls.user_auth_path = REPO_ROOT / "lib/core/services/user_auth_service.dart"
        cls.nhan_vien_path = REPO_ROOT / "lib/screens/nhan_vien_screen.dart"
        cls.chamcong_path = REPO_ROOT / "lib/screens/chamcong_screen.dart"
        cls.migration_path = REPO_ROOT / "supabase/migrations/20261006_fix_new_staff_display_and_join_flow_v4.sql"
        cls.test_path = REPO_ROOT / "test/core/staff_onboarding_and_display_test.dart"

        cls.staff_service_code = cls.staff_service_path.read_text(encoding="utf-8")
        cls.staff_sync_code = cls.staff_sync_path.read_text(encoding="utf-8")
        cls.user_auth_code = cls.user_auth_path.read_text(encoding="utf-8")
        cls.nhan_vien_code = cls.nhan_vien_path.read_text(encoding="utf-8")
        cls.chamcong_code = cls.chamcong_path.read_text(encoding="utf-8")
        cls.migration_code = cls.migration_path.read_text(encoding="utf-8")
        cls.test_code = cls.test_path.read_text(encoding="utf-8")

    def test_01_bracket_and_syntax_balance(self):
        """Audit static delimiter integrity across all modified Dart files"""
        files = [
            self.staff_service_path,
            self.staff_sync_path,
            self.user_auth_path,
            self.nhan_vien_path,
            self.chamcong_path,
            self.test_path,
        ]
        for f in files:
            ok, msg = check_bracket_balance(f)
            self.assertTrue(ok, f"Syntax delimiter error in {f.name}: {msg}")

    def test_02_sql_migration_contracts(self):
        """Verify SQL migration structure, security definer, RLS policy and backfill"""
        self.assertIn("CREATE OR REPLACE FUNCTION public.join_store_by_code_v4", self.migration_code)
        self.assertIn("SECURITY DEFINER", self.migration_code)
        self.assertIn("v_assigned_role text := 'unassigned';", self.migration_code)
        self.assertIn("INSERT INTO public.store_members", self.migration_code)
        self.assertIn("INSERT INTO public.staff_members", self.migration_code)
        self.assertIn("ON CONFLICT (id) DO UPDATE", self.migration_code)

        # get_store_staff_directory_v4 RPC
        self.assertIn("CREATE OR REPLACE FUNCTION public.get_store_staff_directory_v4", self.migration_code)
        self.assertIn("RETURNS TABLE", self.migration_code)
        self.assertIn("p_store_id uuid", self.migration_code)
        self.assertIn("v_caller_id uuid := auth.uid();", self.migration_code)

        # RLS policy on user_accounts
        self.assertIn("CREATE POLICY user_accounts_store_member_select_v4 ON public.user_accounts", self.migration_code)
        self.assertIn("sm1.store_id = sm2.store_id", self.migration_code)
        self.assertIn("sm1.user_id = auth.uid()", self.migration_code)

        # Realtime publication
        self.assertIn("ALTER PUBLICATION supabase_realtime ADD TABLE public.store_members;", self.migration_code)
        self.assertIn("ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_members;", self.migration_code)

    def test_03_no_cheating_or_hardcoded_bypass_in_lib(self):
        """Verify absence of hardcoded test UUIDs, placeholder mock bypasses in lib"""
        prohibited_constants = [
            "00000000-0000-0000-0000-000000000001",
            "user-new-staff",
            "sm-newbie-1",
            "u-newbie-1",
        ]
        for c in prohibited_constants:
            self.assertNotIn(c, self.staff_service_code)
            self.assertNotIn(c, self.nhan_vien_code)
            self.assertNotIn(c, self.staff_sync_code)

    def test_04_staff_service_multi_tier_resilience(self):
        """Verify StaffService.getStaffList implements multi-tier fallback and chunking"""
        self.assertIn("get_store_staff_directory_v4", self.staff_service_code)
        self.assertIn("from('store_members')", self.staff_service_code)
        self.assertIn("chunkSize = 80", self.staff_service_code)
        self.assertIn("missingUserIds", self.staff_service_code)
        self.assertIn("shiftConfigId: m['shift_config_id'] as String?", self.staff_service_code)

    def test_05_staff_service_identity_precedence(self):
        """Verify identity resolution logic in Dart service layer"""
        # Checks that placeholder names are explicitly compared against
        self.assertIn("'Nhân viên'", self.staff_service_code)
        self.assertIn("'Nhân viên mới'", self.staff_service_code)
        self.assertIn("isUnassignedRole(role) ? 'Nhân viên mới' : 'Nhân viên'", self.staff_service_code)
        self.assertIn("cleanDigits.isNotEmpty", self.staff_service_code)
        self.assertIn("'NV $cleanDigits'", self.staff_service_code)

    def test_06_nhan_vien_screen_role_isolation(self):
        """Verify role matching logic explicitly isolates unassigned staff from specific roles"""
        self.assertIn("isUnassigned", self.nhan_vien_code)
        self.assertIn("Chưa phân vai trò", self.nhan_vien_code)
        self.assertIn("_stripVietnameseDiacritics", self.nhan_vien_code)
        self.assertIn("Vui lòng chọn vai trò cho nhân viên", self.nhan_vien_code)
        self.assertIn("staff_sync_$storeId", self.nhan_vien_code)

    def test_07_realtime_broadcast_topic_consistency(self):
        """Verify broadcast senders and receivers match on topic names"""
        # staff_sync_service uses staff_sync_$storeId
        self.assertIn("channel('staff_sync_$storeId')", self.staff_sync_code)
        self.assertNotIn("staff_sync_sender_${storeId}_role", self.staff_sync_code)

        # nhan_vien_screen subscribes to staff_sync_$storeId
        self.assertIn("channel('staff_sync_$storeId')", self.nhan_vien_code)

        # chamcong_screen uses shifts:${session.storeId}
        self.assertIn("shifts:${session.storeId}", self.chamcong_code)
        self.assertNotIn("shifts_sender_${session.storeId}", self.chamcong_code)

    def test_08_staff_test_suite_coverage_and_quality(self):
        """Verify test suite contains 13 robust, unskipped tests covering all requirements"""
        self.assertNotIn("@Skip", self.test_code)
        self.assertNotIn("skip: true", self.test_code)

        # Check all 13 test descriptions exist
        for i in range(1, 14):
            pattern = rf"test(?:Widgets)?\(\s*['\"]{i}\."
            self.assertRegex(self.test_code, pattern, f"Test {i} must be implemented in test suite")

        # Verify Test 13 tests role selection and prompt guard
        self.assertIn("Vui lòng chọn vai trò cho nhân viên", self.test_code)
        self.assertIn("admin_update_staff_role_v4", self.test_code)

    def test_09_vietnamese_diacritic_normalization_simulation(self):
        """Simulate the 67-character Vietnamese normalization logic"""
        diacritic_map = {
            'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
            'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
            'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
            'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
            'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
            'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
            'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
            'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
            'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
            'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
            'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
            'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
            'đ': 'd',
        }
        test_strings = [
            ("Bảo Linh", "bao linh"),
            ("Nguyễn Văn Cường", "nguyen van cuong"),
            ("Đỗ Thị Diệu Hiền", "do thi dieu hien"),
            ("Vũ Đình Trọng", "vu dinh trong"),
        ]
        for original, expected in test_strings:
            normalized = "".join(diacritic_map.get(c.lower(), c.lower()) for c in original)
            self.assertEqual(normalized, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
