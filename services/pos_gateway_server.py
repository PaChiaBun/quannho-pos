# services/pos_gateway_server.py
# ─────────────────────────────────────────────────────────────────────────────
# POS JWT WSGI Gateway Entry Point
# Mounts /api/auth/pos-jwt, /api/auth/onboarding-jwt, /api/auth/exchange-store-jwt,
# /api/auth/health, and handles CORS & IP resolution.
# ─────────────────────────────────────────────────────────────────────────────
import json
import logging
import os
from http.server import BaseHTTPRequestHandler
from wsgiref.simple_server import make_server

from services.pos_jwt_auth_service import (
    handle_pos_jwt_auth_request,
    handle_onboarding_jwt_request,
    handle_exchange_store_jwt_request,
)
from services.pos_jwt_route_adapter import _resolve_client_ip

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("pos_gateway_server")


def _cors_headers(origin):
    """Return CORS headers only for explicitly allowed browser origins."""
    allowed = {
        value.strip()
        for value in os.environ.get("POS_ALLOWED_ORIGINS", "").split(",")
        if value.strip()
    }
    headers = [
        ("Content-Type", "application/json; charset=utf-8"),
        ("Access-Control-Allow-Methods", "POST, GET, OPTIONS"),
        ("Access-Control-Allow-Headers", "Content-Type, Authorization"),
        ("Vary", "Origin"),
    ]
    if origin and origin in allowed:
        headers.append(("Access-Control-Allow-Origin", origin))
    return headers


def _status_line(status_code):
    return f"{status_code} " + {
        200: "OK",
        204: "No Content",
        400: "Bad Request",
        401: "Unauthorized",
        403: "Forbidden",
        404: "Not Found",
        405: "Method Not Allowed",
        409: "Conflict",
        429: "Too Many Requests",
        500: "Internal Server Error",
        502: "Bad Gateway",
        503: "Service Unavailable",
    }.get(status_code, "OK")


def wsgi_app(environ, start_response):
    """WSGI standard application entry point for Gunicorn / uWSGI / standard WSGI containers."""
    path = environ.get("PATH_INFO", "")
    method = environ.get("REQUEST_METHOD", "GET").upper()

    origin = environ.get("HTTP_ORIGIN", "")
    headers = _cors_headers(origin)

    if origin and not any(
        name == "Access-Control-Allow-Origin" for name, _ in headers
    ):
        start_response("403 Forbidden", headers)
        return [b""]

    # 1. CORS Preflight
    if method == "OPTIONS":
        if not any(name == "Access-Control-Allow-Origin" for name, _ in headers):
            start_response("403 Forbidden", headers)
            return [b""]
        start_response("204 No Content", headers)
        return [b""]

    # 2. Health Check Route
    if path in ("/api/auth/health", "/health"):
        start_response("200 OK", headers)
        return [json.dumps({"status": "ok", "service": "pos_jwt_gateway"}).encode("utf-8")]

    # 3. Request Body Extraction
    try:
        content_length = int(environ.get("CONTENT_LENGTH", 0) or 0)
    except ValueError:
        content_length = 0

    if content_length > 4096:
        start_response("400 Bad Request", headers)
        return [json.dumps({"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE", "message": "Dữ liệu yêu cầu vượt quá 4KB"}).encode("utf-8")]

    raw_body = environ.get("wsgi.input").read(content_length) if content_length > 0 else b""
    remote_addr = environ.get("REMOTE_ADDR", "127.0.0.1")
    forwarded_for = environ.get("HTTP_X_FORWARDED_FOR", "")
    client_ip = _resolve_client_ip(remote_addr, forwarded_for)
    auth_header = environ.get("HTTP_AUTHORIZATION", "")

    # 4. Auth Routes
    if path == "/api/auth/pos-jwt":
        if method != "POST":
            start_response("405 Method Not Allowed", headers)
            return [json.dumps({"success": False, "status": 405, "error": "METHOD_NOT_ALLOWED", "message": "Phương thức không được hỗ trợ"}).encode("utf-8")]

        res = handle_pos_jwt_auth_request(raw_body, client_ip=client_ip)
        start_response(_status_line(res.get("status", 200)), headers)
        return [json.dumps(res).encode("utf-8")]

    if path == "/api/auth/onboarding-jwt":
        if method != "POST":
            start_response("405 Method Not Allowed", headers)
            return [json.dumps({"success": False, "status": 405, "error": "METHOD_NOT_ALLOWED", "message": "Phương thức không được hỗ trợ"}).encode("utf-8")]

        res = handle_onboarding_jwt_request(raw_body, client_ip=client_ip)
        start_response(_status_line(res.get("status", 200)), headers)
        return [json.dumps(res).encode("utf-8")]

    if path == "/api/auth/exchange-store-jwt":
        if method != "POST":
            start_response("405 Method Not Allowed", headers)
            return [json.dumps({"success": False, "status": 405, "error": "METHOD_NOT_ALLOWED", "message": "Phương thức không được hỗ trợ"}).encode("utf-8")]

        res = handle_exchange_store_jwt_request(raw_body, auth_header=auth_header, client_ip=client_ip)
        start_response(_status_line(res.get("status", 200)), headers)
        return [json.dumps(res).encode("utf-8")]

    # 5. Fallback 404
    start_response("404 Not Found", headers)
    return [json.dumps({"success": False, "status": 404, "error": "NOT_FOUND", "message": "Đường dẫn không tồn tại"}).encode("utf-8")]


class StandaloneGatewayHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler for standalone server testing."""
    def _send_cors_headers(self):
        for name, value in _cors_headers(self.headers.get("Origin", "")):
            self.send_header(name, value)

    def _origin_allowed(self):
        origin = self.headers.get("Origin", "")
        return not origin or any(
            name == "Access-Control-Allow-Origin"
            for name, _ in _cors_headers(origin)
        )

    def do_OPTIONS(self):
        headers = _cors_headers(self.headers.get("Origin", ""))
        allowed = any(name == "Access-Control-Allow-Origin" for name, _ in headers)
        self.send_response(204 if allowed else 403)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        if not self._origin_allowed():
            self.send_response(403)
            self._send_cors_headers()
            self.end_headers()
            return
        if self.path in ("/api/auth/health", "/health"):
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "pos_jwt_gateway"}).encode("utf-8"))
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "status": 404, "error": "NOT_FOUND"}).encode("utf-8"))

    def do_POST(self):
        if not self._origin_allowed():
            self.send_response(403)
            self._send_cors_headers()
            self.end_headers()
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0) or 0)
        except (TypeError, ValueError):
            self.send_response(400)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "status": 400, "error": "INVALID_CONTENT_LENGTH"}).encode("utf-8"))
            return
        if content_length > 4096:
            self.send_response(400)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE"}).encode("utf-8"))
            return

        raw_body = self.rfile.read(content_length) if content_length > 0 else b""
        remote_addr = self.client_address[0] if self.client_address else "127.0.0.1"
        forwarded_for = self.headers.get("X-Forwarded-For", "")
        client_ip = _resolve_client_ip(remote_addr, forwarded_for)
        auth_header = self.headers.get("Authorization", "")

        if self.path == "/api/auth/pos-jwt":
            res = handle_pos_jwt_auth_request(raw_body, client_ip=client_ip)
        elif self.path == "/api/auth/onboarding-jwt":
            res = handle_onboarding_jwt_request(raw_body, client_ip=client_ip)
        elif self.path == "/api/auth/exchange-store-jwt":
            res = handle_exchange_store_jwt_request(raw_body, auth_header=auth_header, client_ip=client_ip)
        else:
            res = {"success": False, "status": 404, "error": "NOT_FOUND"}

        self.send_response(res.get("status", 200))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(res).encode("utf-8"))

    def log_message(self, format, *args):
        # Do not log sensitive paths or data to standard stderr
        logger.debug("%s - - [%s] %s", self.address_string(), self.log_date_time_string(), format % args)


def run_server(host="0.0.0.0", port=8000):
    """Run the local WSGI server; production must use a hardened WSGI host (e.g. Gunicorn)."""
    logger.info("Starting POS JWT Gateway server on %s:%d", host, port)
    with make_server(host, port, wsgi_app) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server shutting down.")


if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", 8000))
    run_server(host=host, port=port)
