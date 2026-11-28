import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHỦ QUÁN ĐẶT MẬT KHẨU MỚI CHO NHÂN VIÊN (hỗ trợ chủ quán H3 — ke-hoach-ho-tro-chu-quan.md)
// RPC store_staff_set_password_v1 (migration 20261030_ho_tro_h3_chu_quan_dat_mat_khau.sql): chỉ Chủ quán; nhân viên phải
// chỉ làm ở các quán của chủ quán này; mật khẩu 8–72 ký tự. Mọi điều kiện do máy chủ quyết, app chỉ báo lỗi dễ hiểu.
// ─────────────────────────────────────────────────────────────────────────────

const kStaffPasswordMin = 8;
const kStaffPasswordMax = 72;

/// Câu báo lỗi tiếng Việt cho mã lỗi máy chủ.
String staffPasswordErrorText(String code) => switch (code) {
  'OWNER_ONLY' => 'Chỉ Chủ quán mới đặt lại được mật khẩu nhân viên.',
  'SELF' => 'Muốn đổi mật khẩu của chính mình, vào Cài đặt → Đổi mật khẩu.',
  'NOT_MEMBER' => 'Người này không còn thuộc quán.',
  'TARGET_OWNER' => 'Không đặt lại được mật khẩu của Chủ quán.',
  'OTHER_STORES' =>
    'Nhân viên này còn làm ở quán khác (không do anh/chị làm chủ), nên không đổi mật khẩu từ đây được. '
        'Vào Cài đặt → Gửi phản hồi để Quán Nhỏ hỗ trợ.',
  'NOT_ACTIVE' =>
    'Nhân viên này chưa từng tự đăng nhập vào quán bằng app, nên không đổi mật khẩu từ đây được. '
        'Vào Cài đặt → Gửi phản hồi để Quán Nhỏ hỗ trợ.',
  'FORBIDDEN' => 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
  'BAD_PASSWORD' => 'Mật khẩu phải từ $kStaffPasswordMin đến $kStaffPasswordMax ký tự.',
  'TOO_MANY' => 'Đã đổi quá nhiều lần trong 1 giờ. Vui lòng thử lại sau.',
  'NETWORK' => 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.',
  _ => 'Không đổi được mật khẩu ($code). Vui lòng thử lại.',
};

/// Câu báo lỗi khi Chủ quán đổi tên nhân viên (cùng luật với đặt lại mật khẩu — migration 20261031_doi_ten_an_toan.sql).
String staffNameErrorText(String code) => switch (code) {
  'BAD_NAME' => 'Tên phải từ 2 đến 50 ký tự.',
  'OWNER_ONLY' => 'Chỉ Chủ quán mới đổi được tên nhân viên.',
  'SELF' => 'Muốn đổi tên của chính mình, vào Cài đặt → Tên hiển thị.',
  'TARGET_OWNER' => 'Không đổi được tên của Chủ quán.',
  'OTHER_STORES' =>
    'Nhân viên này còn làm ở quán khác (không do anh/chị làm chủ), nên không đổi tên từ đây được. '
        'Nhân viên tự đổi trong Cài đặt → Tên hiển thị.',
  'NOT_ACTIVE' =>
    'Nhân viên này chưa từng tự đăng nhập vào quán bằng app, nên không đổi tên từ đây được. '
        'Nhân viên tự đổi trong Cài đặt → Tên hiển thị sau khi đăng nhập.',
  'TOO_MANY' => 'Đã đổi tên quá nhiều lần trong 1 giờ. Vui lòng thử lại sau.',
  _ => staffPasswordErrorText(code),
};

class StaffPasswordRepository {
  final SupabaseClient? client;
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpcOverride;
  const StaffPasswordRepository({this.client, this.rpcOverride});

  /// Chủ quán đổi tên nhân viên. Trả mã lỗi (null = thành công).
  Future<String?> setName({required String storeId, required String userId, required String name}) async {
    try {
      final params = {'p_store': storeId, 'p_user': userId, 'p_name': name};
      final res = rpcOverride != null
          ? await rpcOverride!('store_staff_set_name_v1', params)
          : await (client ?? Supabase.instance.client).rpc('store_staff_set_name_v1', params: params);
      if (res is Map && res['ok'] == true) return null;
      return res is Map ? (res['error'] as String? ?? 'ERROR') : 'ERROR';
    } catch (_) {
      return 'NETWORK';
    }
  }

  /// Trả mã lỗi (null = thành công).
  Future<String?> setPassword({required String storeId, required String userId, required String newPassword}) async {
    try {
      final params = {'p_store': storeId, 'p_user': userId, 'p_new_password': newPassword};
      final res = rpcOverride != null
          ? await rpcOverride!('store_staff_set_password_v1', params)
          : await (client ?? Supabase.instance.client).rpc('store_staff_set_password_v1', params: params);
      if (res is Map && res['ok'] == true) return null;
      return res is Map ? (res['error'] as String? ?? 'ERROR') : 'ERROR';
    } catch (_) {
      return 'NETWORK';
    }
  }
}
