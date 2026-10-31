# Bước 1 — refresh token xoay vòng: unit tests (không cần mạng/DB)
import json
import os
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import services.pos_jwt_auth_service as svc
from services.pos_jwt_auth_service import (
    handle_pos_jwt_auth_request,
    handle_refresh_request,
    handle_logout_request,
    handle_exchange_store_jwt_request,
    issue_hs256_onboarding_jwt,
    verify_and_decode_hs256_jwt,
    hash_refresh_token,
    PosJwtAuthError,
)
from services.pos_gateway_server import wsgi_app

SECRET = "x" * 40
UID = "11111111-1111-1111-1111-111111111111"
SID = "22222222-2222-2222-2222-222222222222"
ENV = {
    "SUPABASE_URL": "https://db.example.test",
    "SUPABASE_ANON_KEY": "anon",
    "SUPABASE_JWT_SECRET": SECRET,
    "SUPABASE_SERVICE_ROLE_KEY": "service",
}
AUTH_OK = {"user_id": UID, "store_id": SID, "role": "cashier", "stores": []}


class FakeStore:
    """In-memory imitation of qn_refresh_* RPCs to exercise gateway logic."""
    def __init__(self):
        self.rows = {}
        self.calls = []

    def __call__(self, url, key, rpc, params, timeout=8):
        self.calls.append(rpc)
        if rpc == "qn_refresh_issue_v1":
            self.rows[params["p_token_hash"]] = {"used": False, "revoked": False, "family": params["p_token_hash"]}
            return {"success": True, "role": "manager"}
        if rpc == "qn_refresh_rotate_v1":
            row = self.rows.get(params["p_old_hash"])
            if not row:
                return {"success": False, "error_code": "REFRESH_INVALID"}
            if row["revoked"]:
                return {"success": False, "error_code": "REFRESH_REVOKED"}
            if row["used"]:
                for r in self.rows.values():
                    if r["family"] == row["family"]:
                        r["revoked"] = True
                return {"success": False, "error_code": "REFRESH_REUSED"}
            row["used"] = True
            self.rows[params["p_new_hash"]] = {"used": False, "revoked": False, "family": row["family"]}
            return {"success": True, "user_id": UID, "store_id": SID, "role": "manager"}
        if rpc == "qn_refresh_revoke_v1":
            row = self.rows.get(params["p_token_hash"])
            n = 0
            if row:
                for r in self.rows.values():
                    if r["family"] == row["family"] and not r["revoked"]:
                        r["revoked"] = True
                        n += 1
            return {"success": True, "revoked": n}
        raise AssertionError(rpc)


def body(d):
    return json.dumps(d).encode()


