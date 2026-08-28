# services/pos_jwt_auth_service.py
# ─────────────────────────────────────────────────────────────────────────────
# Canonical Production POS JWT Auth Service for Supabase PostgREST RLS Guard
# Supports Standard POS JWT, Zero-Store Onboarding JWT, and Store Exchange.
# ─────────────────────────────────────────────────────────────────────────────
import base64
import hashlib
import hmac
import json
import logging
import os
import secrets
import time
import urllib.request
from threading import Lock

logger = logging.getLogger("pos_jwt_auth_service")


class PosJwtAuthError(Exception):
    def __init__(self, message, status_code=401, error_code="INVALID_CREDENTIALS"):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.error_code = error_code


class ThreadSafeRateLimiter:
    """Thread-safe rate limiter tracking failed auth attempts per IP and per Phone."""
    def __init__(self):
        self._lock = Lock()
        self._history = {}  # (key_type, key_val) -> list of timestamp floats

    def is_rate_limited(self, ip, phone, max_attempts=5, window_sec=300):
        now = time.time()
        with self._lock:
            for key in [("ip", str(ip).strip()), ("phone", str(phone).strip())]:
                if not key[1]:
                    continue
                history = [t for t in self._history.get(key, []) if now - t < window_sec]
                self._history[key] = history
                if len(history) >= max_attempts:
                    return True
        return False

    def record_attempt(self, ip, phone):
        now = time.time()
        with self._lock:
            for key in [("ip", str(ip).strip()), ("phone", str(phone).strip())]:
                if not key[1]:
                    continue
                history = self._history.get(key, [])
                history.append(now)
                self._history[key] = history


_rate_limiter = ThreadSafeRateLimiter()


def get_supabase_config():
    """Load Supabase URL, Anon Key, and JWT Secret strictly from explicit environment variables."""
    url = os.environ.get("SUPABASE_URL", "").strip()
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    jwt_secret = os.environ.get("SUPABASE_JWT_SECRET", "").strip()

    if not url or not anon_key or not jwt_secret:
        raise PosJwtAuthError("Server configuration incomplete", status_code=500, error_code="SERVER_CONFIG_ERROR")

    if not url.startswith("https://"):
        raise PosJwtAuthError("HTTPS transport required", status_code=400, error_code="TLS_REQUIRED")

    return url, anon_key, jwt_secret


def _b64url_encode(data_dict):
    raw_json = json.dumps(data_dict, separators=(',', ':')).encode('utf-8')
    return base64.urlsafe_b64encode(raw_json).decode('utf-8').rstrip('=')


def _b64url_decode(raw_str):
    padded = str(raw_str) + '=' * ((4 - len(str(raw_str)) % 4) % 4)
    return json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))


