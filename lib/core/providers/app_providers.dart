import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../event_bus/app_event_bus.dart';
import '../repositories/core_product_repository.dart';
import '../repositories/core_customer_repository.dart';
import '../repositories/module_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATABASE PROVIDER — Singleton database, dispose khi app tắt
// ─────────────────────────────────────────────────────────────────────────────
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ─────────────────────────────────────────────────────────────────────────────
// EVENT BUS PROVIDER — Singleton EventBus
// ─────────────────────────────────────────────────────────────────────────────
final appEventBusProvider = Provider<AppEventBus>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final bus = AppEventBus(db);
  ref.onDispose(bus.dispose);
  return bus;
});

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final productRepositoryProvider = Provider<CoreProductRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CoreProductRepository(db);
});

final customerRepositoryProvider = Provider<CoreCustomerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CoreCustomerRepository(db);
});

final moduleRepositoryProvider = Provider<ModuleRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ModuleRepository(db);
});

final settingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppSettingsRepository(db);
});

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS — Reactive data
// ─────────────────────────────────────────────────────────────────────────────

/// Tất cả sản phẩm (reactive)
final allProductsProvider = StreamProvider<List<CoreProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

/// Sản phẩm cho POS (chỉ active + available)
final posProductsProvider = StreamProvider<List<CoreProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchAvailableForPos();
});

/// Sản phẩm tồn kho thấp
final lowStockProductsProvider = StreamProvider<List<CoreProduct>>((ref) {
  return ref.watch(productRepositoryProvider).watchLowStock();
});

/// Tất cả khách hàng (reactive)
final allCustomersProvider = StreamProvider<List<CoreCustomer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAll();
});

/// Tất cả modules (sorted by position)
final allModulesProvider = StreamProvider<List<ModuleConfig>>((ref) {
  return ref.watch(moduleRepositoryProvider).watchAll();
});

/// Chỉ active modules
final activeModulesProvider = StreamProvider<List<ModuleConfig>>((ref) {
  return ref.watch(moduleRepositoryProvider).watchActive();
});

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PROVIDERS — Future-based, không reactive (thường không thay đổi)
// ─────────────────────────────────────────────────────────────────────────────

final shopNameProvider = FutureProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).shopName;
});

final receiptEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).receiptEnabled;
});

final taxRateProvider = FutureProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).taxRate;
});

final loyaltyRateProvider = FutureProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).loyaltyRate;
});

/// PIN khoá ứng dụng — FutureProvider, invalidate sau khi thay đổi
final pinEnabledProvider = FutureProvider<bool>((ref) async {
  final val = await ref.watch(settingsRepositoryProvider).get('pin_enabled');
  return val == 'true';
});

/// Global tab index — shared between DashboardScreen and MainShell
class _NavTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void goTo(int index) => state = index;
}

final navTabProvider = NotifierProvider<_NavTabNotifier, int>(
  _NavTabNotifier.new);

/// Tab index constants
class NavTab {
  static const home      = 0;
  static const pos       = 1;
  static const inventory = 2;
  static const finance   = 3;
  static const loyalty   = 4;
  static const report    = 5;
  static const settings  = 6;
}
