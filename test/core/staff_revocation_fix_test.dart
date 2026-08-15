import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeUserAuthRepository implements UserAuthRepository {
  List<Map<String, dynamic>> storeMembers = [];
  List<Map<String, dynamic>> staffMembers = [];
  List<Map<String, dynamic>> stores = [];
  bool queryStoreMembersThrows = false;
  bool queryStoreMemberHangs = false;
  final List<Object?> queryStoreMemberSequence = [];
  int queryStoreMemberCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> queryStoreMembers(String userId) async {
    if (queryStoreMembersThrows) throw Exception('DB store_members error');
    return storeMembers.where((m) => m['user_id'] == userId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> queryStaffMembers(String userId) async {
    return staffMembers
        .where((s) => s['id'] == userId || s['user_id'] == userId)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> queryStoreById(String storeId) async {
    return stores.firstWhere(
      (s) => s['id'] == storeId,
      orElse: () => {
        'id': storeId,
        'name': 'Test Store',
        'store_code': 'QN-TEST',
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> queryStoresByOwner(String userId) async {
    return stores.where((s) => s['owner_user_id'] == userId).toList();
  }

  @override
  Future<Map<String, dynamic>?> queryStoreByCode(String storeCode) async {
    return stores.firstWhere(
      (s) => s['store_code'] == storeCode,
      orElse: () => {'id': 's1', 'name': 'Test Store', 'store_code': storeCode},
    );
  }

  @override
  Future<Map<String, dynamic>?> queryStoreMember(
    String storeId,
    String userId,
  ) async {
    queryStoreMemberCalls++;
    if (queryStoreMemberHangs) {
      return Completer<Map<String, dynamic>?>().future;
    }
    if (queryStoreMemberSequence.isNotEmpty) {
      final next = queryStoreMemberSequence.removeAt(0);
      if (next is Exception) throw next;
      return next as Map<String, dynamic>?;
    }
    if (queryStoreMembersThrows) throw Exception('DB queryStoreMember error');
    final list = storeMembers
        .where((m) => m['store_id'] == storeId && m['user_id'] == userId)
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<Map<String, dynamic>?> queryStaffMember(
    String storeId,
    String userId,
  ) async {
    final list = staffMembers
        .where(
          (s) =>
              s['store_id'] == storeId &&
              (s['id'] == userId || s['user_id'] == userId),
        )
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<Map<String, dynamic>?> queryStaffMemberSimple(String userId) async {
    final list = staffMembers
        .where((s) => s['id'] == userId || s['user_id'] == userId)
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<Map<String, dynamic>?> queryUserAccount(String userId) async {
    return {'id': userId, 'display_name': 'Test User', 'phone': '+84900000000'};
  }

  @override
  Future<Map<String, dynamic>> insertStore(
    Map<String, dynamic> storePayload,
  ) async {
    final id = storePayload['id'] ?? 's_new';
    final data = {...storePayload, 'id': id};
    stores.add(data);
    return data;
  }

  @override
  Future<void> upsertStoreMember(Map<String, dynamic> memberPayload) async {
    storeMembers.removeWhere(
      (m) =>
          m['store_id'] == memberPayload['store_id'] &&
          m['user_id'] == memberPayload['user_id'],
    );
    storeMembers.add(memberPayload);
  }

  @override
  Future<void> upsertStaffMember(Map<String, dynamic> payload) async {
    staffMembers.removeWhere(
      (s) => s['store_id'] == payload['store_id'] && s['id'] == payload['id'],
    );
    staffMembers.add(payload);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Staff Revocation & Single Source of Truth Production Path Tests', () {
    late FakeUserAuthRepository fakeRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeRepo = FakeUserAuthRepository();
      UserAuthService.authRepository = fakeRepo;
      StaffService.rpcTransportOverride = null;
      StaffService.broadcastHandlerOverride = null;
    });

    test(
      '1. getUserStores: orphan staff_members without store_members returns []',
      () async {
        fakeRepo.staffMembers.add({
          'id': 'u1',
          'store_id': 's1',
          'role': 'cashier',
          'is_active': true,
        });

        final result = await UserAuthService.getUserStores('u1');
        expect(result, isEmpty);
      },
    );

    test('2. getUserStores: valid store_members row returns store', () async {
      fakeRepo.storeMembers.add({
        'user_id': 'u1',
        'store_id': 's1',
        'role': 'waiter',
        'is_owner': false,
        'stores': {'id': 's1', 'name': 'KAY-Rạch Giá', 'store_code': 'QN-4EJP'},
      });

      final result = await UserAuthService.getUserStores('u1');
      expect(result.length, 1);
      expect(result.first.storeId, 's1');
      expect(result.first.storeName, 'KAY-Rạch Giá');
    });

    test(
      '3. clearStoreContext await purges all 9 store keys from SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_store_id', 's1');
        await prefs.setString('auth_store_name', 'KAY');
        await prefs.setString('auth_store_code', 'QN-4EJP');
        await prefs.setString('auth_role', 'waiter');
        await prefs.setBool('auth_is_owner', false);
        await prefs.setString('store_id', 's1');
        await prefs.setString('store_name', 'KAY');
        await prefs.setString('store_code', 'QN-4EJP');
        await prefs.setString('device_role', 'waiter');

        await UserAuthService.clearStoreContext();

        expect(prefs.getString('auth_store_id'), null);
        expect(prefs.getString('auth_store_name'), null);
        expect(prefs.getString('auth_store_code'), null);
        expect(prefs.getString('auth_role'), null);
        expect(prefs.getBool('auth_is_owner'), null);
        expect(prefs.getString('store_id'), null);
        expect(prefs.getString('store_name'), null);
        expect(prefs.getString('store_code'), null);
        expect(prefs.getString('device_role'), null);
      },
    );

    test(
      '4. validateActiveMembership returns isActive=false when store_members missing',
      () async {
        final res = await UserAuthService.validateActiveMembership(
          userId: 'u_revoked',
          storeId: 's1',
          emptyConfirmationDelay: Duration.zero,
        );

        expect(res.isActive, false);
        expect(res.isOffline, false);
        expect(fakeRepo.queryStoreMemberCalls, 2);
      },
    );

    test(
      '5. validateActiveMembership returns isActive=true when store_members present',
      () async {
        fakeRepo.storeMembers.add({
          'user_id': 'u_active',
          'store_id': 's1',
          'role': 'waiter',
          'is_owner': false,
        });

        final res = await UserAuthService.validateActiveMembership(
          userId: 'u_active',
          storeId: 's1',
        );

        expect(res.isActive, true);
        expect(res.isOffline, false);
      },
    );

    test(
      '6. validateActiveMembership returns isOffline=true on network exception',
      () async {
        fakeRepo.queryStoreMembersThrows = true;

        final res = await UserAuthService.validateActiveMembership(
          userId: 'u_any',
          storeId: 's1',
        );

        expect(res.isActive, true);
        expect(res.isOffline, true);
      },
    );

    test(
      '6A. transient empty membership is confirmed again before session revocation',
      () async {
        fakeRepo.queryStoreMemberSequence.addAll([
          null,
          {
            'user_id': 'u_active',
            'store_id': 's1',
            'role': 'cashier',
            'is_owner': false,
          },
        ]);

        final res = await UserAuthService.validateActiveMembership(
          userId: 'u_active',
          storeId: 's1',
          emptyConfirmationDelay: Duration.zero,
        );

        expect(res.isActive, true);
        expect(res.isOffline, false);
        expect(fakeRepo.queryStoreMemberCalls, 2);
      },
    );

    test(
      '6B. startup restores a missing local store context from one server membership',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'u_active',
          'auth_user_phone': '+84900000000',
          'auth_user_name': 'Thu ngân',
        });
        fakeRepo.storeMembers.add({
          'user_id': 'u_active',
          'store_id': 's1',
          'role': 'cashier',
          'is_owner': false,
          'stores': {
            'id': 's1',
            'name': 'KAY-Rạch Giá',
            'store_code': 'QN-4EJP',
          },
        });

        final restored = await UserAuthService.restoreSessionOnStartup(
          jwtService: _DisabledPosJwtService(),
        );
        final prefs = await SharedPreferences.getInstance();

        expect(restored, true);
        expect(prefs.getString('auth_store_id'), 's1');
        expect(prefs.getString('store_id'), 's1');
        expect(prefs.getString('auth_role'), 'cashier');
      },
    );

    test(
      '6C. membership timeout preserves the local session and exits promptly',
      () async {
        fakeRepo.queryStoreMemberHangs = true;

        final res = await UserAuthService.validateActiveMembership(
          userId: 'u_active',
          storeId: 's1',
          serverQueryTimeout: const Duration(milliseconds: 10),
        );

        expect(res.isActive, true);
        expect(res.isOffline, true);
      },
    );

    test(
      '7A. StaffService.removeStaff: Consecutive removals of 2 targets send distinct target IDs',
      () async {
        final recordedRpcCalls = <Map<String, dynamic>>[];
        final recordedBroadcasts = <Map<String, dynamic>>[];

        StaffService.rpcTransportOverride = (rpcName, params) async {
          recordedRpcCalls.add({'rpcName': rpcName, ...params});
          return {'success': true, 'code': 'revoked', 'deleted_memberships': 1};
        };

        StaffService.broadcastHandlerOverride =
            ({required storeId, required targetUserId}) async {
              recordedBroadcasts.add({
                'storeId': storeId,
                'targetUserId': targetUserId,
              });
            };

        // Call 1 for target A
        await StaffService.removeStaff(
          storeId: 's1',
          userId: 'user_target_A',
          removedByUserId: 'owner1',
          staffName: 'Staff A',
        );

        // Call 2 for target B
        await StaffService.removeStaff(
          storeId: 's1',
          userId: 'user_target_B',
          removedByUserId: 'owner1',
          staffName: 'Staff B',
        );

        expect(recordedRpcCalls.length, 2);
        expect(recordedRpcCalls[0]['p_target_user_id'], 'user_target_A');
        expect(recordedRpcCalls[0]['p_store_id'], 's1');
        expect(recordedRpcCalls[0]['p_actor_id'], 'owner1');

        expect(recordedRpcCalls[1]['p_target_user_id'], 'user_target_B');
        expect(recordedRpcCalls[1]['p_store_id'], 's1');
        expect(recordedRpcCalls[1]['p_actor_id'], 'owner1');

        expect(recordedBroadcasts.length, 2);
        expect(recordedBroadcasts[0]['targetUserId'], 'user_target_A');
        expect(recordedBroadcasts[1]['targetUserId'], 'user_target_B');
      },
    );

    test(
      '7B. StaffService.removeStaff: RPC success triggers exactly 1 broadcast',
      () async {
        final recordedBroadcasts = <Map<String, dynamic>>[];

        StaffService.rpcTransportOverride = (rpcName, params) async {
          return {'success': true, 'code': 'reconciled'};
        };

        StaffService.broadcastHandlerOverride =
            ({required storeId, required targetUserId}) async {
              recordedBroadcasts.add({
                'storeId': storeId,
                'targetUserId': targetUserId,
              });
            };

        await StaffService.removeStaff(
          storeId: 's1',
          userId: 'user_target_X',
          removedByUserId: 'owner1',
        );

        expect(recordedBroadcasts.length, 1);
        expect(recordedBroadcasts.first['targetUserId'], 'user_target_X');
      },
    );

    test(
      '7C. StaffService.removeStaff: RPC failure throws exception and does NOT broadcast',
      () async {
        final recordedBroadcasts = <Map<String, dynamic>>[];

        StaffService.rpcTransportOverride = (rpcName, params) async {
          return {
            'success': false,
            'code': 'forbidden',
            'message': 'Chỉ Chủ quán mới có quyền xoá',
          };
        };

        StaffService.broadcastHandlerOverride =
            ({required storeId, required targetUserId}) async {
              recordedBroadcasts.add({
                'storeId': storeId,
                'targetUserId': targetUserId,
              });
            };

        expect(
          () => StaffService.removeStaff(
            storeId: 's1',
            userId: 'user_target_X',
            removedByUserId: 'waiter1',
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains('Chỉ Chủ quán mới có quyền xoá'),
            ),
          ),
        );

        expect(recordedBroadcasts, isEmpty);
      },
    );

    test(
      '7D. StaffService.removeStaff: Missing RPC function throws PGRST202 exception and does NOT fallback or broadcast',
      () async {
        final recordedBroadcasts = <Map<String, dynamic>>[];

        StaffService.rpcTransportOverride = (rpcName, params) async {
          throw Exception(
            'PGRST202: Could not find the function public.revoke_store_member in the schema cache',
          );
        };

        StaffService.broadcastHandlerOverride =
            ({required storeId, required targetUserId}) async {
              recordedBroadcasts.add({
                'storeId': storeId,
                'targetUserId': targetUserId,
              });
            };

        expect(
          () => StaffService.removeStaff(
            storeId: 's1',
            userId: 'user_target_X',
            removedByUserId: 'owner1',
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains(
                'Server chưa cài migration thu hồi nhân viên',
              ),
            ),
          ),
        );

        expect(recordedBroadcasts, isEmpty);
      },
    );
  });
}

class _DisabledPosJwtService extends PosJwtAuthService {
  @override
  bool get isConfigured => false;

  @override
  Future<void> clearPosJwt() async {}
}
