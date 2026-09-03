// test/core/staff_membership_admin_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Contract tests for proposal-only staff administration wiring.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/core/services/store_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Staff Membership Administration proposal wiring', () {
    test(
      '1. removeStaff calls admin_revoke_staff_membership_v4 RPC and handles broadcast',
      () async {
        String? invokedRpc;
        Map<String, dynamic>? rpcParams;
        String? broadcastTarget;

        StaffService.rpcTransportOverride = (rpcName, params) async {
          invokedRpc = rpcName;
          rpcParams = params;
          return {
            'success': true,
            'status': 200,
            'message': 'Thu hồi thành công',
          };
        };

        StaffService.broadcastHandlerOverride =
            ({required storeId, required targetUserId}) async {
              broadcastTarget = targetUserId;
            };

        await StaffService.removeStaff(
          storeId: '00000000-0000-0000-0000-000000000001',
          userId: '00000000-0000-0000-0000-000000000002',
          removedByUserId: '00000000-0000-0000-0000-000000000003',
        );

        expect(invokedRpc, equals('admin_revoke_staff_membership_v4'));
        expect(
          rpcParams?['p_store_id'],
          equals('00000000-0000-0000-0000-000000000001'),
        );
        expect(
          rpcParams?['p_staff_id'],
          equals('00000000-0000-0000-0000-000000000002'),
        );
        expect(rpcParams, hasLength(2));
        expect(broadcastTarget, equals('00000000-0000-0000-0000-000000000002'));

        // Clean up overrides
        StaffService.rpcTransportOverride = null;
        StaffService.broadcastHandlerOverride = null;
      },
    );

    test(
      '2. legacy StoreAuthService.joinStore rejects self-assigned role',
      () async {
        final res = await StoreAuthService.joinStore(
          storeCode: 'QN-TEST',
          deviceName: 'Máy test',
          deviceRole: 'manager',
        );

        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, contains('đã được khóa'));
      },
    );
  });
}
