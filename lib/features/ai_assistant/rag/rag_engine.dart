// lib/features/ai_assistant/rag/rag_engine.dart
// ─────────────────────────────────────────────────────────────────────────────
// RAG / FAQ Knowledge Engine — Quản lý Index & Truy vấn Tài liệu Nghiệp vụ Quán Nhỏ
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:crypto/crypto.dart';

class RagChunk {
  final String id;
  final String sourcePath;
  final String heading;
  final String module;
  final String content;
  final String checksum;
  final DateTime updatedAt;

  RagChunk({
    required this.id,
    required this.sourcePath,
    required this.heading,
    required this.module,
    required this.content,
    required this.checksum,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

class RagSearchResult {
  final RagChunk chunk;
  final double score;

  RagSearchResult({required this.chunk, required this.score});
}

class RagEngine {
  static final List<RagChunk> _index = [];
  static const double kRelevanceThreshold = 0.40;

  /// Nạp danh sách các tài liệu hướng dẫn nghiệp vụ Quán Nhỏ
  static void loadKnowledgeBase(List<Map<String, String>> docs) {
    _index.clear();
    for (final doc in docs) {
      final path = doc['path'] ?? 'docs/general.md';
      final module = doc['module'] ?? 'general';
      final rawContent = doc['content'] ?? '';

      // Tách chunk theo Heading (Markdown # / ## / ###)
      final sections = rawContent.split(RegExp(r'\n(?=#{1,3}\s)'));
      for (int i = 0; i < sections.length; i++) {
        final section = sections[i].trim();
        if (section.isEmpty) continue;

        // Trích xuất heading
        final firstLine = section.split('\n').first;
        final heading = firstLine.replaceAll(RegExp(r'^#{1,3}\s*'), '').trim();

        // Lọc bỏ secret hoặc credentials nếu có
        final cleanContent = _sanitizeContent(section);

        final checksum = sha256.convert(utf8.encode(cleanContent)).toString();

        _index.add(RagChunk(
          id: '${module}_chunk_$i',
          sourcePath: path,
          heading: heading.isNotEmpty ? heading : module,
          module: module,
          content: cleanContent,
          checksum: checksum,
        ));
      }
    }
  }

  /// Lọc bỏ thông tin nhạy cảm trước khi index
  static String _sanitizeContent(String text) {
    var sanitized = text;
    sanitized = sanitized.replaceAll(RegExp(r'password\s*=\s*[^\s]+', caseSensitive: false), 'password=[REDACTED]');
    sanitized = sanitized.replaceAll(RegExp(r'secret\s*=\s*[^\s]+', caseSensitive: false), 'secret=[REDACTED]');
    sanitized = sanitized.replaceAll(RegExp(r'key\s*=\s*eyJ[^\s]+', caseSensitive: false), 'key=[REDACTED]');
    return sanitized;
  }

  /// Truy vấn RAG top-k tài liệu liên quan
  static List<RagSearchResult> query(String userQuery, {int topK = 3}) {
    if (_index.isEmpty) return [];

    final queryTerms = _tokenize(userQuery);
    if (queryTerms.isEmpty) return [];

    final List<RagSearchResult> results = [];

    for (final chunk in _index) {
      final chunkTerms = _tokenize('${chunk.heading} ${chunk.content}');
      if (chunkTerms.isEmpty) continue;

      int matchCount = 0;
      for (final term in queryTerms) {
        if (chunkTerms.contains(term)) {
          matchCount++;
        }
      }

      final score = matchCount / queryTerms.length;
      if (score >= kRelevanceThreshold) {
        results.add(RagSearchResult(chunk: chunk, score: score));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  static Set<String> _tokenize(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^\w\sàáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ]'), ' ');
    return clean.split(RegExp(r'\s+')).where((t) => t.length >= 2).toSet();
  }

  static int get totalChunks => _index.length;
}
