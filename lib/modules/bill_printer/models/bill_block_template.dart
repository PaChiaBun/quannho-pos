// lib/modules/bill_printer/models/bill_block_template.dart
// Danh sách blocks — lưu/load từ SharedPreferences dưới dạng JSON

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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

  // ── Lưu vào SharedPreferences ──────────────────────────────────────────────
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'paper':  paperSize,
      'blocks': blocks.map((b) => b.toJson()).toList(),
    });
    await prefs.setString(_kPrefsKey, json);
    debugPrint('[BillTemplate] saved ${blocks.length} blocks');
  }

  // ── Tải từ SharedPreferences ───────────────────────────────────────────────
  static Future<BillBlockTemplate> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final data   = jsonDecode(raw) as Map<String, dynamic>;
        final paper  = data['paper'] as String? ?? '80mm';
        final bList  = (data['blocks'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(BillBlock.fromJson)
            .toList();
        if (bList.isNotEmpty) {
          return BillBlockTemplate(blocks: bList, paperSize: paper);
        }
      }
    } catch (e) {
      debugPrint('[BillTemplate] load error: $e');
    }
    // Trả về template mặc định
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
