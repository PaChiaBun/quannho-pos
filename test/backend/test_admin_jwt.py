# test/backend/test_admin_jwt.py
# ─────────────────────────────────────────────────────────────────────────────
# Vé trang quản trị (/api/auth/admin-jwt) — tài khoản quản trị RIÊNG, đăng nhập bằng tên (ke-hoach-trang-quan-tri.md)
# ─────────────────────────────────────────────────────────────────────────────
import base64
import hashlib
import hmac
import json
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_jwt_auth_service import (
    handle_admin_jwt_request,
    handle_exchange_store_jwt_request,
    verify_and_decode_hs256_jwt,
    issue_hs256_admin_jwt,
    admin_account_login,
    _rate_limiter,
    _admin_ip_limiter,
    _admin_account_limiter,
    PosJwtAuthError,
)

SECRET = "test_supabase_jwt_secret_32_bytes_len"
ADMIN_ID = "11111111-2222-3333-4444-555555555555"


class MockResponse:
    def __init__(self, data, status=200):
        self.status = status
        self._raw = json.dumps(data).encode('utf-8')

    def read(self):
        return self._raw

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


def decode(token):
    h, pl, sig = token.split(".")
    want = base64.urlsafe_b64encode(hmac.new(SECRET.encode(), f"{h}.{pl}".encode(), hashlib.sha256).digest()).decode().rstrip("=")
    assert sig == want
    return json.loads(base64.urlsafe_b64decode(pl + "=" * (-len(pl) % 4)))


class AdminJwtTests(unittest.TestCase):
    def setUp(self):
        for lim in (_rate_limiter, _admin_ip_limiter, _admin_account_limiter):
            with lim._lock:
                lim._history.clear()
        self.env = patch.dict(os.environ, {
            "SUPABASE_URL": "https://quannho.lpm.vn/supabase",
            "SUPABASE_ANON_KEY": "anon_key_test_value",
            "SUPABASE_JWT_SECRET": SECRET,
            "SUPABASE_SERVICE_ROLE_KEY": "service_key_test_value",
        })
        self.env.start()

    def tearDown(self):
        self.env.stop()

    def body(self, username="pachiabun", password="MatKhauDai123"):
        return json.dumps({"username": username, "password": password}).encode()

    @patch('services.pos_jwt_auth_service.admin_account_login', return_value={"id": ADMIN_ID, "name": "Chủ Quán"})
    def test_admin_account_gets_4h_qn_admin_token(self, _login):
        res = handle_admin_jwt_request(self.body(username="PachiaBun"))
        self.assertTrue(res["success"])
        self.assertEqual(_login.call_args[0][2], "pachiabun")  # tên viết thường
        # Bộ kiểm vé của cổng (chỉ nhận role authenticated) phải TỪ CHỐI vé quản trị → không đổi được sang vé khác
        with self.assertRaises(PosJwtAuthError):
            verify_and_decode_hs256_jwt(res["admin_jwt"], SECRET, expected_token_use="admin")
        p = decode(res["admin_jwt"])
        self.assertEqual(p["sub"], ADMIN_ID)
        self.assertEqual(p["role"], "qn_admin")
        self.assertEqual(p["token_use"], "admin")
        self.assertNotIn("store_id", p)
        self.assertEqual(p["exp"] - p["iat"], 14400)

    @patch('services.pos_jwt_auth_service.admin_account_login', return_value=None)
    def test_wrong_credentials_single_error(self, _login):
        res = handle_admin_jwt_request(self.body())
        self.assertEqual(res["status"], 401)
        self.assertEqual(res["error"], "INVALID_CREDENTIALS")
        self.assertNotIn("admin_jwt", res)

    @patch('services.pos_jwt_auth_service.admin_account_login', return_value=None)
    def test_rate_limited_after_5_attempts(self, _login):
        for _ in range(5):
            handle_admin_jwt_request(self.body(), client_ip="203.0.113.9")
        res = handle_admin_jwt_request(self.body(), client_ip="203.0.113.9")
        self.assertEqual(res["status"], 429)

    @patch('services.pos_jwt_auth_service.admin_account_login', return_value=None)
    def test_attacker_ip_cannot_lock_out_owner_from_other_ip(self, _login):
        for _ in range(6):
            handle_admin_jwt_request(self.body(), client_ip="198.51.100.66")
        _login.return_value = {"id": ADMIN_ID, "name": "Chủ Quán"}
        res = handle_admin_jwt_request(self.body(), client_ip="203.0.113.5")
        self.assertTrue(res["success"])
        # thất bại quản trị không chặn đăng nhập bán hàng cùng mạng
        self.assertFalse(_rate_limiter.is_rate_limited("198.51.100.66", "0900000001"))

    @patch('services.pos_jwt_auth_service.admin_account_login', return_value=None)
    def test_account_wide_cap_across_ips(self, _login):
        for i in range(30):
            handle_admin_jwt_request(self.body(), client_ip=f"198.51.100.{i}")
        self.assertEqual(handle_admin_jwt_request(self.body(), client_ip="203.0.113.7")["status"], 429)

    def test_phone_login_no_longer_accepted(self):
        res = handle_admin_jwt_request(json.dumps({"phone": "0900000001", "password": "x"}).encode())
        self.assertEqual(res["status"], 400)

    def test_infra_failure_is_503_not_token(self):
        with patch('urllib.request.urlopen', side_effect=OSError("down")):
            res = handle_admin_jwt_request(self.body())
        self.assertEqual(res["status"], 503)
        self.assertNotIn("admin_jwt", res)

    def test_admin_account_login_reads_rpc(self):
        with patch('urllib.request.urlopen', return_value=MockResponse({"ok": True, "id": ADMIN_ID, "name": "A"})):
            self.assertEqual(admin_account_login("https://x/supabase", "k", "u", "p")["id"], ADMIN_ID)
        with patch('urllib.request.urlopen', return_value=MockResponse({"ok": False})):
            self.assertIsNone(admin_account_login("https://x/supabase", "k", "u", "p"))
        with patch('urllib.request.urlopen', return_value=MockResponse(True)):
            self.assertIsNone(admin_account_login("https://x/supabase", "k", "u", "p"))

    def test_missing_fields_bad_json_and_oversize(self):
        self.assertEqual(handle_admin_jwt_request(b"{")["status"], 400)
        self.assertEqual(handle_admin_jwt_request(json.dumps({"username": "a"}).encode())["status"], 400)
        self.assertEqual(handle_admin_jwt_request(b"x" * 5000)["status"], 400)
        self.assertEqual(handle_admin_jwt_request(self.body(username="a" * 41))["status"], 400)

    def test_admin_token_cannot_be_exchanged_for_store_token(self):
        token = issue_hs256_admin_jwt(ADMIN_ID, SECRET)
        res = handle_exchange_store_jwt_request(json.dumps({"store_id": "s-1"}).encode(),
                                                auth_header=f"Bearer {token}")
        self.assertFalse(res["success"])


if __name__ == '__main__':
    unittest.main()
