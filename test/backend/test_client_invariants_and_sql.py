# test/backend/test_client_invariants_and_sql.py
# ─────────────────────────────────────────────────────────────────────────────
# Invariant & SQL Simulation Test Suite for Flutter & Postgres Auth Logic
# ─────────────────────────────────────────────────────────────────────────────
import base64
import json
import os
import re
import time
import unittest


def mock_dart_is_token_valid(token, expected_store_id=None, now_sec=None):
    """Accurate Python simulation of PosJwtAuthService.isTokenValid in Dart."""
    if not token or not token.strip():
        return False
    try:
        parts = token.strip().split('.')
        if len(parts) != 3:
            return False
        padded = parts[1] + '=' * ((4 - len(parts[1]) % 4) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))
        exp = payload.get('exp')
        if not isinstance(exp, int):
            return False
        now = now_sec if now_sec is not None else int(time.time())
        if exp <= (now + 30):
            return False

        sub = str(payload.get('sub') or '').strip()
        jti = str(payload.get('jti') or '').strip()
        token_store_id = str(payload.get('store_id') or '').strip()
        role = str(payload.get('role') or '').strip()
        issuer = str(payload.get('iss') or '').strip()
        audience = payload.get('aud')
        issued_at = payload.get('iat')
        not_before = payload.get('nbf')

        has_auth_aud = audience == 'authenticated' or (isinstance(audience, list) and 'authenticated' in audience)
        if (not sub or not jti or not token_store_id or role != 'authenticated' or
                issuer != 'supabase' or not has_auth_aud or not isinstance(issued_at, int) or
                issued_at > now + 30 or exp <= issued_at or
                (not_before is not None and not_before > now + 30)):
            return False

        if expected_store_id and expected_store_id.strip():
            if token_store_id != expected_store_id.strip():
                return False

        return True
    except Exception:
        return False


def mock_dart_is_onboarding_token_valid(token, now_sec=None):
    """Accurate Python simulation of PosJwtAuthService.isOnboardingTokenValid in Dart."""
    if not token or not token.strip():
        return False
    try:
        parts = token.strip().split('.')
        if len(parts) != 3:
            return False
        padded = parts[1] + '=' * ((4 - len(parts[1]) % 4) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))
        exp = payload.get('exp')
        if not isinstance(exp, int):
            return False
        now = now_sec if now_sec is not None else int(time.time())
        if exp <= (now + 30):
            return False

        sub = str(payload.get('sub') or '').strip()
        jti = str(payload.get('jti') or '').strip()
        token_use = str(payload.get('token_use') or '').strip()
        role = str(payload.get('role') or '').strip()
        issuer = str(payload.get('iss') or '').strip()
        audience = payload.get('aud')
        issued_at = payload.get('iat')
        not_before = payload.get('nbf')

        has_auth_aud = audience == 'authenticated' or (isinstance(audience, list) and 'authenticated' in audience)
        return (bool(sub) and bool(jti) and token_use == 'onboarding' and
                role == 'authenticated' and issuer == 'supabase' and
                has_auth_aud and isinstance(issued_at, int) and
                issued_at <= now + 30 and exp > issued_at and exp - issued_at <= 600 and
                (not_before is None or not_before <= now + 30) and
                payload.get('store_id') is None)
    except Exception:
        return False


