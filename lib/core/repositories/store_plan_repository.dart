import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GÓI / KHOÁ QUÁN — app hỏi máy chủ quán mình đang ở gói nào, còn hạn dùng thử không, có bị khoá không
// (RPC store_plan_status_v1, migration 20261027_quan_tri_dot1_ho_so_goi.sql). Quản trị đổi trên trang /admin.
// Lỗi mạng / máy chủ chưa có hàm → trả null: app chạy bình thường, KHÔNG bao giờ tự khoá vì lỗi.
// ─────────────────────────────────────────────────────────────────────────────

class StorePlanStatus {
  final String plan; // free | pro
  final String status; // trial | active | locked
  final bool locked;
  final bool isOwner;
  final DateTime? trialEndsAt;
  final DateTime? planEndsAt;
  final String? notice; // trial_expired | trial_ending | pro_expired | pro_ending | null
  final String? contact; // câu liên hệ quản trị đặt (trống → câu mặc định)
  final bool canSelfExtend; // Chủ quán bấm "Gia hạn thêm 30 ngày" được (còn ≤ 3 ngày / đã hết, gói free)

  const StorePlanStatus({
    required this.plan,
    required this.status,
    required this.locked,
    required this.isOwner,
    this.trialEndsAt,
    this.planEndsAt,
    this.notice,
    this.contact,
    this.canSelfExtend = false,
  });

  static DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String? _text(Object? v) {
    final t = v is String ? v.trim() : '';
    return t.isEmpty ? null : t;
  }

  factory StorePlanStatus.fromMap(Map<String, dynamic> m) => StorePlanStatus(
    plan: (m['plan'] as String?) ?? 'free',
    status: (m['status'] as String?) ?? 'trial',
    locked: m['locked'] == true,
    isOwner: m['is_owner'] == true,
    trialEndsAt: _dt(m['trial_ends_at']),
    planEndsAt: _dt(m['plan_ends_at']),
    notice: _text(m['notice']),
    contact: _text(m['contact']),
    canSelfExtend: m['can_self_extend'] == true,
  );
}

/// Câu liên hệ mặc định khi quản trị chưa đặt.
const kStorePlanDefaultContact = 'Liên hệ Quán Nhỏ để gia hạn.';

/// Câu nhắc khi Chủ quán tự gia hạn được.
const kStorePlanSelfExtendHint = 'Bấm "Gia hạn thêm 30 ngày" để dùng tiếp miễn phí.';

/// Câu nhắc thanh toán — CHỈ ở nơi được thu phí (web / bản máy tính).
const kStorePlanPayHint = 'Bấm "Mua gói Pro" để thanh toán.';

String _ddmm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Tiêu đề + nội dung dải nhắc cho Chủ quán; null = không nhắc.
/// [billingAllowed] = billingAllowedHere(): app iOS / Android (false) KHÔNG được nhắc mua / liên hệ mua (Apple 3.1.1,
/// Google Play Billing) — chỉ báo ngày hết hạn; nút "Gia hạn thêm 30 ngày" miễn phí thì vẫn nhắc.
({String title, String body})? storePlanNoticeText(StorePlanStatus s, DateTime now, {bool billingAllowed = false}) {
  final contact = s.canSelfExtend ? kStorePlanSelfExtendHint : (billingAllowed ? kStorePlanPayHint : '');
  int daysLeft(DateTime? end) => end == null ? 0 : (end.difference(now).inHours / 24).ceil().clamp(0, 9999);
  switch (s.notice) {
    case 'trial_expired':
      return (
        title: 'Quán đã hết thời gian dùng thử',
        body: '${s.trialEndsAt != null ? 'Hết hạn từ ${_ddmm(s.trialEndsAt!)}. ' : ''}$contact'.trim(),
      );
    case 'trial_ending':
      return (
        title: 'Còn ${daysLeft(s.trialEndsAt)} ngày dùng thử',
        body: contact.isEmpty && s.trialEndsAt != null ? 'Hết hạn ngày ${_ddmm(s.trialEndsAt!)}.' : contact,
      );
    case 'pro_expired':
      return (
        title: 'Gói Pro đã hết hạn',
        body: '${s.planEndsAt != null ? 'Hết hạn từ ${_ddmm(s.planEndsAt!)}. ' : ''}$contact'.trim(),
      );
    case 'pro_ending':
      return (
        title: 'Gói Pro còn ${daysLeft(s.planEndsAt)} ngày',
        body: contact.isEmpty && s.planEndsAt != null ? 'Hết hạn ngày ${_ddmm(s.planEndsAt!)}.' : contact,
      );
  }
  return null;
}

class StorePlanRepository {
  final SupabaseClient? client;
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpcOverride;
  const StorePlanRepository({this.client, this.rpcOverride});

  Future<StorePlanStatus?> fetch(String storeId) async {
    try {
      final params = {'p_store': storeId};
      final res = rpcOverride != null
          ? await rpcOverride!('store_plan_status_v1', params)
          : await (client ?? Supabase.instance.client).rpc('store_plan_status_v1', params: params);
      if (res is! Map || res['ok'] != true) return null;
      return StorePlanStatus.fromMap(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  /// Chủ quán tự gia hạn thêm 30 ngày dùng thử. Trả mã lỗi (null = thành công).
  /// Máy chủ chỉ cho Chủ quán, gói free, khi còn ≤ 3 ngày / đã hết hạn (không cộng dồn trước).
  Future<String?> selfExtend(String storeId) async {
    try {
      final params = {'p_store': storeId};
      final res = rpcOverride != null
          ? await rpcOverride!('store_self_extend_trial_v1', params)
          : await (client ?? Supabase.instance.client).rpc('store_self_extend_trial_v1', params: params);
      if (res is Map && res['ok'] == true) return null;
      return res is Map ? (res['error'] as String? ?? 'ERROR') : 'ERROR';
    } catch (_) {
      return 'NETWORK';
    }
  }
}

/// Trạng thái gói của một quán. Trang chủ làm mới khi mở lại app / kéo làm mới.
final storePlanStatusProvider = FutureProvider.autoDispose.family<StorePlanStatus?, String>(
  (ref, storeId) => const StorePlanRepository().fetch(storeId),
);