def verify_user_credentials_and_membership(supabase_url, anon_key, phone, password, store_id=None):
    """Authenticate through the database security-definer RPC without reading hashes."""
    effective_phone = str(phone or "").strip()
    effective_pwd = str(password or "").strip()
    effective_store = str(store_id or "").strip() if store_id else None

    if not effective_phone or not effective_pwd:
        raise PosJwtAuthError("Số điện thoại và mật khẩu là bắt buộc", status_code=400, error_code="MISSING_PARAMETERS")

    url = f"{supabase_url.rstrip('/')}/rest/v1/rpc/verify_user_login_v4"
    payload_dict = {
        "p_phone": effective_phone,
        "p_password": effective_pwd,
    }
    if effective_store:
        payload_dict["p_store_id"] = effective_store

    raw_payload = json.dumps(payload_dict).encode("utf-8")
    req = urllib.request.Request(url, data=raw_payload, headers={
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}",
        "User-Agent": "PosJwtAuthService/2.0",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status != 200:
                raise PosJwtAuthError(
                    "Dịch vụ xác thực cơ sở dữ liệu không sẵn sàng",
                    status_code=503,
                    error_code="AUTH_RPC_UNAVAILABLE",
                )
            result = json.loads(resp.read().decode("utf-8"))
    except PosJwtAuthError:
        raise
    except Exception as exc:
        logger.error("Auth RPC request failed: %s", type(exc).__name__)
        raise PosJwtAuthError(
            "Dịch vụ xác thực cơ sở dữ liệu không sẵn sàng",
            status_code=503,
            error_code="AUTH_RPC_UNAVAILABLE",
        ) from exc

    if not isinstance(result, dict) or result.get("success") is not True:
        status = int(result.get("status", 401)) if isinstance(result, dict) else 401
        error_code = (
            str(result.get("error_code", "INVALID_CREDENTIALS"))
            if isinstance(result, dict)
            else "INVALID_CREDENTIALS"
        )
        if status not in (400, 401, 403, 429):
            status = 401
            error_code = "INVALID_CREDENTIALS"
        message = (
            str(result.get("message", "Số điện thoại hoặc mật khẩu không chính xác"))
            if isinstance(result, dict)
            else "Số điện thoại hoặc mật khẩu không chính xác"
        )
        raise PosJwtAuthError(message, status_code=status, error_code=error_code)

    user_id = str(result.get("user_id") or "").strip()
    role = str(result.get("selected_role") or "").strip() if effective_store else None

    if not user_id:
        raise PosJwtAuthError(
            "Phản hồi xác thực không hợp lệ",
            status_code=503,
            error_code="INVALID_AUTH_RESPONSE",
        )

    return {
        "user_id": user_id,
        "store_id": effective_store,
        "role": role or "waiter",
        "stores": result.get("stores", []),
    }


def consume_onboarding_exchange_rpc(
    supabase_url,
    service_role_key,
    jti,
    exp,
    user_id,
    store_id,
):
    """Atomically authorize membership and consume an onboarding JTI.

    The service-role-only backing RPC checks membership and consumes the JTI in
    one database transaction. An in-process set is intentionally not accepted
    because it fails across workers and restarts.
    """
    if not service_role_key:
        raise PosJwtAuthError(
            "Persistent replay protection is not configured",
            status_code=503,
            error_code="REPLAY_STORE_UNAVAILABLE",
        )

    jti_hash = hashlib.sha256(str(jti).encode("utf-8")).hexdigest()
    url = f"{supabase_url.rstrip('/')}/rest/v1/rpc/consume_onboarding_exchange_v4"
    req = urllib.request.Request(
        url,
        data=json.dumps({
            "p_jti_hash": jti_hash,
            "p_expires_at_epoch": int(exp),
            "p_user_id": str(user_id),
            "p_store_id": str(store_id),
        }).encode("utf-8"),
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "User-Agent": "PosJwtAuthService/2.0",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status != 200:
                raise PosJwtAuthError(
                    "Persistent replay protection is unavailable",
                    status_code=503,
                    error_code="REPLAY_STORE_UNAVAILABLE",
                )
            result = json.loads(resp.read().decode("utf-8"))
    except PosJwtAuthError:
        raise
    except Exception as exc:
        logger.error("Replay store request failed: %s", type(exc).__name__)
        raise PosJwtAuthError(
            "Persistent replay protection is unavailable",
            status_code=503,
            error_code="REPLAY_STORE_UNAVAILABLE",
        ) from exc

    if not isinstance(result, dict):
        raise PosJwtAuthError(
            "Persistent replay protection returned an invalid response",
            status_code=503,
            error_code="REPLAY_STORE_UNAVAILABLE",
        )
    return result


def issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role="cashier", ttl_seconds=28800):
    """Issue a Supabase PostgREST compliant HS256 JWT with complete standard claims."""
    if not jwt_secret:
        raise PosJwtAuthError("Server JWT signing key missing", status_code=500, error_code="SERVER_CONFIG_ERROR")

    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user_id),
        "role": "authenticated",
        "staff_role": str(staff_role),
        "store_id": str(store_id),
        "aud": "authenticated",
        "iss": "supabase",
        "iat": now,
        "nbf": now,
        "exp": now + ttl_seconds,
        "jti": f"pos_{secrets.token_urlsafe(18)}"
    }

    header_b64 = _b64url_encode(header)
    payload_b64 = _b64url_encode(payload)
    signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')

    signature = hmac.new(jwt_secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(signature).decode('utf-8').rstrip('=')

    return f"{header_b64}.{payload_b64}.{sig_b64}"


def issue_hs256_onboarding_jwt(user_id, jwt_secret, ttl_seconds=600):
    """Issue a short-lived Onboarding JWT for users without a store (max 10 minutes)."""
    if not jwt_secret:
        raise PosJwtAuthError("Server JWT signing key missing", status_code=500, error_code="SERVER_CONFIG_ERROR")

    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user_id),
        "role": "authenticated",
        "aud": "authenticated",
        "iss": "supabase",
        "iat": now,
        "nbf": now,
        "exp": now + ttl_seconds,
        "jti": f"onb_{secrets.token_urlsafe(18)}",
        "token_use": "onboarding"
    }

    header_b64 = _b64url_encode(header)
    payload_b64 = _b64url_encode(payload)
    signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')

    signature = hmac.new(jwt_secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(signature).decode('utf-8').rstrip('=')

    return f"{header_b64}.{payload_b64}.{sig_b64}"


def verify_and_decode_hs256_jwt(token, jwt_secret, expected_token_use=None):
    """Verify cryptographic signature, expiration, and claims of HS256 JWT."""
    if not token or not isinstance(token, str):
        raise PosJwtAuthError("Token xác thực không hợp lệ", status_code=401, error_code="INVALID_TOKEN")

    parts = token.strip().split(".")
    if len(parts) != 3:
        raise PosJwtAuthError("Định dạng token không hợp lệ", status_code=401, error_code="MALFORMED_TOKEN")

    try:
        header = _b64url_decode(parts[0])
    except Exception:
        raise PosJwtAuthError("Header token không hợp lệ", status_code=401, error_code="MALFORMED_TOKEN")
    if header.get("alg") != "HS256" or header.get("typ") != "JWT":
        raise PosJwtAuthError("Thuật toán token không hợp lệ", status_code=401, error_code="INVALID_TOKEN_ALGORITHM")

    signing_input = f"{parts[0]}.{parts[1]}".encode('utf-8')
    expected_sig = hmac.new(jwt_secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    expected_sig_b64 = base64.urlsafe_b64encode(expected_sig).decode('utf-8').rstrip('=')

    if not hmac.compare_digest(expected_sig_b64, parts[2]):
        raise PosJwtAuthError("Chữ ký token không hợp lệ", status_code=401, error_code="INVALID_SIGNATURE")

    try:
        payload = _b64url_decode(parts[1])
    except Exception:
        raise PosJwtAuthError("Payload token không hợp lệ", status_code=401, error_code="MALFORMED_TOKEN")

    now = time.time()
    required_text_claims = ("sub", "jti", "iss", "role")
    if any(not str(payload.get(name) or "").strip() for name in required_text_claims):
        raise PosJwtAuthError("Token thiếu claim bắt buộc", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if payload.get("iss") != "supabase" or payload.get("role") != "authenticated":
        raise PosJwtAuthError("Token có claim không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    audience = payload.get("aud")
    if audience != "authenticated" and not (isinstance(audience, list) and "authenticated" in audience):
        raise PosJwtAuthError("Audience token không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if not isinstance(payload.get("iat"), int) or not isinstance(payload.get("exp"), int):
        raise PosJwtAuthError("Thời hạn token không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if payload.get("iat") > now + 30:
        raise PosJwtAuthError("Token có thời điểm phát hành không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if payload.get("exp", 0) <= now:
        raise PosJwtAuthError("Token đã hết hạn", status_code=401, error_code="TOKEN_EXPIRED")

    if payload.get("nbf", 0) > now + 30:
        raise PosJwtAuthError("Token chưa có hiệu lực", status_code=401, error_code="TOKEN_NOT_YET_VALID")

    if expected_token_use and payload.get("token_use") != expected_token_use:
        raise PosJwtAuthError(f"Mục đích token không đúng (yêu cầu {expected_token_use})", status_code=403, error_code="INVALID_TOKEN_USE")

    if expected_token_use == "onboarding":
        if payload.get("store_id") is not None or payload["exp"] - payload["iat"] > 600:
            raise PosJwtAuthError("Phạm vi token onboarding không hợp lệ", status_code=403, error_code="INVALID_TOKEN_SCOPE")

    return payload


def handle_pos_jwt_auth_request(raw_body, client_ip="127.0.0.1"):
    """Main production request handler / route adapter for /api/auth/pos-jwt."""
    if len(raw_body or b"") > 4096:
        return {"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE", "message": "Dữ liệu yêu cầu vượt quá 4KB"}

    try:
        body_text = raw_body.decode('utf-8') if isinstance(raw_body, bytes) else str(raw_body)
        payload = json.loads(body_text) if body_text else {}
    except Exception:
        return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}

    phone = str(payload.get("phone") or "").strip()
    password = str(payload.get("password") or "").strip()
    store_id = str(payload.get("store_id") or "").strip()

    if not phone or not password or not store_id:
        return {"success": False, "status": 400, "error": "MISSING_PARAMETERS", "message": "Số điện thoại, mật khẩu và cửa hàng là bắt buộc"}

    if _rate_limiter.is_rate_limited(client_ip, phone):
        logger.warning("Rate limit exceeded for an authentication principal")
        return {"success": False, "status": 429, "error": "RATE_LIMIT_EXCEEDED", "message": "Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút."}

    try:
        supabase_url, anon_key, jwt_secret = get_supabase_config()
        auth_info = verify_user_credentials_and_membership(supabase_url, anon_key, phone, password, store_id)
        token = issue_hs256_pos_jwt(
            auth_info["user_id"],
            auth_info["store_id"],
            jwt_secret,
            staff_role=auth_info["role"],
        )
        logger.info("Successfully issued POS JWT")
        return {
            "success": True,
            "status": 200,
            "pos_jwt": token,
            "store_id": auth_info["store_id"],
            "role": auth_info["role"]
        }
    except PosJwtAuthError as e:
        if e.status_code in (400, 401, 403):
            _rate_limiter.record_attempt(client_ip, phone)
        logger.warning("PosJwtAuthError: code=%s, status=%d", e.error_code, e.status_code)
        return {
            "success": False,
            "status": e.status_code,
            "error": e.error_code,
            "message": e.message
        }
    except Exception as e:
        logger.error("Unhandled auth error: %s", type(e).__name__)
        return {
            "success": False,
            "status": 500,
            "error": "SERVER_ERROR",
            "message": "Lỗi xác thực hệ thống"
        }


def handle_onboarding_jwt_request(raw_body, client_ip="127.0.0.1"):
    """Request handler for POST /api/auth/onboarding-jwt (for zero-store / new user onboarding)."""
    if len(raw_body or b"") > 4096:
        return {"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE", "message": "Dữ liệu yêu cầu vượt quá 4KB"}

    try:
        body_text = raw_body.decode('utf-8') if isinstance(raw_body, bytes) else str(raw_body)
        payload = json.loads(body_text) if body_text else {}
    except Exception:
        return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}

    phone = str(payload.get("phone") or "").strip()
    password = str(payload.get("password") or "").strip()

    if not phone or not password:
        return {"success": False, "status": 400, "error": "MISSING_PARAMETERS", "message": "Số điện thoại và mật khẩu là bắt buộc"}

    if _rate_limiter.is_rate_limited(client_ip, phone):
        logger.warning("Rate limit exceeded for onboarding auth principal")
        return {"success": False, "status": 429, "error": "RATE_LIMIT_EXCEEDED", "message": "Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút."}

    try:
        supabase_url, anon_key, jwt_secret = get_supabase_config()
        auth_info = verify_user_credentials_and_membership(supabase_url, anon_key, phone, password, store_id=None)
        if auth_info.get("stores"):
            return {
                "success": False,
                "status": 409,
                "error": "ONBOARDING_NOT_REQUIRED",
                "message": "Tài khoản đã thuộc cửa hàng; hãy dùng phiên đăng nhập cửa hàng",
            }
        token = issue_hs256_onboarding_jwt(auth_info["user_id"], jwt_secret, ttl_seconds=600)
        logger.info("Successfully issued Onboarding JWT")
        return {
            "success": True,
            "status": 200,
            "onboarding_jwt": token,
            "user_id": auth_info["user_id"],
            "stores": auth_info.get("stores", [])
        }
    except PosJwtAuthError as e:
        if e.status_code in (400, 401, 403):
            _rate_limiter.record_attempt(client_ip, phone)
        logger.warning("Onboarding PosJwtAuthError: code=%s, status=%d", e.error_code, e.status_code)
        return {
            "success": False,
            "status": e.status_code,
            "error": e.error_code,
            "message": e.message
        }
    except Exception as e:
        logger.error("Unhandled onboarding auth error: %s", type(e).__name__)
        return {
            "success": False,
            "status": 500,
            "error": "SERVER_ERROR",
            "message": "Lỗi xác thực hệ thống"
        }


def handle_exchange_store_jwt_request(raw_body, auth_header=None, client_ip="127.0.0.1"):
    """Request handler for POST /api/auth/exchange-store-jwt (exchange onboarding token for store POS JWT)."""
    if len(raw_body or b"") > 4096:
        return {"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE", "message": "Dữ liệu yêu cầu vượt quá 4KB"}

    try:
        body_text = raw_body.decode('utf-8') if isinstance(raw_body, bytes) else str(raw_body)
        payload = json.loads(body_text) if body_text else {}
    except Exception:
        return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}

    token = None
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header[7:].strip()
    if not token:
        token = str(payload.get("onboarding_jwt") or "").strip()

    store_id = str(payload.get("store_id") or "").strip()

    if not token or not store_id:
        return {"success": False, "status": 400, "error": "MISSING_PARAMETERS", "message": "Token onboarding và cửa hàng là bắt buộc"}

    try:
        supabase_url, _anon_key, jwt_secret = get_supabase_config()
        token_payload = verify_and_decode_hs256_jwt(token, jwt_secret, expected_token_use="onboarding")

        jti = token_payload.get("jti")
        user_id = token_payload.get("sub")
        if not user_id:
            return {"success": False, "status": 401, "error": "INVALID_TOKEN", "message": "Token không có định danh người dùng"}

        service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        exchange_authorization = consume_onboarding_exchange_rpc(
            supabase_url,
            service_role_key,
            jti,
            token_payload["exp"],
            user_id,
            store_id,
        )
        if exchange_authorization.get("success") is not True:
            error_code = str(exchange_authorization.get("error_code") or "TOKEN_REPLAY_REJECTED")
            if error_code == "STORE_MEMBERSHIP_FORBIDDEN":
                return {"success": False, "status": 403, "error": error_code, "message": "Tài khoản không thuộc cửa hàng này"}
            logger.warning("Replay of onboarding token detected")
            return {"success": False, "status": 401, "error": "TOKEN_REPLAY_REJECTED", "message": "Mã xác thực onboarding đã được sử dụng"}

        role = str(exchange_authorization.get("role") or "waiter")

        # Issue store-scoped POS JWT
        pos_jwt = issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role=role or "cashier")
        logger.info("Successfully exchanged onboarding token for store POS JWT")
        return {
            "success": True,
            "status": 200,
            "pos_jwt": pos_jwt,
            "store_id": store_id,
            "role": role or "cashier"
        }
    except PosJwtAuthError as e:
        logger.warning("Exchange PosJwtAuthError: code=%s, status=%d", e.error_code, e.status_code)
        return {
            "success": False,
            "status": e.status_code,
            "error": e.error_code,
            "message": e.message
        }
    except Exception as e:
        logger.error("Unhandled exchange error: %s", type(e).__name__)
        return {
            "success": False,
            "status": 500,
            "error": "SERVER_ERROR",
            "message": "Lỗi xác thực hệ thống"
        }
