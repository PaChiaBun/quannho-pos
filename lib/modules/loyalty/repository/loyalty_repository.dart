import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  Stream<T> _robustStream<T>(
    String table,
    String columnFilter,
    String valueFilter,
    T Function(List<Map<String, dynamic>>) mapper,
  ) async* {
    Future<T> fetch() async {
      final rows = await _sb.from(table).select().eq(columnFilter, valueFilter);
      return mapper(rows);
    }

    // Initial fetch
    try {
      yield await fetch();
    } catch (e) {
      print('[RobustStream] Initial fetch err on $table: $e');
    }

    // Realtime connection with fallback to polling on async errors (e.g. RealtimeSubscribeException)
    while (true) {
      try {
        final stream = _sb.from(table).stream(primaryKey: ['id']).eq(columnFilter, valueFilter);
        await for (final rows in stream) {
          yield mapper(rows);
        }
      } catch (e) {
        print('[RobustStream] Realtime err on $table: $e. Falling back to poll 10s.');
        
        // Polling âm thầm 10 giây (chia làm 2 lần 5s) trước khi thử kết nối lại Realtime
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
        
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
      }
    }
  }

  Stream<List<LoyaltyCustomerModel>> watchTopCustomers({int limit = 20}) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'customers', 'store_id', storeId,
      (rows) {
        final sorted = rows
            .where((r) => r['is_deleted'] != true && (r['loyalty_pts'] as num? ?? 0) > 0)
            .map(LoyaltyCustomerModel.fromMap)
            .toList()
          ..sort((a, b) => b.loyaltyPts.compareTo(a.loyaltyPts));
        return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
      }
    );
  }

  Stream<List<LoyaltyCustomerModel>> watchCustomers({bool withPoints = false}) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'customers', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_deleted'] != true &&
              (!withPoints || (r['loyalty_pts'] as num? ?? 0) > 0))
          .map(LoyaltyCustomerModel.fromMap)
          .toList()
        ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent))
    );
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Stream<List<LoyaltyTransactionModel>> watchTransactions(String customerId) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'loyalty_transactions', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['customer_id'] == customerId)
          .map(LoyaltyTransactionModel.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
    );
  }

  // ── Rewards ───────────────────────────────────────────────────────────────

  Stream<List<LoyaltyRewardModel>> watchRewards() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'loyalty_rewards', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_active'] == true)
          .map(LoyaltyRewardModel.fromMap)
          .toList()
        ..sort((a, b) => a.ptsRequired.compareTo(b.ptsRequired))
    );
  }

  Future<void> createReward({
    required String name,
    required double ptsRequired,
    double? discountAmount,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    await _sb.from('loyalty_rewards').insert({
      'id':              _uuid.v4(),
      'store_id':        storeId,
      'name':            name,
      'pts_required':    ptsRequired,
      'discount_amount': discountAmount,
      'is_active':       true,
    });
  }

  Future<void> deleteReward(String id) async {
    await _sb.from('loyalty_rewards').update({'is_active': false}).eq('id', id);
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> earnPoints({
    required String customerId,
    required double pts,
    required String orderId,
    String? storeId,
    String? note,
  }) async {
    if (pts <= 0) return;
    final sid = storeId ?? await _storeId();
    if (sid == null) return;
    final now = DateTime.now().toUtc().toIso8601String();

    // Ghi lịch sử điểm
    await _sb.from('loyalty_transactions').insert({
      'id':          _uuid.v4(),
      'store_id':    sid,
      'customer_id': customerId,
      'order_id':    orderId,
      'pts_earned':  pts,
      'pts_used':    0,
      'note':        note ?? 'Mua hàng',
      'created_at':  now,
    });

    // Cộng điểm vào customers
    final customer = await _sb
        .from('customers')
        .select('loyalty_pts')
        .eq('id', customerId)
        .maybeSingle();
    if (customer != null) {
      final current = (customer['loyalty_pts'] as num?)?.toDouble() ?? 0;
      await _sb.from('customers').update({
        'loyalty_pts': current + pts,
        'updated_at':  now,
      }).eq('id', customerId);
    }
  }

  Future<void> redeemPoints({
    required String customerId,
    required double pts,
    String? orderId,
    String? note,
  }) async {
    if (pts <= 0) return;
    final storeId = await _storeId();
    if (storeId == null) return;

    // Kiểm tra số dư
    final customer = await _sb
        .from('customers')
        .select('loyalty_pts')
        .eq('id', customerId)
        .maybeSingle();
    final current = (customer?['loyalty_pts'] as num?)?.toDouble() ?? 0;
    if (current < pts) throw Exception('Không đủ điểm thưởng');

    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('loyalty_transactions').insert({
      'id':          _uuid.v4(),
      'store_id':    storeId,
      'customer_id': customerId,
      'order_id':    orderId,
      'pts_earned':  0,
      'pts_used':    pts,
      'note':        note ?? 'Đổi điểm',
      'created_at':  now,
    });

    await _sb.from('customers').update({
      'loyalty_pts': current - pts,
      'updated_at':  now,
    }).eq('id', customerId);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<LoyaltyStats> getStats() async {
    final storeId = await _storeId();
    if (storeId == null) return LoyaltyStats.empty;

    final customers = await _sb
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false);
    final totalPts = customers.fold<double>(
        0, (s, c) => s + ((c['loyalty_pts'] as num?)?.toDouble() ?? 0));
    final withPts = customers.where((c) => (c['loyalty_pts'] as num? ?? 0) > 0).length;

    // ‼️ FIX Bug #27: select chỉ cột cần thiết + limit để tránh query timeout
    // Với store lớn: toàn bộ txs không limit → request quá lớn
    final txs = await _sb
        .from('loyalty_transactions')
        .select('pts_earned, pts_used')
        .eq('store_id', storeId)
        .limit(10000); // guard: nếu cần chính xác hơn dùng PostgreSQL SUM aggregate
    final totalEarned   = txs.fold<double>(0, (s, t) => s + ((t['pts_earned'] as num?)?.toDouble() ?? 0));
    final totalRedeemed = txs.fold<double>(0, (s, t) => s + ((t['pts_used'] as num?)?.toDouble() ?? 0));

    return LoyaltyStats(
      totalCustomers:   customers.length,
      customersWithPts: withPts,
      totalActivePts:   totalPts,
      totalPtsEarned:   totalEarned,
      totalPtsRedeemed: totalRedeemed,
    );
  }

  // ── Wallet (Nạp tiền + Bonus) ───────────────────────────────────

  /// Nạp tiền vào ví khách hàng.
  /// [realAmount] = tiền thật khách trả.
  /// [bonusAmount] = thưởng thêm (do quán tặng).
  /// [bonusMonths] = thời hạn bonus (null = không hết hạn).
  Future<void> topUpWallet({
    required String customerId,
    required double realAmount,
    double bonusAmount = 0,
    int? bonusMonths,
    String? note,
    String? customerName, // dùng cho mô tả finance_records
  }) async {
    if (realAmount <= 0) throw Exception('Số tiền nạp phải lớn hơn 0');
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch số dư hiện tại
    final cust = await _sb.from('customers')
        .select('real_balance, bonus_balance, total_topup')
        .eq('id', customerId).maybeSingle();
    if (cust == null) throw Exception('Không tìm thấy khách hàng');

    final curReal  = (cust['real_balance'] as num?)?.toDouble() ?? 0;
    final curBonus = (cust['bonus_balance'] as num?)?.toDouble() ?? 0;
    final curTopup = (cust['total_topup'] as num?)?.toDouble() ?? 0;
    final newReal  = curReal + realAmount;
    final newBonus = curBonus + bonusAmount;
    final expires  = bonusMonths != null
        ? DateTime.now().add(Duration(days: bonusMonths * 30)).toUtc().toIso8601String()
        : null;

    // 1. Cập nhật số dư khách hàng
    await _sb.from('customers').update({
      'real_balance':    newReal,
      'bonus_balance':   newBonus,
      'total_topup':     curTopup + realAmount,
      if (expires != null) 'bonus_expires_at': expires,
      'updated_at':      now,
    }).eq('id', customerId);

    // 2. Ghi balance_transactions (lịch sử nội bộ loyalty)
    await _sb.from('balance_transactions').insert([
      {
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'customer_id':  customerId,
        'type':         'topup_real',
        'amount':       realAmount,
        'balance_after': newReal,
        'bonus_after':   newBonus,
        'note':         note ?? 'Nạp tiền',
        'created_at':   now,
      },
      if (bonusAmount > 0) {
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'customer_id':  customerId,
        'type':         'topup_bonus',
        'amount':       bonusAmount,
        'balance_after': newReal,
        'bonus_after':   newBonus,
        'note':         'Thưởng +${bonusAmount.toStringAsFixed(0)}đ',
        'created_at':   now,
      },
    ]);

    // 3. Ghi finance_records income — chống gian lận thu ngân
    // is_auto=true → không thể xoá thủ công, reference_id trỏ về customer để trace
    final label = customerName != null && customerName.isNotEmpty
        ? customerName
        : 'Khách hàng';
    final bonusNote = bonusAmount > 0
        ? ' (tặng thêm ${bonusAmount.toStringAsFixed(0)}đ bonus)'
        : '';
    try {
      await _sb.from('finance_records').insert({
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'type':         'income',
        'amount':       realAmount,
        'description':  'Nạp ví: $label$bonusNote',
        'reference_id': customerId,
        'is_auto':      true,
        'recorded_at':  now,
      });
      debugPrint('[LoyaltyRepo] ✅ finance_records inserted OK — $label $realAmount');
    } catch (e, st) {
      debugPrint('[LoyaltyRepo] ❌ finance_records INSERT FAILED: $e');
      debugPrint('[LoyaltyRepo] StackTrace: $st');
    }
  }

  /// Tính toán số tiền real + bonus được dùng cho một bill.
  /// Trả về {realUsed, bonusUsed, remaining}
  Map<String, double> computeWalletUsage({
    required double bill,
    required double realBalance,
    required double bonusBalance,
    required int bonusCapPct,
    bool isBonusExpired = false,
  }) {
    final effectiveBonus = isBonusExpired ? 0.0 : bonusBalance;
    final maxBonus = (bill * bonusCapPct / 100).floorToDouble();
    final bonusUsed = effectiveBonus.clamp(0.0, maxBonus);
    final remaining = bill - bonusUsed;
    final realUsed  = remaining.clamp(0.0, realBalance);
    return {
      'bonusUsed': bonusUsed,
      'realUsed':  realUsed,
      'paid':      realUsed + bonusUsed, // tổng từ ví
      'cashNeeded': (bill - realUsed - bonusUsed).clamp(0.0, double.infinity),
    };
  }

  /// Thực hiện trừ ví khi thanh toán (gọi từ _checkout trong ban_screen).
  Future<Map<String, double>> spendWallet({
    required String customerId,
    required double bill,
    required String orderId,
    String? storeId,
  }) async {
    final sid = storeId ?? await _storeId();
    if (sid == null) throw Exception('Chưa chọn quán');

    final cust = await _sb.from('customers')
        .select('real_balance, bonus_balance, bonus_cap_pct, bonus_expires_at')
        .eq('id', customerId).maybeSingle();
    if (cust == null) throw Exception('Không tìm thấy khách');

    final realBal   = (cust['real_balance'] as num?)?.toDouble() ?? 0;
    final bonusBal  = (cust['bonus_balance'] as num?)?.toDouble() ?? 0;
    final capPct    = (cust['bonus_cap_pct'] as num?)?.toInt() ?? 15;
    final expiresAt = cust['bonus_expires_at'] != null
        ? DateTime.tryParse(cust['bonus_expires_at'] as String) : null;
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);

    final usage = computeWalletUsage(
      bill: bill, realBalance: realBal, bonusBalance: bonusBal,
      bonusCapPct: capPct, isBonusExpired: isExpired,
    );

    final now      = DateTime.now().toUtc().toIso8601String();
    final newReal  = (realBal  - usage['realUsed']!).clamp(0.0, double.infinity);
    final newBonus = (bonusBal - usage['bonusUsed']!).clamp(0.0, double.infinity);

    await _sb.from('customers').update({
      'real_balance':  newReal,
      'bonus_balance': newBonus,
      'updated_at':    now,
    }).eq('id', customerId);

    final txs = <Map<String, dynamic>>[];
    if (usage['realUsed']! > 0) {
      txs.add({
        'id': _uuid.v4(), 'store_id': sid, 'customer_id': customerId,
        'order_id': orderId, 'type': 'spend_real',
        'amount': usage['realUsed']!, 'balance_after': newReal,
        'bonus_after': newBonus, 'note': 'Thanh toán đơn', 'created_at': now,
      });
    }
    if (usage['bonusUsed']! > 0) {
      txs.add({
        'id': _uuid.v4(), 'store_id': sid, 'customer_id': customerId,
        'order_id': orderId, 'type': 'spend_bonus',
        'amount': usage['bonusUsed']!, 'balance_after': newReal,
        'bonus_after': newBonus, 'note': 'Dùng thưởng', 'created_at': now,
      });
    }
    if (txs.isNotEmpty) await _sb.from('balance_transactions').insert(txs);

    return usage;
  }

  Stream<List<BalanceTransactionModel>> watchBalanceTransactions(
      String customerId) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'balance_transactions', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['customer_id'] == customerId)
          .map(BalanceTransactionModel.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
    );
  }

  // ── Topup Packages ────────────────────────────────────────────────────────

  Stream<List<TopupPackageModel>> watchPackages() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'topup_packages', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_active'] == true)
          .map(TopupPackageModel.fromMap)
          .toList()
        ..sort((a, b) => a.minAmount.compareTo(b.minAmount))
    );
  }

  Future<List<TopupPackageModel>> getPackages() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb.from('topup_packages')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('min_amount', ascending: true);
    return rows.map(TopupPackageModel.fromMap).toList();
  }

  /// Tìm gói áp dụng được (gói cao nhất có min_amount <= amount)
  TopupPackageModel? findApplicablePackage(
      List<TopupPackageModel> packages, double amount) {
    final eligible = packages
        .where((p) => p.isActive && p.minAmount <= amount)
        .toList()
      ..sort((a, b) => b.minAmount.compareTo(a.minAmount));
    return eligible.isEmpty ? null : eligible.first;
  }

  Future<void> upsertPackage(TopupPackageModel pkg) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('topup_packages').upsert({
      'id':         pkg.id,
      'store_id':   storeId,
      'name':       pkg.name,
      'min_amount': pkg.minAmount,
      'bonus_pct':  pkg.bonusPct,
      'is_active':  pkg.isActive,
      'sort_order': pkg.sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deletePackage(String id) async {
    await _sb.from('topup_packages')
        .update({'is_active': false}).eq('id', id);
  }

  /// Seed gói mặc định nếu store chưa có gói nào
  Future<void> seedDefaultPackagesIfEmpty() async {
    final storeId = await _storeId();
    if (storeId == null) return;
    final existing = await _sb.from('topup_packages')
        .select('id').eq('store_id', storeId).limit(1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = kDefaultTopupPackages.asMap().entries.map((e) => {
      'id':         _uuid.v4(),
      'store_id':   storeId,
      'name':       e.value.name,
      'min_amount': e.value.minAmount,
      'bonus_pct':  e.value.bonusPct,
      'is_active':  true,
      'sort_order': e.key,
      'created_at': now,
      'updated_at': now,
    }).toList();
    await _sb.from('topup_packages').insert(rows);
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class LoyaltyCustomerModel {
  final String id;
  final String name;
  final String? phone;
  final double loyaltyPts;
  final double totalSpent;
  final int visitCount;
  // Wallet
  final double realBalance;
  final double bonusBalance;
  final int bonusCapPct;        // % tối đa bonus/bill
  final DateTime? bonusExpiresAt;
  final double totalTopup;

  const LoyaltyCustomerModel({
    required this.id, required this.name, this.phone,
    required this.loyaltyPts, required this.totalSpent, required this.visitCount,
    this.realBalance = 0, this.bonusBalance = 0,
    this.bonusCapPct = 15, this.bonusExpiresAt,
    this.totalTopup = 0,
  });

  bool get hasWallet => realBalance > 0 || bonusBalance > 0;
  double get totalWallet => realBalance + bonusBalance;
  bool get isBonusExpired =>
      bonusExpiresAt != null && DateTime.now().isAfter(bonusExpiresAt!);

  factory LoyaltyCustomerModel.fromMap(Map<String, dynamic> m) =>
      LoyaltyCustomerModel(
        id:             m['id'] as String,
        name:           m['name'] as String,
        phone:          m['phone'] as String?,
        loyaltyPts:     (m['loyalty_pts'] as num?)?.toDouble() ?? 0,
        totalSpent:     (m['total_spent'] as num?)?.toDouble() ?? 0,
        visitCount:     (m['visit_count'] as num?)?.toInt() ?? 0,
        realBalance:    (m['real_balance'] as num?)?.toDouble() ?? 0,
        bonusBalance:   (m['bonus_balance'] as num?)?.toDouble() ?? 0,
        bonusCapPct:    (m['bonus_cap_pct'] as num?)?.toInt() ?? 15,
        bonusExpiresAt: m['bonus_expires_at'] != null
            ? DateTime.tryParse(m['bonus_expires_at'] as String)
            : null,
        totalTopup:     (m['total_topup'] as num?)?.toDouble() ?? 0,
      );
}


class LoyaltyTransactionModel {
  final String id;
  final String customerId;
  final double ptsEarned;
  final double ptsUsed;
  final String? note;
  final String createdAt;

  const LoyaltyTransactionModel({
    required this.id, required this.customerId,
    required this.ptsEarned, required this.ptsUsed,
    this.note, required this.createdAt,
  });

  factory LoyaltyTransactionModel.fromMap(Map<String, dynamic> m) =>
      LoyaltyTransactionModel(
        id:         m['id'] as String,
        customerId: m['customer_id'] as String,
        ptsEarned:  (m['pts_earned'] as num?)?.toDouble() ?? 0,
        ptsUsed:    (m['pts_used'] as num?)?.toDouble() ?? 0,
        note:       m['note'] as String?,
        createdAt:  m['created_at'] as String? ?? '',
      );
}

class LoyaltyRewardModel {
  final String id;
  final String name;
  final double ptsRequired;
  final double? discountAmount;

  const LoyaltyRewardModel({
    required this.id, required this.name,
    required this.ptsRequired, this.discountAmount,
  });

  factory LoyaltyRewardModel.fromMap(Map<String, dynamic> m) =>
      LoyaltyRewardModel(
        id:             m['id'] as String,
        name:           m['name'] as String,
        ptsRequired:    (m['pts_required'] as num).toDouble(),
        discountAmount: (m['discount_amount'] as num?)?.toDouble(),
      );
}

class LoyaltyStats {
  final int totalCustomers;
  final int customersWithPts;
  final double totalActivePts;
  final double totalPtsEarned;
  final double totalPtsRedeemed;

  const LoyaltyStats({
    required this.totalCustomers, required this.customersWithPts,
    required this.totalActivePts, required this.totalPtsEarned,
    required this.totalPtsRedeemed,
  });

  static const empty = LoyaltyStats(
    totalCustomers: 0, customersWithPts: 0,
    totalActivePts: 0, totalPtsEarned: 0, totalPtsRedeemed: 0,
  );
}

class BalanceTransactionModel {
  final String id;
  final String customerId;
  final String type; // topup_real | topup_bonus | spend_real | spend_bonus | bonus_expired | refund
  final double amount;
  final double balanceAfter;
  final double bonusAfter;
  final String? note;
  final String? orderId;
  final String createdAt;

  const BalanceTransactionModel({
    required this.id, required this.customerId,
    required this.type, required this.amount,
    required this.balanceAfter, required this.bonusAfter,
    this.note, this.orderId, required this.createdAt,
  });

  bool get isCredit => type.startsWith('topup') || type == 'refund';
  bool get isBonus  => type == 'topup_bonus' || type == 'spend_bonus';

  factory BalanceTransactionModel.fromMap(Map<String, dynamic> m) =>
      BalanceTransactionModel(
        id:           m['id'] as String,
        customerId:   m['customer_id'] as String,
        type:         m['type'] as String? ?? 'unknown',
        amount:       (m['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (m['balance_after'] as num?)?.toDouble() ?? 0,
        bonusAfter:   (m['bonus_after'] as num?)?.toDouble() ?? 0,
        note:         m['note'] as String?,
        orderId:      m['order_id'] as String?,
        createdAt:    m['created_at'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TOPUP PACKAGE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class TopupPackageModel {
  final String id;
  final String name;
  final double minAmount;
  final double bonusPct;
  final bool isActive;
  final int sortOrder;

  const TopupPackageModel({
    required this.id, required this.name,
    required this.minAmount, required this.bonusPct,
    this.isActive = true, this.sortOrder = 0,
  });

  double bonusFor(double amount) => (amount * bonusPct / 100).floorToDouble();

  factory TopupPackageModel.fromMap(Map<String, dynamic> m) => TopupPackageModel(
    id:         m['id'] as String,
    name:       m['name'] as String,
    minAmount:  (m['min_amount'] as num).toDouble(),
    bonusPct:   (m['bonus_pct'] as num).toDouble(),
    isActive:   m['is_active'] as bool? ?? true,
    sortOrder:  (m['sort_order'] as num?)?.toInt() ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGE DEFAULTS — Gợi ý gói cơ bản cho chủ quán
// ─────────────────────────────────────────────────────────────────────────────
const kDefaultTopupPackages = [
  (name: 'Gói Đồng',    minAmount: 100000.0,  bonusPct: 5.0),
  (name: 'Gói Bạc',     minAmount: 200000.0,  bonusPct: 10.0),
  (name: 'Gói Vàng',    minAmount: 500000.0,  bonusPct: 15.0),
  (name: 'Gói Bạch Kim',minAmount: 1000000.0, bonusPct: 20.0),
  (name: 'Gói Kim Cương',minAmount: 2000000.0,bonusPct: 30.0),
];
