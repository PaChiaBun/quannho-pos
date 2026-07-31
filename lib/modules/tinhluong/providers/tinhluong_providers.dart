// lib/modules/tinhluong/providers/tinhluong_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_provider.dart';
import '../repository/tinhluong_repository.dart';

// Tường minh: dùng StateProvider từ flutter_riverpod
// ignore_for_file: unused_import

// ─── PERIODS ─────────────────────────────────────────────────────────────────

final payrollPeriodsProvider =
    FutureProvider.autoDispose<List<PayrollPeriodModel>>((ref) {
      return TinhLuongRepository.fetchPeriods();
    });

// ─── RECORDS (theo period) ───────────────────────────────────────────────────
// ‼️ KHÔNG dùng autoDispose: khi navigate vào RecordDetailScreen,
// PeriodDetailScreen ngừng watch → provider bị dispose → invalidate từ child
// không có tác dụng (provider đã chết). Giữ alive để invalidate hoạt động đúng.

final payrollRecordsProvider =
    FutureProvider.family<List<PayrollRecordModel>, String>((ref, periodId) {
      return TinhLuongRepository.fetchRecords(periodId);
    });

final payrollReadinessProvider =
    FutureProvider.family<PayrollReadiness, PayrollPeriodModel>((
      ref,
      period,
    ) async {
      final session = ref.watch(sessionProvider);
      final storeId = session?.storeId;
      if (storeId == null || storeId.isEmpty) {
        throw Exception('Không có storeId');
      }
      return TinhLuongRepository.evaluateReadiness(
        storeId: storeId,
        fromDateStr: period.fromDate,
        toDateStr: period.toDate,
      );
    });

// ─── ITEMS (theo record) ─────────────────────────────────────────────────────

final payrollItemsProvider = FutureProvider.autoDispose
    .family<List<PayrollItemModel>, String>((ref, recordId) {
      return TinhLuongRepository.fetchItems(recordId);
    });

// Note: dùng local StatefulWidget state thay vì StateProvider để tránh dependency
