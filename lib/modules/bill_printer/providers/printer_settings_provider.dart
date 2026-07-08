import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/bill_preview_screen.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/user_auth_service.dart';
import 'package:uuid/uuid.dart';

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
  final bool autoOpenDrawer;
  final bool autoPrintServer; // Chế độ máy chủ in ấn (Auto-print từ Cloud)

  const StationPrintersState({
    required this.cashier,
    required this.bepNong,
    required this.bepBar,
    required this.barLabel,
    this.autoPrintCheckout = true,
    this.autoPrintKitchen = true,
    this.autoOpenDrawer = true,
    this.autoPrintServer = false,
  });

  StationPrintersState copyWith({
    PrinterConfig? cashier,
    PrinterConfig? bepNong,
    PrinterConfig? bepBar,
    PrinterConfig? barLabel,
    bool? autoPrintCheckout,
    bool? autoPrintKitchen,
    bool? autoOpenDrawer,
    bool? autoPrintServer,
  }) =>
      StationPrintersState(
        cashier: cashier ?? this.cashier,
        bepNong: bepNong ?? this.bepNong,
        bepBar: bepBar ?? this.bepBar,
        barLabel: barLabel ?? this.barLabel,
        autoPrintCheckout: autoPrintCheckout ?? this.autoPrintCheckout,
        autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
        autoOpenDrawer: autoOpenDrawer ?? this.autoOpenDrawer,
        autoPrintServer: autoPrintServer ?? this.autoPrintServer,
      );
}

class PrinterSettingsNotifier extends Notifier<StationPrintersState> {
  StreamSubscription? _subscription;

  @override
  StationPrintersState build() {
    // Lắng nghe thay đổi của sessionProvider để tự động tải cài đặt khi đăng nhập thành công
    ref.listen<SessionData?>(sessionProvider, (previous, next) {
      if (next != null && next.storeId != null) {
        _loadSettings(next.storeId!);
      }
    });

    // Thử tải cài đặt ngay lập tức nếu session đã được khôi phục từ trước
    final initialSession = ref.read(sessionProvider);
    if (initialSession != null && initialSession.storeId != null) {
      _loadSettings(initialSession.storeId!);
    } else {
      // Fallback: Tải cấu hình từ SharedPreferences trước để giao diện hiện lập tức
      _loadLocalSettings();
    }

    ref.onDispose(() {
      _subscription?.cancel();
      _kitchenTicketsSubscription?.unsubscribe();
    });

    return const StationPrintersState(
      cashier: PrinterConfig(name: '', type: 'system', enabled: true),
      bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
      bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
      barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
      autoOpenDrawer: true,
      autoPrintServer: false,
    );
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('qn_station_printers');
    if (jsonStr != null) {
      _applyJson(jsonStr);
    }
  }