@patch.dict(os.environ, ENV, clear=False)
class RefreshTokenTests(unittest.TestCase):
    def setUp(self):
        for limiter in (svc._rate_limiter, svc._refresh_rate_limiter):
            with limiter._lock:
                limiter._history.clear()
        os.environ.pop("POS_REFRESH_ENABLED", None)
        os.environ.pop("POS_ACCESS_TTL_SECONDS", None)

    def _login(self, store, **extra):
        with patch.object(svc, "verify_user_credentials_and_membership", return_value=dict(AUTH_OK)), \
             patch.object(svc, "call_service_rpc", side_effect=store):
            return handle_pos_jwt_auth_request(body({"phone": "0900", "password": "p", "store_id": SID, **extra}), "1.1.1.1")

    def test_01_legacy_client_gets_30_day_token_without_refresh(self):
        store = FakeStore()
        res = self._login(store)
        self.assertTrue(res["success"])
        self.assertNotIn("refresh_token", res)
        claims = verify_and_decode_hs256_jwt(res["pos_jwt"], SECRET)
        self.assertEqual(claims["exp"] - claims["iat"], 2592000)
        self.assertEqual(store.calls, [])

    def test_02_new_client_gets_12h_access_and_refresh(self):
        store = FakeStore()
        res = self._login(store, supports_refresh=True)
        self.assertTrue(res["success"], res)
        self.assertTrue(res["refresh_token"].startswith("qnr_"))
        claims = verify_and_decode_hs256_jwt(res["pos_jwt"], SECRET)
        self.assertEqual(claims["exp"] - claims["iat"], 2592000)
        self.assertEqual(claims["store_id"], SID)
        self.assertEqual(claims["staff_role"], "manager")  # role from DB wins
        self.assertEqual(res["expires_in"], 2592000)
        # only the hash is sent to DB
        self.assertIn(hash_refresh_token(res["refresh_token"]), store.rows)
        self.assertNotIn(res["refresh_token"], store.rows)

    def test_03_refresh_store_down_falls_back_to_legacy(self):
        def down(*a, **k):
            raise PosJwtAuthError("down", 503, "REFRESH_STORE_UNAVAILABLE")
        res = self._login(down, supports_refresh=True)
        self.assertTrue(res["success"])
        self.assertNotIn("refresh_token", res)
        claims = verify_and_decode_hs256_jwt(res["pos_jwt"], SECRET)
        self.assertEqual(claims["exp"] - claims["iat"], 2592000)

    def test_04_rotate_then_reuse_revokes_family(self):
        store = FakeStore()
        first = self._login(store, supports_refresh=True)["refresh_token"]
        with patch.object(svc, "call_service_rpc", side_effect=store):
            r1 = handle_refresh_request(body({"refresh_token": first}), "1.1.1.1")
            self.assertTrue(r1["success"], r1)
            self.assertNotEqual(r1["refresh_token"], first)
            verify_and_decode_hs256_jwt(r1["pos_jwt"], SECRET)
            r2 = handle_refresh_request(body({"refresh_token": first}), "1.1.1.1")
            self.assertEqual((r2["status"], r2["error"]), (401, "REFRESH_REUSED"))
            r3 = handle_refresh_request(body({"refresh_token": r1["refresh_token"]}), "1.1.1.1")
            self.assertEqual(r3["error"], "REFRESH_REVOKED")

    def test_05_logout_revokes(self):
        store = FakeStore()
        tok = self._login(store, supports_refresh=True)["refresh_token"]
        with patch.object(svc, "call_service_rpc", side_effect=store):
            out = handle_logout_request(body({"refresh_token": tok}), "1.1.1.1")
            self.assertEqual(out["revoked"], 1)
            r = handle_refresh_request(body({"refresh_token": tok}), "1.1.1.1")
            self.assertEqual(r["status"], 401)

    def test_06_garbage_refresh_rejected_without_db_and_rate_limited(self):
        with patch.object(svc, "call_service_rpc") as rpc:
            for _ in range(20):
                r = handle_refresh_request(body({"refresh_token": "abc"}), "9.9.9.9")
                self.assertEqual(r["status"], 401)
            r = handle_refresh_request(body({"refresh_token": "qnr_" + "a" * 40}), "9.9.9.9")
            self.assertEqual(r["status"], 429)
            rpc.assert_not_called()

    def test_07_race_maps_to_409(self):
        with patch.object(svc, "call_service_rpc", return_value={"success": False, "error_code": "REFRESH_RACE"}):
            r = handle_refresh_request(body({"refresh_token": "qnr_" + "b" * 40}), "1.1.1.1")
        self.assertEqual(r["status"], 409)

    def test_08_membership_removed_maps_to_403(self):
        with patch.object(svc, "call_service_rpc", return_value={"success": False, "error_code": "STORE_MEMBERSHIP_FORBIDDEN"}):
            r = handle_refresh_request(body({"refresh_token": "qnr_" + "c" * 40}), "1.1.1.1")
        self.assertEqual(r["status"], 403)

    def test_09_refresh_disabled_by_env(self):
        os.environ["POS_REFRESH_ENABLED"] = "0"
        store = FakeStore()
        res = self._login(store, supports_refresh=True)
        self.assertNotIn("refresh_token", res)
        self.assertEqual(store.calls, [])

    def test_10_exchange_supports_refresh(self):
        store = FakeStore()
        onb = issue_hs256_onboarding_jwt(UID, SECRET, ttl_seconds=600)
        with patch.object(svc, "consume_onboarding_exchange_rpc", return_value={"success": True, "role": "owner"}), \
             patch.object(svc, "call_service_rpc", side_effect=store):
            res = handle_exchange_store_jwt_request(body({"store_id": SID, "supports_refresh": True}),
                                                    auth_header=f"Bearer {onb}")
        self.assertTrue(res["success"], res)
        self.assertIn("refresh_token", res)

    def test_11_wsgi_routes(self):
        import io
        store = FakeStore()
        tok = self._login(store, supports_refresh=True)["refresh_token"]
        for path in ("/api/auth/refresh", "/api/auth/logout"):
            raw = body({"refresh_token": tok})
            env = {"PATH_INFO": path, "REQUEST_METHOD": "POST", "CONTENT_LENGTH": str(len(raw)),
                   "wsgi.input": io.BytesIO(raw), "REMOTE_ADDR": "127.0.0.1"}
            got = {}
            with patch.object(svc, "call_service_rpc", side_effect=store):
                out = b"".join(wsgi_app(env, lambda s, h: got.setdefault("s", s)))
            self.assertTrue(got["s"].startswith("200"), (path, got, out))
        env = {"PATH_INFO": "/api/auth/refresh", "REQUEST_METHOD": "GET", "wsgi.input": io.BytesIO(b"")}
        got = {}
        wsgi_app(env, lambda s, h: got.setdefault("s", s))
        self.assertTrue(got["s"].startswith("405"))


if __name__ == "__main__":
    unittest.main()
