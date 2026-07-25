import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/bill_preview_screen.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/user_auth_service.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/app_logger.dart';

Future<void> writePrintLog(String message) async {
  if (message.contains('[Polling Orders]') || message.contains('[Polling Tickets]')) return;
  AppLogger.info('printer', message);
}

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
    // Tải đệm lịch sử đã in từ SharedPreferences đĩa cứng ngay khi khởi tạo
    _loadPrintedIdsFromPrefs();

    // Lắng nghe thay đổi của sessionProvider để tự động tải cài đặt khi đăng nhập thành công
    ref.listen<SessionData?>(sessionProvider, (previous, next) {
      if (next != null && next.storeId != null) {
        _loadSettings(next.storeId!);
      } else {
        _kitchenTicketsSubscription?.unsubscribe();
        _kitchenTicketsSubscription = null;
        _ordersSubscription?.unsubscribe();
        _ordersSubscription = null;
        _pollTimer?.cancel();
        _pollTimer = null;
        _activeStoreId = null;
        // KHÔNG clear _printedTicketIds và _printedOrderIds để bảo vệ vết đã in trên đĩa
        writePrintLog('[PrintServer] Tam dung cac listener in an do dang xuat (Bao ve vet da in).');
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
      _ordersSubscription?.unsubscribe();
      _pollTimer?.cancel();
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

  Future<String> _getSettingsKey() async {
    final info = await StoreAuthService.getStoreInfo();
    var deviceId = info['device_id'];
    if (deviceId == null || deviceId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }
    }
    AppLogger.setDeviceId(deviceId);
    return 'qn_station_printers_global';
  }

  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getSettingsKey();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        _applyJson(jsonStr);
        final initialSession = ref.read(sessionProvider);
        if (initialSession != null && initialSession.storeId != null && state.autoPrintServer) {
          _setupPrintServerListener(initialSession.storeId!);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSettings(String storeId) async {
    await _loadLocalSettings();

    try {
      final key = await _getSettingsKey();
      // Đảm bảo x-store-id tồn tại trong Header REST của Supabase cho chính sách RLS
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      final res = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', key)
          .maybeSingle();

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);

      if (res != null && res['value'] != null) {
        final cloudJson = res['value'] as String;
        if (cloudJson != jsonStr) {
          _applyJson(cloudJson);
          await prefs.setString(key, cloudJson);
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
            final settingsKey = await _getSettingsKey();
            final row = rows.firstWhere(
              (r) => r['key'] == settingsKey,
              orElse: () => {},
            );
            if (row.isNotEmpty) {
              final newValue = row['value'] as String?;
              if (newValue != null) {
                final currentPrefs = await SharedPreferences.getInstance();
                final currentLocalJson = currentPrefs.getString(settingsKey);
                if (newValue != currentLocalJson) {
                  _applyJson(newValue);
                  await currentPrefs.setString(settingsKey, newValue);
                  
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
      _saveLocalOnly();
    } catch (_) {}
  }

  Future<void> _saveLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getSettingsKey();
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
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> saveConfig(String station, PrinterConfig config) async {
    state = state.copyWith(
      cashier: station == 'cashier' ? config : null,
      bepNong: station == 'bepNong' ? config : null,
      bepBar: station == 'bepBar' ? config : null,
      barLabel: station == 'barLabel' ? config : null,
    );
    AppLogger.info('settings', 'Thay doi cau hinh may in tram $station: enabled=${config.enabled}, name=${config.name}, type=${config.type}');
    await _persist();
  }

  Future<void> toggleAutoPrint({bool? checkout, bool? kitchen, bool? openDrawer, bool? printServer}) async {
    state = state.copyWith(
      autoPrintCheckout: checkout ?? state.autoPrintCheckout,
      autoPrintKitchen: kitchen ?? state.autoPrintKitchen,
      autoOpenDrawer: openDrawer ?? state.autoOpenDrawer,
      autoPrintServer: printServer ?? state.autoPrintServer,
    );
    AppLogger.info('settings', 'Thay doi tuy chon in tu dong: PrintCheckout=$checkout, PrintKitchen=$kitchen, OpenDrawer=$openDrawer, PrintServer=$printServer');
    await _persist();
    
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    if (storeId != null) {
      _setupPrintServerListener(storeId);
    }
  }

  Future<void> _persist() async {
    try {
      final key = await _getSettingsKey();
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
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonStr);

      final session = ref.read(sessionProvider);
      final storeId = session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
      print('[_persist] storeId: $storeId, key: $key');
      if (storeId != null) {
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': key,
          'value': jsonStr,
        }, onConflict: 'store_id,key');
        print('[_persist] Supabase upsert success for key: $key');
      } else {
        print('[_persist] storeId is null!');
      }
    } catch (e) {
      print('[_persist] Supabase upsert error: $e');
    }
  }

  RealtimeChannel? _kitchenTicketsSubscription;
  RealtimeChannel? _ordersSubscription;
  final Set<String> _printedTicketIds = {};
  final Set<String> _printedOrderIds = {};
  Timer? _pollTimer;
  DateTime? _startupTime;
  String? _activeStoreId;
  bool _isWarmedUp = false;

  // ── Khởi động ấm hệ thống máy in & Font tiếng Việt (Warmup) ────────────────
  Future<void> _warmupPrinting() async {
    if (_isWarmedUp) return;
    _isWarmedUp = true;
    try {
      writePrintLog('[Warmup] Dang nap san Google Fonts & Quet danh sach may in OS...');
      await Future.wait([
        PdfGoogleFonts.notoSansRegular(),
        PdfGoogleFonts.notoSansBold(),
      ]);
      if (!kIsWeb) {
        await Printing.listPrinters();
      }
      writePrintLog('[Warmup] He thong in an da duoc khoi dong am thanh cong!');
    } catch (e) {
      writePrintLog('[Warmup Error] Loi khoi dong am may in: $e');
    }
  }

  // ── Lưu vết đệm ID đã in xuống SharedPreferences ──────────────────────────
  Future<void> _loadPrintedIdsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tickets = prefs.getStringList('qn_printed_ticket_ids') ?? [];
      final orders = prefs.getStringList('qn_printed_order_ids') ?? [];
      _printedTicketIds.addAll(tickets);
      _printedOrderIds.addAll(orders);
      writePrintLog('[PrintCache] Da nap ${_printedTicketIds.length} ticket_ids va ${_printedOrderIds.length} order_ids tu SharedPrefs.');
    } catch (e) {
      writePrintLog('[PrintCache Error] Loi nap print cache: $e');
    }
  }

  Future<void> _markTicketPrinted(String id) async {
    _printedTicketIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _printedTicketIds.toList();
      final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
      await prefs.setStringList('qn_printed_ticket_ids', trimmed);
    } catch (_) {}
  }

  Future<void> _markOrderPrinted(String id) async {
    _printedOrderIds.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _printedOrderIds.toList();
      final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
      await prefs.setStringList('qn_printed_order_ids', trimmed);
    } catch (_) {}
  }

  Future<void> _setupPrintServerListener(String storeId) async {
    // Guard chống race condition khi _setupPrintServerListener bị gọi liên tiếp trong vài ms
    if (_activeStoreId == storeId && _kitchenTicketsSubscription != null) {
      writePrintLog('[Setup] Stream cho storeId $storeId da ton tai. Bo qua re-init.');
      return;
    }
    _activeStoreId = storeId;

    _kitchenTicketsSubscription?.unsubscribe();
    _kitchenTicketsSubscription = null;
    _ordersSubscription?.unsubscribe();
    _ordersSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    writePrintLog('[Setup] storeId: $storeId, autoPrintServer: ${state.autoPrintServer}');

    if (!state.autoPrintServer) {
      print('[PrintServer] Chế độ máy chủ in ấn (Print Server) hiện đang TẮT.');
      return;
    }

    // Tự động khởi động ấm Font & máy in ngay lập tức
    _warmupPrinting();

    final startupTime = DateTime.now().toUtc();
    _startupTime = startupTime;
    final past12hIso = startupTime.subtract(const Duration(hours: 12)).toIso8601String();

    // Nạp lịch sử phiếu bếp trong 12h qua để tuyệt đối không in lại phiếu cũ
    try {
      final oldTickets = await Supabase.instance.client
          .from('kitchen_tickets')
          .select('id')
          .eq('store_id', storeId)
          .gte('sent_at', past12hIso)
          .order('sent_at', ascending: false)
          .limit(200);
      for (final row in oldTickets) {
        final id = row['id'] as String?;
        if (id != null) _markTicketPrinted(id);
      }
      writePrintLog('[PrintServer] Da nap ${_printedTicketIds.length} phieu bep lich su (12h).');
    } catch (e) {
      writePrintLog('[PrintServer Error] Loi nap phieu bep lich su: $e');
    }

    // Nạp lịch sử hoá đơn trong 12h qua để tuyệt đối không in lại bill cũ
    try {
      final oldOrders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('store_id', storeId)
          .inFilter('status', ['paid', 'completed'])
          .gte('created_at', past12hIso)
          .order('created_at', ascending: false)
          .limit(200);
      for (final row in oldOrders) {
        final id = row['id'] as String?;
        if (id != null) _markOrderPrinted(id);
      }
      writePrintLog('[PrintServer] Da nap ${_printedOrderIds.length} hoa don lich su (12h).');
    } catch (e) {
      writePrintLog('[PrintServer Error] Loi nap hoa don lich su: $e');
    }

    print('[PrintServer] Khởi chạy dịch vụ lắng nghe in ấn realtime (Bếp & Hóa đơn) cho store: $storeId');
    
    // 1. WebSocket Realtime - Lắng nghe kitchen_tickets
    _kitchenTicketsSubscription = Supabase.instance.client
        .channel('print_server_tickets')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'kitchen_tickets',
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            final ticketStoreId = newRow['store_id'] as String? ?? '';
            if (ticketStoreId != storeId) return;
            final ticketId = newRow['id'] as String?;
            writePrintLog('[WS Ticket] Nhận ticket: $ticketId');
            if (ticketId != null) {
              _processTicket(ticketId, storeId);
            }
          },
        );
    _kitchenTicketsSubscription!.subscribe((status, [error]) {
      writePrintLog('[WS Ticket Status] Kênh: $status. Error: $error');
      print('[PrintServer] Kênh Realtime phiếu bếp: $status ${error != null ? "- Lỗi: $error" : ""}');
    });

    // 2. WebSocket Realtime - Lắng nghe orders (đã thanh toán)
    _ordersSubscription = Supabase.instance.client
        .channel('print_server_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            final orderStoreId = newRow['store_id'] as String? ?? '';
            if (orderStoreId != storeId) return;
            final orderId = newRow['id'] as String?;
            writePrintLog('[WS Order] Nhận order: $orderId');
            if (orderId != null) {
              _processOrder(orderId, storeId);
            }
          },
        );
    _ordersSubscription!.subscribe((status, [error]) {
      writePrintLog('[WS Order Status] Kênh: $status. Error: $error');
      print('[PrintServer] Kênh Realtime đơn hàng: $status ${error != null ? "- Lỗi: $error" : ""}');
    });

    // 3. Polling Fallback - Tự động quét in bù mỗi 30 giây đề phòng mất mạng / socket lỗi
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _pollActiveTicketsAndOrders(storeId);
    });
  }

  Future<void> _processTicket(String ticketId, String storeId) async {
    if (_printedTicketIds.contains(ticketId)) {
      writePrintLog('[Process Ticket] Ticket $ticketId đã được in. Bỏ qua.');
      return;
    }
    _markTicketPrinted(ticketId); // Đánh dấu đang xử lý và lưu đệm đĩa cứng ngay lập tức

    writePrintLog('[Process Ticket] Đang tải chi tiết cho ticket: $ticketId');
    print('[PrintServer] Xử lý phiếu bếp mới: $ticketId. Đang tải chi tiết món...');
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final ticketData = await Supabase.instance.client
          .from('kitchen_tickets')
          .select()
          .eq('id', ticketId)
          .maybeSingle();

      if (ticketData == null) {
        writePrintLog('[Process Ticket] Không tìm thấy ticket: $ticketId trên DB. Rollback.');
        _printedTicketIds.remove(ticketId); // Rollback nếu không tìm thấy bản ghi
        return;
      }

      final itemsData = await Supabase.instance.client
          .from('kitchen_ticket_items')
          .select()
          .eq('ticket_id', ticketId);

      if (itemsData.isEmpty) {
        writePrintLog('[Process Ticket] Ticket $ticketId trống món (itemsData empty). Rollback.');
        _printedTicketIds.remove(ticketId); // Rollback nếu món ăn chưa kịp lưu
        return;
      }

      final tableName = ticketData['table_label'] as String? ?? 'Mang về';

      final note = ticketData['note'] as String? ?? '';
      final round = ticketData['round'] as int? ?? 1;
      final orderNumber = 'Bep-$round';

      final List<BillItem> billItems = [];
      for (final item in itemsData) {
        final name = (item['product_name'] as String?) ?? (item['name'] as String?) ?? '';
        final qty = ((item['quantity'] as num?) ?? (item['qty'] as num?) ?? 1).toInt();
        final stationCode = (item['station_code'] as String?) ?? 'bep_nong';

        String? noteText;
        final rawMods = (item['modifiers_json'] as String?) ?? (item['kitchen_note'] as String?);
        final freeNote = item['free_note'] as String?;
        final List<String> noteParts = [];

        if (rawMods != null && rawMods.isNotEmpty && rawMods != '[]') {
          try {
            final decoded = jsonDecode(rawMods);
            if (decoded is List) {
              final modsText = decoded.map<String>((m) {
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
              if (modsText.isNotEmpty) {
                noteParts.add('+ $modsText');
              }
            } else {
              noteParts.add(rawMods);
            }
          } catch (_) {
            noteParts.add(rawMods);
          }
        }

        if (freeNote != null && freeNote.trim().isNotEmpty) {
          noteParts.add('Ghi chú: ${freeNote.trim()}');
        }

        if (noteParts.isNotEmpty) {
          noteText = noteParts.join('\n');
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
        waiterName: note,
      );

      writePrintLog('[Process Ticket] Đẩy in: $orderNumber. Bàn: $tableName, số món: ${billItems.length}');
      print('[PrintServer] Bắt đầu đẩy in phiếu bếp $orderNumber...');
      await StationPrinterDispatcher.printBill(billData, this.state, onlyKitchen: true);
      writePrintLog('[Process Ticket] In thành công!');
      print('[PrintServer] Đã đẩy in thành công!');
    } catch (e) {
      writePrintLog('[Process Ticket ERROR] Lỗi in ticket $ticketId: $e');
      print('[PrintServer] Lỗi xử lý in bếp: $e');
      _printedTicketIds.remove(ticketId); // Rollback nếu in lỗi để chu kỳ sau quét in lại
    }
  }

  Future<void> _processOrder(String orderId, String storeId) async {
    if (_printedOrderIds.contains(orderId)) {
      writePrintLog('[Process Order] Order $orderId đã in. Bỏ qua.');
      return;
    }
    _markOrderPrinted(orderId); // Đánh dấu đang xử lý và lưu đệm đĩa cứng ngay lập tức

    writePrintLog('[Process Order] Đang tải chi tiết cho order: $orderId');
    print('[PrintServer] Xử lý đơn hàng mới: $orderId. Đang tải chi tiết để in bill thanh toán...');
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final orderData = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderData == null) {
        writePrintLog('[Process Order] Không tìm thấy order: $orderId trên DB. Rollback.');
        _printedOrderIds.remove(orderId); // Rollback nếu không tìm thấy
        return;
      }

      final status = orderData['status'] as String? ?? 'open';
      writePrintLog('[Process Order] Order status: $status');
      if (status != 'paid' && status != 'completed') {
        writePrintLog('[Process Order] Đơn hàng $orderId chưa thanh toán (status=$status). Bỏ qua.');
        print('[PrintServer] Đơn hàng $orderId chưa được thanh toán (status=$status). Bỏ qua.');
        return;
      }

      final itemsData = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      if (itemsData.isEmpty) {
        writePrintLog('[Process Order] Order $orderId trống món (itemsData empty). Rollback.');
        _printedOrderIds.remove(orderId); // Rollback nếu món ăn chưa kịp lưu
        return;
      }

      final storeRow = await Supabase.instance.client
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();

      final shopName = storeRow?['name'] as String? ?? 'QUÁN NHỎ POS';
      const String? shopPhone = null;
      const String? shopAddress = null;

      String tableName = 'Mang về';
      final sourceId = orderData['source_id'] as String?;
      final sourceType = orderData['source_type'] as String?;
      writePrintLog('[Process Order] sourceType: $sourceType, sourceId: $sourceId');
      if ((sourceType == 'table' || sourceType == 'ban') && sourceId != null) {
        final tableRow = await Supabase.instance.client
            .from('ban_dining_tables')
            .select('name, label')
            .eq('id', sourceId)
            .maybeSingle();
        if (tableRow != null) {
          tableName = (tableRow['name'] as String?) ?? (tableRow['label'] as String?) ?? 'Mang về';
        }
      }

      final orderNumber = orderId.substring(0, 8).toUpperCase();
      final totalAmount = ((orderData['total'] as num?) ?? 0).toDouble();

      final List<BillItem> billItems = [];
      for (final item in itemsData) {
        final name = item['name'] as String? ?? '';
        final qty = ((item['qty'] as num?) ?? 1).toInt();
        final price = ((item['unit_price'] as num?) ?? 0).toDouble();
        final note = item['note'] as String?;

        billItems.add(BillItem(
          name: name,
          qty: qty,
          price: price,
          note: note,
          stationCode: 'thu_ngan',
        ));
      }

      final billData = BillData(
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        tableName: tableName,
        items: billItems,
        subtotal: totalAmount,
        total: totalAmount,
        type: BillType.receipt,
        note: orderData['note'] as String? ?? '',
      );

      writePrintLog('[Process Order] Đẩy in hoá đơn: $orderNumber. Bàn: $tableName, số món: ${billItems.length}');
      print('[PrintServer] Bắt đầu đẩy in hoá đơn thanh toán $orderNumber...');
      await StationPrinterDispatcher.printBill(billData, this.state, onlyReceipt: true);
      writePrintLog('[Process Order] In hoá đơn thành công!');
      print('[PrintServer] Đã đẩy in hoá đơn thành công!');
    } catch (e) {
      writePrintLog('[Process Order ERROR] Lỗi in hoá đơn $orderId: $e');
      print('[PrintServer] Lỗi xử lý in hoá đơn: $e');
      _printedOrderIds.remove(orderId); // Rollback nếu in lỗi để chu kỳ sau quét in lại
    }
  }

  Future<void> _pollActiveTicketsAndOrders(String storeId) async {
    try {
      // 1. Quét 10 phiếu bếp mới nhất đang ở trạng thái 'chờ' và được gửi gần đây
      final limitTime = (_startupTime ?? DateTime.now().toUtc()).subtract(const Duration(minutes: 5)).toIso8601String();
      final tickets = await Supabase.instance.client
          .from('kitchen_tickets')
          .select('id')
          .eq('store_id', storeId)
          .eq('status', 'cho')
          .gt('sent_at', limitTime)
          .order('sent_at', ascending: false)
          .limit(10);
      
      for (final row in tickets) {
        final ticketId = row['id'] as String?;
        if (ticketId != null && !_printedTicketIds.contains(ticketId)) {
          writePrintLog('[Polling Ticket] Phát hiện ticket chưa in: $ticketId');
          print('[PrintServer Polling] Phát hiện phiếu bếp chưa in qua WebSocket: $ticketId');
          _processTicket(ticketId, storeId);
        }
      }

      // 2. Quét 10 đơn hàng thanh toán mới nhất được thanh toán gần đây
      final orders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('store_id', storeId)
          .inFilter('status', ['paid', 'completed'])
          .gt('created_at', limitTime)
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in orders) {
        final orderId = row['id'] as String?;
        if (orderId != null && !_printedOrderIds.contains(orderId)) {
          writePrintLog('[Polling Order] Phát hiện order chưa in: $orderId');
          print('[PrintServer Polling] Phát hiện đơn hàng chưa in qua WebSocket: $orderId');
          _processOrder(orderId, storeId);
        }
      }
    } catch (e) {
      writePrintLog('[Polling ERROR] Lỗi quét db: $e');
      print('[PrintServer Polling] Lỗi quét dữ liệu in: $e');
    }
  }
}

final printerSettingsProvider =
    NotifierProvider<PrinterSettingsNotifier, StationPrintersState>(PrinterSettingsNotifier.new);

final systemPrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return Printing.listPrinters();
});
