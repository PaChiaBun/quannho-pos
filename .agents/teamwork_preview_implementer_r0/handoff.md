# Handoff — teamwork_preview_implementer_r0

## To Reviewer / Next Agent
- **Round**: 0 (Implementation & Verification)
- **Status**: Ready for adversarial review
- **Artifacts**:
  - `analysis.md`: Detailed adversarial security analysis of changes
  - `progress.md`: Task progress and verification status
  - `nhat_ky.md`: Updated with comprehensive QC acceptance protocol, edge case risk ledger, and deployment runbook

## Key Invariants Verified
1. **Anon Key Restored**: `applyAuthToSupabase(null)` correctly restores `SupabaseService.supabaseAnonKey` to both REST and Realtime clients instead of setting to null.
2. **Onboarding Token Pre-Flight Application**: Supabase client is configured with `effectiveOnboardingJwt` before triggering `join_store_by_code_v4` or `create_store_with_owner_v4`.
3. **Fail-Closed Principle**: All storage, network, and token validation failures clean up auth state and reject requests.
4. **RPC Multi-tier Extraction**: `join_store_by_code_v4` extracts user ID from `auth.uid()` or fallback `request.jwt.claims ->> 'sub'`, maintaining store data isolation and role assignment.
5. **Session Continuity**: 30-day POS JWT lifecycle is preserved for existing store staff and owners.
