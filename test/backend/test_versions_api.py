# test/backend/test_versions_api.py
# ─────────────────────────────────────────────────────────────────────────────
# Tier 1 & Tier 2: Feature Coverage & Boundary Tests for /api/versions WSGI Endpoint
# Verifies:
#   - GET /api/versions with and without platform query param
#   - Supported platforms: android, windows, ios, macos
#   - Error handling: unsupported platform (404), disallowed methods (405)
#   - CORS preflight and allowed origins
#   - Supabase query integration and graceful fallback when Supabase is offline
#   - Force update flag propagation and UTF-8 Vietnamese changelog fidelity
# ─────────────────────────────────────────────────────────────────────────────
import io
import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch
import urllib.error

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_gateway_server import wsgi_app, _handle_get_versions, FALLBACK_APP_VERSIONS


class TestVersionsApi(unittest.TestCase):
    def _call_wsgi(self, path="/api/versions", method="GET", body=b"", headers=None, remote_addr="127.0.0.1", query_string=""):
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

    # ── Tier 1: Feature Coverage ──────────────────────────────────────────────

    def test_01_get_versions_all_platforms_returns_200(self):
        """GET /api/versions with no platform query returns 200 with list of versions."""
        res = self._call_wsgi(path="/api/versions", method="GET")
        self.assertTrue(res["status"].startswith("200"), f"Expected 200 OK, got: {res['status']}")
        self.assertIn("application/json", res["headers"].get("Content-Type", ""))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data.get("success"), "Expected success=True")
        self.assertIn("data", data)
        self.assertIsInstance(data["data"], list)

        # Verify default platforms exist in list
        platforms = {item.get("platform") for item in data["data"]}
        self.assertIn("android", platforms)
        self.assertIn("windows", platforms)
        self.assertIn("ios", platforms)

    def test_02_get_versions_android_returns_metadata(self):
        """GET /api/versions?platform=android returns valid Android metadata."""
        res = self._call_wsgi(path="/api/versions", query_string="platform=android", method="GET")
        self.assertTrue(res["status"].startswith("200"))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["platform"], "android")
        self.assertIn(".apk", data["download_url"])
        self.assertGreaterEqual(data["build_number"], 1)
        self.assertTrue(len(data["version_name"]) > 0)
        self.assertIn("changelog", data)

    def test_03_get_versions_windows_returns_metadata(self):
        """GET /api/versions?platform=windows returns valid Windows metadata with .exe installer."""
        res = self._call_wsgi(path="/api/versions", query_string="platform=windows", method="GET")
        self.assertTrue(res["status"].startswith("200"))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["platform"], "windows")
        self.assertIn(".exe", data["download_url"])
        self.assertGreaterEqual(data["build_number"], 1)

    def test_04_get_versions_ios_returns_metadata(self):
        """GET /api/versions?platform=ios returns valid iOS metadata pointing to Apple App Store."""
        res = self._call_wsgi(path="/api/versions", query_string="platform=ios", method="GET")
        self.assertTrue(res["status"].startswith("200"))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertTrue(data["success"])
        self.assertEqual(data["platform"], "ios")
        self.assertIn("apps.apple.com", data["download_url"])

    def test_05_get_versions_trailing_slash_returns_200(self):
        """GET /api/versions/ (trailing slash) works identically to /api/versions."""
        res = self._call_wsgi(path="/api/versions/", query_string="platform=android", method="GET")
        self.assertTrue(res["status"].startswith("200"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["platform"], "android")

    # ── Tier 2: Boundary & Corner Cases ───────────────────────────────────────

    def test_06_unsupported_platform_returns_404(self):
        """GET /api/versions with unsupported platform returns 404 with error code."""
        res = self._call_wsgi(path="/api/versions", query_string="platform=playstation", method="GET")
        self.assertTrue(res["status"].startswith("404"))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertFalse(data["success"])
        self.assertEqual(data["error"], "PLATFORM_NOT_FOUND")

    def test_07_post_method_not_allowed(self):
        """POST /api/versions is disallowed and returns 405 Method Not Allowed."""
        res = self._call_wsgi(path="/api/versions", method="POST", body=b"{}")
        self.assertTrue(res["status"].startswith("405"))

        data = json.loads(res["body"].decode("utf-8"))
        self.assertFalse(data["success"])
        self.assertEqual(data["error"], "METHOD_NOT_ALLOWED")

    def test_08_put_delete_methods_not_allowed(self):
        """PUT /api/versions and DELETE /api/versions return 405."""
        for m in ("PUT", "DELETE"):
            res = self._call_wsgi(path="/api/versions", method=m)
            self.assertTrue(res["status"].startswith("405"), f"Method {m} should return 405")

    def test_09_cors_options_preflight_returns_204(self):
        """OPTIONS /api/versions returns 204 with allowed headers."""
        with patch.dict(os.environ, {"POS_ALLOWED_ORIGINS": "https://pos.quannho.vn"}, clear=False):
            res = self._call_wsgi(
                path="/api/versions",
                method="OPTIONS",
                headers={"Origin": "https://pos.quannho.vn"},
            )
        self.assertTrue(res["status"].startswith("204"))
        self.assertEqual(res["headers"].get("Access-Control-Allow-Origin"), "https://pos.quannho.vn")
        self.assertIn("GET", res["headers"].get("Access-Control-Allow-Methods", ""))

    def test_10_cors_untrusted_origin_is_rejected(self):
        """OPTIONS /api/versions with untrusted origin is rejected with 403."""
        with patch.dict(os.environ, {"POS_ALLOWED_ORIGINS": "https://pos.quannho.vn"}, clear=False):
            res = self._call_wsgi(
                path="/api/versions",
                method="OPTIONS",
                headers={"Origin": "https://attacker.evil.com"},
            )
        self.assertTrue(res["status"].startswith("403"))

    def test_11_mock_supabase_success_returns_live_data(self):
        """When Supabase returns a live record, endpoint returns it with success=True."""
        mock_response_payload = json.dumps([{
            "id": "ver-android-99",
            "platform": "android",
            "version_name": "2.0.0",
            "build_number": 99,
            "download_url": "https://quannho.lpm.vn/download/QuanNhoPOS-2.0.0.apk",
            "changelog": "Tính năng mới kiểm thử tự động",
            "is_force_update": True,
            "created_at": "2026-09-24T12:00:00Z",
        }]).encode("utf-8")

        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.read.return_value = mock_response_payload
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None

        with patch.dict(os.environ, {
            "SUPABASE_URL": "https://supabase.test.local",
            "SUPABASE_SERVICE_ROLE_KEY": "test-service-key",
        }, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                status, body = _handle_get_versions("platform=android")

        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["version_name"], "2.0.0")
        self.assertEqual(body["build_number"], 99)
        self.assertTrue(body["is_force_update"])
        self.assertEqual(body["changelog"], "Tính năng mới kiểm thử tự động")

    def test_12_mock_supabase_failure_falls_back_gracefully_never_500(self):
        """When Supabase throws an exception, endpoint falls back to local definitions with 200 (never 500)."""
        with patch.dict(os.environ, {
            "SUPABASE_URL": "https://supabase.test.local",
            "SUPABASE_SERVICE_ROLE_KEY": "test-service-key",
        }, clear=False):
            with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("Connection refused")):
                status, body = _handle_get_versions("platform=windows")

        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["platform"], "windows")
        self.assertTrue(body.get("fallback"))
        self.assertIn("download_url", body)

    def test_13_force_update_flag_boolean_fidelity(self):
        """Ensure is_force_update flag is strictly boolean and correctly propagated."""
        res = self._call_wsgi(path="/api/versions", query_string="platform=android", method="GET")
        data = json.loads(res["body"].decode("utf-8"))
        self.assertIsInstance(data["is_force_update"], bool)

    def test_14_vietnamese_changelog_utf8_encoding(self):
        """Ensure Vietnamese characters in changelog preserve 100% UTF-8 fidelity."""
        test_changelog = "Cập nhật tính năng: Quán Nhỏ POS tự động đồng bộ kho hàng & bàn ăn!"
        mock_response_payload = json.dumps([{
            "platform": "android",
            "version_name": "1.0.5",
            "build_number": 15,
            "download_url": "https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk",
            "changelog": test_changelog,
            "is_force_update": False,
        }]).encode("utf-8")

        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.read.return_value = mock_response_payload
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None

        with patch.dict(os.environ, {
            "SUPABASE_URL": "https://supabase.test.local",
            "SUPABASE_ANON_KEY": "anon-key",
        }, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                res = self._call_wsgi(path="/api/versions", query_string="platform=android", method="GET")

        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["changelog"], test_changelog)


if __name__ == "__main__":
    unittest.main()
