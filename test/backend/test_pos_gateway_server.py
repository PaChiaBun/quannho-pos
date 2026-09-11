# test/backend/test_pos_gateway_server.py
# ─────────────────────────────────────────────────────────────────────────────
# Test Suite for services.pos_gateway_server WSGI / HTTP Endpoints
# ─────────────────────────────────────────────────────────────────────────────
import io
import json
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_gateway_server import wsgi_app


class TestPosGatewayServer(unittest.TestCase):
    def _call_wsgi(self, path="/", method="GET", body=b"", headers=None, remote_addr="127.0.0.1", query_string=""):
        headers = headers or {}
        path_info = path.split("?", 1)[0]
        qs = query_string or (path.split("?", 1)[1] if "?" in path else "")
        environ = {
            "PATH_INFO": path_info,
            "QUERY_STRING": qs,
            "REQUEST_METHOD": method,
            "CONTENT_LENGTH": str(len(body)),
            "wsgi.input": io.BytesIO(body),
            "REMOTE_ADDR": remote_addr,
        }
        for k, v in headers.items():
            key = "HTTP_" + k.upper().replace("-", "_")
            environ[key] = v

        captured = {}
        def start_response(status, response_headers, exc_info=None):
            captured["status"] = status
            captured["headers"] = dict(response_headers)

        response_body = b"".join(wsgi_app(environ, start_response))
        captured["body"] = response_body
        return captured

    def test_01_health_check_returns_200(self):
        with patch.dict(
            os.environ,
            {"POS_ALLOWED_ORIGINS": "https://pos.example.com"},
            clear=False,
        ):
            res = self._call_wsgi(
                path="/api/auth/health",
                method="GET",
                headers={"Origin": "https://pos.example.com"},
            )
        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["service"], "pos_jwt_gateway")
        self.assertEqual(
            res["headers"].get("Access-Control-Allow-Origin"),
            "https://pos.example.com",
        )

    def test_02_options_cors_preflight_returns_204(self):
        with patch.dict(
            os.environ,
            {"POS_ALLOWED_ORIGINS": "https://pos.example.com"},
            clear=False,
        ):
            res = self._call_wsgi(
                path="/api/auth/pos-jwt",
                method="OPTIONS",
                headers={"Origin": "https://pos.example.com"},
            )
        self.assertTrue(res["status"].startswith("204"))
        self.assertEqual(
            res["headers"].get("Access-Control-Allow-Origin"),
            "https://pos.example.com",
        )
        self.assertIn("POST", res["headers"].get("Access-Control-Allow-Methods", ""))

    def test_03_get_on_pos_jwt_returns_405(self):
        res = self._call_wsgi(path="/api/auth/pos-jwt", method="GET")
        self.assertTrue(res["status"].startswith("405"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["error"], "METHOD_NOT_ALLOWED")

    def test_04_unknown_route_returns_404(self):
        res = self._call_wsgi(path="/api/unknown", method="GET")
        self.assertTrue(res["status"].startswith("404"))

    def test_05_payload_too_large_returns_400(self):
        large_body = b"x" * 5000
        res = self._call_wsgi(path="/api/auth/pos-jwt", method="POST", body=large_body)
        self.assertTrue(res["status"].startswith("400"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["error"], "PAYLOAD_TOO_LARGE")

    def test_06_untrusted_cors_origin_is_rejected(self):
        with patch.dict(
            os.environ,
            {"POS_ALLOWED_ORIGINS": "https://pos.example.com"},
            clear=False,
        ):
            res = self._call_wsgi(
                path="/api/auth/pos-jwt",
                method="OPTIONS",
                headers={"Origin": "https://evil.example"},
            )
        self.assertTrue(res["status"].startswith("403"))
        self.assertNotIn("Access-Control-Allow-Origin", res["headers"])

    def test_06b_wildcard_configuration_does_not_open_password_endpoint(self):
        with patch.dict(os.environ, {"POS_ALLOWED_ORIGINS": "*"}, clear=False):
            res = self._call_wsgi(
                path="/api/auth/pos-jwt",
                method="OPTIONS",
                headers={"Origin": "https://evil.example"},
            )
        self.assertTrue(res["status"].startswith("403"))
        self.assertNotIn("Access-Control-Allow-Origin", res["headers"])

    @patch("services.pos_gateway_server.handle_pos_jwt_auth_request")
    def test_07_post_pos_jwt_invokes_handler_with_resolved_ip(self, mock_handler):
        mock_handler.return_value = {
            "success": True,
            "status": 200,
            "pos_jwt": "test_token",
            "store_id": "store-1",
            "role": "owner",
        }

        body = json.dumps({
            "phone": "0900000001",
            "password": "valid_password",
            "store_id": "store-1",
        }).encode("utf-8")

        with patch.dict(os.environ, {"POS_TRUSTED_PROXY_IPS": "10.0.0.1"}, clear=False):
            res = self._call_wsgi(
                path="/api/auth/pos-jwt",
                method="POST",
                body=body,
                remote_addr="10.0.0.1",
                headers={"X-Forwarded-For": "203.0.113.195, 10.0.0.1"}
            )

        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["pos_jwt"], "test_token")
        mock_handler.assert_called_once_with(body, client_ip="203.0.113.195")

    @patch("services.pos_gateway_server.handle_onboarding_jwt_request")
    def test_08_post_onboarding_jwt_invokes_handler(self, mock_handler):
        mock_handler.return_value = {
            "success": True,
            "status": 200,
            "onboarding_jwt": "onboarding_test_token",
            "user_id": "user-1",
        }

        body = json.dumps({
            "phone": "0900000001",
            "password": "valid_password",
        }).encode("utf-8")

        res = self._call_wsgi(path="/api/auth/onboarding-jwt", method="POST", body=body)
        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["onboarding_jwt"], "onboarding_test_token")
        mock_handler.assert_called_once_with(body, client_ip="127.0.0.1")

    @patch("services.pos_gateway_server.handle_exchange_store_jwt_request")
    def test_09_post_exchange_store_jwt_invokes_handler(self, mock_handler):
        mock_handler.return_value = {
            "success": True,
            "status": 200,
            "pos_jwt": "exchanged_pos_token",
            "store_id": "store-1",
            "role": "owner",
        }

        body = json.dumps({"store_id": "store-1"}).encode("utf-8")
        res = self._call_wsgi(
            path="/api/auth/exchange-store-jwt",
            method="POST",
            body=body,
            headers={"Authorization": "Bearer onb_token"}
        )
        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["pos_jwt"], "exchanged_pos_token")
        mock_handler.assert_called_once_with(body, auth_header="Bearer onb_token", client_ip="127.0.0.1")

    def test_10_health_check_readiness_missing_env_returns_503(self):
        with patch.dict(os.environ, {}, clear=True):
            res = self._call_wsgi(path="/api/auth/health?check=readiness", method="GET")
        self.assertTrue(res["status"].startswith("503"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["status"], "unhealthy")
        self.assertEqual(data["error"], "CONFIG_INCOMPLETE")

    @patch("urllib.request.urlopen")
    def test_11_health_check_readiness_probe_200_returns_ready(self, mock_urlopen):
        mock_resp = unittest.mock.MagicMock()
        mock_resp.status = 200
        mock_resp.__enter__.return_value = mock_resp
        mock_urlopen.return_value = mock_resp

        env = {
            "SUPABASE_URL": "https://test.supabase.co",
            "SUPABASE_ANON_KEY": "anon_key",
            "SUPABASE_JWT_SECRET": "jwt_secret",
            "SUPABASE_SERVICE_ROLE_KEY": "service_role_key",
        }
        with patch.dict(os.environ, env, clear=True):
            res = self._call_wsgi(path="/api/auth/health?check=readiness", method="GET")
        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["readiness"], "ready")

    @patch("urllib.request.urlopen")
    def test_12_health_check_readiness_probe_401_or_403_returns_upstream_auth_failed(self, mock_urlopen):
        import urllib.error
        mock_urlopen.side_effect = urllib.error.HTTPError("url", 401, "Unauthorized", {}, None)

        env = {
            "SUPABASE_URL": "https://test.supabase.co",
            "SUPABASE_ANON_KEY": "bad_anon_key",
            "SUPABASE_JWT_SECRET": "jwt_secret",
            "SUPABASE_SERVICE_ROLE_KEY": "service_role_key",
        }
        with patch.dict(os.environ, env, clear=True):
            res = self._call_wsgi(path="/api/auth/health?check=readiness", method="GET")
        self.assertTrue(res["status"].startswith("503"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["status"], "degraded")
        self.assertEqual(data["error"], "UPSTREAM_AUTH_FAILED")

    @patch("urllib.request.urlopen")
    def test_13_health_check_readiness_probe_500_or_timeout_returns_upstream_unavailable(self, mock_urlopen):
        import urllib.error
        mock_urlopen.side_effect = urllib.error.URLError("Connection refused")

        env = {
            "SUPABASE_URL": "https://test.supabase.co",
            "SUPABASE_ANON_KEY": "anon_key",
            "SUPABASE_JWT_SECRET": "jwt_secret",
            "SUPABASE_SERVICE_ROLE_KEY": "service_role_key",
        }
        with patch.dict(os.environ, env, clear=True):
            res = self._call_wsgi(path="/api/auth/health?check=readiness", method="GET")
        self.assertTrue(res["status"].startswith("503"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["status"], "degraded")
        self.assertEqual(data["error"], "UPSTREAM_UNAVAILABLE")

    def test_14_trusted_proxy_separate_client_ips_do_not_share_rate_limit(self):
        from services.pos_jwt_auth_service import _rate_limiter
        ip_a = "203.0.113.10"
        ip_b = "198.51.100.25"
        # Simulate IP A exhausting its attempts
        for _ in range(5):
            _rate_limiter.record_attempt(ip_a, "phone_a")

        self.assertTrue(_rate_limiter.is_rate_limited(ip_a, "phone_a"))
        # IP B must NOT be rate limited
        self.assertFalse(_rate_limiter.is_rate_limited(ip_b, "phone_b"))


if __name__ == "__main__":
    unittest.main()
