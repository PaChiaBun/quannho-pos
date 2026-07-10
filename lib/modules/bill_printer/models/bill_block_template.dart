// lib/modules/bill_printer/models/bill_block_template.dart
// Danh sách blocks — lưu/load từ SharedPreferences dưới dạng JSON

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import 'bill_block.dart';

const _kPrefsKey = 'bill_blocks_v2';

// ─── Template ─────────────────────────────────────────────────────────────────
class BillBlockTemplate {
  final List<BillBlock> blocks;
  final String paperSize; // '58mm' | '80mm' | 'a4'

  const BillBlockTemplate({
    required this.blocks,
    this.paperSize = '80mm',
  });

  BillBlockTemplate copyWith({List<BillBlock>? blocks, String? paperSize}) =>
      BillBlockTemplate(
        blocks:    blocks    ?? this.blocks,
        paperSize: paperSize ?? this.paperSize,
      );

  // ── Lưu vào SharedPreferences & Supabase ──────────────────────────────────────
  Future<void> save({String? storeId, String stationKey = 'cashier'}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'paper':  paperSize,
      'blocks': blocks.map((b) => b.toJson()).toList(),
    });
    final prefKey = '${_kPrefsKey}_$stationKey';
    await prefs.setString(prefKey, json);
    debugPrint('[BillTemplate] saved ${blocks.length} blocks for station $stationKey');

    try {
      final resolvedStoreId = storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
      if (resolvedStoreId != null) {
        // Đảm bảo x-store-id tồn tại trong Header REST cho RLS
        Supabase.instance.client.rest.headers['x-store-id'] = resolvedStoreId;

        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': resolvedStoreId,
          'key': 'qn_bill_template_$stationKey',
          'value': json,
        }, onConflict: 'store_id,key');
      } else {
        debugPrint('[BillTemplate] save failed: storeId is null!');
      }
    } catch (e) {
      debugPrint('[BillTemplate] save Supabase error: $e');
    }
  }

  // ── Tải từ SharedPreferences & Supabase ───────────────────────────────────────
  static Future<BillBlockTemplate> load({String stationKey = 'cashier'}) async {
    String? raw;
    final prefKey = '${_kPrefsKey}_$stationKey';
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(prefKey);
    } catch (_) {}

    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId != null) {
        // Đảm bảo x-store-id tồn tại trong Header REST cho RLS
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        final res = await Supabase.instance.client
            .from('app_settings')
            .select('value')
            .eq('store_id', storeId)
            .eq('key', 'qn_bill_template_$stationKey')
            .maybeSingle();
        if (res != null && res['value'] != null) {
          final cloudJson = res['value'] as String;
          if (cloudJson != raw) {
            raw = cloudJson;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(prefKey, cloudJson);
          }
        }
      }
    } catch (e) {
      debugPrint('[BillTemplate] load Supabase error: $e');
    }

    if (raw != null) {
      try {
        final data   = jsonDecode(raw) as Map<String, dynamic>;
        final paper  = data['paper'] as String? ?? '80mm';
        final bList  = (data['blocks'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(BillBlock.fromJson)
            .toList();
        if (bList.isNotEmpty) {
          return BillBlockTemplate(blocks: bList, paperSize: paper);
        }
      } catch (e) {
        debugPrint('[BillTemplate] parse error: $e');
      }
    }
    // Trả về template mặc định cho từng trạm
    return BillBlockTemplate.defaultTemplateForStation(stationKey);
  }

  // ── Template mặc định cho từng trạm ────────────────────────────────────────
  factory BillBlockTemplate.defaultTemplateForStation(String stationKey) {
    const uuid = Uuid();
    if (stationKey == 'bepNong' || stationKey == 'bepBar') {
      return BillBlockTemplate(
        paperSize: '80mm',
        blocks: [
          BillBlock(
            id: uuid.v4(), type: BillBlockType.tableInfo, enabled: true,
            config: {'showTable': true, 'label': 'PHIẾU BẾP:', 'fontSize': 14},
          ),
          BillBlock(
            id: uuid.v4(), type: BillBlockType.orderInfo, enabled: true,
            config: {'showOrderNo': true, 'showDate': true, 'showCashier': false, 'fontSize': 10},
          ),
          BillBlock(
            id: uuid.v4(), type: BillBlockType.divider, enabled: true,
            config: {'style': 'solid', 'thickness': 1.0},
          ),
          BillBlock(
            id: uuid.v4(), type: BillBlockType.itemsList, enabled: true,
            config: {'showPrice': false, 'showQty': true, 'showTotal': false, 'fontSize': 12},
          ),
          BillBlock(
            id: uuid.v4(), type: BillBlockType.divider, enabled: true,
            config: {'style': 'solid', 'thickness': 1.0},
          ),
        ],
      );
    }
    return BillBlockTemplate.defaultTemplate();
  }

  // ── Template mặc định ──────────────────────────────────────────────────────
  factory BillBlockTemplate.defaultTemplate() {
    const uuid = Uuid();
    return BillBlockTemplate(
      paperSize: '80mm',
      blocks: [
        BillBlock(
          id: uuid.v4(), type: BillBlockType.shopHeader, enabled: true,
          config: {'shopName': '', 'tagline': '', 'fontSize': 16, 'bold': true, 'align': 'center'},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.shopAddress, enabled: true,
          config: {'address': '', 'fontSize': 10, 'align': 'center'},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.shopPhone, enabled: true,
          config: {'phone': '', 'fontSize': 10, 'align': 'center', 'label': 'ĐT:'},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.divider, enabled: true,
          config: {'style': 'solid', 'thickness': 1.0},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.orderInfo, enabled: true,
          config: {'showOrderNo': true, 'showDate': true, 'showCashier': true, 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.tableInfo, enabled: true,
          config: {'showTable': true, 'label': 'Bàn:', 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.divider, enabled: true,
          config: {'style': 'dashed', 'thickness': 1.0},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.itemsList, enabled: true,
          config: {'showPrice': true, 'showQty': true, 'showTotal': true, 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.divider, enabled: true,
          config: {'style': 'solid', 'thickness': 1.0},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.totals, enabled: true,
          config: {'showSubtotal': true, 'showDiscount': true, 'showTax': false,
                   'boldTotal': true, 'totalFontSize': 14, 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.paymentMethod, enabled: true,
          config: {'label': 'Thanh toán:', 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.loyaltyPoints, enabled: true,
          config: {'showEarned': true, 'showBalance': true, 'borderBox': true, 'fontSize': 10},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.divider, enabled: true,
          config: {'style': 'solid', 'thickness': 1.0},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.footer, enabled: true,
          config: {'text': 'Cảm ơn quý khách!', 'subText': 'Hẹn gặp lại 🙏',
                   'fontSize': 12, 'align': 'center', 'bold': true},
        ),
        BillBlock(
          id: uuid.v4(), type: BillBlockType.appBranding, enabled: true,
          config: {'fontSize': 8, 'align': 'center'},
        ),
      ],
    );
  }
}
