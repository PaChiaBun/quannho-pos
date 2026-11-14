# QR chống phá lớp 3 — cổng cấp vé /api/auth/qr-ticket (không cần mạng/DB)
import hashlib
import hmac
import io
import json
import os
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import services.pos_jwt_auth_service as svc
from services.pos_gateway_server import wsgi_app

ENV = {
    "SUPABASE_URL": "https://db.example.test",
    "SUPABASE_ANON_KEY": "anon",
    "SUPABASE_JWT_SECRET": "x" * 40,
    "SUPABASE_SERVICE_ROLE_KEY": "service",
}
CFG = {"ticket_secret": "ab" * 32, "turnstile_secret": "0x-turnstile-secret", "require_ticket": "true"}
BODY = {"channel_code": "TBL_AAAAAAAAAAAA", "idempotency_key": "qr_1234567890_abc", "turnstile_token": "tok-123"}


def _reset_cache():
    svc._QR_CFG_CACHE["value"] = None
    svc._QR_CFG_CACHE["at"] = 0.0


def _post(path, body):
    raw = json.dumps(body).encode()
    out = {}
    env = {
        "REQUEST_METHOD": "POST", "PATH_INFO": path, "CONTENT_LENGTH": str(len(raw)),
        "wsgi.input": io.BytesIO(raw), "REMOTE_ADDR": "127.0.0.1", "HTTP_ORIGIN": "",
    }
    def sr(status, headers): out["status"] = status
    resp = wsgi_app(env, sr)
    return out["status"], json.loads(b"".join(resp).decode())


class QrTicketTests(unittest.TestCase):
    def setUp(self):
        _reset_cache()
        self.env = patch.dict(os.environ, ENV, clear=False)
        self.env.start()

    def tearDown(self):
        self.env.stop()
        _reset_cache()

    def test_ticket_matches_sql_formula(self):
        # Công thức phải KHỚP db qr_verify_ticket_v4: HMAC-SHA256(secret, code|exp|key)
        t = svc.make_qr_ticket("sec", "CODE", "key-12345678", now=1_000_000_000)
        exp, sig = t.split(".")
        self.assertEqual(exp, str(1_000_000_000 + svc.QR_TICKET_TTL_SECONDS))
        want = hmac.new(b"sec", f"CODE|{exp}|key-12345678".encode(), hashlib.sha256).hexdigest()
        self.assertEqual(sig, want)
        self.assertRegex(t, r"^[0-9]{9,12}\.[0-9a-f]{64}$")

    def test_success_issues_ticket(self):
        with patch.object(svc, "call_service_rpc", return_value=CFG), patch.object(svc, "_verify_turnstile", return_value=True):
            res = svc.handle_qr_ticket_request(json.dumps(BODY).encode(), client_ip="1.2.3.4")
        self.assertTrue(res["success"])
        exp, sig = res["ticket"].split(".")
        want = hmac.new(CFG["ticket_secret"].encode(), f"{BODY['channel_code']}|{exp}|{BODY['idempotency_key']}".encode(), hashlib.sha256).hexdigest()
        self.assertEqual(sig, want)
        self.assertGreater(int(exp), int(time.time()))

    def test_turnstile_failure_gives_403_and_no_ticket(self):
        with patch.object(svc, "call_service_rpc", return_value=CFG), patch.object(svc, "_verify_turnstile", return_value=False):
            res = svc.handle_qr_ticket_request(json.dumps(BODY).encode())
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], 403)
        self.assertNotIn("ticket", res)

    def test_not_configured_gives_503(self):
        cfg = dict(CFG, turnstile_secret="")
        with patch.object(svc, "call_service_rpc", return_value=cfg):
            res = svc.handle_qr_ticket_request(json.dumps(BODY).encode())
        self.assertEqual(res["status"], 503)
        self.assertEqual(res["error"], "TURNSTILE_NOT_CONFIGURED")

    def test_bad_params(self):
        for bad in (
            dict(BODY, channel_code=""), dict(BODY, channel_code="x" * 65),
            dict(BODY, idempotency_key="short"), dict(BODY, idempotency_key="k" * 129),
            dict(BODY, turnstile_token=""), dict(BODY, turnstile_token="t" * 2049),
        ):
            res = svc.handle_qr_ticket_request(json.dumps(bad).encode())
            self.assertEqual(res["status"], 400, bad)
        self.assertEqual(svc.handle_qr_ticket_request(b"not json")["status"], 400)

    def test_turnstile_network_error_is_503(self):
        with patch.object(svc, "call_service_rpc", return_value=CFG), \
             patch("urllib.request.urlopen", side_effect=OSError("boom")):
            res = svc.handle_qr_ticket_request(json.dumps(BODY).encode())
        self.assertEqual(res["status"], 503)
        self.assertEqual(res["error"], "TURNSTILE_UNAVAILABLE")

    def test_config_is_cached(self):
        with patch.object(svc, "call_service_rpc", return_value=CFG) as rpc, patch.object(svc, "_verify_turnstile", return_value=True):
            svc.handle_qr_ticket_request(json.dumps(BODY).encode())
            svc.handle_qr_ticket_request(json.dumps(BODY).encode())
        self.assertEqual(rpc.call_count, 1)

    def test_wsgi_route_and_method(self):
        with patch.object(svc, "call_service_rpc", return_value=CFG), patch.object(svc, "_verify_turnstile", return_value=True):
            status, body = _post("/api/auth/qr-ticket", BODY)
        self.assertTrue(status.startswith("200"))
        self.assertTrue(body["success"])


if __name__ == "__main__":
    unittest.main()
