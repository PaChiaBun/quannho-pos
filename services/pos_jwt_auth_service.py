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
import urllib.parse
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
_refresh_rate_limiter = ThreadSafeRateLimiter()

LEGACY_POS_JWT_TTL_SECONDS = 2592000  # 30 ngày — chỉ cho bản app cũ chưa hỗ trợ refresh


def _env_int(name, default, minimum, maximum):
    try:
        value = int(str(os.environ.get(name, "")).strip() or default)
    except ValueError:
        value = default
    return max(minimum, min(maximum, value))


def get_token_policy():
    """TTL policy. Access token ngắn hạn + refresh token dài hạn xoay vòng."""
    return {
        # Chủ Quán quyết định (13/10/2026): access token 30 ngày để nhân viên không bị đăng xuất giữa ca.
        # Đánh đổi: token bị lộ vẫn dùng được tới khi hết hạn; thu hồi tức thì chỉ bằng cách đổi JWT secret (đăng xuất mọi người).
        "access_ttl": _env_int("POS_ACCESS_TTL_SECONDS", 2592000, 300, 2592000),
        "refresh_ttl": _env_int("POS_REFRESH_TTL_SECONDS", 2592000, 3600, 7776000),
        "refresh_enabled": str(os.environ.get("POS_REFRESH_ENABLED", "1")).strip() not in ("0", "false", "no"),
    }


def generate_refresh_token():
    """Return (plain_token, sha256_hex). Only the hash is ever stored server-side."""
    plain = "qnr_" + secrets.token_urlsafe(32)
    return plain, hash_refresh_token(plain)


def hash_refresh_token(plain):
    return hashlib.sha256(str(plain).encode("utf-8")).hexdigest()


def _client_wants_refresh(payload):
    value = payload.get("supports_refresh") if isinstance(payload, dict) else None
    return value is True or str(value).strip().lower() in ("1", "true", "yes")


def call_service_rpc(supabase_url, service_role_key, rpc_name, params, timeout=8):
    """POST a service-role-only RPC. Raises PosJwtAuthError(503) on infra failure."""
    if not service_role_key:
        raise PosJwtAuthError("Refresh store is not configured", status_code=503, error_code="REFRESH_STORE_UNAVAILABLE")
    req = urllib.request.Request(
        f"{supabase_url.rstrip('/')}/rest/v1/rpc/{rpc_name}",
        data=json.dumps(params).encode("utf-8"),
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "User-Agent": "PosJwtAuthService/2.1",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                raise PosJwtAuthError("Refresh store unavailable", status_code=503, error_code="REFRESH_STORE_UNAVAILABLE")
            result = json.loads(resp.read().decode("utf-8"))
    except PosJwtAuthError:
        raise
    except Exception as exc:
        logger.error("Service RPC %s failed: %s", rpc_name, type(exc).__name__)
        raise PosJwtAuthError("Refresh store unavailable", status_code=503, error_code="REFRESH_STORE_UNAVAILABLE") from exc
    if not isinstance(result, dict):
        raise PosJwtAuthError("Refresh store returned an invalid response", status_code=503, error_code="REFRESH_STORE_UNAVAILABLE")
    return result


def issue_token_pair(supabase_url, jwt_secret, user_id, store_id, role, client_ip, client_label=None):
    """Issue short access JWT + rotating refresh token.

    Returns None when the refresh store is unavailable so callers can fall back to
    the legacy long-lived token instead of failing a login (zero-downtime deploy).
    """
    policy = get_token_policy()
    if not policy["refresh_enabled"]:
        return None
    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    plain, token_hash = generate_refresh_token()
    try:
        result = call_service_rpc(supabase_url, service_role_key, "qn_refresh_issue_v1", {
            "p_user_id": str(user_id),
            "p_store_id": str(store_id),
            "p_token_hash": token_hash,
            "p_ttl_seconds": policy["refresh_ttl"],
            "p_client_label": (str(client_label)[:120] if client_label else None),
            "p_client_ip": str(client_ip or "")[:64] or None,
        })
    except PosJwtAuthError as exc:
        logger.warning("Refresh issue unavailable, falling back to legacy token: %s", exc.error_code)
        return None
    if result.get("success") is not True:
        if result.get("error_code") == "STORE_MEMBERSHIP_FORBIDDEN":
            raise PosJwtAuthError("Tài khoản không thuộc cửa hàng này", status_code=403, error_code="STORE_MEMBERSHIP_FORBIDDEN")
        logger.warning("Refresh issue rejected: %s", result.get("error_code"))
        return None
    effective_role = str(result.get("role") or role or "cashier")
    access = issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role=effective_role, ttl_seconds=policy["access_ttl"])
    return {
        "pos_jwt": access,
        "refresh_token": plain,
        "expires_in": policy["access_ttl"],
        "refresh_expires_in": policy["refresh_ttl"],
        "role": effective_role,
    }


