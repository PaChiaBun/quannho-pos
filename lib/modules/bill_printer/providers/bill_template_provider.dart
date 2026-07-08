// lib/modules/bill_printer/providers/bill_template_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_block.dart';
import '../models/bill_block_template.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/store_auth_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final billTemplateProvider =
    AsyncNotifierProvider<BillTemplateNotifier, BillBlockTemplate>(
  BillTemplateNotifier.new,
);

class BillTemplateNotifier extends AsyncNotifier<BillBlockTemplate> {
  @override
  Future<BillBlockTemplate> build() => BillBlockTemplate.load();

  BillBlockTemplate? get _tpl => state.value;

  // ── Reorder blocks (drag & drop) ──────────────────────────────────────────
  void reorder(int oldIndex, int newIndex) {
    final tpl = _tpl;
    if (tpl == null) return;
    final list = List<BillBlock>.from(tpl.blocks);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = AsyncData(tpl.copyWith(blocks: list));
  }

  // ── Thêm block mới ────────────────────────────────────────────────────────
  void addBlock(BillBlockType type) {
    final tpl = _tpl;
    if (tpl == null) return;
    final list = List<BillBlock>.from(tpl.blocks);
    if (!type.isMultiAllowed && !type.isLocked) {
      if (list.any((b) => b.type == type)) return;
    }
    list.add(BillBlock.create(type));
    state = AsyncData(tpl.copyWith(blocks: list));
  }

  // ── Xóa block ─────────────────────────────────────────────────────────────
  void removeBlock(String id) {
    final tpl = _tpl;
    if (tpl == null) return;
    final list = List<BillBlock>.from(tpl.blocks)
      ..removeWhere((b) => b.id == id && !b.locked);
    state = AsyncData(tpl.copyWith(blocks: list));
  }

  // ── Cập nhật config của block ─────────────────────────────────────────────
  void updateBlock(String id, Map<String, dynamic> newConfig) {
    final tpl = _tpl;
    if (tpl == null) return;
    final list = tpl.blocks.map((b) {
      if (b.id == id) return b.copyWith(config: {...b.config, ...newConfig});
      return b;
    }).toList();
    state = AsyncData(tpl.copyWith(blocks: list));
  }

  // ── Toggle enable/disable block ───────────────────────────────────────────
  void toggleBlock(String id) {
    final tpl = _tpl;
    if (tpl == null) return;
    final list = tpl.blocks.map((b) {
      if (b.id == id && !b.locked) return b.copyWith(enabled: !b.enabled);
      return b;
    }).toList();
    state = AsyncData(tpl.copyWith(blocks: list));
  }

  // ── Đổi khổ giấy ─────────────────────────────────────────────────────────
  void setPaperSize(String size) {
    final tpl = _tpl;
    if (tpl == null) return;
    state = AsyncData(tpl.copyWith(paperSize: size));
  }

  // ── Lưu ──────────────────────────────────────────────────────────────────
  Future<void> save() async {
    final tpl = _tpl;
    if (tpl == null) return;
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    await tpl.save(storeId: storeId);
  }

  // ── Reset về default ──────────────────────────────────────────────────────
  Future<void> reset() async {
    final tpl = BillBlockTemplate.defaultTemplate();
    state = AsyncData(tpl);
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    await tpl.save(storeId: storeId);
  }

  // ── Áp dụng mẫu dựng sẵn từ Gallery ─────────────────────────────────────
  Future<void> applyPreset(BillBlockTemplate preset) async {
    state = AsyncData(preset);
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    await preset.save(storeId: storeId);
  }
}
