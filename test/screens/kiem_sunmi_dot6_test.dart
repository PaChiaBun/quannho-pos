// Kiểm Sunmi Bò Đen đợt 6 (03/11/2026, bản 24, đọc-chỉ): món bán theo công thức không bị Bán hàng / Bàn khoá
// theo tồn của chính món (G6), công thức của cốt / bán thành phẩm không ghi "Tự trừ kho khi bán" (G1), dòng
// Hao hụt gần đây có giờ ngày (G3).
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/models/product_model.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/recipe_product_ids.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/screens/stock_waste_screen.dart';

ProductModel _p(String id, {double stock = 0, double min = 10}) => ProductModel(
      id: id,
      storeId: 's',
      name: id,
      unit: 'ly',
      productType: 'finished',
      stockQty: stock,
      minStock: min,
      sellPrice: 25000,
      costPrice: 0,
      stationCode: 'bep_bar',
      isAvailable: true,
      isActive: true,
      isDeleted: false,
    );

void main() {
  test('G6 — chỉ khoá theo tồn khi có tồn tối thiểu và món không bán theo công thức', () {
    const recipeIds = {'tra-tac'};
    expect(locksOnOwnStock(_p('tra-tac'), recipeIds), isFalse); // Trà Tắc đặt tồn tối thiểu 10
    expect(locksOnOwnStock(_p('banh-nep'), recipeIds), isTrue); // món bán thẳng từ kho
    expect(locksOnOwnStock(_p('tran-chau', min: 0), recipeIds), isFalse); // không theo dõi tồn
  });

  test('G1 — công thức của nguyên liệu / bán thành phẩm là công thức sản xuất', () {
    expect(recipeMakesStock('ingredient'), isTrue); // Cot Tra Den
    expect(recipeMakesStock('semi_finished'), isTrue);
    expect(recipeMakesStock('finished'), isFalse);
    expect(recipeMakesStock(null), isFalse); // chưa tải loại món: giữ nhãn món bán
  });

  test('G3 — dòng Hao hụt gần đây ghi giờ ngày', () {
    expect(wasteTimeLabel('2026-11-02T22:15:00'), '22:15 02/11 · ');
    expect(wasteTimeLabel(null), '');
    expect(wasteTimeLabel('không rõ'), '');
  });
}
