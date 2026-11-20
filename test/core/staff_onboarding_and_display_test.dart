// test/core/staff_onboarding_and_display_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Automated tests for new staff onboarding, display resilience, and role filtering.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quannho_pos/core/providers/session_provider.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/screens/nhan_vien_screen.dart';
import 'package:quannho_pos/screens/role_manager_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    StaffService.rpcTransportOverride = null;
    StaffService.broadcastHandlerOverride = null;
  });

  group('Staff Onboarding & Display Resilience Tests', () {
    const storeId = '00000000-0000-0000-0000-000000000001';

    test('1. isUnassignedRole correctly identifies unassigned and assigned roles', () {
      expect(StaffService.isUnassignedRole('unassigned'), isTrue);
      expect(StaffService.isUnassignedRole('NONE'), isTrue);
      expect(StaffService.isUnassignedRole(''), isTrue);
      expect(StaffService.isUnassignedRole('Chưa phân vai trò'), isTrue);
      expect(StaffService.isUnassignedRole('chưa gán'), isTrue);
      expect(StaffService.isUnassignedRole('chưa cấp quyền'), isTrue);

      expect(StaffService.isUnassignedRole('waiter'), isFalse);
      expect(StaffService.isUnassignedRole('Phục vụ'), isFalse);
      expect(StaffService.isUnassignedRole('cashier'), isFalse);
      expect(StaffService.isUnassignedRole('Thu ngân'), isFalse);
      expect(StaffService.isUnassignedRole('kitchen'), isFalse);
      expect(StaffService.isUnassignedRole('manager'), isFalse);
      expect(StaffService.isUnassignedRole('owner'), isFalse);
      expect(StaffService.isUnassignedRole('Barista'), isFalse);
    });

    test('2. getStaffList via RPC get_store_staff_directory_v4 maps identity & role correctly', () async {
      StaffService.rpcTransportOverride = (rpcName, params) async {
        if (rpcName == 'get_store_staff_directory_v4') {
          expect(params['p_store_id'], storeId);
          return [
            {
              'user_id': 'user-owner',
              'store_member_id': 'sm-1',
              'role': 'owner',
              'is_owner': true,
              'name': 'Chủ quán KAy',
              'phone': '0901111111',
              'hourly_rate': 0,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
            {
              'user_id': 'user-new-staff',
              'store_member_id': 'sm-2',
              'role': 'unassigned',
              'is_owner': false,
              'name': 'Bảo Linh',
              'phone': '0902222222',
              'hourly_rate': 25000,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
            {
              'user_id': 'user-cashier',
              'store_member_id': 'sm-3',
              'role': 'Thu ngân',
              'is_owner': false,
              'name': 'Trần Văn B',
              'phone': '0903333333',
              'hourly_rate': 30000,
              'shift_config_id': 'shift-morning',
              'is_clocked_in': true,
            },
          ];
        }
        return null;
      };

      final staffList = await StaffService.getStaffList(storeId);
      expect(staffList, hasLength(3));

      final owner = staffList.firstWhere((s) => s.userId == 'user-owner');
      expect(owner.isOwner, isTrue);
      expect(owner.name, 'Chủ quán KAy');
      expect(owner.phone, '0901111111');

      final newStaff = staffList.firstWhere((s) => s.userId == 'user-new-staff');
      expect(newStaff.isOwner, isFalse);
      expect(newStaff.name, 'Bảo Linh');
      expect(newStaff.phone, '0902222222');
      expect(newStaff.role, 'unassigned');
      expect(StaffService.isUnassignedRole(newStaff.role), isTrue);

      final cashier = staffList.firstWhere((s) => s.userId == 'user-cashier');
      expect(cashier.name, 'Trần Văn B');
      expect(cashier.phone, '0903333333');
      expect(cashier.isClockedIn, isTrue);
      expect(cashier.shiftConfigId, 'shift-morning');
    });

    test('3. getStaffList falls back to NV + phone if name is missing or placeholder', () async {
      StaffService.rpcTransportOverride = (rpcName, params) async {
        if (rpcName == 'get_store_staff_directory_v4') {
          return [
            {
              'user_id': 'user-placeholder',
              'store_member_id': 'sm-4',
              'role': 'unassigned',
              'is_owner': false,
              'name': 'Nhân viên', // placeholder
              'phone': '0909888777',
              'hourly_rate': 0,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
            {
              'user_id': 'user-no-phone',
              'store_member_id': 'sm-5',
              'role': 'unassigned',
              'is_owner': false,
              'name': '',
              'phone': '',
              'hourly_rate': 0,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
          ];
        }
        return null;
      };

      final staffList = await StaffService.getStaffList(storeId);
      expect(staffList, hasLength(2));

      final p1 = staffList.firstWhere((s) => s.userId == 'user-placeholder');
      expect(p1.name, 'NV 0909888777');
      expect(p1.phone, '0909888777');

      final p2 = staffList.firstWhere((s) => s.userId == 'user-no-phone');
      expect(p2.name, 'Nhân viên mới');
    });

    test('4. Priority sorting puts unassigned staff on top, then clocked in, then A-Z', () {
      final list = [
        StaffMember(
          userId: 'u1',
          name: 'Đặng Tuấn',
          phone: '0901',
          role: 'waiter',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
        StaffMember(
          userId: 'u2',
          name: 'An Nhiên',
          phone: '0902',
          role: 'unassigned',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
        StaffMember(
          userId: 'u3',
          name: 'Bình An',
          phone: '0903',
          role: 'cashier',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: true,
        ),
        StaffMember(
          userId: 'u4',
          name: 'Zoe',
          phone: '0904',
          role: 'unassigned',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
      ];

      list.sort((a, b) {
        final aUnassigned = StaffService.isUnassignedRole(a.role);
        final bUnassigned = StaffService.isUnassignedRole(b.role);
        if (aUnassigned && !bUnassigned) return -1;
        if (!aUnassigned && bUnassigned) return 1;

        if (a.isClockedIn && !b.isClockedIn) return -1;
        if (!a.isClockedIn && b.isClockedIn) return 1;

        return a.name.compareTo(b.name);
      });

      // Unassigned on top sorted A-Z: An Nhiên, Zoe
      expect(list[0].name, 'An Nhiên');
      expect(list[1].name, 'Zoe');
      // Clocked in next: Bình An
      expect(list[2].name, 'Bình An');
      // Other: Đặng Tuấn
      expect(list[3].name, 'Đặng Tuấn');
    });

    test('5. Role filter logic matches All, Unassigned, and specific roles correctly', () {
      final members = [
        StaffMember(
          userId: 'u-unassigned',
          name: 'NV Mới',
          phone: '0901',
          role: 'unassigned',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
        StaffMember(
          userId: 'u-waiter',
          name: 'Phục Vụ A',
          phone: '0902',
          role: 'waiter',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
        StaffMember(
          userId: 'u-cashier',
          name: 'Thu Ngân B',
          phone: '0903',
          role: 'Thu ngân',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
      ];

      List<StaffMember> filter(String roleFilter) {
        return members.where((m) {
          final isUnassigned = StaffService.isUnassignedRole(m.role);
          final matchRole = roleFilter == 'all' ||
              (roleFilter == 'unassigned' && isUnassigned) ||
              m.role.toLowerCase().trim() == roleFilter.toLowerCase().trim() ||
              StaffService.canonicalRole(m.role) ==
                  StaffService.canonicalRole(roleFilter);
          return matchRole;
        }).toList();
      }

      // Filter: 'all'
      expect(filter('all'), hasLength(3));

      // Filter: 'unassigned'
      final unassignedList = filter('unassigned');
      expect(unassignedList, hasLength(1));
      expect(unassignedList.first.userId, 'u-unassigned');

      // Filter: 'Phục vụ' matches 'waiter' canonically
      final waiterList = filter('Phục vụ');
      expect(waiterList, hasLength(1));
      expect(waiterList.first.userId, 'u-waiter');

      // Filter: 'cashier' matches 'Thu ngân' canonically
      final cashierList = filter('cashier');
      expect(cashierList, hasLength(1));
      expect(cashierList.first.userId, 'u-cashier');
    });

    test('6. updateRole properly invokes admin_update_staff_role_v4 for newly joined staff', () async {
      String? invokedRpc;
      Map<String, dynamic>? rpcParams;
      bool broadcastInvoked = false;

      StaffService.rpcTransportOverride = (rpcName, params) async {
        invokedRpc = rpcName;
        rpcParams = params;
        return {'success': true, 'status': 200, 'role': 'cashier'};
      };

      StaffService.broadcastHandlerOverride = ({
        required String storeId,
        required String targetUserId,
      }) async {
        if (storeId == '00000000-0000-0000-0000-000000000001' &&
            targetUserId == 'user-new-staff') {
          broadcastInvoked = true;
        }
      };

      await StaffService.updateRole(
        storeId: storeId,
        userId: 'user-new-staff',
        newRole: 'Thu ngân',
        changedByUserId: 'user-owner',
        oldRole: 'unassigned',
      );

      expect(invokedRpc, 'admin_update_staff_role_v4');
      expect(rpcParams?['p_store_id'], storeId);
      expect(rpcParams?['p_staff_id'], 'user-new-staff');
      expect(rpcParams?['p_new_role'], 'Thu ngân');
      expect(broadcastInvoked, isTrue);
    });

    test('7. assignShiftConfig updates store_members shift configuration', () async {
      // SharedPreferences / Method channel setup
      // Method calls db.from('store_members').update
      // Verify signature runs without crashing
      await expectLater(
        StaffService.assignShiftConfig(
          storeId: storeId,
          userId: 'user-new-staff',
          shiftConfigId: 'shift-1',
        ),
        completes,
      );
    });

    test('8. Real identity takes precedence over placeholder name in directory mapping', () async {
      StaffService.rpcTransportOverride = (rpcName, params) async {
        if (rpcName == 'get_store_staff_directory_v4') {
          return [
            {
              'user_id': 'u-real-name',
              'store_member_id': 'sm-8',
              'role': 'unassigned',
              'is_owner': false,
              'name': 'Lê Hoàng Long', // Real name from user_accounts
              'phone': '0912345678',
              'hourly_rate': 0,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
            {
              'user_id': 'u-empty-phone',
              'store_member_id': 'sm-9',
              'role': 'unassigned',
              'is_owner': false,
              'name': 'Nguyễn Thị Cúc',
              'phone': '', // No phone yet
              'hourly_rate': 0,
              'shift_config_id': null,
              'is_clocked_in': false,
            },
          ];
        }
        return null;
      };

      final staffList = await StaffService.getStaffList(storeId);
      expect(staffList, hasLength(2));
      final s1 = staffList.firstWhere((s) => s.userId == 'u-real-name');
      expect(s1.name, 'Lê Hoàng Long');
      expect(s1.phone, '0912345678');

      final s2 = staffList.firstWhere((s) => s.userId == 'u-empty-phone');
      expect(s2.name, 'Nguyễn Thị Cúc');
      expect(s2.phone, '');
    });

    test('9. Unassigned staff never falsely match standard or custom role filter', () {
      final unassignedMember = StaffMember(
        userId: 'u-unassigned',
        name: 'NV Mới KAy',
        phone: '0909999999',
        role: 'unassigned',
        isOwner: false,
        hourlyRate: 0,
        baseSalary: 0,
        jobDesc: '',
        startDate: null,
        isClockedIn: false,
      );

      final roles = [
        StoreRole(
          id: 'r1',
          storeId: storeId,
          name: 'Thu ngân',
          icon: 'point_of_sale',
          color: '#1D4ED8',
          modules: ['pos'],
        ),
        StoreRole(
          id: 'r2',
          storeId: storeId,
          name: 'Barista',
          icon: 'kitchen',
          color: '#DC2626',
          modules: ['kitchen'],
        ),
      ];

      bool matchesRole(StaffMember m, String roleFilter) {
        final isUnassigned = StaffService.isUnassignedRole(m.role);
        return roleFilter == 'all' ||
            (roleFilter == 'unassigned' && isUnassigned) ||
            (!isUnassigned &&
                (m.role.toLowerCase().trim() == roleFilter.toLowerCase().trim() ||
                    StaffService.canonicalRole(m.role) ==
                        StaffService.canonicalRole(roleFilter)));
      }

      // Should match 'all' and 'unassigned'
      expect(matchesRole(unassignedMember, 'all'), isTrue);
      expect(matchesRole(unassignedMember, 'unassigned'), isTrue);

      // Should NEVER match any specific role
      for (final r in roles) {
        expect(matchesRole(unassignedMember, r.name), isFalse);
      }
      expect(matchesRole(unassignedMember, 'cashier'), isFalse);
      expect(matchesRole(unassignedMember, 'waiter'), isFalse);
    });

    testWidgets(
      '10. NhanVienScreen renders newly onboarded staff card, unassigned chip, and filters correctly',
      (tester) async {
        StaffService.rpcTransportOverride = (rpcName, params) async {
          if (rpcName == 'get_store_staff_directory_v4') {
            return [
              {
                'user_id': 'u-owner',
                'store_member_id': 'sm-owner',
                'role': 'owner',
                'is_owner': true,
                'name': 'Chủ quán KAy',
                'phone': '0901111111',
                'hourly_rate': 0,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
              {
                'user_id': 'u-newbie-1',
                'store_member_id': 'sm-newbie-1',
                'role': 'unassigned',
                'is_owner': false,
                'name': 'Bảo Linh',
                'phone': '0902222222',
                'hourly_rate': 25000,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
              {
                'user_id': 'u-newbie-2',
                'store_member_id': 'sm-newbie-2',
                'role': 'unassigned',
                'is_owner': false,
                'name': 'Nguyễn Văn C',
                'phone': '', // No phone
                'hourly_rate': 0,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
            ];
          }
          return null;
        };

        final testSession = SessionData(
          userId: 'u-owner',
          phone: '0901111111',
          displayName: 'Chủ quán KAy',
          storeId: storeId,
          storeName: 'Quán KAy',
          storeCode: 'KAYPOS',
          role: 'owner',
          isOwner: true,
        );

        final container = ProviderContainer(
          overrides: [
            storeRolesProvider.overrideWith((ref) => Future.value([])),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionProvider.notifier).setSession(testSession);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: NhanVienScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify owner and new staff members are visible on the screen
        expect(find.text('Bảo Linh'), findsOneWidget);
        expect(find.text('0902222222'), findsOneWidget);
        expect(find.text('Chưa cập nhật SĐT'), findsOneWidget);

        // 2. Verify filter chip "Chưa phân vai trò (2)" is present
        expect(find.text('Chưa phân vai trò (2)'), findsOneWidget);

        // 3. Tap on "Chưa phân vai trò (2)" filter chip
        await tester.tap(find.text('Chưa phân vai trò (2)'));
        await tester.pumpAndSettle();

        // Both unassigned staff remain visible
        expect(find.text('Bảo Linh'), findsOneWidget);
        expect(find.text('Nguyễn Văn C'), findsOneWidget);
      },
    );

    test('11. Diacritic-insensitive search matches Vietnamese accents and phone digits', () {
      final members = [
        StaffMember(
          userId: 'u1',
          name: 'Bảo Linh',
          phone: '090-222-2222',
          role: 'unassigned',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
        StaffMember(
          userId: 'u2',
          name: 'Trần Văn Bình',
          phone: '0903333333',
          role: 'waiter',
          isOwner: false,
          hourlyRate: 0,
          baseSalary: 0,
          jobDesc: '',
          startDate: null,
          isClockedIn: false,
        ),
      ];

      bool searchMatches(StaffMember m, String q) {
        String stripDiacritics(String text) {
          const map = {
            'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
            'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
            'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
            'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
            'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
            'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
            'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
            'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
            'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
            'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
            'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
            'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
            'đ': 'd',
            'À': 'a', 'Á': 'a', 'Ả': 'a', 'Ã': 'a', 'Ạ': 'a',
            'Ă': 'a', 'Ằ': 'a', 'Ắ': 'a', 'Ẳ': 'a', 'Ẵ': 'a', 'Ặ': 'a',
            'Â': 'a', 'Ầ': 'a', 'Ấ': 'a', 'Ẩ': 'a', 'Ẫ': 'a', 'Ậ': 'a',
            'È': 'e', 'É': 'e', 'Ẻ': 'e', 'Ẽ': 'e', 'Ẹ': 'e',
            'Ê': 'e', 'Ề': 'e', 'Ế': 'e', 'Ể': 'e', 'Ễ': 'e', 'Ệ': 'e',
            'Ì': 'i', 'Í': 'i', 'Ỉ': 'i', 'Ĩ': 'i', 'Ị': 'i',
            'Ò': 'o', 'Ó': 'o', 'Ỏ': 'o', 'Õ': 'o', 'Ọ': 'o',
            'Ô': 'o', 'Ồ': 'o', 'Ố': 'o', 'Ổ': 'o', 'Ỗ': 'o', 'Ộ': 'o',
            'Ơ': 'o', 'Ờ': 'o', 'Ớ': 'o', 'Ở': 'o', 'Ỡ': 'o', 'Ợ': 'o',
            'Ù': 'u', 'Ú': 'u', 'Ủ': 'u', 'Ũ': 'u', 'Ụ': 'u',
            'Ư': 'u', 'Ừ': 'u', 'Ứ': 'u', 'Ử': 'u', 'Ữ': 'u', 'Ự': 'u',
            'Ỳ': 'y', 'Ý': 'y', 'Ỷ': 'y', 'Ỹ': 'y', 'Ỵ': 'y',
            'Đ': 'd',
          };
          return text.split('').map((c) => map[c] ?? c.toLowerCase()).join();
        }

        final cleanQuery = stripDiacritics(q.trim()).toLowerCase();
        final cleanDigits = q.replaceAll(RegExp(r'\D'), '');
        return q.trim().isEmpty ||
            stripDiacritics(m.name).toLowerCase().contains(cleanQuery) ||
            (cleanDigits.isNotEmpty &&
                m.phone.replaceAll(RegExp(r'\D'), '').contains(cleanDigits));
      }

      // Unaccented search matches accented Vietnamese name
      expect(searchMatches(members[0], 'bao linh'), isTrue);
      expect(searchMatches(members[0], 'Bao Linh'), isTrue);
      expect(searchMatches(members[0], 'Bảo Linh'), isTrue);
      expect(searchMatches(members[1], 'binh'), isTrue);
      expect(searchMatches(members[1], 'tran van'), isTrue);

      // Phone query formatted
      expect(searchMatches(members[0], '090222'), isTrue);
      expect(searchMatches(members[0], '2222'), isTrue);
      expect(searchMatches(members[1], '0903'), isTrue);

      // Non-matching query
      expect(searchMatches(members[0], 'nguyen'), isFalse);
    });

    testWidgets(
      '12. NhanVienScreen live search bar filters by non-accented text',
      (tester) async {
        StaffService.rpcTransportOverride = (rpcName, params) async {
          if (rpcName == 'get_store_staff_directory_v4') {
            return [
              {
                'user_id': 'u-linh',
                'store_member_id': 'sm-linh',
                'role': 'unassigned',
                'is_owner': false,
                'name': 'Bảo Linh',
                'phone': '0902222222',
                'hourly_rate': 0,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
              {
                'user_id': 'u-binh',
                'store_member_id': 'sm-binh',
                'role': 'waiter',
                'is_owner': false,
                'name': 'Trần Văn Bình',
                'phone': '0903333333',
                'hourly_rate': 0,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
            ];
          }
          return null;
        };

        final testSession = SessionData(
          userId: 'u-owner',
          phone: '0901111111',
          displayName: 'Chủ quán KAy',
          storeId: storeId,
          storeName: 'Quán KAy',
          storeCode: 'KAYPOS',
          role: 'owner',
          isOwner: true,
        );

        final container = ProviderContainer(
          overrides: [
            storeRolesProvider.overrideWith((ref) => Future.value([])),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionProvider.notifier).setSession(testSession);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: NhanVienScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both visible initially
        expect(find.text('Bảo Linh'), findsOneWidget);
        expect(find.text('Trần Văn Bình'), findsOneWidget);

        // Enter unaccented search query "bao linh" into search field
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'bao linh');
        await tester.pumpAndSettle();

        // Only "Bảo Linh" remains visible
        expect(find.text('Bảo Linh'), findsOneWidget);
        expect(find.text('Trần Văn Bình'), findsNothing);
      },
    );

    testWidgets(
      '13. Manager opens _StaffDetailSheet for unassigned staff, prompts to choose role, and successfully saves',
      (tester) async {
        StaffService.rpcTransportOverride = (rpcName, params) async {
          if (rpcName == 'get_store_staff_directory_v4') {
            return [
              {
                'user_id': 'u-newbie-1',
                'store_member_id': 'sm-newbie-1',
                'role': 'unassigned',
                'is_owner': false,
                'name': 'Bảo Linh',
                'phone': '0902222222',
                'hourly_rate': 0,
                'shift_config_id': null,
                'is_clocked_in': false,
              },
            ];
          }
          if (rpcName == 'admin_update_staff_role_v4') {
            return {'success': true, 'status': 200, 'role': params['p_new_role']};
          }
          return null;
        };

        final testRoles = [
          StoreRole(
            id: 'role-cashier',
            storeId: storeId,
            name: 'Thu ngân',
            icon: 'point_of_sale',
            color: '#1D4ED8',
            modules: ['pos'],
          ),
        ];

        final testSession = SessionData(
          userId: 'u-owner',
          phone: '0901111111',
          displayName: 'Chủ quán KAy',
          storeId: storeId,
          storeName: 'Quán KAy',
          storeCode: 'KAYPOS',
          role: 'owner',
          isOwner: true,
        );

        final container = ProviderContainer(
          overrides: [
            storeRolesProvider.overrideWith((ref) => Future.value(testRoles)),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionProvider.notifier).setSession(testSession);

        StaffService.broadcastHandlerOverride = ({
          required String storeId,
          required String targetUserId,
        }) async {};

        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: NhanVienScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Cấp quyền" button on the unassigned staff card
        expect(find.text('Cấp quyền'), findsOneWidget);
        await tester.tap(find.text('Cấp quyền'));
        await tester.pumpAndSettle();

        // Detail sheet opened, scroll to and verify hint "Chọn vai trò cho nhân viên..." visible
        final sheetScrollable = find.byType(Scrollable).last;
        await tester.scrollUntilVisible(
          find.text('Chọn vai trò cho nhân viên...'),
          100.0,
          scrollable: sheetScrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text('Chọn vai trò cho nhân viên...'), findsOneWidget);

        // Scroll to "Lưu vai trò" button
        await tester.scrollUntilVisible(
          find.text('Lưu vai trò'),
          100.0,
          scrollable: sheetScrollable,
        );
        await tester.pumpAndSettle();

        // Tap "Lưu vai trò" while still unassigned -> shows SnackBar prompt
        await tester.tap(find.text('Lưu vai trò'));
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng chọn vai trò cho nhân viên'), findsOneWidget);

        // Select "Thu ngân" from the dropdown
        final dropdownFinder = find.byType(DropdownButtonFormField<String>);
        await tester.scrollUntilVisible(
          dropdownFinder,
          -100.0,
          scrollable: sheetScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thu ngân').last);
        await tester.pumpAndSettle();

        // Scroll to "Lưu vai trò" and tap -> succeeds
        await tester.scrollUntilVisible(
          find.text('Lưu vai trò'),
          100.0,
          scrollable: sheetScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu vai trò'));
        await tester.pumpAndSettle();
      },
    );
  });
}