class TestClientInvariantsAndSql(unittest.TestCase):
    def test_sql_migration_syntax_and_structure(self):
        sql_path = os.path.abspath(os.path.join(
            os.path.dirname(__file__),
            '../../supabase/migrations/20260913_resilient_join_store_by_code_v4.sql'
        ))
        self.assertTrue(os.path.exists(sql_path))
        with open(sql_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()

        # Check required function declarations
        self.assertIn("FUNCTION public.join_store_by_code_v4", sql_content)
        self.assertIn("FUNCTION public.create_store_with_owner_v4", sql_content)

        # Check SECURITY DEFINER and search_path on both
        self.assertEqual(sql_content.count("SECURITY DEFINER"), 2)
        self.assertEqual(sql_content.count("SET search_path = public, extensions, pg_temp"), 2)

        # Check Multi-tier fallback on both
        fallback_pattern = r"v_user_id := \(nullif\(current_setting\('request\.jwt\.claims', true\), ''\)::jsonb ->> 'sub'\)::uuid;"
        matches = re.findall(fallback_pattern, sql_content)
        self.assertEqual(len(matches), 2)

        # Check 401 UNAUTHORIZED on both
        self.assertEqual(sql_content.count("'error_code', 'UNAUTHORIZED'"), 2)

        # Check grants and revokes
        self.assertIn("REVOKE ALL ON FUNCTION public.join_store_by_code_v4(text) FROM PUBLIC;", sql_content)
        self.assertIn("GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text) TO anon, authenticated;", sql_content)
        self.assertIn("REVOKE ALL ON FUNCTION public.create_store_with_owner_v4(text, text) FROM PUBLIC;", sql_content)
        self.assertIn("GRANT EXECUTE ON FUNCTION public.create_store_with_owner_v4(text, text) TO anon, authenticated;", sql_content)

    def test_dart_is_token_valid_boundary_cases(self):
        now = 1700000000
        # Normal valid token
        token_valid = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "store_id": "store-1",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now, "exp": now + 3600
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertTrue(mock_dart_is_token_valid(token_valid, expected_store_id="store-1", now_sec=now))
        self.assertFalse(mock_dart_is_token_valid(token_valid, expected_store_id="store-2", now_sec=now))

        # Expired token
        token_expired = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "store_id": "store-1",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now - 3600, "exp": now + 15  # <= now + 30
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertFalse(mock_dart_is_token_valid(token_expired, now_sec=now))

        # exp <= iat
        token_exp_le_iat = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "store_id": "store-1",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now + 100, "exp": now + 100
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertFalse(mock_dart_is_token_valid(token_exp_le_iat, now_sec=now))

    def test_dart_is_onboarding_token_valid_boundary_cases(self):
        now = 1700000000
        # Valid onboarding token
        token_onb_valid = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "token_use": "onboarding",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now, "exp": now + 600
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertTrue(mock_dart_is_onboarding_token_valid(token_onb_valid, now_sec=now))

        # Token with store_id must be rejected
        token_onb_with_store = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "token_use": "onboarding", "store_id": "leak",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now, "exp": now + 600
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertFalse(mock_dart_is_onboarding_token_valid(token_onb_with_store, now_sec=now))

        # TTL > 600 must be rejected
        token_onb_long_ttl = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "user-1", "jti": "j1", "token_use": "onboarding",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now, "exp": now + 601
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"
        self.assertFalse(mock_dart_is_onboarding_token_valid(token_onb_long_ttl, now_sec=now))

    def test_join_store_by_code_simulation_edge_cases(self):
        def simulate_join(auth_uid, claims_sub, store_code, stores_table, members_table, staff_table, accounts_table):
            # Step 1: User ID extraction
            user_id = auth_uid
            if not user_id and claims_sub:
                user_id = claims_sub
            if not user_id:
                return {'success': False, 'status': 401, 'error_code': 'UNAUTHORIZED', 'message': 'Chưa xác thực phiên đăng nhập'}

            # Step 2: Code validation
            code = (store_code or '').strip().upper()
            if not code:
                return {'success': False, 'status': 400, 'error_code': 'MISSING_STORE_CODE', 'message': 'Vui lòng nhập mã quán'}

            # Step 3: Store lookup
            store = stores_table.get(code)
            if not store:
                return {'success': False, 'status': 404, 'error_code': 'STORE_NOT_FOUND', 'message': 'Mã quán không tồn tại'}

            # Step 4: Status check
            if store.get('status') in ('suspended', 'deleted'):
                return {'success': False, 'status': 403, 'error_code': 'STORE_INACTIVE', 'message': 'Quán này đã bị khóa hoặc ngừng hoạt động'}

            # Step 5: Existing member check
            existing = members_table.get((user_id, store['id']))
            if existing:
                return {
                    'success': True, 'status': 200,
                    'store_id': store['id'], 'store_code': store['store_code'],
                    'store_name': store['name'], 'role': existing['role'],
                    'is_owner': existing.get('is_owner', False)
                }

            # Step 6: Role resolution
            if store.get('owner_user_id') == user_id:
                assigned_role = 'owner'
            else:
                caller_phone = accounts_table.get(user_id, {}).get('phone')
                staff = None
                for s in staff_table.values():
                    if s.get('store_id') == store['id']:
                        if s.get('id') == user_id or (caller_phone and s.get('phone') == caller_phone):
                            staff = s
                            break
                if staff and staff.get('role'):
                    assigned_role = staff['role']
                else:
                    assigned_role = 'waiter'

            return {
                'success': True, 'status': 200,
                'store_id': store['id'], 'store_code': store['store_code'],
                'store_name': store['name'], 'role': assigned_role,
                'is_owner': (assigned_role == 'owner')
            }

        stores = {
            'QN-1111': {'id': 's1', 'store_code': 'QN-1111', 'name': 'Quán 1', 'status': 'active', 'owner_user_id': 'owner-1'},
            'QN-SUSP': {'id': 's2', 'store_code': 'QN-SUSP', 'name': 'Quán Khóa', 'status': 'suspended', 'owner_user_id': 'owner-2'},
        }
        members = {
            ('user-existing', 's1'): {'role': 'cashier', 'is_owner': False}
        }
        staff = {
            'staff-1': {'id': 'staff-1', 'store_id': 's1', 'phone': '0900000001', 'role': 'bartender'}
        }
        accounts = {
            'user-staff': {'phone': '0900000001'},
            'user-plain': {'phone': '0900000099'},
        }

        # 1. Unauthenticated -> 401
        res = simulate_join(None, None, 'QN-1111', stores, members, staff, accounts)
        self.assertEqual(res['status'], 401)
        self.assertEqual(res['error_code'], 'UNAUTHORIZED')

        # 2. Multi-tier fallback claims_sub -> 200
        res = simulate_join(None, 'owner-1', 'QN-1111', stores, members, staff, accounts)
        self.assertEqual(res['status'], 200)
        self.assertEqual(res['role'], 'owner')
        self.assertTrue(res['is_owner'])

        # 3. Missing code -> 400
        res = simulate_join('user-plain', None, '', stores, members, staff, accounts)
        self.assertEqual(res['status'], 400)
        self.assertEqual(res['error_code'], 'MISSING_STORE_CODE')

        # 4. Unknown store -> 404
        res = simulate_join('user-plain', None, 'QN-9999', stores, members, staff, accounts)
        self.assertEqual(res['status'], 404)
        self.assertEqual(res['error_code'], 'STORE_NOT_FOUND')

        # 5. Suspended store -> 403
        res = simulate_join('user-plain', None, 'QN-SUSP', stores, members, staff, accounts)
        self.assertEqual(res['status'], 403)
        self.assertEqual(res['error_code'], 'STORE_INACTIVE')

        # 6. Existing member keeps role
        res = simulate_join('user-existing', None, 'QN-1111', stores, members, staff, accounts)
        self.assertEqual(res['status'], 200)
        self.assertEqual(res['role'], 'cashier')

        # 7. Staff match by phone gets staff role
        res = simulate_join('user-staff', None, 'QN-1111', stores, members, staff, accounts)
        self.assertEqual(res['status'], 200)
        self.assertEqual(res['role'], 'bartender')

        # 8. Unmatched user defaults to waiter
        res = simulate_join('user-plain', None, 'QN-1111', stores, members, staff, accounts)
        self.assertEqual(res['status'], 200)
        self.assertEqual(res['role'], 'waiter')
        self.assertFalse(res['is_owner'])

    def test_create_store_simulation_edge_cases(self):
        def simulate_create(auth_uid, claims_sub, store_name, p_store_code, existing_codes):
            user_id = auth_uid or claims_sub
            if not user_id:
                return {'success': False, 'status': 401, 'error_code': 'UNAUTHORIZED'}
            name = (store_name or '').strip()
            if not name:
                return {'success': False, 'status': 400, 'error_code': 'INVALID_STORE_NAME'}
            if p_store_code and p_store_code.strip():
                code = p_store_code.strip().upper()
                if code in existing_codes:
                    return {'success': False, 'status': 409, 'error_code': 'STORE_CODE_EXISTS'}
            else:
                code = 'QN-NEW1'
            return {
                'success': True, 'status': 200,
                'store_id': 'store-uuid', 'store_code': code,
                'store_name': name, 'role': 'owner', 'is_owner': True
            }

        # 1. Unauthenticated -> 401
        self.assertEqual(simulate_create(None, None, 'Test', None, set())['status'], 401)
        # 2. Empty name -> 400
        self.assertEqual(simulate_create('u1', None, '  ', None, set())['status'], 400)
        # 3. Duplicate code -> 409
        self.assertEqual(simulate_create('u1', None, 'Test', 'QN-DUP1', {'QN-DUP1'})['status'], 409)
        # 4. Success with auto-code -> 200
        res = simulate_create('u1', None, 'Quán Nhỏ 1', None, set())
        self.assertEqual(res['status'], 200)
        self.assertEqual(res['role'], 'owner')
        self.assertTrue(res['is_owner'])

    def test_stored_onboarding_jwt_purge_invariants(self):
        """Simulates PosJwtAuthService.getStoredOnboardingJwtFor storage handling."""
        storage = {}

        def mock_get_stored_token(user_id, now_sec=None):
            clean_user_id = (user_id or "").strip()
            if not clean_user_id:
                return None
            token = storage.get("pos_supabase_onboarding_jwt")
            if token:
                if not mock_dart_is_onboarding_token_valid(token, now_sec=now_sec):
                    # Purge expired or malformed token
                    storage.pop("pos_supabase_onboarding_jwt", None)
                else:
                    parts = token.split(".")
                    padded = parts[1] + '=' * ((4 - len(parts[1]) % 4) % 4)
                    payload = json.loads(base64.urlsafe_b64decode(padded).decode('utf-8'))
                    if payload.get("sub") == clean_user_id:
                        return token
            return None

        now = 1700000000
        # Valid token for userA
        token_a = "header." + base64.urlsafe_b64encode(json.dumps({
            "sub": "userA", "jti": "j1", "token_use": "onboarding",
            "role": "authenticated", "iss": "supabase", "aud": "authenticated",
            "iat": now, "exp": now + 600
        }).encode('utf-8')).decode('utf-8').rstrip('=') + ".sig"

        storage["pos_supabase_onboarding_jwt"] = token_a

        # Querying for userB should return None, but MUST NOT delete userA's valid token!
        res_b = mock_get_stored_token("userB", now_sec=now)
        self.assertIsNone(res_b)
        self.assertIn("pos_supabase_onboarding_jwt", storage)
        self.assertEqual(storage["pos_supabase_onboarding_jwt"], token_a)

        # Querying for userA returns token_a
        res_a = mock_get_stored_token("userA", now_sec=now)
        self.assertEqual(res_a, token_a)

        # Querying when expired (now + 601) purges the token
        res_expired = mock_get_stored_token("userA", now_sec=now + 601)
        self.assertIsNone(res_expired)
        self.assertNotIn("pos_supabase_onboarding_jwt", storage)

    def test_service_error_invariants(self):
        """Simulates UserAuthService joinStoreByCode and createStore error propagation."""
        def simulate_create_store_logic(clean_name, rpc_override, effective_token):
            if not clean_name:
                return {'success': False, 'error_code': 'INVALID_STORE_NAME'}
            if not effective_token:
                return {'success': False, 'error_code': 'ONBOARDING_TOKEN_REQUIRED'}
            if rpc_override is None:
                return {'success': False, 'error_code': 'NETWORK_ERROR'}
            rpc_res = rpc_override('create_store_with_owner_v4')
            if not isinstance(rpc_res, dict):
                return {'success': False, 'error_code': 'GATEWAY_UNAVAILABLE'}
            if not rpc_res.get('success'):
                return {'success': False, 'error_code': rpc_res.get('error_code', 'CREATE_STORE_FAILED')}
            store_id = str(rpc_res.get('store_id') or '').strip()
            if not store_id:
                return {'success': False, 'error_code': 'INVALID_STORE_ID'}
            return {'success': True, 'store_id': store_id}

        # 1. Empty name
        self.assertEqual(simulate_create_store_logic('', None, 'token')['error_code'], 'INVALID_STORE_NAME')
        # 2. Missing token
        self.assertEqual(simulate_create_store_logic('Name', None, None)['error_code'], 'ONBOARDING_TOKEN_REQUIRED')
        # 3. Missing connection
        self.assertEqual(simulate_create_store_logic('Name', None, 'token')['error_code'], 'NETWORK_ERROR')
        # 4. Corrupted response
        self.assertEqual(simulate_create_store_logic('Name', lambda _: 'str', 'token')['error_code'], 'GATEWAY_UNAVAILABLE')
        # 5. Missing store_id
        self.assertEqual(simulate_create_store_logic('Name', lambda _: {'success': True}, 'token')['error_code'], 'INVALID_STORE_ID')
        # 6. Success
        res = simulate_create_store_logic('Name', lambda _: {'success': True, 'store_id': 's1'}, 'token')
        self.assertTrue(res['success'])
        self.assertEqual(res['store_id'], 's1')


if __name__ == "__main__":
    unittest.main()
