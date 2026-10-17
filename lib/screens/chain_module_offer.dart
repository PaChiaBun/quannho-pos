import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/repositories/chain_repository.dart';
import '../core/repositories/module_repository.dart';

/// Tự BẬT module "Báo cáo chuỗi" MỘT LẦN cho mỗi cửa hàng khi Chủ quán đủ điều kiện
/// (sở hữu từ 2 cửa hàng hoặc đã có chuỗi). Sau đó Chủ quán vẫn gỡ được trong chế độ Sửa;
/// cờ đã-bật được nhớ nên module không tự quay lại. Widget không hiển thị gì.
/// Lỗi/chưa có JWT/chủ chỉ có 1 cửa hàng: không làm gì, lần mở sau kiểm tra lại (chưa đặt cờ).
class ChainModuleOffer extends StatefulWidget {
  final String storeId;
  final VoidCallback onEnabled;
  final ChainRepository? repository;
  final Future<void> Function()? activateModule;

  const ChainModuleOffer({
    super.key,
    required this.storeId,
    required this.onEnabled,
    this.repository,
    this.activateModule,
  });

  static String prefsKey(String storeId) => 'chain_module_offered_$storeId';

  @override
  State<ChainModuleOffer> createState() => _ChainModuleOfferState();
}

class _ChainModuleOfferState extends State<ChainModuleOffer> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = ChainModuleOffer.prefsKey(widget.storeId);
      if (prefs.getBool(key) == true) return;

      final mine = await (widget.repository ?? ChainRepository()).listMine();
      if (!mine.worthShowing) return;

      await (widget.activateModule ?? () => ModuleRepository().activate('chain'))();
      await prefs.setBool(key, true);
      if (mounted) widget.onEnabled();
    } catch (_) {
      // Không chặn Trang chủ; lần mở sau sẽ thử lại.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
