import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterConfig {
  final String name; // printer name or IP
  final String type; // 'system' | 'network'
  final bool enabled;

  const PrinterConfig({
    required this.name,
    required this.type,
    this.enabled = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'enabled': enabled,
      };

  factory PrinterConfig.fromMap(Map<String, dynamic> map) => PrinterConfig(
        name: map['name'] as String? ?? '',
        type: map['type'] as String? ?? 'system',
        enabled: map['enabled'] as bool? ?? false,
      );

  PrinterConfig copyWith({String? name, String? type, bool? enabled}) =>
      PrinterConfig(
        name: name ?? this.name,
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
      );
}

class StationPrintersState {
  final PrinterConfig cashier;
  final PrinterConfig bepNong;
  final PrinterConfig bepBar;
  final PrinterConfig barLabel;
  final bool autoPrintCheckout;
  final bool autoPrintKitchen;

  const StationPrintersState({
    required this.cashier,
    required this.bepNong,
    required this.bepBar,
    required this.barLabel,
    this.autoPrintCheckout = true,
    this.autoPrintKitchen = true,
  });

  StationPrintersState copyWith({
    PrinterConfig? cashier,
    PrinterConfig? bepNong,
    PrinterConfig? bepBar,
    PrinterConfig? barLabel,
    bool? autoPrintCheckout,
    bool? autoPrintKitchen,
  }) =>
      StationPrintersState(
        cashier: cashier ?? this.cashier,
        bepNong: bepNong ?? this.bepNong,
        bepBar: bepBar ?? this.bepBar,
        barLabel: barLabel ?? this.barLabel,
        autoPrintCheckout: autoPrintCheckout ?? this.autoPrintCheckout,
        autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
      );
}

class PrinterSettingsNotifier extends StateNotifier<StationPrintersState> {
  PrinterSettingsNotifier()
      : super(const StationPrintersState(
          cashier: PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
          bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('qn_station_printers');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = StationPrintersState(
          cashier: PrinterConfig.fromMap(map['cashier'] ?? {}),
          bepNong: PrinterConfig.fromMap(map['bepNong'] ?? {}),
          bepBar: PrinterConfig.fromMap(map['bepBar'] ?? {}),
          barLabel: PrinterConfig.fromMap(map['barLabel'] ?? {}),
          autoPrintCheckout: map['autoPrintCheckout'] ?? true,
          autoPrintKitchen: map['autoPrintKitchen'] ?? true,
        );
      } catch (_) {}
    }
  }

  Future<void> saveConfig(String station, PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      cashier: station == 'cashier' ? config : null,
      bepNong: station == 'bepNong' ? config : null,
      bepBar: station == 'bepBar' ? config : null,
      barLabel: station == 'barLabel' ? config : null,
    );
    await _persist();
  }

  Future<void> toggleAutoPrint({bool? checkout, bool? kitchen}) async {
    state = state.copyWith(
      autoPrintCheckout: checkout ?? state.autoPrintCheckout,
      autoPrintKitchen: kitchen ?? state.autoPrintKitchen,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'cashier': state.cashier.toMap(),
      'bepNong': state.bepNong.toMap(),
      'bepBar': state.bepBar.toMap(),
      'barLabel': state.barLabel.toMap(),
      'autoPrintCheckout': state.autoPrintCheckout,
      'autoPrintKitchen': state.autoPrintKitchen,
    };
    await prefs.setString('qn_station_printers', jsonEncode(data));
  }
}

final printerSettingsProvider =
    StateNotifierProvider<PrinterSettingsNotifier, StationPrintersState>((ref) {
  return PrinterSettingsNotifier();
});

final systemPrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return Printing.listPrinters();
});
