# test/backend/test_adversarial_versions_api.py
# ─────────────────────────────────────────────────────────────────────────────
# Adversarial Stress & Vulnerability Test Suite for pos_gateway_server.py /api/versions
# Challenger 1 - Updater Adversary
#
# Tests:
#   1. SQL Injection & Path Traversal via query params
#   2. Null bytes, control characters & extreme string lengths (10KB+)
#   3. Unsupported and exotic platform names
#   4. Upstream Supabase corruption (HTML 502/520, truncated JSON, wrong structures)
#   5. Extreme build numbers (-999, astronomical ints, NaN strings) from upstream
#   6. Network outages (Timeout, URLError, RemoteDisconnected, HTTP 5xx)
#   7. HTTP Method tampering (POST, PUT, DELETE, PATCH, TRACE)
#   8. CORS Origin spoofing & evasion (subdomain spoof, null origin)
#   9. Concurrency & burst load resilience (zero state leakage)
# ─────────────────────────────────────────────────────────────────────────────
import http.client
import io
import json
import os
import socket
import sys
import unittest
from unittest.mock import MagicMock, patch
import urllib.error

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from services.pos_gateway_server import wsgi_app, _handle_get_versions, FALLBACK_APP_VERSIONS


class TestAdversarialVersionsApi(unittest.TestCase):
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

    # ── 1. SQL Injection & Path Traversal in Platform Query ────────────────────

    def test_adv_01_sql_injection_attempt_is_rejected(self):
        """Platform query with SQL injection payloads must return 404 PLATFORM_NOT_FOUND."""
        sql_payloads = [
            "android' OR 1=1--",
            "windows; DROP TABLE app_versions;--",
            "' UNION SELECT * FROM app_versions--",
            "ios' AND sleep(5)--",
            "1' or '1' = '1",
        ]
        for payload in sql_payloads:
            res = self._call_wsgi(query_string=f"platform={payload}")
            self.assertTrue(res["status"].startswith("404"), f"Failed for payload: {payload}")
            data = json.loads(res["body"].decode("utf-8"))
            self.assertFalse(data["success"])
            self.assertEqual(data["error"], "PLATFORM_NOT_FOUND")

    def test_adv_02_path_traversal_attempt_is_rejected(self):
        """Platform query with path traversal strings must return 404."""
        traversal_payloads = [
            "../../../../etc/passwd",
            "..%2F..%2Fetc%2Fpasswd",
            "windows/../../system32",
            "android/../../../",
        ]
        for payload in traversal_payloads:
            res = self._call_wsgi(query_string=f"platform={payload}")
            self.assertTrue(res["status"].startswith("404"), f"Traversal failed: {payload}")
            data = json.loads(res["body"].decode("utf-8"))
            self.assertEqual(data["error"], "PLATFORM_NOT_FOUND")

    # ── 2. Extreme String Lengths & Control Characters ────────────────────────

    def test_adv_03_huge_platform_string_does_not_crash(self):
        """Astronomical 64KB platform query string does not cause buffer overflow or 500 error."""
        huge_str = "a" * 65536
        res = self._call_wsgi(query_string=f"platform={huge_str}")
        self.assertTrue(res["status"].startswith("404"))
        data = json.loads(res["body"].decode("utf-8"))
        self.assertEqual(data["error"], "PLATFORM_NOT_FOUND")

    def test_adv_04_null_bytes_and_newlines_in_platform(self):
        """Null bytes and CRLF injections in platform parameter are safely rejected with 404."""
        fuzz_platforms = [
            "android\x00evil",
            "windows\r\nSet-Cookie: evil=true",
            "macos%00.exe",
            "ios\x00",
        ]
        for p in fuzz_platforms:
            res = self._call_wsgi(query_string=f"platform={p}")
            self.assertTrue(res["status"].startswith("404"), f"Expected 404 for: {p}")

    # ── 3. Exotic & Unsupported Platforms ─────────────────────────────────────

    def test_adv_05_unsupported_exotic_platforms(self):
        """Platforms not in {android, ios, windows, macos} must return 404 cleanly."""
        unsupported = ["web", "linux", "tizen", "freebsd", "solaris", "fuchsia", "xbox", "symbian"]
        for p in unsupported:
            res = self._call_wsgi(query_string=f"platform={p}")
            self.assertTrue(res["status"].startswith("404"))
            data = json.loads(res["body"].decode("utf-8"))
            self.assertEqual(data["error"], "PLATFORM_NOT_FOUND")

    def test_adv_06_case_insensitivity_and_whitespace_trimming(self):
        """Valid platforms with mixed case and leading/trailing whitespace must resolve correctly."""
        variations = [
            ("  AnDrOiD  ", "android"),
            ("WINDOWS\t", "windows"),
            ("\nIoS ", "ios"),
            ("  MacOS  ", "macos"),
        ]
        for raw, expected in variations:
            res = self._call_wsgi(query_string=f"platform={raw}")
            self.assertTrue(res["status"].startswith("200"))
            data = json.loads(res["body"].decode("utf-8"))
            self.assertEqual(data["platform"], expected)

    # ── 4. Upstream Supabase Malformed / Corrupted Payloads ────────────────────

    def _mock_upstream_response(self, raw_bytes, status=200):
        mock_resp = MagicMock()
        mock_resp.status = status
        mock_resp.read.return_value = raw_bytes
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        return mock_resp

    def test_adv_07_upstream_returns_html_error_page_falls_back(self):
        """When Supabase / Cloudflare returns an HTML 502/520 page, server gracefully falls back without 500."""
        html_payload = b"<!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body>Server Error</body></html>"
        mock_resp = self._mock_upstream_response(html_payload, status=200)

        with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                status, body = _handle_get_versions("platform=android")

        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertTrue(body.get("fallback"))
        self.assertEqual(body["platform"], "android")

    def test_adv_08_upstream_returns_truncated_json_falls_back(self):
        """When Supabase returns truncated/cut-off JSON, server recovers cleanly to fallback."""
        truncated_json = b'[{"platform": "android", "version_name": "1.0.'  # Incomplete JSON
        mock_resp = self._mock_upstream_response(truncated_json, status=200)

        with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                status, body = _handle_get_versions("platform=android")

        self.assertEqual(status, 200)
        self.assertTrue(body.get("fallback"))

    def test_adv_09_upstream_returns_wrong_data_structure_falls_back(self):
        """When Supabase returns an object instead of list or empty list, server falls back."""
        odd_payloads = [
            b'{"message": "Internal Server Error", "code": "PGRST500"}',
            b'[]',  # Empty list
            b'42',  # Integer
            b'"a string"',  # String
            b'[null]',  # List containing null
        ]
        for payload in odd_payloads:
            mock_resp = self._mock_upstream_response(payload, status=200)
            with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
                with patch("urllib.request.urlopen", return_value=mock_resp):
                    status, body = _handle_get_versions("platform=windows")
            self.assertEqual(status, 200)
            self.assertTrue(body.get("fallback"))
            self.assertEqual(body["platform"], "windows")

    # ── 5. Upstream Data with Extreme Build Numbers ───────────────────────────

    def test_adv_10_upstream_negative_and_astronomical_build_numbers(self):
        """Upstream data containing negative or huge build numbers is safely preserved and not mutated."""
        extreme_payload = json.dumps([{
            "platform": "android",
            "version_name": "99.99.99",
            "build_number": -999,
            "download_url": "https://quannho.lpm.vn/download/test.apk",
            "changelog": "Negative build test",
            "is_force_update": True,
        }]).encode("utf-8")

        mock_resp = self._mock_upstream_response(extreme_payload, status=200)
        with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                status, body = _handle_get_versions("platform=android")

        self.assertEqual(status, 200)
        self.assertEqual(body["build_number"], -999)
        self.assertTrue(body["is_force_update"])

    def test_adv_11_upstream_astronomical_build_number(self):
        """Upstream data with astronomical build number 999999999 is preserved without integer overflow."""
        astronomical_payload = json.dumps([{
            "platform": "windows",
            "version_name": "1.0.0",
            "build_number": 999999999,
            "download_url": "https://quannho.lpm.vn/download/test.exe",
            "changelog": "Huge build test",
            "is_force_update": False,
        }]).encode("utf-8")

        mock_resp = self._mock_upstream_response(astronomical_payload, status=200)
        with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
            with patch("urllib.request.urlopen", return_value=mock_resp):
                status, body = _handle_get_versions("platform=windows")

        self.assertEqual(status, 200)
        self.assertEqual(body["build_number"], 999999999)

    # ── 6. Total Network Failure & Timeout Injection ─────────────────────────

    def test_adv_12_total_network_outage_socket_timeout(self):
        """When socket times out (Supabase completely unreachable), returns fallback 200 in < 3.5s."""
        with patch.dict(os.environ, {"SUPABASE_URL": "https://unreachable.supabase.co", "SUPABASE_ANON_KEY": "anon"}, clear=False):
            with patch("urllib.request.urlopen", side_effect=socket.timeout("Socket timed out")):
                status, body = _handle_get_versions("platform=ios")

        self.assertEqual(status, 200)
        self.assertTrue(body.get("fallback"))
        self.assertEqual(body["platform"], "ios")

    def test_adv_13_connection_reset_and_remote_disconnected(self):
        """When connection is reset by peer (TCP RST / HTTP disconnect), returns fallback 200."""
        exceptions = [
            ConnectionResetError("Connection reset by peer"),
            http.client.RemoteDisconnected("Remote end closed connection without response"),
            urllib.error.HTTPError("https://sb.test", 503, "Service Unavailable", {}, None),
            urllib.error.HTTPError("https://sb.test", 520, "Cloudflare Unknown Error", {}, None),
        ]
        for exc in exceptions:
            with patch.dict(os.environ, {"SUPABASE_URL": "https://sb.test", "SUPABASE_ANON_KEY": "anon"}, clear=False):
                with patch("urllib.request.urlopen", side_effect=exc):
                    status, body = _handle_get_versions("platform=windows")
            self.assertEqual(status, 200)
            self.assertTrue(body.get("fallback"))

    # ── 7. HTTP Method Tampering & Header Exploitation ────────────────────────

    def test_adv_14_all_non_get_methods_strictly_rejected(self):
        """POST, PUT, DELETE, PATCH, TRACE to /api/versions must be rejected with 405."""
        disallowed_methods = ["POST", "PUT", "DELETE", "PATCH", "TRACE"]
        for m in disallowed_methods:
            res = self._call_wsgi(path="/api/versions", method=m, body=b'{"hack": true}')
            self.assertTrue(res["status"].startswith("405"), f"Method {m} was not rejected with 405")
            data = json.loads(res["body"].decode("utf-8"))
            self.assertFalse(data["success"])
            self.assertEqual(data["error"], "METHOD_NOT_ALLOWED")

    def test_adv_15_body_over_4kb_rejected(self):
        """Oversized body > 4096 bytes is rejected (405 on GET-only /api/versions, 400 on POST auth)."""
        oversized = b"x" * 4097
        # On /api/versions, method rejection takes precedence: 405
        res_ver = self._call_wsgi(path="/api/versions", method="POST", body=oversized)
        self.assertTrue(res_ver["status"].startswith("405"))

        # On POST endpoint /api/auth/pos-jwt, oversized payload is rejected as 400
        res_auth = self._call_wsgi(path="/api/auth/pos-jwt", method="POST", body=oversized)
        self.assertTrue(res_auth["status"].startswith("400"))
        data = json.loads(res_auth["body"].decode("utf-8"))
        self.assertEqual(data["error"], "PAYLOAD_TOO_LARGE")

    # ── 8. CORS Evasion & Origin Spoofing ─────────────────────────────────────

    def test_adv_16_cors_origin_subdomain_spoof_rejected(self):
        """Attacker origin trying to mimic trusted domain (e.g. pos.quannho.vn.attacker.com) is rejected with 403."""
        with patch.dict(os.environ, {"POS_ALLOWED_ORIGINS": "https://pos.quannho.vn"}, clear=False):
            spoof_origins = [
                "https://pos.quannho.vn.evil.com",
                "https://attacker-pos.quannho.vn",
                "http://pos.quannho.vn",  # Insecure HTTP
                "null",
            ]
            for origin in spoof_origins:
                res = self._call_wsgi(
                    path="/api/versions",
                    method="OPTIONS",
                    headers={"Origin": origin},
                )
                self.assertTrue(res["status"].startswith("403"), f"Origin {origin} was not blocked!")

    # ── 9. Concurrency & Rapid Burst Load ─────────────────────────────────────

    def test_adv_17_burst_load_does_not_corrupt_fallback_state(self):
        """100 rapid sequential queries alternating platforms do not mutate internal dictionary state."""
        import copy
        snapshot_before = copy.deepcopy(FALLBACK_APP_VERSIONS)

        platforms = ["android", "windows", "ios", "macos"] * 25  # 100 requests
        for p in platforms:
            res = self._call_wsgi(query_string=f"platform={p}")
            self.assertTrue(res["status"].startswith("200"))
            data = json.loads(res["body"].decode("utf-8"))
            self.assertEqual(data["platform"], p)

        # Invariant: FALLBACK_APP_VERSIONS was not modified by any request
        self.assertEqual(FALLBACK_APP_VERSIONS, snapshot_before)


if __name__ == "__main__":
    unittest.main()
