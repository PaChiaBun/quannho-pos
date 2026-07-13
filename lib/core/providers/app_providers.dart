import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/core_product_repository.dart';
import '../repositories/core_customer_repository.dart';
import '../repositories/module_repository.dart';
import '../repositories/kitchen_repository.dart';
import '../repositories/ban_repository.dart';
import '../../modules/pos/repository/pos_repository.dart';
import '../../modules/finance/repository/finance_repository.dart';
import '../../modules/kho/repository/kho_repository.dart';
import '../../modules/kho_chuyen_nghiep/providers/kho_chuyen_nghiep_providers.dart'
    show khoProRepositoryProvider; // re-use provider đã có
import '../../modules/loyalty/repository/loyalty_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDERS — 100% Supabase, không còn AppDatabase
// ─────────────────────────────────────────────────────────────────────────────

final productRepositoryProvider = Provider<CoreProductRepository>((ref) {
  return CoreProductRepository();
});

final customerRepositoryProvider = Provider<CoreCustomerRepository>((ref) {
  return CoreCustomerRepository();
});

final khoRepositoryProvider = Provider<KhoRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return KhoRepository(productRepo);
});

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  return KitchenRepository();
});

final settingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository();
});

final moduleRepositoryProvider = Provider<ModuleRepository>((ref) {
  return ModuleRepository();
});

final posRepositoryProvider = Provider<PosRepository>((ref) {
  final productRepo  = ref.watch(productRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final khoProRepo   = ref.watch(khoProRepositoryProvider);
  return PosRepository(productRepo, customerRepo, khoProRepo);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository();
});



final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository();
});

final banRepositoryProvider = Provider<BanRepository>((ref) {
  return BanRepository();
});

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS — Reactive data
// ─────────────────────────────────────────────────────────────────────────────

/// Tất cả sản phẩm (reactive)
final allProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  ref.watch(sessionProvider); // bắt buộc refresh khi chuyển quán
  return ref.watch(productRepositoryProvider).watchAll();
});

/// Sản phẩm cho POS (chỉ active + available)
final posProductsProvider = Provider<AsyncValue<List<ProductModel>>>((ref) {
  return ref.watch(allProductsProvider).whenData((products) => products
      .where((p) =>
          p.isActive &&
          p.isAvailable &&
          p.category != 'Nguyên liệu' &&
          p.productType != 'ingredient')
      .toList());
});

/// Tất cả khách hàng (reactive)
final allCustomersProvider = StreamProvider<List<CustomerModel>>((ref) {
  ref.watch(sessionProvider); // bắt buộc refresh khi chuyển quán
  return ref.watch(customerRepositoryProvider).watchAll();
});

/// Tất cả modules (refresh khi session thay đổi)
final allModulesProvider = StreamProvider<List<ModuleConfig>>((ref) async* {
  ref.watch(sessionProvider); // bắt buộc refresh khi storeId có
  yield await ref.read(moduleRepositoryProvider).getAll();
});

/// Chỉ active modules (refresh khi session thay đổi)
final activeModulesProvider = StreamProvider<List<ModuleConfig>>((ref) async* {
  ref.watch(sessionProvider); // bắt buộc refresh khi storeId có
  final all = await ref.read(moduleRepositoryProvider).getAll();
  yield all.where((m) => m.isActive).toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final shopNameProvider = FutureProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).shopName;
});

final taxRateProvider = FutureProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).taxRate;
});

final loyaltyRateProvider = FutureProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).loyaltyRate;
});

final pinEnabledProvider = FutureProvider<bool>((ref) async {
  final val = await ref.watch(settingsRepositoryProvider).get('pin_enabled');
  return val == 'true';
});

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATION PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

class _NavTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void goTo(int index) => state = index;
}

final navTabProvider = NotifierProvider<_NavTabNotifier, int>(
  _NavTabNotifier.new);

class NavTab {
  static const home      = 0;
  static const pos       = 1;
  static const inventory = 2;
  static const finance   = 3;
  static const loyalty   = 4;
  static const report    = 5;
  static const settings  = 6;
  static const table     = 7;
  static const kitchen   = 8;
  static const staff     = 9;
  static const chamcong  = 10;
  static const khoPro    = 11;
  static const tinhLuong = 12;
  static const kayOps    = 13; // Module Vận Hành (KAY Ops)
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV SLOTS PROVIDER — 4 slot tuỳ chỉnh, lưu SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────

class NavSlotsNotifier extends AsyncNotifier<List<int>> {
  static const _prefKey  = 'nav_slots_v2'; // v2 → reset khi thêm Kho Pro
  static const _defaults = [0, 1, 2, 11]; // Home, Bán hàng, Kho, Kho Pro

  @override
  Future<List<int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final parsed = saved.split(',').map(int.tryParse).whereType<int>().toList();
      if (parsed.length == 4) return parsed;
    }
    return List<int>.from(_defaults);
  }

  Future<void> updateSlot(int slotIndex, int tabIndex) async {
    final current = state.value ?? List<int>.from(_defaults);
    final updated = List<int>.from(current);
    updated[slotIndex] = tabIndex;
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, updated.join(','));
  }
}

final navSlotsProvider =
    AsyncNotifierProvider<NavSlotsNotifier, List<int>>(NavSlotsNotifier.new);

final openShiftCCProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s == null) return null;
  try {
    return await Supabase.instance.client
        .from('staff_shifts').select('id,clock_in')
        .eq('user_id', s.userId).eq('store_id', s.storeId ?? '')
        .isFilter('clock_out', null).maybeSingle();
  } catch (_) { return null; }
});
