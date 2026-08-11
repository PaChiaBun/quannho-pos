# services/pos_jwt_auth_service.py
# ─────────────────────────────────────────────────────────────────────────────
# Canonical Production POS JWT Auth Service for Supabase PostgREST RLS Guard
# ─────────────────────────────────────────────────────────────────────────────
import os
import json
import time
import hmac
import hashlib
import base64
import logging
import urllib.request
import urllib.parse
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


def constant_time_password_hash_check(phone, password, stored_hash, salt="qn_pos_2024_salt"):
    """Verify password_hash against sha256(phone:password:qn_pos_2024_salt) using hmac.compare_digest."""
    if not password or not stored_hash:
        return False
    
    clean_digits = "".join(c for c in str(phone) if c.isdigit())
    phone_variants = [str(phone).strip()]
    if len(clean_digits) >= 9:
        last9 = clean_digits[-9:]
        phone_variants.extend([f"0{last9}", f"+84{last9}", f"84{last9}"])

    for p_var in phone_variants:
        calc_input = f"{p_var}:{password}:{salt}".encode('utf-8')
        calc_hash = hashlib.sha256(calc_input).hexdigest()
        if hmac.compare_digest(calc_hash.lower(), stored_hash.lower()):
            return True
    return False


def verify_user_credentials_and_membership(supabase_url, anon_key, phone, password, store_id):
    """Authenticate phone+password against user_accounts and verify active store_members role."""
    effective_phone = str(phone or "").strip()
    effective_pwd = str(password or "").strip()
    effective_store = str(store_id or "").strip()

    if not effective_phone or not effective_pwd or not effective_store:
        raise PosJwtAuthError("Số điện thoại, mật khẩu và cửa hàng là bắt buộc", status_code=400, error_code="MISSING_PARAMETERS")

    clean_digits = "".join(c for c in effective_phone if c.isdigit())
    phone_variants = [effective_phone]
    if len(clean_digits) >= 9:
        last9 = clean_digits[-9:]
        phone_variants.extend([f"0{last9}", f"+84{last9}", f"84{last9}"])

    user_acc = None
    for p in phone_variants:
        try:
            encoded_p = urllib.parse.quote(p)
            url = f"{supabase_url.rstrip('/')}/rest/v1/user_accounts?select=id,phone,password_hash&phone=eq.{encoded_p}&limit=1"
            req = urllib.request.Request(url, headers={
                "apikey": anon_key,
                "Authorization": f"Bearer {anon_key}",
                "User-Agent": "PosJwtAuthService/1.0",
                "Content-Type": "application/json",
                "Accept": "application/json"
            }, method="GET")

            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    if isinstance(data, list) and len(data) > 0:
                        user_acc = data[0]
                        break
        except Exception as e:
            logger.debug("Failed querying user_accounts: %s", type(e).__name__)

    if not user_acc:
        raise PosJwtAuthError("Số điện thoại hoặc mật khẩu không chính xác", status_code=401, error_code="INVALID_CREDENTIALS")

    stored_hash = user_acc.get("password_hash", "")
    db_phone = user_acc.get("phone", effective_phone)
    user_id = user_acc.get("id")

    if not constant_time_password_hash_check(db_phone, effective_pwd, stored_hash):
        raise PosJwtAuthError("Số điện thoại hoặc mật khẩu không chính xác", status_code=401, error_code="INVALID_CREDENTIALS")

    # Verify store_members active membership or stores owner
    is_member = False
    role = "cashier"
    try:
        url = f"{supabase_url.rstrip('/')}/rest/v1/store_members?select=user_id,store_id,role,is_owner&user_id=eq.{user_id}&store_id=eq.{effective_store}"
        req = urllib.request.Request(url, headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "User-Agent": "PosJwtAuthService/1.0",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }, method="GET")

        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode('utf-8'))
                if isinstance(data, list) and len(data) > 0:
                    row = data[0]
                    is_member = True
                    role = str(row.get("role", "cashier")).strip()
    except Exception as e:
        logger.debug("Failed querying store_members: %s", type(e).__name__)

    if not is_member:
        try:
            url = f"{supabase_url.rstrip('/')}/rest/v1/stores?select=id,owner_user_id&id=eq.{effective_store}&owner_user_id=eq.{user_id}"
            req = urllib.request.Request(url, headers={
                "apikey": anon_key,
                "Authorization": f"Bearer {anon_key}",
                "User-Agent": "PosJwtAuthService/1.0",
                "Content-Type": "application/json",
                "Accept": "application/json"
            }, method="GET")

            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    if isinstance(data, list) and len(data) > 0:
                        is_member = True
                        role = "owner"
        except Exception as e:
            logger.debug("Failed querying stores owner: %s", type(e).__name__)

    if not is_member:
        raise PosJwtAuthError("Tài khoản không thuộc cửa hàng này", status_code=403, error_code="STORE_MEMBERSHIP_FORBIDDEN")

    return {
        "user_id": user_id,
        "store_id": effective_store,
        "role": role
    }


def issue_hs256_pos_jwt(user_id, store_id, jwt_secret, ttl_seconds=28800):
    """Issue a Supabase PostgREST compliant HS256 JWT valid for at most one shift (8 hours)."""
    if not jwt_secret:
        raise PosJwtAuthError("Server JWT signing key missing", status_code=500, error_code="SERVER_CONFIG_ERROR")

    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user_id),
        "role": "authenticated",
        "store_id": str(store_id),
        "aud": "authenticated",
        "iss": "supabase",
        "iat": now,
        "nbf": now,
        "exp": now + ttl_seconds,
        "jti": f"pos_{user_id}_{now}"
    }

    def b64url_encode(data_dict):
        raw_json = json.dumps(data_dict, separators=(',', ':')).encode('utf-8')
        return base64.urlsafe_b64encode(raw_json).decode('utf-8').rstrip('=')

    header_b64 = b64url_encode(header)
    payload_b64 = b64url_encode(payload)
    signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')

    signature = hmac.new(jwt_secret.encode('utf-8'), signing_input, hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(signature).decode('utf-8').rstrip('=')

    return f"{header_b64}.{payload_b64}.{sig_b64}"


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
        logger.warning("Rate limit exceeded for IP %s / Phone %s", client_ip, phone[:4] + "***")
        return {"success": False, "status": 429, "error": "RATE_LIMIT_EXCEEDED", "message": "Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút."}

    try:
        supabase_url, anon_key, jwt_secret = get_supabase_config()
        auth_info = verify_user_credentials_and_membership(supabase_url, anon_key, phone, password, store_id)
        token = issue_hs256_pos_jwt(auth_info["user_id"], auth_info["store_id"], jwt_secret)
        logger.info("Successfully issued POS JWT for user %s at store %s", auth_info["user_id"], auth_info["store_id"])
        return {
            "success": True,
            "status": 200,
            "pos_jwt": token,
            "store_id": auth_info["store_id"],
            "role": auth_info["role"]
        }
    except PosJwtAuthError as e:
        _rate_limiter.record_attempt(client_ip, phone)
        logger.warning("PosJwtAuthError: code=%s, status=%d", e.error_code, e.status_code)
        return {
            "success": False,
            "status": e.status_code,
            "error": e.error_code,
            "message": e.message
        }
    except Exception as e:
        _rate_limiter.record_attempt(client_ip, phone)
        logger.error("Unhandled auth error: %s", type(e).__name__)
        return {
            "success": False,
            "status": 500,
            "error": "SERVER_ERROR",
            "message": "Lỗi xác thực hệ thống"
        }
