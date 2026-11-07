import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/qr_order/models/qr_order_model.dart';
import 'package:quannho_pos/modules/qr_order/screens/customer_qr_order_screen.dart';
import 'package:quannho_pos/modules/qr_order/services/settlement_operation_manager.dart';
import 'package:quannho_pos/core/services/staff_service.dart';

void main() {
  group('QR Order V4 - Model & Serialization Tests', () {
    test(
      'QrErrorCode maps all standard error codes to meaningful Vietnamese messages',
      () {
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidQr),
          contains('không hợp lệ'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.channelDisabled),
          contains('tạm đóng'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.requestExpired),
          contains('hết hạn'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.tokenAlreadyUsed),
          contains('đã được sử dụng'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.alreadyClaimed),
          contains('nhân viên khác tiếp nhận'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.wrongStore),
          contains('cửa hàng khác'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.permissionDenied),
          contains('không có quyền'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidState),
          contains('không hợp lệ'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.tableNotFound),
          contains('Không tìm thấy bàn'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.paymentRequired),
          contains('yêu cầu thanh toán'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.alreadySent),
          contains('gửi bếp trước đó'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.idempotencyConflict),
          contains('trùng lặp'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.productNotAvailable),
          contains('tạm ngưng'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.versionConflict),
          contains('cập nhật bởi thiết bị khác'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.financialQuoteChanged),
          contains('thay đổi'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidPoints),
          contains('không hợp lệ'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.customerRequired),
          contains('chọn thông tin khách hàng'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.customerNotFound),
          contains('không tồn tại'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.insufficientPoints),
          contains('vượt quá số dư điểm'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidLoyaltyConfig),
          contains('chưa hợp lệ'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponNotFound),
          contains('không tồn tại'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponDisabled),
          contains('tạm khóa'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponNotStarted),
          contains('chưa đến ngày'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponExpired),
          contains('hết hạn'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponMinOrderNotMet),
          contains('chưa đạt giá trị tối thiểu'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.couponSchemaUnavailable),
          contains('chưa được khởi tạo'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidCouponValue),
          contains('không hợp lệ'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidSurcharge),
          contains('Phụ phí'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidPaymentMethod),
          contains('Phương thức'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.sessionAlreadySettled),
          contains('trước đó'),
        );
        expect(
          QrErrorCode.toUserMessage(QrErrorCode.invalidSessionItems),
          contains('không có món ăn'),
        );
      },
    );

    test('QrRpcResponse properly parses success and failure payloads', () {
      // Success case
      final successJson = {
        'success': true,
        'data': {'request_id': 'req_123', 'total_amount': 75000},
        'message': 'Thành công',
        'error_code': null,
      };
      final successResp = QrRpcResponse<Map<String, dynamic>>.fromMap(
        successJson,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      expect(successResp.isSuccess, isTrue);
      expect(successResp.data!['request_id'], equals('req_123'));
      expect(successResp.data!['total_amount'], equals(75000));
      expect(successResp.message, equals('Thành công'));
      expect(successResp.errorCode, isNull);

      // Failure case
      final errorJson = {
        'success': false,
        'data': null,
        'error_code': 'ALREADY_CLAIMED',
        'message': 'Đơn hàng này đã được nhân viên khác tiếp nhận',
      };
      final errorResp = QrRpcResponse<Map<String, dynamic>>.fromMap(
        errorJson,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      expect(errorResp.isSuccess, isFalse);
      expect(errorResp.data, isNull);
      expect(errorResp.errorCode, equals('ALREADY_CLAIMED'));
      expect(errorResp.message, contains('tiếp nhận'));
    });

    test(
      'QrChannelModel correctly serializes and identifies TABLE_SHARED vs COUNTER_TAKEAWAY',
      () {
        final tableCh = QrChannelModel(
          id: 'ch_1',
          storeId: 'store_1',
          type: 'TABLE_SHARED',
          channelCode: 'TBL_A1B2C3',
          name: 'QR Bàn Chung',
          isActive: true,
          paymentMode: 'PAY_BEFORE_KITCHEN',
          createdAt: DateTime(2026, 8, 27),
        );
        expect(tableCh.isTableShared, isTrue);
        expect(tableCh.isCounterTakeaway, isFalse);

        final counterCh = QrChannelModel(
          id: 'ch_2',
          storeId: 'store_1',
          type: 'COUNTER_TAKEAWAY',
          channelCode: 'CTR_D4E5F6',
          name: 'QR Quầy',
          isActive: true,
          paymentMode: 'PAY_BEFORE_KITCHEN',
          createdAt: DateTime(2026, 8, 27),
        );
        expect(counterCh.isTableShared, isFalse);
        expect(counterCh.isCounterTakeaway, isTrue);

        final map = counterCh.toMap();
        final fromMap = QrChannelModel.fromMap(map);
        expect(fromMap.id, equals(counterCh.id));
        expect(fromMap.channelCode, equals('CTR_D4E5F6'));
        expect(fromMap.paymentMode, equals('PAY_BEFORE_KITCHEN'));
      },
    );

    test('QrRequestModel parse, status normalize và round-trip', () {
      final req = QrRequestModel.fromMap({
        'id': 'req_001',
        'store_id': 'store_001',
        'type': 'table',
        'table_id': 'tbl_005',
        'table_name': 'Bàn 05',
        'status': 'customer_submitted', // giá trị cũ -> submitted
        'payment_status': 'unpaid',
        'total_amount': '120000', // chuỗi vẫn parse an toàn
        'version': 2.0, // num -> int
        'claimed_by': 'u1',
        'items': [
          {
            'id': 'it_001',
            'product_id': 'prod_1',
            'product_name': 'Cơm Rang Dưa Bò',
            'unit_price': 60000,
            'quantity': 2.0,
            'modifiers_json': [
              {'id': 'top_1', 'name': 'Trứng Ốp La', 'quantity': 1},
            ],
          },
        ],
      });

      expect(req.type, equals(QrChannelType.table));
      expect(req.isTable, isTrue);
      expect(req.isSubmitted, isTrue);
      expect(req.status, equals(QrStatus.submitted));
      expect(req.totalAmount, equals(120000));
      expect(req.version, equals(2));
      expect(req.tableId, equals('tbl_005'));
      expect(req.displayTitle, equals('Bàn 05'));
      expect(req.items.single.quantity, equals(2));
      expect(req.items.single.subtotal, equals(120000));

      final back = QrRequestModel.fromMap(req.toMap());
      expect(back.id, equals(req.id));
      expect(back.tableName, equals('Bàn 05'));
      expect(back.claimedBy, equals('u1'));
      expect(back.items.first.modifiersJson.first['name'], 'Trứng Ốp La');
    });

    test('QrStatus.normalize gom về 6 trạng thái', () {
      expect(QrStatus.normalize('pending_staff'), QrStatus.submitted);
      expect(QrStatus.normalize('awaiting_payment'), QrStatus.claimed);
      expect(QrStatus.normalize('ready_for_kitchen'), QrStatus.claimed);
      expect(QrStatus.normalize('sent_kitchen'), QrStatus.sentKitchen);
      expect(QrStatus.normalize('rejected'), QrStatus.rejected);
      expect(QrStatus.normalize('expired'), QrStatus.expired);
      expect(QrStatus.normalize(null), QrStatus.submitted);
    });

    test('QrRequestModel COUNTER: mã lấy món không bịa mã giả', () {
      final withCode = QrRequestModel.fromMap({
        'id': 'c_01',
        'type': 'COUNTER_TAKEAWAY',
        'pickup_code': '#Q07',
        'status': 'claimed',
      });
      expect(withCode.displayPickupCode, equals('#Q07'));
      expect(withCode.displayTitle, equals('Mang đi #Q07'));

      final noPrefix = QrRequestModel.fromMap({
        'id': 'c_02',
        'type': 'counter',
        'pickup_code': '15',
        'status': 'claimed',
      });
      expect(noPrefix.displayPickupCode, equals('#15'));

      final noCode = QrRequestModel.fromMap({
        'id': 'c_03',
        'type': 'COUNTER_TAKEAWAY',
        'status': 'submitted',
      });
      expect(noCode.displayPickupCode, isEmpty);
    });

    test('QrOrderSettingsModel defaults and custom overrides', () {
      const defaultSettings = QrOrderSettingsModel();
      expect(defaultSettings.isTableEnabled, isTrue);
      expect(defaultSettings.isCounterEnabled, isTrue);
      expect(defaultSettings.counterPaymentMode, equals('CASHIER_CONFIRM'));
      expect(defaultSettings.transferBankBin, equals('970422'));
      expect(defaultSettings.transferAccountNo, isEmpty);
      expect(defaultSettings.counterTitle, equals('QUÉT QR GỌI MÓN TẠI QUẦY'));

      final customSettings = defaultSettings.copyWith(
        counterPaymentMode: 'CASHIER_CONFIRM',
        customBaseUrl: 'https://quannho.lpm.vn/pos',
        transferBankBin: '970436',
        transferAccountNo: '123456789',
        transferAccountName: 'NGUYEN VAN A',
      );
      expect(customSettings.counterPaymentMode, equals('CASHIER_CONFIRM'));
      expect(customSettings.transferBankBin, equals('970436'));
      expect(customSettings.transferAccountNo, equals('123456789'));
      expect(
        customSettings.customBaseUrl,
        equals('https://quannho.lpm.vn/pos'),
      );
    });
  });

  group('QR Order V4 - Business Rules & Utility Tests', () {
    test('QrUrlBuilder builds links from a single validated source', () {
      expect(
        QrUrlBuilder.build(channelCode: 'TBL_12345'),
        equals('https://quannho.lpm.vn/pos/goi-mon/?code=TBL_12345'),
      );
      expect(
        QrUrlBuilder.build(
          customBaseUrl: 'https://quannho.lpm.vn',
          channelCode: 'TBL_12345',
        ),
        equals('https://quannho.lpm.vn/goi-mon/?code=TBL_12345'),
      );
      expect(
        QrUrlBuilder.build(
          customBaseUrl: 'https://quannho.lpm.vn/pos///',
          channelCode: 'CTR_999',
        ),
        equals('https://quannho.lpm.vn/pos/goi-mon/?code=CTR_999'),
      );
      expect(
        QrUrlBuilder.build(channelCode: 'A B&C'),
        equals('https://quannho.lpm.vn/pos/goi-mon/?code=A+B%26C'),
      );
      expect(QrUrlBuilder.build(channelCode: ''), isNull);
      expect(
        QrUrlBuilder.build(
          customBaseUrl: 'https://localhost',
          channelCode: 'X',
        ),
        isNull,
      );

      bool ok(String u) => QrUrlBuilder.isValidPublicUrl(u);
      expect(ok('https://quannho.lpm.vn/pos'), isTrue);
      expect(ok('https://10.example.com'), isTrue);
      expect(ok('http://quannho.lpm.vn/pos'), isFalse);
      for (final bad in [
        'https://localhost:8080',
        'https://127.0.0.1:3000',
        'https://192.168.1.5',
        'https://10.1.2.3',
        'https://172.16.0.1',
        'https://172.31.255.1',
        'https://169.254.1.1',
        'https://0.0.0.0',
        'https://[::1]',
        'https://printer.local',
        'https://nas.lan',
        'https://svc.internal',
        'https://a.localhost',
        'https://user:pw@quannho.lpm.vn',
        'https://quannho.lpm.vn/pos?x=1',
        'https://quannho.lpm.vn/pos#frag',
        'https://intranet',
      ]) {
        expect(ok(bad), isFalse, reason: bad);
      }
      expect(ok('https://172.32.0.1'), isTrue);
    });

    test(
      'CustomerQrOrderScreen.computeCanonicalPayloadHash is deterministic and order-independent',
      () {
        final itemsA = [
          {
            'product_id': 'prod_b',
            'quantity': 2,
            'note': 'ít đường',
            'modifiers_json': [
              {'id': 'top_2', 'quantity': 1},
              {'id': 'top_1', 'quantity': 2},
            ],
          },
          {
            'product_id': 'prod_a',
            'quantity': 1,
            'note': '',
            'modifiers_json': [],
          },
        ];

        final itemsB = [
          {
            'product_id': 'prod_a',
            'quantity': 1,
            'note': '',
            'modifiers_json': [],
          },
          {
            'product_id': 'prod_b',
            'quantity': 2,
            'note': 'ít đường',
            'modifiers_json': [
              {'id': 'top_1', 'quantity': 2},
              {'id': 'top_2', 'quantity': 1},
            ],
          },
        ];

        final hashA = CustomerQrOrderScreen.computeCanonicalPayloadHash(
          channelCode: 'TBL_01',
          tableId: 'B01',
          items: itemsA,
        );

        final hashB = CustomerQrOrderScreen.computeCanonicalPayloadHash(
          channelCode: 'TBL_01',
          tableId: 'B01',
          items: itemsB,
        );

        // Sắp xếp thứ tự items hoặc modifiers khác nhau vẫn phải ra cùng một hash chuẩn
        expect(hashA, equals(hashB));

        // Thay đổi số lượng hoặc topping phải ra hash khác
        final itemsC = [
          {
            'product_id': 'prod_a',
            'quantity': 2, // changed quantity
            'note': '',
            'modifiers_json': [],
          },
        ];
        final hashC = CustomerQrOrderScreen.computeCanonicalPayloadHash(
          channelCode: 'TBL_01',
          tableId: 'B01',
          items: itemsC,
        );
        expect(hashA, isNot(equals(hashC)));
      },
    );

    test(
      'Simulate Lego Modules & Role-Based Permission Matrix for pos.checkout',
      () {
        bool hasCheckoutPermission({
          required String role,
          required bool isOwner,
          List<String>? modules,
          Map<String, dynamic>? appSettingsPerms,
        }) {
          // 1. Owner always allowed
          if (isOwner || role == 'owner') return true;

          // 2. Canonical role check (manager, cashier, thu ngân)
          final canon = StaffService.canonicalRole(role);
          if (canon == 'manager' ||
              canon == 'cashier' ||
              role.toLowerCase().contains('thu ngân')) {
            return true;
          }

          // 3. Lego modules check (pos or ban)
          if (modules != null &&
              (modules.contains('pos') || modules.contains('ban'))) {
            return true;
          }

          // 4. app_settings fallback override
          if (appSettingsPerms != null &&
              appSettingsPerms.containsKey('action_perms_$role')) {
            final val = appSettingsPerms['action_perms_$role'];
            if (val is List) {
              return val.contains('pos.checkout');
            }
          }

          return false;
        }

        // Owner always allowed
        expect(hasCheckoutPermission(role: 'owner', isOwner: true), isTrue);

        // Cashier without explicit app_settings config -> ALLOWED (Lego module / canonical role)
        expect(hasCheckoutPermission(role: 'cashier', isOwner: false), isTrue);
        expect(hasCheckoutPermission(role: 'Thu ngân', isOwner: false), isTrue);

        // Manager without explicit app_settings config -> ALLOWED
        expect(hasCheckoutPermission(role: 'manager', isOwner: false), isTrue);

        // Custom role with module 'pos' -> ALLOWED
        expect(
          hasCheckoutPermission(
            role: 'Pha chế',
            isOwner: false,
            modules: ['pos', 'ban'],
          ),
          isTrue,
        );

        // Waiter without pos/ban modules -> DENIED
        expect(
          hasCheckoutPermission(
            role: 'waiter',
            isOwner: false,
            modules: ['kitchen'],
          ),
          isFalse,
        );

        // Waiter granted pos.checkout in app_settings -> ALLOWED
        expect(
          hasCheckoutPermission(
            role: 'waiter',
            isOwner: false,
            appSettingsPerms: {
              'action_perms_waiter': ['pos.checkout'],
            },
          ),
          isTrue,
        );
      },
    );

    test('Strict SHA-256 Hex Hash Regex Validation', () {
      bool isValidSha256Hex(String? hash) {
        if (hash == null || hash.trim().isEmpty) return false;
        final clean = hash.trim().toLowerCase();
        return RegExp(r'^[0-9a-f]{64}$').hasMatch(clean);
      }

      // Valid lowercase 64-hex
      expect(
        isValidSha256Hex(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
        isTrue,
      );

      // Valid uppercase 64-hex (normalized)
      expect(
        isValidSha256Hex(
          'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855',
        ),
        isTrue,
      );

      // Invalid: 63 characters
      expect(
        isValidSha256Hex(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85',
        ),
        isFalse,
      );

      // Invalid: 65 characters
      expect(
        isValidSha256Hex(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8555',
        ),
        isFalse,
      );

      // Invalid: Non-hex character 'z'
      expect(
        isValidSha256Hex(
          'z3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
        isFalse,
      );

      // Invalid: Empty or null
      expect(isValidSha256Hex(''), isFalse);
      expect(isValidSha256Hex(null), isFalse);
    });

    test(
      'Fail-closed Topping Filtering: Products without mappings have 0 toppings',
      () {
        final allToppings = [
          {'id': 'top_pearl', 'name': 'Trân Châu', 'sell_price': 10000},
          {'id': 'top_cheese', 'name': 'Kem Cheese', 'sell_price': 15000},
        ];

        final toppingLinks = [
          {'product_id': 'prod_drink', 'topping_id': 'top_pearl'},
        ];

        List<Map<String, dynamic>> getToppingsForProduct(
          String productId,
          List<Map<String, dynamic>> links,
          List<Map<String, dynamic>> toppings,
        ) {
          if (links.isEmpty) return [];
          final linkedIds = links
              .where((l) => l['product_id'] == productId)
              .map((l) => l['topping_id'] as String)
              .toSet();
          if (linkedIds.isEmpty) return [];
          return toppings.where((t) => linkedIds.contains(t['id'])).toList();
        }

        // Product with links -> returns only mapped toppings
        final drinkToppings = getToppingsForProduct(
          'prod_drink',
          toppingLinks,
          allToppings,
        );
        expect(drinkToppings.length, equals(1));
        expect(drinkToppings.first['id'], equals('top_pearl'));

        // Product without links (Food) -> returns empty list (Fail-closed)
        final foodToppings = getToppingsForProduct(
          'prod_food',
          toppingLinks,
          allToppings,
        );
        expect(foodToppings, isEmpty);

        // Store with 0 links -> returns empty list (Fail-closed)
        final zeroLinksToppings = getToppingsForProduct(
          'prod_drink',
          [],
          allToppings,
        );
        expect(zeroLinksToppings, isEmpty);
      },
    );

    test('Static contract: SQL migration, repository and screens agree', () {
      final migrationFile = File(
        'supabase/migrations/20261013_qr_order_simple_v4.sql',
      );
      expect(migrationFile.existsSync(), isTrue);
      // Bản chống phá (20261014) thay 3 hàm và thêm rotate_qr_channel_v4: gộp cả hai để kiểm hợp đồng.
      final antiAbuse = File('supabase/migrations/20261014_qr_chong_pha_v4.sql');
      expect(antiAbuse.existsSync(), isTrue);
      final sql = migrationFile.readAsStringSync() + antiAbuse.readAsStringSync();
      final repo = File(
        'lib/modules/qr_order/repository/qr_order_repository.dart',
      ).readAsStringSync();

      // 1. Mọi RPC mà repository gọi (trừ settle V5 có sẵn) đều được định nghĩa.
      final called = RegExp(
        r"rpc\(\s*'([a-z_0-9]+)'",
      ).allMatches(repo).map((m) => m.group(1)!).toSet();
      expect(called, isNotEmpty);
      for (final fn in called.where((f) => f != 'settle_ban_session_v5')) {
        expect(
          sql.contains('CREATE OR REPLACE FUNCTION public.$fn('),
          isTrue,
          reason: 'Thiếu định nghĩa SQL cho RPC $fn',
        );
      }

      // 2. Chỉ 4 RPC công khai được cấp cho anon.
      final anonGrants = RegExp(
        r'GRANT EXECUTE ON FUNCTION public\.([a-z_0-9]+)\([^)]*\) TO anon',
      ).allMatches(sql).map((m) => m.group(1)!).toSet();
      expect(anonGrants, {
        'get_qr_channel_info_v4',
        'get_qr_menu_v4',
        'submit_qr_order_v4',
        'get_qr_request_status_v4',
      });

      // 3. Không còn dấu vết QR động / ghép thiết bị / thu tiền tách bước.
      for (final gone in [
        'claim_qr_handoff_v4',
        'regenerate_handoff_token_v4',
        'assign_qr_order_table_v4',
        'mark_qr_order_paid_v4',
        'send_qr_order_to_kitchen_v4',
      ]) {
        expect(
          repo.contains("'$gone'"),
          isFalse,
          reason: 'Repository không được gọi RPC đã bỏ: $gone',
        );
      }
      expect(
        sql.contains('CREATE TABLE IF NOT EXISTS public.qr_handoff_tokens'),
        isFalse,
      );

      // 4. Tham số RPC nhân viên khớp chữ ký SQL.
      expect(repo.contains("'p_version': version"), isTrue);
      expect(repo.contains("'p_expected_version': expectedVersion"), isTrue);
      expect(
        sql.contains(
          'CREATE OR REPLACE FUNCTION public.approve_and_send_table_v4(p_request_id uuid, p_store_id uuid, p_version integer)',
        ),
        isTrue,
      );
      expect(sql.contains('p_table_id text DEFAULT NULL'), isTrue);

      // 5. Id bàn là text, không FK cứng, không ghi cột status của bàn.
      expect(sql.contains('table_id text'), isTrue);
      expect(
        sql.contains('UPDATE public.ban_dining_tables SET status'),
        isFalse,
      );

      // 6. Khách chọn bàn; không còn tableHint và QR bàn giao động.
      final customerScreen = File(
        'lib/modules/qr_order/screens/customer_qr_order_screen.dart',
      ).readAsStringSync();
      expect(customerScreen.contains('tableHint'), isFalse);
      expect(customerScreen.contains('regenerateHandoffToken'), isFalse);
      expect(customerScreen.contains('tableId'), isTrue);

      // 7. Màn Mã QR không còn TabBar; trạng thái kênh lấy từ channel.
      final qrScreen = File(
        'lib/modules/qr_order/screens/qr_order_screen.dart',
      ).readAsStringSync();
      expect(qrScreen.contains('TabBar'), isFalse);
    });

    test('Fail-Closed Checkout Detection logic simulation', () {
      // Simulate Lookup Function
      bool lookupSucceeded = false;
      bool hasQrOrders = false;
      bool threwException = false;

      void simulateCheckoutCheck({
        required bool networkOk,
        required bool hasQrInDb,
      }) {
        if (!networkOk) {
          throw Exception('Network error connecting to DB');
        }
        lookupSucceeded = true;
        hasQrOrders = hasQrInDb;
      }

      // Case 1: Lookup fails (network/schema error) -> Must throw and NOT fallback to legacy
      try {
        simulateCheckoutCheck(networkOk: false, hasQrInDb: false);
      } catch (e) {
        threwException = true;
      }
      expect(threwException, isTrue);
      expect(lookupSucceeded, isFalse);

      // Case 2: Pure manual session (network ok, 0 QR orders) -> Proceeds to legacy
      threwException = false;
      simulateCheckoutCheck(networkOk: true, hasQrInDb: false);
      expect(threwException, isFalse);
      expect(hasQrOrders, isFalse);

      // Case 3: QR session (network ok, QR orders exist) -> Proceeds to QR Settlement RPC
      threwException = false;
      simulateCheckoutCheck(networkOk: true, hasQrInDb: true);
      expect(threwException, isFalse);
      expect(hasQrOrders, isTrue);
    });

    test('Financial Calculations on Server Engine simulation', () {
      const double rawSubtotal = 170000;
      const double couponDiscount = 18000; // From DB coupons table
      const int customerAvailablePts = 5;
      const int requestedPts = 2;
      const double pointRate = 1000; // From app_settings
      const double surcharge = 5000;
      const double loyaltyRate = 10000; // From app_settings

      // Server clamp points used
      final int actualPtsUsed = requestedPts.clamp(0, customerAvailablePts);
      final double pointsDiscount = actualPtsUsed * pointRate;

      // 100% Server Authoritative Discount (no client manual discount)
      final double totalDiscount = (couponDiscount + pointsDiscount).clamp(
        0,
        rawSubtotal,
      );
      expect(totalDiscount, equals(20000));

      final double finalTotal = (rawSubtotal - totalDiscount + surcharge).clamp(
        0,
        double.infinity,
      );
      expect(finalTotal, equals(155000));

      final int ptsEarned = (finalTotal / loyaltyRate).floor();
      expect(ptsEarned, equals(15));

      final int newCustomerPts =
          customerAvailablePts + ptsEarned - actualPtsUsed;
      expect(newCustomerPts, equals(18));
    });
  });

  group('SettlementOperationManager Tests', () {
    late SettlementOperationManager manager;

    setUp(() {
      manager = SettlementOperationManager();
    });

    test(
      'Retry with exact same financial intent reuses the same operation key',
      () {
        final key1 = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          customerId: 'cust_abc',
          pointsUsed: 5,
          couponCode: 'VOUCHER20K',
          surcharge: 5000,
          discount: 20000,
        );

        final key2 = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          customerId: 'cust_abc',
          pointsUsed: 5,
          couponCode: 'VOUCHER20K',
          surcharge: 5000,
          discount: 20000,
        );

        expect(key1, isNotEmpty);
        expect(key1, equals(key2));
        expect(manager.hasPendingOperation, isTrue);
        expect(manager.currentPendingKey, equals(key1));
      },
    );

    test('Changing coupon code generates a new operation key', () {
      final key1 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_abc',
        pointsUsed: 5,
        couponCode: 'VOUCHER20K',
        surcharge: 5000,
        discount: 20000,
      );

      final key2 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_abc',
        pointsUsed: 5,
        couponCode: 'VOUCHER50K', // Changed coupon
        surcharge: 5000,
        discount: 20000,
      );

      expect(key1, isNot(equals(key2)));
      expect(manager.currentPendingKey, equals(key2));
    });

    test('Changing points used generates a new operation key', () {
      final key1 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_abc',
        pointsUsed: 5,
        couponCode: 'VOUCHER20K',
        surcharge: 5000,
        discount: 20000,
      );

      final key2 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_abc',
        pointsUsed: 10, // Changed points
        couponCode: 'VOUCHER20K',
        surcharge: 5000,
        discount: 20000,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('Changing customer id generates a new operation key', () {
      final key1 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_abc',
        pointsUsed: 0,
      );

      final key2 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
        customerId: 'cust_xyz', // Changed customer
        pointsUsed: 0,
      );

      expect(key1, isNot(equals(key2)));
    });

    test(
      'Changing payment method or surcharge generates a new operation key',
      () {
        final key1 = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          surcharge: 0,
        );

        final key2 = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'transfer', // Changed payment method
          surcharge: 0,
        );

        final key3 = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'transfer',
          surcharge: 10000, // Changed surcharge
        );

        expect(key1, isNot(equals(key2)));
        expect(key2, isNot(equals(key3)));
      },
    );

    test(
      'Negative points (-5) and zero (0) generate different operation keys without intent mutation',
      () {
        final keyNeg = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          pointsUsed: -5,
        );

        final keyZero = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          pointsUsed: 0,
        );

        expect(keyNeg, isNot(equals(keyZero)));
      },
    );

    test(
      'Authoritative quote changes produce a new operation key for subsequent confirmation',
      () {
        final keyInitial = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          discount: 20000,
        );

        // Server returns authoritative quote with discount = 18000
        final authoritativeQuote = AuthoritativeQuote.fromMap({
          'authoritative_subtotal': 170000,
          'authoritative_discount': 18000,
          'authoritative_points_discount': 0,
          'authoritative_coupon_discount': 18000,
          'authoritative_surcharge': 5000,
          'authoritative_total': 157000,
        });

        expect(authoritativeQuote.subtotal, equals(170000.0));
        expect(authoritativeQuote.discount, equals(18000.0));
        expect(authoritativeQuote.total, equals(157000.0));

        final keyConfirmed = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          discount: authoritativeQuote.discount,
          surcharge: authoritativeQuote.surcharge,
        );

        expect(keyConfirmed, isNot(equals(keyInitial)));

        // Retry with same authoritative quote preserves the confirmed key
        final keyRetry = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          discount: authoritativeQuote.discount,
          surcharge: authoritativeQuote.surcharge,
        );
        expect(keyRetry, equals(keyConfirmed));

        // After successful payment, clearing state resets pending key
        manager.clear();
        expect(manager.hasPendingOperation, isFalse);
      },
    );

    test(
      'Non-finite money values (NaN, Infinity, -Infinity) are rejected with ArgumentError and preserve pending state',
      () {
        // 1. Direct normalizeMoney validation
        expect(
          () => SettlementOperationManager.normalizeMoney(double.nan),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => SettlementOperationManager.normalizeMoney(double.infinity),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => SettlementOperationManager.normalizeMoney(
            double.negativeInfinity,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Valid finite numbers are rounded to integer VNĐ
        expect(
          SettlementOperationManager.normalizeMoney(15000.4),
          equals(15000),
        );
        expect(
          SettlementOperationManager.normalizeMoney(15000.6),
          equals(15001),
        );

        // 2. Setting up a clean initial state
        final initialKey = manager.getOrCreateKey(
          sessionId: 'sess_123',
          paymentMethod: 'cash',
          surcharge: 0,
          discount: 0,
        );
        final initialFp = manager.currentPendingFingerprint;

        // 3. Passing NaN/Infinity to getOrCreateKey must throw and NOT modify pending state
        expect(
          () => manager.getOrCreateKey(
            sessionId: 'sess_123',
            paymentMethod: 'cash',
            surcharge: double.nan,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(manager.currentPendingKey, equals(initialKey));
        expect(manager.currentPendingFingerprint, equals(initialFp));

        expect(
          () => manager.getOrCreateKey(
            sessionId: 'sess_123',
            paymentMethod: 'cash',
            discount: double.infinity,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(manager.currentPendingKey, equals(initialKey));
        expect(manager.currentPendingFingerprint, equals(initialFp));
      },
    );

    test(
      'SettlementQuoteHelper computes correct contract totals without double discount deduction',
      () {
        // Case 1: Initial checkout presentation
        // Subtotal = 170.000, Discount = 20.000, Surcharge = 5.000
        const subtotal = 170000.0;
        const discount = 20000.0;
        const surcharge = 5000.0;

        final amountBeforeSurcharge = (subtotal - discount).clamp(
          0.0,
          double.infinity,
        );
        expect(amountBeforeSurcharge, equals(150000.0));

        final oldPayableTotal = SettlementQuoteHelper.computeOldPayableTotal(
          amountBeforeSurcharge: amountBeforeSurcharge,
          surcharge: surcharge,
        );
        // Correct total is 155.000, NOT 135.000 (which occurred when discount was subtracted twice)
        expect(oldPayableTotal, equals(155000.0));

        // Case 2: Authoritative quote confirmation
        // Server returns authoritative quote: Subtotal = 170.000, Discount = 18.000, Surcharge = 5.000, Total = 157.000
        final authoritativeQuote = AuthoritativeQuote.fromMap({
          'authoritative_subtotal': 170000,
          'authoritative_discount': 18000,
          'authoritative_points_discount': 0,
          'authoritative_coupon_discount': 18000,
          'authoritative_surcharge': 5000,
          'authoritative_total': 157000,
        });

        final confirmedAmountBeforeSurcharge =
            SettlementQuoteHelper.computeConfirmedAmountBeforeSurcharge(
              quoteTotal: authoritativeQuote.total,
              quoteSurcharge: authoritativeQuote.surcharge,
            );
        expect(confirmedAmountBeforeSurcharge, equals(152000.0));

        final confirmedPayableTotal =
            SettlementQuoteHelper.computeOldPayableTotal(
              amountBeforeSurcharge: confirmedAmountBeforeSurcharge,
              surcharge: authoritativeQuote.surcharge,
            );
        expect(confirmedPayableTotal, equals(157000.0));
      },
    );

    test('Calling clear resets pending operation state completely', () {
      final key1 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
      );
      expect(manager.hasPendingOperation, isTrue);

      manager.clear();
      expect(manager.hasPendingOperation, isFalse);
      expect(manager.currentPendingKey, isNull);
      expect(manager.currentPendingFingerprint, isNull);

      final key2 = manager.getOrCreateKey(
        sessionId: 'sess_123',
        paymentMethod: 'cash',
      );
      expect(key1, isNot(equals(key2)));
    });
  });
}