def get_supabase_config():
    """Load Supabase URL, Anon Key, and JWT Secret strictly from explicit environment variables."""
    url = (
        os.environ.get("SUPABASE_INTERNAL_URL", "").strip()
        or os.environ.get("SUPABASE_URL", "").strip()
    )
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    jwt_secret = os.environ.get("SUPABASE_JWT_SECRET", "").strip()

    if not url or not anon_key or not jwt_secret:
        raise PosJwtAuthError("Server configuration incomplete", status_code=500, error_code="SERVER_CONFIG_ERROR")

    if not url.startswith("https://") and not url.startswith("http://127.0.0.1") and not url.startswith("http://localhost"):
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


def issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role="cashier", ttl_seconds=2592000):
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
    if payload.get("exp", 0) <= payload.get("iat", 0):
        raise PosJwtAuthError("Thời hạn token không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if payload.get("iat") > now + 30:
        raise PosJwtAuthError("Token có thời điểm phát hành không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
    if payload.get("exp", 0) <= now:
        raise PosJwtAuthError("Token đã hết hạn", status_code=401, error_code="TOKEN_EXPIRED")

    nbf = payload.get("nbf")
    if nbf is not None:
        if not isinstance(nbf, int):
            raise PosJwtAuthError("Thời điểm hiệu lực token không hợp lệ", status_code=401, error_code="INVALID_TOKEN_CLAIMS")
        if nbf > now + 30:
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
        if not isinstance(payload, dict):
            return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}
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
        if _client_wants_refresh(payload):
            pair = issue_token_pair(
                supabase_url, jwt_secret, auth_info["user_id"], auth_info["store_id"],
                auth_info["role"], client_ip, client_label=payload.get("client_label"),
            )
            if pair:
                logger.info("Successfully issued POS JWT + refresh token")
                return {
                    "success": True,
                    "status": 200,
                    "pos_jwt": pair["pos_jwt"],
                    "refresh_token": pair["refresh_token"],
                    "expires_in": pair["expires_in"],
                    "refresh_expires_in": pair["refresh_expires_in"],
                    "store_id": auth_info["store_id"],
                    "role": pair["role"],
                }
        token = issue_hs256_pos_jwt(
            auth_info["user_id"],
            auth_info["store_id"],
            jwt_secret,
            staff_role=auth_info["role"],
            ttl_seconds=LEGACY_POS_JWT_TTL_SECONDS,
        )
        logger.info("Successfully issued POS JWT")
        return {
            "success": True,
            "status": 200,
            "pos_jwt": token,
            "expires_in": LEGACY_POS_JWT_TTL_SECONDS,
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
        if not isinstance(payload, dict):
            return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}
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
        if not isinstance(payload, dict):
            return {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}
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

        if _client_wants_refresh(payload):
            pair = issue_token_pair(supabase_url, jwt_secret, user_id, store_id, role, client_ip,
                                    client_label=payload.get("client_label"))
            if pair:
                logger.info("Exchanged onboarding token for POS JWT + refresh token")
                return {
                    "success": True,
                    "status": 200,
                    "pos_jwt": pair["pos_jwt"],
                    "refresh_token": pair["refresh_token"],
                    "expires_in": pair["expires_in"],
                    "refresh_expires_in": pair["refresh_expires_in"],
                    "store_id": store_id,
                    "role": pair["role"],
                }

        # Issue store-scoped POS JWT (legacy long-lived)
        pos_jwt = issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role=role or "cashier",
                                      ttl_seconds=LEGACY_POS_JWT_TTL_SECONDS)
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


def _parse_json_body(raw_body):
    if len(raw_body or b"") > 4096:
        return None, {"success": False, "status": 400, "error": "PAYLOAD_TOO_LARGE", "message": "Dữ liệu yêu cầu vượt quá 4KB"}
    try:
        body_text = raw_body.decode('utf-8') if isinstance(raw_body, bytes) else str(raw_body or "")
        payload = json.loads(body_text) if body_text else {}
    except Exception:
        payload = None
    if not isinstance(payload, dict):
        return None, {"success": False, "status": 400, "error": "MALFORMED_JSON", "message": "Định dạng JSON không hợp lệ"}
    return payload, None


