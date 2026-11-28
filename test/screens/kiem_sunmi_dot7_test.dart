// Kiểm Sunmi Bò Đen đợt 7 (03/11/2026, bản 24, đọc-chỉ): giá vốn công thức nấu theo mẻ ghi đúng đơn vị (H2),
// nút "Xem bill hôm qua" theo quyền xem Báo cáo như thanh dưới, không chỉ chủ quán (H3).
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';

class _Role {
  final String name;
  final List<String> modules;
  const _Role(this.name, this.modules);
}

RecipeModel _recipe(double size, String unit) =>
    RecipeModel(id: 'r', storeId: 's', name: 'x', servingSize: size, servingUnit: unit, createdAt: '');

void main() {
  test('H2 — giá vốn cả mẻ ghi theo đơn vị công thức, món 1 phần vẫn "phần"', () {
    expect(_recipe(1, 'phần').yieldLabel, 'phần');
    expect(_recipe(16, 'lít').yieldLabel, '16 lít'); // Cot Tra Den: trước ghi "136.000 đ /phần"
    expect(_recipe(0.5, 'kg').yieldLabel, '0,5 kg');
  });

  test('H3 — ai mở được Báo cáo thì thấy nút mở Báo cáo', () {
    bool report(String role, [List<_Role> roles = const []]) =>
        navTabsForRole(role, roles, false).contains(NavTab.report);
    expect(report('Quản lý nhà hàng'), isTrue); // anh Dương — trước không thấy nút
    expect(report('Thu ngân', const [_Role('Thu ngân', ['pos', 'ban', 'report'])]), isTrue);
    expect(report('Nhân viên', const [_Role('Nhân viên', ['ban'])]), isFalse);
    expect(navTabsForRole(null, const [], true).contains(NavTab.report), isTrue); // chủ quán
  });
}
