import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chủ quán xem, sửa, xoá những gì Bé Boom nhớ về quán (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md giai đoạn 4).
/// Gọi các hàm boom_bo_nho_*_v1 (migration 20261107_boom_bo_nho_quan_v1). Hàm chưa có trên máy chủ hoặc không phải
/// chủ quán → máy chủ trả null / lỗi → ô vào màn này tự ẩn, không hiện tính năng hỏng.

class GhiNhoQuan {
  final String id, noiDung, loai, nguon, trangThai, mucXem;
  const GhiNhoQuan(
    this.id,
    this.noiDung,
    this.loai,
    this.nguon,
    this.trangThai,
    this.mucXem,
  );

  bool get laDoan => trangThai == 'doan';

  static GhiNhoQuan? fromJson(Object? j) {
    if (j is! Map) return null;
    String s(Object? v) => v is String ? v : '';
    final id = s(j['id']), nd = s(j['noi_dung']);
    if (id.isEmpty || nd.isEmpty) return null;
    return GhiNhoQuan(
      id,
      nd,
      s(j['loai']),
      s(j['nguon']),
      s(j['trang_thai']),
      s(j['muc_xem']),
    );
  }
}

class BoNhoQuan {
  final bool tat;
  final List<GhiNhoQuan> ghiNho;
  const BoNhoQuan(this.tat, this.ghiNho);

  static BoNhoQuan? fromJson(Object? j) {
    if (j is! Map) return null;
    final hs = j['ho_so'];
    final ds = j['ghi_nho'];
    return BoNhoQuan(hs is Map && hs['tat'] == true, [
      for (final x in (ds is List ? ds : const [])) ?GhiNhoQuan.fromJson(x),
    ]);
  }
}

/// Bộ nhớ của một quán; null = chưa có tính năng hoặc không phải chủ quán.
final boNhoQuanProvider = FutureProvider.autoDispose.family<BoNhoQuan?, String>(
  (ref, storeId) async {
    try {
      final r = await Supabase.instance.client.rpc(
        'boom_bo_nho_xem_v1',
        params: {'p_store': storeId},
      );
      return BoNhoQuan.fromJson(r);
    } catch (e) {
      if (kDebugMode) debugPrint('[BoNho] $e');
      return null;
    }
  },
);

/// Ô trên màn Cài đặt. Chỉ hiện khi máy chủ trả được bộ nhớ (đã có tính năng và người xem là chủ quán).
class BoNhoQuanTile extends ConsumerWidget {
  final String storeId;
  const BoNhoQuanTile({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(boNhoQuanProvider(storeId)).value;
    if (v == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8CC)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        leading: const Icon(
          Icons.psychology_alt_rounded,
          color: Color(0xFF6A1B9A),
        ),
        title: const Text(
          'Bé Boom nhớ gì về quán',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          v.tat ? 'Đang tắt' : '${v.ghiNho.length} điều · xem, sửa, xoá',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BoNhoQuanScreen(storeId: storeId)),
        ),
      ),
    );
  }
}

class BoNhoQuanScreen extends ConsumerWidget {
  final String storeId;
  const BoNhoQuanScreen({super.key, required this.storeId});

  static const _nhom = [
    ('xac_nhan', 'Điều anh/chị đã nói'),
    ('doan', 'Bé Boom đoán, chờ anh/chị xác nhận'),
    ('da_thu', 'Việc đã thử'),
    ('khong_hoi', 'Bé Boom không hỏi lại'),
  ];

  String _nhomCua(GhiNhoQuan g) => g.loai == 'da_thu' || g.loai == 'khong_hoi'
      ? g.loai
      : g.laDoan
      ? 'doan'
      : 'xac_nhan';

  Future<void> _goi(
    BuildContext context,
    WidgetRef ref,
    String fn,
    Map<String, dynamic> p,
    String loi,
  ) async {
    try {
      final r = await Supabase.instance.client.rpc(fn, params: p);
      if (r == null || r == false) throw StateError('false');
    } catch (e) {
      if (kDebugMode) debugPrint('[BoNho] $fn $e');
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loi)));
    }
    ref.invalidate(boNhoQuanProvider(storeId));
  }

  Future<void> _sua(BuildContext context, WidgetRef ref, GhiNhoQuan g) async {
    final ctl = TextEditingController(text: g.noiDung);
    final moi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa điều Bé Boom nhớ'),
        content: TextField(
          controller: ctl,
          maxLength: 300,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (moi == null || moi.length < 3 || !context.mounted) return;
    await _goi(context, ref, 'boom_bo_nho_sua_v1', {
      'p_id': g.id,
      'p_noi_dung': moi,
    }, 'Chưa lưu được, thử lại sau.');
  }

  Future<void> _xoa(BuildContext context, WidgetRef ref, GhiNhoQuan g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá điều này?'),
        content: Text(
          '"${g.noiDung}"\n\nBé Boom sẽ quên hẳn điều này, kể cả các bản trước.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _goi(context, ref, 'boom_bo_nho_xoa_v1', {
      'p_id': g.id,
    }, 'Chưa xoá được, thử lại sau.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final as = ref.watch(boNhoQuanProvider(storeId));
    final v = as.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Bé Boom nhớ gì về quán')),
      body: as.isLoading && v == null
          ? const Center(child: CircularProgressIndicator())
          : v == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa xem được bộ nhớ. Thử lại sau.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho Bé Boom ghi nhớ về quán'),
                  subtitle: const Text(
                    'Bé Boom nhớ điều anh/chị kể để tư vấn hợp quán hơn. Tắt thì Bé Boom không đọc, không ghi thêm.',
                  ),
                  value: !v.tat,
                  onChanged: (b) => _goi(context, ref, 'boom_bo_nho_tat_v1', {
                    'p_store': storeId,
                    'p_tat': !b,
                  }, 'Chưa đổi được, thử lại sau.'),
                ),
                const Text(
                  'Bé Boom không ghi số doanh thu, số điện thoại hay tài khoản. Điều có ghi "chỉ chủ quán" thì nhân viên hỏi Bé Boom cũng không thấy.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 12),
                if (v.ghiNho.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Bé Boom chưa nhớ điều gì. Khi anh/chị kể về quán lúc trò chuyện, Bé Boom sẽ ghi lại ở đây.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final (ma, ten) in _nhom)
                  if (v.ghiNho.any((g) => _nhomCua(g) == ma)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        ten,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ),
                    for (final g in v.ghiNho.where((g) => _nhomCua(g) == ma))
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(g.noiDung),
                          subtitle: Text(
                            [
                              if (g.nguon == 'nhan_vien_noi') 'nhân viên kể',
                              if (g.nguon == 'boom_doan') 'Bé Boom đoán',
                              if (g.mucXem == 'chu_quan') 'chỉ chủ quán',
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (g.laDoan)
                                IconButton(
                                  tooltip: 'Đúng rồi',
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _goi(
                                    context,
                                    ref,
                                    'boom_bo_nho_sua_v1',
                                    {'p_id': g.id, 'p_noi_dung': g.noiDung},
                                    'Chưa lưu được, thử lại sau.',
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Sửa',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _sua(context, ref, g),
                              ),
                              IconButton(
                                tooltip: 'Xoá',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _xoa(context, ref, g),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}