_REFRESH_ERROR_MAP = {
    "REFRESH_RACE": (409, "Phiên đang được làm mới ở nơi khác, vui lòng thử lại"),
    "REFRESH_EXPIRED": (401, "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại"),
    "REFRESH_REVOKED": (401, "Phiên đăng nhập đã bị thu hồi, vui lòng đăng nhập lại"),
    "REFRESH_REUSED": (401, "Phiên đăng nhập không còn hợp lệ, vui lòng đăng nhập lại"),
    "REFRESH_INVALID": (401, "Phiên đăng nhập không hợp lệ, vui lòng đăng nhập lại"),
    "STORE_MEMBERSHIP_FORBIDDEN": (403, "Tài khoản không còn thuộc cửa hàng này"),
    "INVALID_PARAMETERS": (400, "Yêu cầu không hợp lệ"),
}


def _valid_refresh_format(token):
    return isinstance(token, str) and token.startswith("qnr_") and 20 <= len(token) <= 200


def handle_refresh_request(raw_body, client_ip="127.0.0.1"):
    """POST /api/auth/refresh {refresh_token} -> new access JWT + rotated refresh token."""
    payload, err = _parse_json_body(raw_body)
    if err:
        return err
    refresh_token = str(payload.get("refresh_token") or "").strip()
    if not refresh_token:
        return {"success": False, "status": 400, "error": "MISSING_PARAMETERS", "message": "Thiếu refresh token"}

    if _refresh_rate_limiter.is_rate_limited(client_ip, "", max_attempts=20, window_sec=300):
        return {"success": False, "status": 429, "error": "RATE_LIMIT_EXCEEDED", "message": "Quá nhiều yêu cầu. Vui lòng thử lại sau."}

    if not _valid_refresh_format(refresh_token):
        _refresh_rate_limiter.record_attempt(client_ip, "")
        return {"success": False, "status": 401, "error": "REFRESH_INVALID", "message": _REFRESH_ERROR_MAP["REFRESH_INVALID"][1]}

    try:
        supabase_url, _anon_key, jwt_secret = get_supabase_config()
        policy = get_token_policy()
        service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        new_plain, new_hash = generate_refresh_token()
        result = call_service_rpc(supabase_url, service_role_key, "qn_refresh_rotate_v1", {
            "p_old_hash": hash_refresh_token(refresh_token),
            "p_new_hash": new_hash,
            "p_ttl_seconds": policy["refresh_ttl"],
            "p_client_ip": str(client_ip or "")[:64] or None,
        })
        if result.get("success") is not True:
            code = str(result.get("error_code") or "REFRESH_INVALID")
            status, message = _REFRESH_ERROR_MAP.get(code, _REFRESH_ERROR_MAP["REFRESH_INVALID"])
            if status == 401:
                _refresh_rate_limiter.record_attempt(client_ip, "")
            logger.warning("Refresh rejected: %s", code)
            return {"success": False, "status": status, "error": code, "message": message}

        user_id = str(result.get("user_id") or "")
        store_id = str(result.get("store_id") or "")
        role = str(result.get("role") or "cashier")
        if not user_id or not store_id:
            raise PosJwtAuthError("Invalid refresh response", status_code=503, error_code="REFRESH_STORE_UNAVAILABLE")
        access = issue_hs256_pos_jwt(user_id, store_id, jwt_secret, staff_role=role, ttl_seconds=policy["access_ttl"])
        return {
            "success": True,
            "status": 200,
            "pos_jwt": access,
            "refresh_token": new_plain,
            "expires_in": policy["access_ttl"],
            "refresh_expires_in": policy["refresh_ttl"],
            "store_id": store_id,
            "role": role,
        }
    except PosJwtAuthError as e:
        logger.warning("Refresh PosJwtAuthError: code=%s, status=%d", e.error_code, e.status_code)
        return {"success": False, "status": e.status_code, "error": e.error_code, "message": e.message}
    except Exception as e:
        logger.error("Unhandled refresh error: %s", type(e).__name__)
        return {"success": False, "status": 500, "error": "SERVER_ERROR", "message": "Lỗi xác thực hệ thống"}


def handle_logout_request(raw_body, client_ip="127.0.0.1"):
    """POST /api/auth/logout {refresh_token} -> revoke the whole refresh family. Idempotent."""
    payload, err = _parse_json_body(raw_body)
    if err:
        return err
    refresh_token = str(payload.get("refresh_token") or "").strip()
    if not _valid_refresh_format(refresh_token):
        return {"success": True, "status": 200, "revoked": 0}
    try:
        supabase_url, _anon_key, _jwt_secret = get_supabase_config()
        service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        result = call_service_rpc(supabase_url, service_role_key, "qn_refresh_revoke_v1", {
            "p_token_hash": hash_refresh_token(refresh_token),
            "p_reason": "logout",
        })
        return {"success": True, "status": 200, "revoked": int(result.get("revoked") or 0)}
    except PosJwtAuthError as e:
        return {"success": False, "status": e.status_code, "error": e.error_code, "message": e.message}
    except Exception as e:
        logger.error("Unhandled logout error: %s", type(e).__name__)
        return {"success": False, "status": 500, "error": "SERVER_ERROR", "message": "Lỗi xác thực hệ thống"}


