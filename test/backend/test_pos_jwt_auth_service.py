# test/backend/test_pos_jwt_auth_service.py
# ─────────────────────────────────────────────────────────────────────────────
# Backend Unit & Security Test Suite importing canonical services.pos_jwt_auth_service
# ─────────────────────────────────────────────────────────────────────────────
import base64
import json
import os
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_jwt_auth_service import (
    handle_pos_jwt_auth_request,
    handle_onboarding_jwt_request,
    handle_exchange_store_jwt_request,
    issue_hs256_pos_jwt,
    issue_hs256_onboarding_jwt,
    verify_and_decode_hs256_jwt,
    consume_onboarding_exchange_rpc,
    _rate_limiter,
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
    def test_06_valid_credentials_and_membership_returns_jwt_with_strict_claims(self, mock_urlopen):
        phone = "0900000001"
        password = "valid_password"
        mock_urlopen.return_value = MockResponse({
            "success": True,
            "status": 200,
            "user_id": "usr-123",
            "selected_role": "owner",
        })

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

        token = res["pos_jwt"]
        parts = token.split(".")
        self.assertEqual(len(parts), 3)
        padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))

        self.assertEqual(payload["iss"], "supabase")
        self.assertEqual(payload["aud"], "authenticated")
        self.assertEqual(payload["role"], "authenticated")
        self.assertEqual(payload["staff_role"], "owner")
        self.assertEqual(payload["sub"], "usr-123")
        self.assertEqual(payload["store_id"], "str-456")
        self.assertIn("iat", payload)
        self.assertIn("exp", payload)
        self.assertIn("jti", payload)
        self.assertTrue(payload["exp"] > payload["iat"])

    @patch('urllib.request.urlopen')
    def test_07_invalid_password_returns_generic_401(self, mock_urlopen):
        phone = "0900000001"
        mock_urlopen.return_value = MockResponse({
            "success": False,
            "status": 401,
            "error_code": "INVALID_CREDENTIALS",
            "message": "Số điện thoại hoặc mật khẩu không chính xác",
        })

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
        mock_urlopen.return_value = MockResponse({
            "success": False,
            "status": 403,
            "error_code": "STORE_MEMBERSHIP_FORBIDDEN",
            "message": "Tài khoản không thuộc cửa hàng này",
        })

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
            mock_urlopen.side_effect = lambda req, **kwargs: MockResponse({
                "success": False,
                "status": 401,
                "error_code": "INVALID_CREDENTIALS",
                "message": "Số điện thoại hoặc mật khẩu không chính xác",
            })

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

        def router(req, **kwargs):
            self.assertIn('/rest/v1/rpc/verify_user_login_v4', req.full_url)
            self.assertNotIn('user_accounts', req.full_url)
            self.assertNotIn('store_members', req.full_url)
            return MockResponse({
                "success": True,
                "status": 200,
                "user_id": "u1",
                "selected_role": "owner",
            })

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

    def test_11_jti_is_unique_for_tokens_issued_in_same_second(self):
        token_a = issue_hs256_pos_jwt("u1", "s1", "secret", staff_role="cashier")
        token_b = issue_hs256_pos_jwt("u1", "s1", "secret", staff_role="cashier")

        def decode_payload(token):
            encoded = token.split('.')[1]
            padded = encoded + '=' * ((4 - len(encoded) % 4) % 4)
            return json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))

        self.assertNotEqual(decode_payload(token_a)["jti"], decode_payload(token_b)["jti"])

    @patch('services.pos_jwt_auth_service.verify_user_credentials_and_membership')
    def test_12_infrastructure_failure_does_not_consume_auth_attempts(self, mock_verify):
        from services.pos_jwt_auth_service import PosJwtAuthError

        mock_verify.side_effect = PosJwtAuthError(
            "unavailable",
            status_code=503,
            error_code="AUTH_RPC_UNAVAILABLE",
        )
        with patch.dict(os.environ, {
            "SUPABASE_URL": "https://example.supabase.co",
            "SUPABASE_ANON_KEY": "anon",
            "SUPABASE_JWT_SECRET": "secret",
        }, clear=False):
            for _ in range(7):
                result = handle_pos_jwt_auth_request(json.dumps({
                    "phone": "0900000012",
                    "password": "password",
                    "store_id": "store-12",
                }), client_ip="192.0.2.12")

        self.assertEqual(result["status"], 503)
        self.assertEqual(result["error"], "AUTH_RPC_UNAVAILABLE")

    @patch('urllib.request.urlopen')
    def test_13_onboarding_jwt_issued_for_valid_user_without_store(self, mock_urlopen):
        mock_urlopen.return_value = MockResponse({
            "success": True,
            "status": 200,
            "user_id": "user-zero-store-123",
            "stores": []
        })

        res = handle_onboarding_jwt_request(json.dumps({
            "phone": "0912345678",
            "password": "ValidPassword123"
        }).encode('utf-8'))

        self.assertTrue(res["success"])
        self.assertEqual(res["status"], 200)
        self.assertIn("onboarding_jwt", res)

        token = res["onboarding_jwt"]
        payload = verify_and_decode_hs256_jwt(token, "test_supabase_jwt_secret_32_bytes_len", expected_token_use="onboarding")
        self.assertEqual(payload["sub"], "user-zero-store-123")
        self.assertEqual(payload["token_use"], "onboarding")
        self.assertNotIn("store_id", payload)
        self.assertEqual(payload["exp"] - payload["iat"], 600)

    @patch('services.pos_jwt_auth_service.consume_onboarding_exchange_rpc', return_value={"success": True, "role": "owner"})
    def test_14_onboarding_jwt_exchange_success_with_valid_membership(self, mock_consume):
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len")

        res = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-xyz-789"}).encode('utf-8'),
            auth_header=f"Bearer {token}"
        )

        self.assertTrue(res["success"])
        self.assertEqual(res["status"], 200)
        self.assertEqual(res["store_id"], "store-xyz-789")
        self.assertEqual(res["role"], "owner")
        self.assertIn("pos_jwt", res)

        # Decoded POS JWT has store_id and is authenticated
        pos_payload = verify_and_decode_hs256_jwt(res["pos_jwt"], "test_supabase_jwt_secret_32_bytes_len")
        self.assertEqual(pos_payload["sub"], "user-123")
        self.assertEqual(pos_payload["store_id"], "store-xyz-789")
        self.assertEqual(pos_payload["staff_role"], "owner")
        self.assertTrue(mock_consume.called)

    @patch('services.pos_jwt_auth_service.consume_onboarding_exchange_rpc', return_value={"success": False, "error_code": "STORE_MEMBERSHIP_FORBIDDEN"})
    def test_15_onboarding_jwt_exchange_fails_when_store_not_joined(self, mock_consume):
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len")

        res = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "forbidden-store-999"}).encode('utf-8'),
            auth_header=f"Bearer {token}"
        )

        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 403)
        self.assertEqual(res["error"], "STORE_MEMBERSHIP_FORBIDDEN")

    @patch('services.pos_jwt_auth_service.consume_onboarding_exchange_rpc', side_effect=[
        {"success": True, "role": "cashier"},
        {"success": False, "error_code": "TOKEN_REPLAY_REJECTED"},
    ])
    def test_16_onboarding_jwt_exchange_rejects_replay(self, mock_consume):
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len")

        # First exchange succeeds
        res1 = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-1"}).encode('utf-8'),
            auth_header=f"Bearer {token}"
        )
        self.assertTrue(res1["success"])

        # Second exchange with identical token is rejected (replay attack)
        res2 = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-1"}).encode('utf-8'),
            auth_header=f"Bearer {token}"
        )
        self.assertFalse(res2["success"])
        self.assertEqual(res2["status"], 401)
        self.assertEqual(res2["error"], "TOKEN_REPLAY_REJECTED")
        self.assertEqual(mock_consume.call_count, 2)

    def test_17_onboarding_jwt_exchange_rejects_tampered_signature_or_token_use(self):
        token = issue_hs256_pos_jwt("user-123", "store-1", "test_supabase_jwt_secret_32_bytes_len")

        # Standard POS JWT cannot be exchanged via onboarding exchange endpoint
        res = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-1"}).encode('utf-8'),
            auth_header=f"Bearer {token}"
        )
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 403)
        self.assertEqual(res["error"], "INVALID_TOKEN_USE")

    def test_18_exchange_fails_closed_without_persistent_replay_store(self):
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len")

        with patch.dict(os.environ, {"SUPABASE_SERVICE_ROLE_KEY": ""}, clear=False):
            res = handle_exchange_store_jwt_request(
                json.dumps({"store_id": "store-1"}).encode("utf-8"),
                auth_header=f"Bearer {token}",
            )

        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 503)
        self.assertEqual(res["error"], "REPLAY_STORE_UNAVAILABLE")

    @patch('urllib.request.urlopen')
    def test_19_onboarding_is_rejected_for_account_with_existing_store(self, mock_urlopen):
        mock_urlopen.return_value = MockResponse({
            "success": True,
            "status": 200,
            "user_id": "user-existing",
            "stores": [{"store_id": "store-1"}],
        })

        res = handle_onboarding_jwt_request(json.dumps({
            "phone": "0912345678",
            "password": "ValidPassword123",
        }).encode("utf-8"))

        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 409)
        self.assertEqual(res["error"], "ONBOARDING_NOT_REQUIRED")

    @patch('urllib.request.urlopen')
    def test_20_persistent_exchange_uses_service_role_and_hashes_jti(self, mock_urlopen):
        raw_jti = "onb_secret_single_use_identifier"

        def inspect_request(req, **kwargs):
            self.assertIn('/rest/v1/rpc/consume_onboarding_exchange_v4', req.full_url)
            self.assertEqual(req.headers['Authorization'], 'Bearer service-role-secret')
            body = json.loads(req.data.decode('utf-8'))
            self.assertNotEqual(body['p_jti_hash'], raw_jti)
            self.assertNotIn(raw_jti, req.data.decode('utf-8'))
            self.assertEqual(len(body['p_jti_hash']), 64)
            self.assertEqual(body['p_user_id'], 'user-1')
            self.assertEqual(body['p_store_id'], 'store-1')
            return MockResponse({"success": True, "role": "cashier"})

        mock_urlopen.side_effect = inspect_request
        result = consume_onboarding_exchange_rpc(
            'https://example.supabase.co',
            'service-role-secret',
            raw_jti,
            int(time.time()) + 300,
            'user-1',
            'store-1',
        )

        self.assertTrue(result['success'])
        self.assertEqual(result['role'], 'cashier')

    def test_21_onboarding_token_with_ttl_over_600_rejected(self):
        # Create an onboarding token with TTL > 600 seconds
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len", ttl_seconds=1200)

        res = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-1"}).encode("utf-8"),
            auth_header=f"Bearer {token}",
        )
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 403)
        self.assertEqual(res["error"], "INVALID_TOKEN_SCOPE")

    def test_22_tampered_signature_on_onboarding_token_rejected(self):
        token = issue_hs256_onboarding_jwt("user-123", "test_supabase_jwt_secret_32_bytes_len")
        parts = token.split(".")
        tampered_token = f"{parts[0]}.{parts[1]}.badsignature"

        res = handle_exchange_store_jwt_request(
            json.dumps({"store_id": "store-1"}).encode("utf-8"),
            auth_header=f"Bearer {tampered_token}",
        )
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 401)
        self.assertEqual(res["error"], "INVALID_SIGNATURE")


if __name__ == "__main__":
    unittest.main()
