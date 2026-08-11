// test/core/rls_stale_header_security_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// RLS Integration Security Test Suite for Server-Signed POS JWT Guard
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const rlsTestBaseUrl = String.fromEnvironment('RLS_TEST_BASE_URL');
  const rlsTestAnonKey = String.fromEnvironment('RLS_TEST_ANON_KEY');
  const enableRlsIntegrationTest = bool.fromEnvironment(
    'ENABLE_RLS_INTEGRATION_TEST',
  );

  const kayStoreId = '79fd45e9-14c3-4dd2-81ba-aa288a45b472';

  const skipReason = !enableRlsIntegrationTest
      ? 'BLOCKED: quannho-staging.lpm.vn does not resolve. Real Staging DB environment is required to execute live RLS mutation & RPC integration tests.'
      : false;

  group('P0 RLS Supabase Integration Security Test Suite', () {
    setUp(() {
      if (enableRlsIntegrationTest &&
          (rlsTestBaseUrl.isEmpty || rlsTestAnonKey.isEmpty)) {
        fail(
          'Missing required configuration: --dart-define=RLS_TEST_BASE_URL and --dart-define=RLS_TEST_ANON_KEY must be provided via --dart-define when ENABLE_RLS_INTEGRATION_TEST=true.',
        );
      }
    });

    test(
      '1. No Authorization header returns 401 or 0 rows on 4 sensitive tables',
      () async {
        final tables = [
          'orders',
          'order_items',
          'staff_members',
          'app_settings',
        ];
        for (final tbl in tables) {
          final res = await http.get(
            Uri.parse(
              '$rlsTestBaseUrl/rest/v1/$tbl?select=id,store_id&limit=1',
            ),
            headers: {'apikey': rlsTestAnonKey},
          );
          if (res.statusCode == 200) {
            final List list = jsonDecode(res.body);
            expect(list.isEmpty, isTrue);
          } else {
            expect(res.statusCode, anyOf(401, 403));
          }
        }
      },
      skip: skipReason,
    );

    test(
      '2. Anon key + forged x-user-id header is rejected (0 rows)',
      () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&limit=1',
          ),
          headers: {
            'apikey': rlsTestAnonKey,
            'Authorization': 'Bearer $rlsTestAnonKey',
            'x-user-id': '83e5f7c3-3eb4-43b9-9a61-b1a58c075f5e',
            'x-store-id': kayStoreId,
          },
        );
        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          expect(list.isEmpty, isTrue);
        } else {
          expect(res.statusCode, anyOf(401, 403));
        }
      },
      skip: skipReason,
    );

    test('3. Malformed / invalid UUID headers are rejected', () async {
      final res = await http.get(
        Uri.parse('$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&limit=1'),
        headers: {
          'apikey': rlsTestAnonKey,
          'Authorization': 'Bearer $rlsTestAnonKey',
          'x-user-id': 'not-a-valid-uuid',
          'x-store-id': 'invalid-store-uuid',
        },
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        expect(list.isEmpty, isTrue);
      } else {
        expect(res.statusCode, anyOf(401, 403));
      }
    }, skip: skipReason);

    test('4. Forged JWT or bad signature JWT is rejected', () async {
      final badJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI4M2U1ZjdjMy0zZWI0LTQzYjktOWE2MS1iMWE1OGMwNzVmNWUiLCJyb2xlIjoiYXV0aGVudGljYXRlZCIsInN0b3JlX2lkIjoiNzlmZDQ1ZTktMTRjMy00ZGQyLTgxYmEtYWEyODhhNDViNDcyIn0.invalid_signature_xxx';
      final res = await http.get(
        Uri.parse('$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&limit=1'),
        headers: {'apikey': rlsTestAnonKey, 'Authorization': 'Bearer $badJwt'},
      );
      expect(res.statusCode, anyOf(401, 403));
    }, skip: skipReason);
  });
}
