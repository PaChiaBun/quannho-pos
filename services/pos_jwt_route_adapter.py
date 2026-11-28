# services/pos_jwt_route_adapter.py
# ─────────────────────────────────────────────────────────────────────────────
# Framework Integration Adapters for /api/auth/pos-jwt
# Provides Flask Blueprint, FastAPI APIRouter, and WSGI/ASGI route handlers.
# ─────────────────────────────────────────────────────────────────────────────
import ipaddress
import os

from services.pos_jwt_auth_service import handle_pos_jwt_auth_request


def _resolve_client_ip(remote_addr, forwarded_for):
    """Trust X-Forwarded-For only from explicitly configured proxy peers."""
    peer = str(remote_addr or "127.0.0.1").strip()
    trusted_raw = os.environ.get("POS_TRUSTED_PROXY_IPS", "")
    trusted = {value.strip() for value in trusted_raw.split(",") if value.strip()}
    if peer not in trusted or not forwarded_for:
        return peer

    candidate = str(forwarded_for).split(",", 1)[0].strip()
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return peer

def create_flask_blueprint():
    """Create Flask Blueprint for /api/auth/pos-jwt."""
    try:
        from flask import Blueprint, request, jsonify
        bp = Blueprint("pos_jwt_auth", __name__)

        @bp.route("/api/auth/pos-jwt", methods=["POST"])
        def pos_jwt_endpoint():
            raw_body = request.get_data()
            client_ip = _resolve_client_ip(
                request.remote_addr,
                request.headers.get("X-Forwarded-For"),
            )
            res = handle_pos_jwt_auth_request(raw_body, client_ip=client_ip)
            return jsonify(res), res.get("status", 200)

        return bp
    except ImportError:
        return None

def create_fastapi_router():
    """Create FastAPI APIRouter for /api/auth/pos-jwt."""
    try:
        from fastapi import APIRouter, Request, Response, status
        import json

        router = APIRouter()

        @router.post("/api/auth/pos-jwt")
        async def pos_jwt_endpoint(request: Request):
            raw_body = await request.body()
            remote_addr = request.client.host if request.client else "127.0.0.1"
            client_ip = _resolve_client_ip(
                remote_addr,
                request.headers.get("x-forwarded-for"),
            )
            res = handle_pos_jwt_auth_request(raw_body, client_ip=client_ip)
            return Response(
                content=json.dumps(res),
                status_code=res.get("status", 200),
                media_type="application/json"
            )

        return router
    except ImportError:
        return None
