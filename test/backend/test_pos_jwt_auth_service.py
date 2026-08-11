# test/backend/test_pos_jwt_auth_service.py
# ─────────────────────────────────────────────────────────────────────────────
# Backend Unit & Security Test Suite importing canonical services.pos_jwt_auth_service
# ─────────────────────────────────────────────────────────────────────────────
import unittest
from unittest.mock import patch
import json
import time
import base64
import hashlib
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_jwt_auth_service import (
    handle_pos_jwt_auth_request,
    constant_time_password_hash_check,
    issue_hs256_pos_jwt,
    PosJwtAuthError,
    _rate_limiter
)

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


class TestCanonicalPosJwtAuthService(unittest.TestCase):
    def setUp(self):
        with _rate_limiter._lock:
            _rate_limiter._history.clear()

        self.env_patcher = patch.dict(os.environ, {
            "SUPABASE_URL": "https://quannho.lpm.vn/supabase",
            "SUPABASE_ANON_KEY": "anon_key_test_value",
            "SUPABASE_JWT_SECRET": "test_supabase_jwt_secret_32_bytes_len"
        })
        self.env_patcher.start()

    def tearDown(self):
        self.env_patcher.stop()

    def test_01_malformed_json_returns_400(self):
        res = handle_pos_jwt_auth_request(b"invalid_json_payload")
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 400)
        self.assertEqual(res["error"], "MALFORMED_JSON")

    def test_02_missing_parameters_returns_400(self):
        res = handle_pos_jwt_auth_request(json.dumps({"phone": "0900000001"}).encode('utf-8'))
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 400)
        self.assertEqual(res["error"], "MISSING_PARAMETERS")

    def test_03_payload_too_large_returns_400(self):
        large_body = json.dumps({"phone": "0900000001", "pad": "x" * 5000}).encode('utf-8')
        res = handle_pos_jwt_auth_request(large_body)
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 400)
        self.assertEqual(res["error"], "PAYLOAD_TOO_LARGE")

    def test_04_missing_env_config_fails_closed_500(self):
        with patch.dict(os.environ, {}, clear=True):
            res = handle_pos_jwt_auth_request(json.dumps({
                "phone": "0900000001",
                "password": "pass",
                "store_id": "store-1"
            }).encode('utf-8'))
            self.assertFalse(res["success"])
            self.assertEqual(res["status"], 500)
            self.assertEqual(res["error"], "SERVER_CONFIG_ERROR")

    def test_05_http_non_tls_config_rejected(self):
        with patch.dict(os.environ, {
            "SUPABASE_URL": "http://insecure-http.com",
            "SUPABASE_ANON_KEY": "anon",
            "SUPABASE_JWT_SECRET": "sec"
        }):
            res = handle_pos_jwt_auth_request(json.dumps({
                "phone": "0900000001",
                "password": "pass",
                "store_id": "store-1"
            }).encode('utf-8'))
            self.assertFalse(res["success"])
            self.assertEqual(res["status"], 400)
            self.assertEqual(res["error"], "TLS_REQUIRED")

    @patch('urllib.request.urlopen')
    def test_06_valid_credentials_and_membership_returns_jwt(self, mock_urlopen):
        phone = "0900000001"
        password = "valid_password"
        salt = "qn_pos_2024_salt"
        correct_hash = hashlib.sha256(f"{phone}:{password}:{salt}".encode('utf-8')).hexdigest()

        def router(req, **kwargs):
            url = req.full_url if hasattr(req, 'full_url') else str(req)
            if "user_accounts" in url:
                return MockResponse([{"id": "usr-123", "phone": phone, "password_hash": correct_hash}])
            elif "store_members" in url:
                return MockResponse([{"user_id": "usr-123", "store_id": "str-456", "role": "owner"}])
            return MockResponse([])

        mock_urlopen.side_effect = router

        res = handle_pos_jwt_auth_request(json.dumps({
            "phone": phone,
            "password": password,
            "store_id": "str-456"
        }).encode('utf-8'))

        self.assertTrue(res["success"])
        self.assertEqual(res["status"], 200)
        self.assertIn("pos_jwt", res)
        self.assertEqual(res["store_id"], "str-456")
        self.assertEqual(res["role"], "owner")

    @patch('urllib.request.urlopen')
    def test_07_invalid_password_returns_generic_401(self, mock_urlopen):
        phone = "0900000001"
        def router(req, **kwargs):
            return MockResponse([{"id": "usr-123", "phone": phone, "password_hash": "invalid_hash_value"}])

        mock_urlopen.side_effect = router

        res = handle_pos_jwt_auth_request(json.dumps({
            "phone": phone,
            "password": "wrong_password",
            "store_id": "str-456"
        }).encode('utf-8'))

        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 401)
        self.assertEqual(res["error"], "INVALID_CREDENTIALS")
        self.assertEqual(res["message"], "Số điện thoại hoặc mật khẩu không chính xác")

    @patch('urllib.request.urlopen')
    def test_08_invalid_store_membership_returns_403(self, mock_urlopen):
        phone = "0900000001"
        password = "valid_password"
        salt = "qn_pos_2024_salt"
        correct_hash = hashlib.sha256(f"{phone}:{password}:{salt}".encode('utf-8')).hexdigest()

        def router(req, **kwargs):
            url = req.full_url if hasattr(req, 'full_url') else str(req)
            if "user_accounts" in url:
                return MockResponse([{"id": "usr-123", "phone": phone, "password_hash": correct_hash}])
            return MockResponse([])

        mock_urlopen.side_effect = router

        res = handle_pos_jwt_auth_request(json.dumps({
            "phone": phone,
            "password": password,
            "store_id": "forbidden-store-999"
        }).encode('utf-8'))

        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 403)
        self.assertEqual(res["error"], "STORE_MEMBERSHIP_FORBIDDEN")
        self.assertEqual(res["message"], "Tài khoản không thuộc cửa hàng này")

    def test_09_rate_limiting_blocks_after_5_failures(self):
        ip = "192.168.1.150"
        phone = "0900000001"

        with patch('urllib.request.urlopen') as mock_urlopen:
            mock_urlopen.side_effect = lambda req, **kwargs: MockResponse([])

            for _ in range(5):
                res = handle_pos_jwt_auth_request(json.dumps({
                    "phone": phone,
                    "password": "wrong",
                    "store_id": "str-456"
                }).encode('utf-8'), client_ip=ip)
                self.assertEqual(res["status"], 401)

            res_blocked = handle_pos_jwt_auth_request(json.dumps({
                "phone": phone,
                "password": "wrong",
                "store_id": "str-456"
            }).encode('utf-8'), client_ip=ip)

            self.assertFalse(res_blocked["success"])
            self.assertEqual(res_blocked["status"], 429)
            self.assertEqual(res_blocked["error"], "RATE_LIMIT_EXCEEDED")

    def test_10_zero_credential_logging_audit(self):
        phone = "0900000001"
        pwd = "secret_user_password_xyz"
        salt = "qn_pos_2024_salt"
        h = hashlib.sha256(f"{phone}:{pwd}:{salt}".encode('utf-8')).hexdigest()

        def router(req, **kwargs):
            url = req.full_url if hasattr(req, 'full_url') else str(req)
            if "user_accounts" in url:
                return MockResponse([{"id": "u1", "phone": phone, "password_hash": h}])
            elif "store_members" in url:
                return MockResponse([{"user_id": "u1", "store_id": "s1", "role": "owner"}])
            return MockResponse([])

        with self.assertLogs("pos_jwt_auth_service", level="INFO") as log_cm:
            with patch('urllib.request.urlopen', side_effect=router):
                res = handle_pos_jwt_auth_request(json.dumps({
                    "phone": phone,
                    "password": pwd,
                    "store_id": "s1"
                }).encode('utf-8'))

                self.assertTrue(res["success"])

            full_log_output = "\n".join(log_cm.output)
            self.assertNotIn("secret_user_password_xyz", full_log_output)
            self.assertNotIn("qn_pos_2024_salt", full_log_output)
            self.assertNotIn("test_supabase_jwt_secret", full_log_output)


if __name__ == "__main__":
    unittest.main()
