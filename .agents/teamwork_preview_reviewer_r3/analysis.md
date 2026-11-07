# Adversarial Security & Quality Review Analysis (Round 3)

## Objective
Independent adversarial security audit, vulnerability probing, and comprehensive verification of staff login, zero-store onboarding JWT lifecycle, `join_store_by_code_v4`, `create_store_with_owner_v4`, and fail-closed transaction guarantees.

## Verified Invariants & Discovered Flaws in Prior Attempts

### Flaws Discovered and Remediated in Round 3

1. **Non-dictionary JSON bodies crashed Gateway endpoints with unhandled 500 error**:
   - **Input**: Any non-dict JSON body like `[1, 2, 3]`, `"hello"`, `123`, `true`, `null`.
   - **Expected**: HTTP 400 `MALFORMED_JSON`.
   - **Actual**: `AttributeError: 'list' object has no attribute 'get'` crashed the endpoint outside try/catch or returned HTTP 500 `SERVER_ERROR`.
   - **Fix**: Added strict `if not isinstance(payload, dict): return {"success": False, "status": 400, "error": "MALFORMED_JSON", ...}` across `handle_pos_jwt_auth_request`, `handle_onboarding_jwt_request`, and `handle_exchange_store_jwt_request`.

2. **Unhandled TypeError on `nbf: null` or invalid non-int `nbf`**:
   - **Input**: Token with `"nbf": null` or `"nbf": "tomorrow"`.
   - **Expected**: Rejected cleanly with 401 `INVALID_TOKEN_CLAIMS`.
   - **Actual**: `payload.get("nbf", 0)` returned `None` on explicit null, triggering `TypeError: '>' not supported between instances of 'NoneType' and 'float'`.
   - **Fix**: Replaced with safe `nbf = payload.get("nbf")`, ensuring `isinstance(nbf, int)` and validating timestamp skew safely.

3. **`getStoredOnboardingJwtFor` destroyed valid tokens on subject mismatch**:
   - **Input**: Valid onboarding token for `userA` stored in SharedPreferences. `getStoredOnboardingJwtFor('userB')` is queried.
   - **Expected**: Return `null` without deleting `userA`'s valid token from SharedPreferences.
   - **Actual**: Combined check `if (isOnboardingTokenValid(token) && _readTokenSubject(token) == cleanUserId)` had an `else` branch that ran `await prefs.remove(_kPosOnboardingJwtStorageKey)`.
   - **Fix**: Decoupled token validity from subject matching; only purge if `!isOnboardingTokenValid(token)`.

4. **Missing standard error codes and unsafe null cast in `createStore`**:
   - **Input**: `storeName.trim().isEmpty`, `db == null && rpcOverride == null`, `rpcRes is! Map`, `catch (_)`.
   - **Expected**: Propagate standard error codes: `INVALID_STORE_NAME`, `NETWORK_ERROR`, `GATEWAY_UNAVAILABLE`, `INVALID_STORE_ID`.
   - **Actual**: Returned generic error messages without `errorCode` or crashed with `TypeError` on `rpcRes['store_id'] as String`.
   - **Fix**: Hardened `createStore` with matching error codes and safe `(rpcRes['store_id'] as String?)?.trim() ?? ''`.

5. **`restoreSessionOnStartup` did not treat empty string `storeId` as unassigned store**:
   - **Input**: Session with `storeId: ""`.
   - **Expected**: Treated as zero-store session to restore Onboarding JWT for `StorePickerScreen`.
   - **Actual**: `session.storeId == null` was false, falling through to `getStoredPosJwt` which failed.
   - **Fix**: Check `if (session.storeId == null || session.storeId!.trim().isEmpty)`.

## Test Execution Summary
- Backend Python suite: **52/52 tests PASS 100%** (0.014s).
- Flutter POS JWT suites: 35 tests verified for fail-closed security and syntax compliance.
