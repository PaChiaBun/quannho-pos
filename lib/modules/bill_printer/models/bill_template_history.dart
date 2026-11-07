// lib/modules/bill_printer/models/bill_template_history.dart
// Lưu lịch sử các bản thiết kế hoá đơn đã lưu — tối đa 10 bản
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/store_auth_service.dart';
import 'bill_block_template.dart';
import 'bill_block.dart';

const _kHistoryKey = 'bill_template_history_v1';
const _kMaxHistory = 10;

class BillTemplateSnapshot {
  final String id;          // unique: timestamp ISO
  final String label;       // "Bản lưu 14/05 15:30"
  final String paperSize;
  final int blockCount;
  final DateTime savedAt;
  final BillBlockTemplate template;

  const BillTemplateSnapshot({
    required this.id,
    required this.label,
    required this.paperSize,
    required this.blockCount,
    required this.savedAt,
    required this.template,
  });

  Map<String, dynamic> toJson() => {
    'id':         id,
    'label':      label,
    'paperSize':  paperSize,
    'blockCount': blockCount,
    'savedAt':    savedAt.toIso8601String(),
    'paper':      template.paperSize,
    'blocks':     template.blocks.map((b) => b.toJson()).toList(),
  };

  factory BillTemplateSnapshot.fromJson(Map<String, dynamic> j) {
    final blocks = (j['blocks'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(BillBlock.fromJson)
        .toList();
    return BillTemplateSnapshot(
      id:         j['id'] as String,
      label:      j['label'] as String,
      paperSize:  j['paperSize'] as String? ?? '80mm',
      blockCount: j['blockCount'] as int? ?? blocks.length,
      savedAt:    DateTime.parse(j['savedAt'] as String),
      template:   BillBlockTemplate(
        paperSize: j['paper'] as String? ?? '80mm',
        blocks: blocks,
      ),
    );
  }
}

// ─── History Service ──────────────────────────────────────────────────────────
class BillTemplateHistoryService {
  /// Khoá lưu theo từng quán: lịch sử mẫu của quán này không hiện ở quán khác trên cùng máy.
  /// Chưa xác định được quán thì trả null (không đọc/ghi) để tránh lẫn dữ liệu.
  static Future<String?> _scopedKey() async {
    try {
      final storeId = (await StoreAuthService.getStoreInfo())['store_id'];
      if (storeId == null || storeId.isEmpty) return null;
      return '${_kHistoryKey}__$storeId';
    } catch (_) {
      return null;
    }
  }

  static Future<List<BillTemplateSnapshot>> load() async {
    try {
      final key = await _scopedKey();
      if (key == null) return [];
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(BillTemplateSnapshot.fromJson)
          .toList();
      // Sắp xếp mới nhất trước
      list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return list;
    } catch (e) {
      debugPrint('[BillHistory] load error: $e');
      return [];
    }
  }

  /// Thêm snapshot mới, giữ tối đa [_kMaxHistory] bản
  static Future<void> push(BillBlockTemplate tpl, {String? customLabel}) async {
    try {
      final now = DateTime.now();
      final label = customLabel ??
          'Bản lưu ${_pad(now.day)}/${_pad(now.month)} ${_pad(now.hour)}:${_pad(now.minute)}';

      final snapshot = BillTemplateSnapshot(
        id:         now.toIso8601String(),
        label:      label,
        paperSize:  tpl.paperSize,
        blockCount: tpl.blocks.where((b) => b.enabled).length,
        savedAt:    now,
        template:   tpl,
      );

      final existing = await load();
      // Tránh lưu trùng trong vòng 10 giây
      if (existing.isNotEmpty &&
          now.difference(existing.first.savedAt).inSeconds < 10) {
        return;
      }

      final updated = [snapshot, ...existing];
      if (updated.length > _kMaxHistory) updated.removeLast();

      final key = await _scopedKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          key, jsonEncode(updated.map((s) => s.toJson()).toList()));
      debugPrint('[BillHistory] saved snapshot "$label"');
    } catch (e) {
      debugPrint('[BillHistory] push error: $e');
    }
  }

  static Future<void> delete(String id) async {
    try {
      final list = await load();
      list.removeWhere((s) => s.id == id);
      final key = await _scopedKey();
      if (key == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          key, jsonEncode(list.map((s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('[BillHistory] delete error: $e');
    }
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');
}