# ─────────────────────────────────────────────────────────────────────────────
# QR gọi món — vé xác minh người thật (Cloudflare Turnstile → vé HMAC)
# POST /api/auth/qr-ticket {channel_code, idempotency_key, turnstile_token}
# Vé = "<hết hạn epoch>.<HMAC-SHA256(secret, channel_code|exp|idempotency_key)>", sống 5 phút,
# chỉ dùng được cho ĐÚNG khoá chống trùng của một đơn (db: qr_verify_ticket_v4).
# ─────────────────────────────────────────────────────────────────────────────
QR_TICKET_TTL_SECONDS = 300
_QR_CFG_CACHE = {"at": 0.0, "value": None}
_QR_CFG_LOCK = Lock()
_TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"


def _qr_gateway_config(supabase_url, service_role_key, now=None):
    now = time.time() if now is None else now
    with _QR_CFG_LOCK:
        if _QR_CFG_CACHE["value"] is not None and now - _QR_CFG_CACHE["at"] < 30:
            return _QR_CFG_CACHE["value"]
    cfg = call_service_rpc(supabase_url, service_role_key, "qr_gateway_config_v1", {})
    with _QR_CFG_LOCK:
        _QR_CFG_CACHE["value"] = cfg
        _QR_CFG_CACHE["at"] = now
    return cfg


def _verify_turnstile(secret, token, client_ip, timeout=6):
    """True nếu Cloudflare xác nhận token. Lỗi mạng => PosJwtAuthError(503)."""
    form = {"secret": secret, "response": token}
    if client_ip:
        form["remoteip"] = client_ip
    req = urllib.request.Request(
        _TURNSTILE_VERIFY_URL,
        data=urllib.parse.urlencode(form).encode("utf-8"),
        headers={"Content-Type": "application/x-www-form-urlencoded", "User-Agent": "PosJwtAuthService/2.1"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        logger.error("Turnstile verify failed: %s", type(exc).__name__)
        raise PosJwtAuthError("Không kiểm tra được xác minh, thử lại sau", status_code=503, error_code="TURNSTILE_UNAVAILABLE") from exc
    return bool(isinstance(data, dict) and data.get("success") is True)


def make_qr_ticket(secret, channel_code, idempotency_key, now=None, ttl=QR_TICKET_TTL_SECONDS):
    exp = int((time.time() if now is None else now)) + int(ttl)
    msg = f"{channel_code}|{exp}|{idempotency_key}".encode("utf-8")
    sig = hmac.new(secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()
    return f"{exp}.{sig}"


def handle_qr_ticket_request(raw_body, client_ip="127.0.0.1"):
    payload, err = _parse_json_body(raw_body)
    if err:
        return err
    channel_code = str(payload.get("channel_code") or "").strip()
    key = str(payload.get("idempotency_key") or "").strip()
    token = str(payload.get("turnstile_token") or "").strip()
    if not channel_code or len(channel_code) > 64 or not (8 <= len(key) <= 128) or not token or len(token) > 2048:
        return {"success": False, "status": 400, "error": "INVALID_PARAMETERS", "message": "Yêu cầu không hợp lệ"}
    try:
        supabase_url, _anon_key, _jwt_secret = get_supabase_config()
        service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        cfg = _qr_gateway_config(supabase_url, service_role_key)
        ticket_secret = str(cfg.get("ticket_secret") or "")
        turnstile_secret = str(cfg.get("turnstile_secret") or "")
        if not ticket_secret or not turnstile_secret:
            return {"success": False, "status": 503, "error": "TURNSTILE_NOT_CONFIGURED",
                    "message": "Chưa cấu hình xác minh người thật"}
        if not _verify_turnstile(turnstile_secret, token, client_ip):
            return {"success": False, "status": 403, "error": "TURNSTILE_FAILED",
                    "message": "Xác minh không thành công, vui lòng thử lại"}
        return {"success": True, "status": 200, "ticket": make_qr_ticket(ticket_secret, channel_code, key),
                "expires_in": QR_TICKET_TTL_SECONDS}
    except PosJwtAuthError as e:
        return {"success": False, "status": e.status_code, "error": e.error_code, "message": e.message}
    except Exception as e:
        logger.error("Unhandled qr-ticket error: %s", type(e).__name__)
        return {"success": False, "status": 500, "error": "SERVER_ERROR", "message": "Lỗi hệ thống"}
