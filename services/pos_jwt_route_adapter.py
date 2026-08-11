# services/pos_jwt_route_adapter.py
# ─────────────────────────────────────────────────────────────────────────────
# Framework Integration Adapters for /api/auth/pos-jwt
# Provides Flask Blueprint, FastAPI APIRouter, and WSGI/ASGI route handlers.
# ─────────────────────────────────────────────────────────────────────────────
from services.pos_jwt_auth_service import handle_pos_jwt_auth_request

def create_flask_blueprint():
    """Create Flask Blueprint for /api/auth/pos-jwt."""
    try:
        from flask import Blueprint, request, jsonify
        bp = Blueprint("pos_jwt_auth", __name__)

        @bp.route("/api/auth/pos-jwt", methods=["POST"])
        def pos_jwt_endpoint():
            raw_body = request.get_data()
            client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "127.0.0.1").split(",")[0].strip()
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
            client_ip = request.headers.get("x-forwarded-for", request.client.host if request.client else "127.0.0.1").split(",")[0].strip()
            res = handle_pos_jwt_auth_request(raw_body, client_ip=client_ip)
            return Response(
                content=json.dumps(res),
                status_code=res.get("status", 200),
                media_type="application/json"
            )

        return router
    except ImportError:
        return None
