import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const rlsTestBaseUrl = String.fromEnvironment('RLS_TEST_BASE_URL');
  const rlsTestAnonKey = String.fromEnvironment('RLS_TEST_ANON_KEY');
  const enableRlsIntegrationTest = bool.fromEnvironment(
    'ENABLE_RLS_INTEGRATION_TEST',
  );

  const revokedUserId = '9df9e114-9b6c-4044-a47e-f7b7e1ed015e';
  const ownerUserId = '83e5f7c3-3eb4-43b9-9a61-b1a58c075f5e';
  const activeStaffUserId = 'b09a37ca-9925-498a-9cf2-15c9b5b7a2ec';
  const kayStoreId = '79fd45e9-14c3-4dd2-81ba-aa288a45b472';
  const randomStoreId = '3b164035-0a7b-4086-843e-87ab44885076';

  Map<String, String> getHeaders({
    required String userId,
    required String storeId,
  }) {
    return {
      'apikey': rlsTestAnonKey,
      'Authorization': 'Bearer $rlsTestAnonKey',
      'x-user-id': userId,
      'x-store-id': storeId,
      'Content-Type': 'application/json',
    };
  }

  group(
    'P0 RLS Stale Header & 4 Sensitive Tables Isolation Tests',
    () {
      setUp(() {
        if (rlsTestBaseUrl.isEmpty || rlsTestAnonKey.isEmpty) {
          fail(
            'Missing required configuration: RLS_TEST_BASE_URL and RLS_TEST_ANON_KEY must be provided via --dart-define when ENABLE_RLS_INTEGRATION_TEST=true.',
          );
        }
      });

      test('A. Revoked employee stale headers MUST NOT access orders', () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
          ),
          headers: getHeaders(userId: revokedUserId, storeId: kayStoreId),
        );

        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          expect(
            list.isEmpty,
            isTrue,
            reason:
                'Revoked staff received order rows via stale headers when RLS migration is active.',
          );
        } else {
          expect(res.statusCode, anyOf(401, 403));
        }
      });

      test(
        'A. Revoked employee stale headers MUST NOT access order_items',
        () async {
          final res = await http.get(
            Uri.parse(
              '$rlsTestBaseUrl/rest/v1/order_items?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
            ),
            headers: getHeaders(userId: revokedUserId, storeId: kayStoreId),
          );

          if (res.statusCode == 200) {
            final List list = jsonDecode(res.body);
            expect(
              list.isEmpty,
              isTrue,
              reason:
                  'Revoked staff received order_item rows via stale headers when RLS migration is active.',
            );
          } else {
            expect(res.statusCode, anyOf(401, 403));
          }
        },
      );

      test(
        'A. Revoked employee stale headers MUST NOT access staff_members',
        () async {
          final res = await http.get(
            Uri.parse(
              '$rlsTestBaseUrl/rest/v1/staff_members?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
            ),
            headers: getHeaders(userId: revokedUserId, storeId: kayStoreId),
          );

          if (res.statusCode == 200) {
            final List list = jsonDecode(res.body);
            expect(
              list.isEmpty,
              isTrue,
              reason:
                  'Revoked staff received staff_members rows via stale headers when RLS migration is active.',
            );
          } else {
            expect(res.statusCode, anyOf(401, 403));
          }
        },
      );

      test(
        'A. Revoked employee stale headers MUST NOT access app_settings',
        () async {
          final res = await http.get(
            Uri.parse(
              '$rlsTestBaseUrl/rest/v1/app_settings?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
            ),
            headers: getHeaders(userId: revokedUserId, storeId: kayStoreId),
          );

          if (res.statusCode == 200) {
            final List list = jsonDecode(res.body);
            expect(
              list.isEmpty,
              isTrue,
              reason:
                  'Revoked staff received app_settings rows via stale headers when RLS migration is active.',
            );
          } else {
            expect(res.statusCode, anyOf(401, 403));
          }
        },
      );

      test('B. Store Owner KAY CAN access KAY orders', () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
          ),
          headers: getHeaders(userId: ownerUserId, storeId: kayStoreId),
        );

        expect(res.statusCode, 200);
        final List list = jsonDecode(res.body);
        expect(
          list,
          isNotEmpty,
          reason:
              'Owner KAY must still receive at least one KAY order after RLS migration.',
        );
        expect(list.first['store_id'], kayStoreId);
      });

      test('C. Active employee CAN access KAY data', () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/staff_members?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
          ),
          headers: getHeaders(userId: activeStaffUserId, storeId: kayStoreId),
        );

        expect(res.statusCode, 200);
        final List list = jsonDecode(res.body);
        expect(
          list,
          isNotEmpty,
          reason:
              'Active KAY employee must still receive KAY data after RLS migration.',
        );
        expect(list.first['store_id'], kayStoreId);
      });

      test(
        'D. Cross-store attempt: Owner requesting Store B receives empty',
        () async {
          final res = await http.get(
            Uri.parse(
              '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&store_id=eq.$randomStoreId&limit=1',
            ),
            headers: getHeaders(userId: ownerUserId, storeId: randomStoreId),
          );

          if (res.statusCode == 200) {
            final List list = jsonDecode(res.body);
            expect(list.isEmpty, isTrue);
          } else {
            expect(res.statusCode, anyOf(401, 403));
          }
        },
      );

      test('E. Missing x-user-id header returns 0 rows', () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
          ),
          headers: {
            'apikey': rlsTestAnonKey,
            'Authorization': 'Bearer $rlsTestAnonKey',
            'x-store-id': kayStoreId,
          },
        );

        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          expect(list.isEmpty, isTrue);
        } else {
          expect(res.statusCode, anyOf(401, 403));
        }
      });

      test('E. Invalid UUID header returns 0 rows', () async {
        final res = await http.get(
          Uri.parse(
            '$rlsTestBaseUrl/rest/v1/orders?select=id,store_id&store_id=eq.$kayStoreId&limit=1',
          ),
          headers: getHeaders(
            userId: 'invalid-uuid-string',
            storeId: kayStoreId,
          ),
        );

        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          expect(list.isEmpty, isTrue);
        } else {
          expect(res.statusCode, anyOf(401, 403));
        }
      });
    },
    skip: !enableRlsIntegrationTest
        ? 'Set ENABLE_RLS_INTEGRATION_TEST=true and provide staging configuration.'
        : false,
  );
}