  Future<void> _loadSettings(String storeId) async {
    await _loadLocalSettings();

    try {
      // Đảm bảo x-store-id tồn tại trong Header REST của Supabase cho chính sách RLS
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      final res = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'qn_station_printers')
          .maybeSingle();

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('qn_station_printers');

      if (res != null && res['value'] != null) {
        final cloudJson = res['value'] as String;
        if (cloudJson != jsonStr) {
          _applyJson(cloudJson);
          await prefs.setString('qn_station_printers', cloudJson);
        }
      }

      // Khởi động lắng nghe in ngầm nếu chế độ Print Server được bật
      _setupPrintServerListener(storeId);

      // Đăng ký luồng lắng nghe Real-time của Supabase
      _subscription?.cancel();
      _subscription = Supabase.instance.client
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .eq('store_id', storeId)
          .listen((List<Map<String, dynamic>> rows) async {
            final row = rows.firstWhere(
              (r) => r['key'] == 'qn_station_printers',
              orElse: () => {},
            );
            if (row.isNotEmpty) {
              final newValue = row['value'] as String?;
              if (newValue != null) {
                final currentPrefs = await SharedPreferences.getInstance();
                final currentLocalJson = currentPrefs.getString('qn_station_printers');
                if (newValue != currentLocalJson) {
                  _applyJson(newValue);
                  await currentPrefs.setString('qn_station_printers', newValue);
                  
                  // Thiết lập lại listener in ngầm khi có cập nhật cấu hình từ Cloud
                  _setupPrintServerListener(storeId);
                }
              }
            }
          });
    } catch (_) {}
  }

  void _applyJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      state = StationPrintersState(
        cashier: PrinterConfig.fromMap(map['cashier'] ?? {}),
        bepNong: PrinterConfig.fromMap(map['bepNong'] ?? {}),
        bepBar: PrinterConfig.fromMap(map['bepBar'] ?? {}),
        barLabel: PrinterConfig.fromMap(map['barLabel'] ?? {}),
        autoPrintCheckout: map['autoPrintCheckout'] ?? true,
        autoPrintKitchen: map['autoPrintKitchen'] ?? true,
        autoOpenDrawer: map['autoOpenDrawer'] ?? true,
        autoPrintServer: map['autoPrintServer'] ?? false,
      );
    } catch (_) {}
  }

  Future<void> saveConfig(String station, PrinterConfig config) async {
    state = state.copyWith(
      cashier: station == 'cashier' ? config : null,
      bepNong: station == 'bepNong' ? config : null,
      bepBar: station == 'bepBar' ? config : null,
      barLabel: station == 'barLabel' ? config : null,
    );
    await _persist();
  }

  Future<void> toggleAutoPrint({bool? checkout, bool? kitchen, bool? openDrawer, bool? printServer}) async {
    state = state.copyWith(
      autoPrintCheckout: checkout ?? state.autoPrintCheckout,
      autoPrintKitchen: kitchen ?? state.autoPrintKitchen,
      autoOpenDrawer: openDrawer ?? state.autoOpenDrawer,
      autoPrintServer: printServer ?? state.autoPrintServer,
    );
    await _persist();
    
    // Khởi động hoặc dừng realtime listener ngay lập tức khi thay đổi setting
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    if (storeId != null) {
      _setupPrintServerListener(storeId);
    }
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
      'autoOpenDrawer': state.autoOpenDrawer,
      'autoPrintServer': state.autoPrintServer,
    };
    final jsonStr = jsonEncode(data);
    await prefs.setString('qn_station_printers', jsonStr);

    try {
      final session = ref.read(sessionProvider);
      final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
      print('[_persist] storeId: $storeId');
      if (storeId != null) {
        // Đảm bảo x-store-id tồn tại trong Header
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': 'qn_station_printers',
          'value': jsonStr,
        }, onConflict: 'store_id,key'); // Sửa khoảng trắng ở onConflict để trùng khớp unique constraint 100%
        print('[_persist] Supabase upsert success');
      } else {
        print('[_persist] storeId is null!');
      }
    } catch (e) {
      print('[_persist] Supabase upsert error: $e');
    }
  }

  RealtimeChannel? _kitchenTicketsSubscription;
  final Set<String> _printedTicketIds = {};

  void _setupPrintServerListener(String storeId) {
    _kitchenTicketsSubscription?.unsubscribe();
    _kitchenTicketsSubscription = null;

    if (!state.autoPrintServer) {
      print('[PrintServer] Chế độ máy chủ in ấn (Print Server) hiện đang TẮT.');
      return;
    }

    print('[PrintServer] Khởi chạy dịch vụ lắng nghe phiếu bếp realtime cho store: $storeId');
    
    // Đăng ký nhận sự kiện realtime INSERT trên bảng kitchen_tickets
    _kitchenTicketsSubscription = Supabase.instance.client
        .channel('print_server_tickets')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'kitchen_tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;

            final ticketId = newRow['id'] as String?;
            if (ticketId == null) return;

            if (_printedTicketIds.contains(ticketId)) return;
            _printedTicketIds.add(ticketId);

            print('[PrintServer] Phát hiện phiếu bếp mới: $ticketId. Đang tải chi tiết món để in...');
            
            try {
              // Chờ 800ms để đảm bảo các items liên kết đã kịp lưu vào database
              await Future.delayed(const Duration(milliseconds: 800));

              // Tải thông tin ticket
              final ticketData = await Supabase.instance.client
                  .from('kitchen_tickets')
                  .select()
                  .eq('id', ticketId)
                  .maybeSingle();

              if (ticketData == null) return;

              // Tải thông tin items của ticket
              final itemsData = await Supabase.instance.client
                  .from('kitchen_ticket_items')
                  .select()
                  .eq('ticket_id', ticketId);

              if (itemsData.isEmpty) return;

              // Tải tên bàn từ ban_sessions
              String tableName = 'Mang về';
              final sessionId = ticketData['order_id'] as String?;
              if (sessionId != null) {
                final sessionData = await Supabase.instance.client
                    .from('ban_sessions')
                    .select('label')
                    .eq('id', sessionId)
                    .maybeSingle();
                if (sessionData != null) {
                  tableName = sessionData['label'] as String? ?? 'Mang về';
                }
              }

              // Build BillData cho phiếu bếp
              final note = ticketData['note'] as String? ?? '';
              final orderNumber = note.isNotEmpty ? note : ticketId.substring(0, 8).toUpperCase();

              final List<BillItem> billItems = [];
              for (final item in itemsData) {
                final name = (item['product_name'] as String?) ?? (item['name'] as String?) ?? '';
                final qty = ((item['quantity'] as num?) ?? (item['qty'] as num?) ?? 1).toInt();
                final stationCode = (item['station_code'] as String?) ?? 'bep_nong';

                String? noteText;
                final rawNote = (item['modifiers_json'] as String?) ?? (item['kitchen_note'] as String?) ?? (item['free_note'] as String?);
                if (rawNote != null && rawNote.isNotEmpty) {
                  try {
                    final decoded = jsonDecode(rawNote);
                    if (decoded is List) {
                      noteText = decoded.map<String>((m) {
                        if (m is Map) {
                          final nameVal = m['name'] as String? ?? '';
                          final qtyVal  = (m['qty'] as num?)?.toInt() ?? 1;
                          final typeVal = m['type'] as String? ?? '';
                          if (typeVal == 'topping') {
                            return qtyVal > 1 ? '+$nameVal ×$qtyVal' : '+$nameVal';
                          }
                          return nameVal;
                        }
                        return '$m';
                      }).where((s) => s.isNotEmpty).join(', ');
                    } else {
                      noteText = rawNote;
                    }
                  } catch (_) {
                    noteText = rawNote;
                  }
                }

                billItems.add(BillItem(
                  name: name,
                  qty: qty,
                  price: 0,
                  note: noteText,
                  stationCode: stationCode,
                ));
              }

              final billData = BillData(
                shopName: 'QUÁN NHỎ POS',
                shopAddress: '',
                shopPhone: '',
                orderNumber: orderNumber,
                createdAt: DateTime.now(),
                tableName: tableName,
                items: billItems,
                subtotal: 0,
                total: 0,
                type: BillType.kitchen,
                note: '',
              );

              print('[PrintServer] Bắt đầu đẩy in phiếu bếp $orderNumber...');
              await StationPrinterDispatcher.printBill(billData, this.state, onlyKitchen: true);
              print('[PrintServer] Đã đẩy in thành công!');
            } catch (e) {
              print('[PrintServer] Lỗi xử lý in: $e');
            }
          },
        );
    _kitchenTicketsSubscription!.subscribe();
  }
}

final printerSettingsProvider =
    NotifierProvider<PrinterSettingsNotifier, StationPrintersState>(PrinterSettingsNotifier.new);

final systemPrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return Printing.listPrinters();
});
