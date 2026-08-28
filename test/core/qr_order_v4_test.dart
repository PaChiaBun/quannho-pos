import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/qr_order/models/qr_order_model.dart';
import 'package:quannho_pos/modules/qr_order/screens/customer_qr_order_screen.dart';
import 'package:quannho_pos/modules/qr_order/widgets/qr_scanner_dialog.dart';
import 'package:quannho_pos/modules/qr_order/services/settlement_operation_manager.dart';

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

    test(
      'QrRequestModel accurately tracks V4 status machine & paymentMode',
      () {
        final req = QrRequestModel(
          id: 'req_001',
          storeId: 'store_001',
          channelId: 'ch_001',
          type: 'TABLE_SHARED',
          tableHint: 'Bàn 05',
          assignedTableId: 'tbl_005',
          assignedTableName: 'Bàn 05 (Tầng 1)',
          trackingToken: 'TRK_999',
          status: 'customer_submitted',
          paymentStatus: 'unpaid',
          paymentMode: 'CASHIER_CONFIRM',
          totalAmount: 120000,
          version: 1,
          createdAt: DateTime(2026, 8, 27, 10, 0),
          items: [
            const QrRequestItemModel(
              id: 'it_001',
              requestId: 'req_001',
              productId: 'prod_1',
              productName: 'Cơm Rang Dưa Bò',
              unitPrice: 60000,
              quantity: 2,
              subtotal: 120000,
              modifiersJson: [
                {
                  'id': 'top_1',
                  'name': 'Trứng Ốp La',
                  'price': 10000,
                  'quantity': 1,
                },
              ],
            ),
          ],
        );

        expect(req.isTable, isTrue);
        expect(req.isCounter, isFalse);
        expect(req.isSubmitted, isTrue);
        expect(req.isSentKitchen, isFalse);
        expect(req.paymentMode, equals('CASHIER_CONFIRM'));
        expect(req.items.first.modifiersJson.length, equals(1));
        expect(req.displayTitle, equals('Bàn 05 (Tầng 1)'));

        final serialized = req.toMap();
        final deserialized = QrRequestModel.fromMap(serialized);
        expect(deserialized.id, equals(req.id));
        expect(deserialized.totalAmount, equals(120000));
        expect(deserialized.paymentMode, equals('CASHIER_CONFIRM'));
        expect(deserialized.items.length, equals(1));
        expect(
          deserialized.items.first.modifiersJson.first['name'],
          equals('Trứng Ốp La'),
        );
      },
    );

    test('QrRequestModel formatting for COUNTER_TAKEAWAY pickup codes', () {
      final counterReq1 = QrRequestModel(
        id: 'c_01',
        storeId: 's_01',
        channelId: 'ch_c1',
        type: 'COUNTER_TAKEAWAY',
        pickupCode: '#Q07',
        trackingToken: 'TRK_C1',
        status: 'claimed',
        totalAmount: 45000,
        createdAt: DateTime.now(),
      );
      expect(counterReq1.displayPickupCode, equals('#Q07'));
      expect(counterReq1.displayTitle, equals('QUẦY THU NGÂN — #Q07'));

      final counterReq2 = QrRequestModel(
        id: 'c_02',
        storeId: 's_01',
        channelId: 'ch_c1',
        type: 'COUNTER_TAKEAWAY',
        pickupCode: '15',
        trackingToken: 'TRK_C2',
        status: 'claimed',
        totalAmount: 45000,
        createdAt: DateTime.now(),
      );
      expect(counterReq2.displayPickupCode, equals('#15'));
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
    test(
      'QrScannerDialog.extractValidHandoffToken extracts correctly from all token formats',
      () {
        // 1. Raw token with QRN_ prefix
        expect(
          QrScannerDialog.extractValidHandoffToken(
            'QRN_A1B2C3D4E5F6071829384756AABBCCDD',
          ),
          equals('QRN_A1B2C3D4E5F6071829384756AABBCCDD'),
        );

        // 2. URL with ?code= query param
        expect(
          QrScannerDialog.extractValidHandoffToken(
            'https://quannho.lpm.vn/pos/qr-handoff?code=QRN_99887766554433221100AABBCCDDEEFF',
          ),
          equals('QRN_99887766554433221100AABBCCDDEEFF'),
        );

        // 3. URL with ?t= query param
        expect(
          QrScannerDialog.extractValidHandoffToken(
            'https://quannho.lpm.vn/pos/goi-mon/?t=QRN_11223344556677889900AABBCCDDEEFF&store=xyz',
          ),
          equals('QRN_11223344556677889900AABBCCDDEEFF'),
        );

        // 4. Raw string containing QRN_ inside
        expect(
          QrScannerDialog.extractValidHandoffToken(
            'prefix_QRN_AABBCCDDEEFF00112233445566778899_suffix',
          ),
          equals('QRN_AABBCCDDEEFF00112233445566778899'),
        );

        // 5. Invalid string without QRN prefix or query param
        expect(
          QrScannerDialog.extractValidHandoffToken('invalid_random_string'),
          isNull,
        );
        expect(
          QrScannerDialog.extractValidHandoffToken('QRN_A1B2C3D4'),
          isNull,
        );
        expect(QrScannerDialog.extractValidHandoffToken(''), isNull);
      },
    );

    test(
      'QrUrlBuilder handles domain root, base path /pos, {code}, and trailing slashes correctly',
      () {
        // 1. Domain root
        expect(
          QrUrlBuilder.formatQrUrl('https://quannho.lpm.vn', 'TBL_12345'),
          equals('https://quannho.lpm.vn/goi-mon/?code=TBL_12345'),
        );

        // 2. Base path /pos preserved!
        expect(
          QrUrlBuilder.formatQrUrl('https://quannho.lpm.vn/pos', 'TBL_12345'),
          equals('https://quannho.lpm.vn/pos/goi-mon/?code=TBL_12345'),
        );

        // 3. Trailing slashes cleaned
        expect(
          QrUrlBuilder.formatQrUrl('https://quannho.lpm.vn/pos///', 'CTR_999'),
          equals('https://quannho.lpm.vn/pos/goi-mon/?code=CTR_999'),
        );

        // 4. Custom template with {code}
        expect(
          QrUrlBuilder.formatQrUrl(
            'https://quannho.lpm.vn/order/{code}',
            'TBL_ABC',
          ),
          equals('https://quannho.lpm.vn/order/TBL_ABC'),
        );

        // 5. Public URL validation rejects localhost and non-https
        expect(
          QrUrlBuilder.isValidPublicUrl('https://quannho.lpm.vn/pos'),
          isTrue,
        );
        expect(
          QrUrlBuilder.isValidPublicUrl('http://quannho.lpm.vn/pos'),
          isFalse,
        ); // non-https
        expect(
          QrUrlBuilder.isValidPublicUrl('https://localhost:8080'),
          isFalse,
        ); // localhost
        expect(
          QrUrlBuilder.isValidPublicUrl('https://127.0.0.1:3000'),
          isFalse,
        ); // 127.0.0.1
        expect(
          QrUrlBuilder.isValidPublicUrl('https://192.168.1.5'),
          isFalse,
        ); // LAN
      },
    );

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
          tableHint: 'B01',
          items: itemsA,
        );

        final hashB = CustomerQrOrderScreen.computeCanonicalPayloadHash(
          channelCode: 'TBL_01',
          tableHint: 'B01',
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
          tableHint: 'B01',
          items: itemsC,
        );
        expect(hashA, isNot(equals(hashC)));
      },
    );

    test('Simulate 100% Fail-Closed Permission Matrix for pos.checkout', () {
      bool hasCheckoutPermission({
        required String role,
        required bool isOwner,
        Map<String, dynamic>? appSettingsPerms,
      }) {
        // 1. Owner always allowed
        if (isOwner || role == 'owner') return true;

        // 2. Strict Fail-Closed: only allowed if app_settings action_perms_<role> contains 'pos.checkout'
        if (appSettingsPerms != null &&
            appSettingsPerms.containsKey('action_perms_$role')) {
          final val = appSettingsPerms['action_perms_$role'];
          if (val is List) {
            return val.contains('pos.checkout');
          }
        }

        // NO fallback based on role name!
        return false;
      }

      // Owner always allowed
      expect(hasCheckoutPermission(role: 'owner', isOwner: true), isTrue);

      // Cashier without explicit app_settings config -> DENIED (Fail-closed)
      expect(hasCheckoutPermission(role: 'cashier', isOwner: false), isFalse);

      // Manager without explicit app_settings config -> DENIED (Fail-closed)
      expect(hasCheckoutPermission(role: 'manager', isOwner: false), isFalse);

      // Waiter without config -> DENIED
      expect(hasCheckoutPermission(role: 'waiter', isOwner: false), isFalse);

      // Cashier granted pos.checkout in app_settings -> ALLOWED
      expect(
        hasCheckoutPermission(
          role: 'cashier',
          isOwner: false,
          appSettingsPerms: {
            'action_perms_cashier': ['pos.checkout', 'pos.view_history'],
          },
        ),
        isTrue,
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

      // Cashier revoked pos.checkout in app_settings -> DENIED
      expect(
        hasCheckoutPermission(
          role: 'cashier',
          isOwner: false,
          appSettingsPerms: {
            'action_perms_cashier': ['pos.view_history'],
          },
        ),
        isFalse,
      );
    });

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

    test(
      'Static Schema Contract Check: Migration adheres strictly to real production catalog',
      () {
        final migrationFile = File(
          'supabase/migrations/20260827_qr_order_v4.sql',
        );
        expect(migrationFile.existsSync(), isTrue);

        final sqlContent = migrationFile.readAsStringSync();

        // 1. order_items contract: must NOT contain total_price or created_at in insert list
        expect(sqlContent.contains('INSERT INTO public.order_items'), isTrue);
        expect(sqlContent.contains('total_price'), isFalse);

        // 2. finance_records contract: must NOT contain category or source or ref_id in insert
        expect(
          sqlContent.contains('INSERT INTO public.finance_records'),
          isTrue,
        );
        expect(sqlContent.contains('ref_id,'), isFalse);

        // 3. ban_sessions contract: must NOT contain checkin_at, created_at or 'serving'
        expect(sqlContent.contains('checkin_at'), isFalse);
        expect(sqlContent.contains("'serving'"), isFalse);
        expect(sqlContent.contains("status = 'open'"), isTrue);
        expect(sqlContent.contains('opened_at'), isTrue);

        // 4. kitchen_tickets contract: must NOT contain table_id
        final ktInsertMatch = RegExp(
          r'INSERT INTO public\.kitchen_tickets\s*\([^)]+\)',
        ).firstMatch(sqlContent);
        expect(ktInsertMatch, isNotNull);
        expect(ktInsertMatch!.group(0)!.contains('table_id'), isFalse);
        expect(ktInsertMatch.group(0)!.contains('session_id'), isTrue);

        // 5. kitchen_ticket_items contract: must contain legacy & new required columns
        final ktiInsertMatch = RegExp(
          r'INSERT INTO public\.kitchen_ticket_items\s*\([^)]+\)',
        ).firstMatch(sqlContent);
        expect(ktiInsertMatch, isNotNull);
        expect(ktiInsertMatch!.group(0)!.contains('free_note'), isTrue);
        expect(ktiInsertMatch.group(0)!.contains('kitchen_note'), isTrue);
        expect(ktiInsertMatch.group(0)!.contains('station_code'), isTrue);
        expect(ktiInsertMatch.group(0)!.contains('modifiers_json'), isTrue);

        // 6. Security grants: Explicit REVOKE ALL ON FUNCTION from PUBLIC, anon, authenticated
        expect(
          sqlContent.contains(
            'REVOKE ALL ON FUNCTION public.claim_qr_handoff_v4(text, uuid) FROM PUBLIC, anon, authenticated;',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'REVOKE ALL ON FUNCTION public.mark_qr_order_paid_v4(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'REVOKE ALL ON FUNCTION public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'REVOKE ALL ON FUNCTION public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) FROM PUBLIC, anon, authenticated;',
          ),
          isTrue,
        );

        // 7. Data structures: qr_payment_idempotency, qr_kitchen_idempotency, ban_session_orders, ban_session_order_items, payment_settlements
        expect(
          sqlContent.contains(
            'CREATE TABLE IF NOT EXISTS public.qr_payment_idempotency',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'CREATE TABLE IF NOT EXISTS public.qr_kitchen_idempotency',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'CREATE TABLE IF NOT EXISTS public.ban_session_orders',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'CREATE TABLE IF NOT EXISTS public.ban_session_order_items',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'CREATE TABLE IF NOT EXISTS public.payment_settlements',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'CONSTRAINT uq_qr_channels_code UNIQUE (channel_code)',
          ),
          isTrue,
        );

        // 8. reference_id type check: no text casting when inserting into stock_movements or finance_records
        expect(sqlContent.contains('v_order_id::text, is_auto'), isFalse);
        expect(sqlContent.contains('v_order_id::text, now()'), isFalse);
        expect(sqlContent.contains('v_settlement_id::text, is_auto'), isFalse);

        // 9. Atomic advisory locks
        expect(
          sqlContent.contains(
            "pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('settle_ban_session:' || p_idempotency_key))",
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            "pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('send_kitchen:' || p_idempotency_key))",
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            "pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('mark_qr_paid:' || p_idempotency_key))",
          ),
          isTrue,
        );

        // 10. Upgrade block idempotency for payment_settlements
        expect(
          sqlContent.contains(
            'ADD COLUMN IF NOT EXISTS request_fingerprint text;',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'ADD COLUMN IF NOT EXISTS points_discount numeric NOT NULL DEFAULT 0;',
          ),
          isTrue,
        );
        expect(
          sqlContent.contains(
            'ADD COLUMN IF NOT EXISTS coupon_discount numeric NOT NULL DEFAULT 0;',
          ),
          isTrue,
        );

        // 11. PostgREST named RPC arguments must match the SQL signature exactly.
        final repositoryFile = File(
          'lib/modules/qr_order/repository/qr_order_repository.dart',
        );
        expect(repositoryFile.existsSync(), isTrue);
        final repositoryContent = repositoryFile.readAsStringSync();
        expect(
          sqlContent.contains(
            'CREATE OR REPLACE FUNCTION public.claim_qr_handoff_v4(\n  p_token text,',
          ),
          isTrue,
        );
        expect(
          repositoryContent.contains("'p_token': rawHandoffToken"),
          isTrue,
        );
        expect(repositoryContent.contains('p_raw_handoff_token'), isFalse);
        expect(
          repositoryContent.contains('channel:qr_channels(payment_mode)'),
          isTrue,
          reason: 'Active request pipeline must preserve channel payment_mode',
        );

        String rpcDefinition(String functionName) {
          final start = sqlContent.indexOf(
            'CREATE OR REPLACE FUNCTION public.$functionName(',
          );
          expect(start, isNonNegative, reason: 'Missing RPC $functionName');
          final end = sqlContent.indexOf('\n\$\$;', start);
          expect(
            end,
            greaterThan(start),
            reason: 'Malformed RPC $functionName',
          );
          return sqlContent.substring(start, end);
        }

        // 12. Every request-detail response must preserve the channel payment
        // mode. Otherwise CASHIER_CONFIRM silently falls back to PAY_BEFORE_KITCHEN.
        for (final rpcName in [
          'get_qr_request_status_v4',
          'claim_qr_handoff_v4',
          'get_qr_request_detail_v4',
        ]) {
          final rpcSql = rpcDefinition(rpcName);
          expect(
            rpcSql.contains("'payment_mode'"),
            isTrue,
            reason: '$rpcName must return payment_mode',
          );
          expect(
            rpcSql.contains('v_table.label'),
            isFalse,
            reason: '$rpcName must be safe when no table has been assigned',
          );
        }

        // 13. Channel-info payload must satisfy QrChannelModel without defaults.
        final channelInfoSql = rpcDefinition('get_qr_channel_info_v4');
        for (final field in ["'id'", "'name'", "'created_at'"]) {
          expect(
            channelInfoSql.contains(field),
            isTrue,
            reason: 'get_qr_channel_info_v4 must return $field',
          );
        }

        // 14. COUNTER is always paid at the cashier before kitchen dispatch,
        // regardless of the legacy payment_mode value.
        final sendKitchenSql = rpcDefinition('send_qr_order_to_kitchen_v4');
        expect(
          sendKitchenSql.contains("IF v_req.payment_status <> 'paid' THEN"),
          isTrue,
        );
        expect(
          sendKitchenSql.contains(
            "v_channel.payment_mode = 'PAY_BEFORE_KITCHEN' AND",
          ),
          isFalse,
        );

        // 15. Customer never enters a table; staff assigns it after claim.
        final customerScreen = File(
          'lib/modules/qr_order/screens/customer_qr_order_screen.dart',
        ).readAsStringSync();
        expect(customerScreen.contains('_tableHintCtrl'), isFalse);
        expect(customerScreen.contains('tableHint: null'), isTrue);

        // 16. Opening settings is read-only for existing channel state and the
        // legacy per-table print tab is no longer exposed.
        final qrScreen = File(
          'lib/modules/qr_order/screens/qr_order_screen.dart',
        ).readAsStringSync();
        expect(qrScreen.contains('getChannelByType'), isTrue);
        expect(qrScreen.contains('BatchTablePrintTab'), isFalse);

        // 17. Table assignment is server-authoritative: only TABLE_SHARED,
        // only the staff member who claimed it, only before kitchen; retries
        // for the same table must be idempotent.
        final assignTableSql = rpcDefinition('assign_qr_order_table_v4');
        expect(
          assignTableSql.contains(
            "v_req.channel_type NOT IN ('TABLE_SHARED', 'table')",
          ),
          isTrue,
        );
        expect(
          assignTableSql.contains(
            'v_req.claimed_by_user_id IS DISTINCT FROM v_staff.member_user_id',
          ),
          isTrue,
        );
        expect(
          assignTableSql.contains(
            "v_req.status NOT IN ('claimed', 'staff_review', 'confirmed')",
          ),
          isTrue,
        );
        expect(assignTableSql.contains("'is_replay', true"), isTrue);
      },
    );

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
