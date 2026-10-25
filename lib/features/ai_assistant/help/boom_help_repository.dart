// lib/features/ai_assistant/help/boom_help_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Nạp bộ hướng dẫn cho Boom: bản đóng gói trong app (assets/boom_help/huong_dan.json,
// tạo bằng tool/xuat_huong_dan_boom.dart) + bản mới hơn trên máy chủ (bảng boom_help_packs,
// chỉ quản trị ghi) nếu có — sửa bài không cần phát hành app. Bản máy chủ hỏng / lọt tên
// kỹ thuật → bỏ qua, dùng bản đóng gói. Máy chủ chưa có bảng / mất mạng → dùng bản đóng gói.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'help_search.dart';
import 'huong_dan_parser.dart';

const kBoomHelpAsset = 'assets/boom_help/huong_dan.json';
const kBoomHelpMinChunks = 50; // bộ nhỏ bất thường → coi là hỏng

class HelpPack {
  final int version;
  final List<HelpChunk> chunks;
  const HelpPack(this.version, this.chunks);

  /// null nếu sai cấu trúc, quá ít đoạn hoặc lọt tên kỹ thuật.
  static HelpPack? tryParse(Object? raw) {
    try {
      final m = (raw is String ? jsonDecode(raw) : raw) as Map;
      final version = (m['version'] as num).toInt();
      final chunks = [
        for (final c in m['chunks'] as List)
          HelpChunk.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
      if (chunks.length < kBoomHelpMinChunks || chunks.length > 3000) {
        return null;
      }
      final ids = <String>{};
      for (final c in chunks) {
        if (!ids.add(c.id) ||
            c.title.trim().isEmpty ||
            c.text.trim().isEmpty ||
            c.text.length > 8000) {
          return null;
        }
      }
      if (lintChunks(chunks).isNotEmpty) return null;
      return HelpPack(version, chunks);
    } catch (_) {
      return null;
    }
  }
}

class BoomHelpRepository {
  final AssetBundle bundle;
  final SupabaseClient? client;
  BoomHelpRepository({AssetBundle? bundle, this.client})
    : bundle = bundle ?? rootBundle;

  Future<HelpIndex?> load() async {
    HelpPack? best;
    try {
      best = HelpPack.tryParse(await bundle.loadString(kBoomHelpAsset));
    } catch (_) {}
    final sb = client;
    if (sb != null) {
      try {
        final rows = await sb
            .from('boom_help_packs')
            .select('version, content')
            .gt('version', best?.version ?? 0)
            .order('version', ascending: false)
            .limit(1)
            .timeout(const Duration(seconds: 5));
        if (rows.isNotEmpty) {
          final pack = HelpPack.tryParse(rows.first['content']);
          if (pack != null && pack.version > (best?.version ?? 0)) best = pack;
        }
      } catch (_) {
        // máy chủ chưa có bảng / mất mạng → giữ bản đóng gói
      }
    }
    return best == null ? null : HelpIndex(best.chunks, version: best.version);
  }
}

/// Nạp một lần mỗi lần mở app (giữ trong bộ nhớ).
final boomHelpIndexProvider = FutureProvider<HelpIndex?>((ref) async {
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {}
  return BoomHelpRepository(client: client).load();
});
