import 'package:flutter/material.dart';

/// Thông tin mô tả 1 module trong Quán Nhỏ POS
/// Mỗi module phải đăng ký qua class này
class ModuleInfo {
  /// ID duy nhất của module (ví dụ: 'menu', 'pos', 'inventory')
  final String id;

  /// Tên hiển thị (ví dụ: 'Menu', 'Bán hàng', 'Kho')
  final String name;

  /// Mô tả ngắn
  final String description;

  /// Icon của module
  final IconData icon;

  /// Có phải module core không (không thể gỡ)
  final bool isCore;

  /// Module nào phải có trước khi cài module này
  final List<String> dependencies;

  /// Widget chính của module (màn hình)
  final Widget Function() screenBuilder;

  /// Widget cho dashboard (nếu có)
  final Widget Function()? dashboardWidgetBuilder;

  const ModuleInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.screenBuilder,
    this.isCore = false,
    this.dependencies = const [],
    this.dashboardWidgetBuilder,
  });
}

/// Registry quản lý tất cả module
/// Module muốn hoạt động phải đăng ký vào đây
class ModuleRegistry {
  ModuleRegistry._();

  static final ModuleRegistry _instance = ModuleRegistry._();
  static ModuleRegistry get instance => _instance;

  /// Tất cả module đã đăng ký
  final Map<String, ModuleInfo> _allModules = {};

  /// Danh sách module đang bật (user đã cài)
  final Set<String> _enabledModuleIds = {};

  /// Đăng ký 1 module mới
  void register(ModuleInfo module) {
    _allModules[module.id] = module;
  }

  /// Đăng ký nhiều module
  void registerAll(List<ModuleInfo> modules) {
    for (final module in modules) {
      register(module);
    }
  }

  /// Bật module (user cài đặt)
  bool enable(String moduleId) {
    final module = _allModules[moduleId];
    if (module == null) return false;

    // Kiểm tra dependencies
    for (final depId in module.dependencies) {
      if (!_enabledModuleIds.contains(depId)) {
        return false; // Thiếu module phụ thuộc
      }
    }

    _enabledModuleIds.add(moduleId);
    return true;
  }

  /// Tắt module (user gỡ bỏ)
  /// Trả về danh sách module bị ảnh hưởng (phụ thuộc vào module này)
  List<String> disable(String moduleId) {
    final module = _allModules[moduleId];
    if (module == null || module.isCore) return []; // Không gỡ được core

    // Tìm module nào phụ thuộc vào module này
    final affected = <String>[];
    for (final entry in _allModules.entries) {
      if (_enabledModuleIds.contains(entry.key) &&
          entry.value.dependencies.contains(moduleId)) {
        affected.add(entry.key);
      }
    }

    _enabledModuleIds.remove(moduleId);
    return affected;
  }

  /// Kiểm tra module có đang bật không
  bool isEnabled(String moduleId) => _enabledModuleIds.contains(moduleId);

  /// Lấy tất cả module đã đăng ký
  List<ModuleInfo> get allModules => _allModules.values.toList();

  /// Lấy module core (không gỡ được)
  List<ModuleInfo> get coreModules =>
      _allModules.values.where((m) => m.isCore).toList();

  /// Lấy module mở rộng (+)
  List<ModuleInfo> get extensionModules =>
      _allModules.values.where((m) => !m.isCore).toList();

  /// Lấy module đang bật
  List<ModuleInfo> get enabledModules =>
      _allModules.values
          .where((m) => _enabledModuleIds.contains(m.id))
          .toList();

  /// Bật tất cả module core
  void enableAllCore() {
    for (final module in coreModules) {
      _enabledModuleIds.add(module.id);
    }
  }
}
