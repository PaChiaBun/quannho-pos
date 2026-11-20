import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/repositories/ban_repository.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/vietqr_service.dart';
import '../models/qr_order_model.dart';
import '../providers/qr_order_providers.dart';
import '../services/qr_sound_service.dart';

const _kViolet = Color(0xFF8B5CF6);

/// Sheet duyệt đơn QR (dùng chung TABLE và COUNTER).
///
/// - Mở từ hàng chờ: tự nhận đơn (`claim_qr_request_v4`).
/// - TABLE: hiện bàn khách chọn, đổi bàn bằng dropdown, một nút
///   "Duyệt & gửi bếp".
/// - COUNTER: một nút "Đã thu tiền & gửi bếp" (cần quyền `pos.checkout`).
/// - Theo dõi đơn theo id từ hàng chờ, không dùng ảnh chụp tĩnh.
class QrOrderReviewSheet extends ConsumerStatefulWidget {
  final QrRequestModel request;
  final VoidCallback? onApproved;
  final VoidCallback? onRejected;

  const QrOrderReviewSheet({
    super.key,
    required this.request,
    this.onApproved,
    this.onRejected,
  });

  @override
  ConsumerState<QrOrderReviewSheet> createState() => _QrOrderReviewSheetState();
}

class _QrOrderReviewSheetState extends ConsumerState<QrOrderReviewSheet> {
  final BanRepository _banRepo = BanRepository();
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  late QrRequestModel _req;
  late List<QrRequestItemModel> _items;
  String _storeId = '';
  String _paymentMethod = 'cash';
  List<BanTableModel> _tables = [];

  bool _initializing = true;
  String? _initError;
  bool _busy = false; // đang gọi server
  bool _closing = false; // đã thành công, chờ pop: khóa vĩnh viễn
  bool _dirty = false; // có sửa món chưa lưu
  bool _needsSync = false; // lỗi mạng sau khi gọi: cần refetch trước khi thử lại
  bool _remoteChanged = false;
  bool _goneHandled = false;

  @override
  void initState() {
    super.initState();
    _req = widget.request;
    _items = List.of(widget.request.items);
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _initError = null;
    });
    try {
      final info = await StoreAuthService.getStoreInfo();
      _storeId = info['store_id'] ?? widget.request.storeId;
      if (_storeId.isEmpty) {
        throw StateError('no store');
      }
      if (_req.isTable) {
        try {
          _tables = await _banRepo.getAllTables();
        } catch (_) {
          // Không tải được danh sách bàn: vẫn duyệt được với bàn khách chọn.
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = 'Không xác định được quán. Vui lòng thử lại.';
        });
      }
      return;
    }

    // Mở đơn từ hàng chờ = nhận đơn (idempotent với chính mình).
    if (_req.isSubmitted || _req.isClaimed) {
      final res = await ref
          .read(qrOrderRepoProvider)
          .claimRequest(requestId: _req.id, storeId: _storeId);
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        setState(() {
          _req = res.data!;
          _items = List.of(_req.items);
          _initializing = false;
        });
        ref.invalidate(qrActivePipelineStreamProvider);
        return;
      }
      if (res.errorCode == QrErrorCode.alreadyClaimed ||
          res.errorCode == QrErrorCode.notClaimer) {
        _toast(QrErrorCode.toUserMessage(res.errorCode), error: true);
        ref.invalidate(qrActivePipelineStreamProvider);
        _closeSheet();
        return;
      }
      setState(() {
        _initializing = false;
        _initError = res.errorCode == QrErrorCode.networkError
            ? res.message
            : QrErrorCode.toUserMessage(res.errorCode, res.message);
      });
      return;
    }
    setState(() => _initializing = false);
  }

  bool get _editable => _req.isClaimed && !_closing;

  double get _localTotal =>
      _items.fold<double>(0, (s, it) => s + it.unitPrice * it.quantity);

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  void _closeSheet() {
    if (!mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  /// Đồng bộ lại version/status/món từ server. Trả false nếu lỗi.
  Future<bool> _refresh({bool keepLocalItems = false}) async {
    final res = await ref
        .read(qrOrderRepoProvider)
        .getRequestDetail(requestId: _req.id, storeId: _storeId);
    if (!mounted) return false;
    if (res.isSuccess && res.data != null) {
      setState(() {
        _req = res.data!;
        if (!keepLocalItems) {
          _items = List.of(_req.items);
          _dirty = false;
        }
        _needsSync = false;
        _remoteChanged = false;
      });
      return true;
    }
    return false;
  }

  void _applyRemote(QrRequestModel next) {
    setState(() {
      _req = next;
      _items = List.of(next.items);
      _remoteChanged = false;
    });
  }

  // ── Sửa món ─────────────────────────────────────────────────────────────────
  void _updateItemQuantity(int index, int delta) {
    if (!_editable || _busy) return;
    setState(() {
      final item = _items[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _items.removeAt(index);
      } else if (newQty <= 99) {
        _items[index] = item.copyWith(
          quantity: newQty,
          subtotal: item.unitPrice * newQty,
        );
      }
      _dirty = true;
    });
  }

  Future<void> _openAddProductPicker() async {
    if (!_editable || _busy) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerSheet(storeId: _storeId),
    );
    if (selected == null || !mounted) return;
    final pId = selected['id']?.toString();
    final pName = selected['name']?.toString() ?? '';
    final pPrice = (selected['sell_price'] as num?)?.toDouble() ?? 0.0;
    if (pId == null) return;
    setState(() {
      final idx = _items.indexWhere(
        (it) => it.productId == pId && it.modifiersJson.isEmpty,
      );
      if (idx != -1) {
        final ext = _items[idx];
        _items[idx] = ext.copyWith(
          quantity: ext.quantity + 1,
          subtotal: ext.unitPrice * (ext.quantity + 1),
        );
      } else {
        _items.add(
          QrRequestItemModel(
            id: '',
            requestId: _req.id,
            productId: pId,
            productName: pName,
            unitPrice: pPrice,
            quantity: 1,
            subtotal: pPrice,
          ),
        );
      }
      _dirty = true;
    });
  }

  /// Lưu món (update_qr_order_items_v4) rồi lấy lại tổng/version từ server.
  Future<bool> _saveItems() async {
    if (!_dirty) return true;
    final res = await ref
        .read(qrOrderRepoProvider)
        .updateOrderItems(
          requestId: _req.id,
          storeId: _storeId,
          expectedVersion: _req.version,
          items: _items
              .map(
                (it) => {
                  'product_id': it.productId,
                  'quantity': it.quantity,
                  'modifiers_json': it.modifiersJson,
                  'note': it.note,
                },
              )
              .toList(),
        );
    if (!mounted) return false;
    if (res.isSuccess) {
      if (await _refresh()) return true;
      // Đã lưu nhưng chưa tải lại được: lấy version từ phản hồi.
      final v = res.data?['version'];
      setState(() {
        if (v is num) _req = _req.copyWith(version: v.toInt());
        _dirty = false;
        _needsSync = true;
      });
      return true;
    }
    await _handleFailure(res.errorCode, res.message);
    return false;
  }

  Future<void> _onSavePressed() async {
    if (_busy || _closing || !_dirty) return;
    setState(() => _busy = true);
    await _saveItems();
    if (mounted) setState(() => _busy = false);
  }

  // ── Đổi bàn ─────────────────────────────────────────────────────────────────
  Future<void> _changeTable(String tableId) async {
    if (_busy || !_editable || tableId == _req.tableId) return;
    setState(() => _busy = true);
    final res = await ref
        .read(qrOrderRepoProvider)
        .setOrderTable(requestId: _req.id, storeId: _storeId, tableId: tableId);
    if (!mounted) return;
    if (res.isSuccess) {
      await _refresh(keepLocalItems: _dirty);
      ref.invalidate(qrActivePipelineStreamProvider);
    } else {
      await _handleFailure(res.errorCode, res.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── Hành động chính ─────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_busy || _closing) return;
    if (_items.isEmpty) {
      _toast('Đơn không có món nào để gửi bếp.', error: true);
      return;
    }
    if (_req.isTable && (_req.tableId == null || _req.tableId!.isEmpty)) {
      _toast('Vui lòng chọn bàn trước khi gửi bếp.', error: true);
      return;
    }
    setState(() => _busy = true);

    // Lỗi mạng lần trước: đồng bộ version/status trước khi thử lại.
    if (_needsSync && !await _refresh(keepLocalItems: _dirty)) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Chưa kết nối được máy chủ. Vui lòng thử lại.', error: true);
      }
      return;
    }
    if (!mounted) return;
    if (_req.isSentKitchen) {
      _finishSuccess();
      return;
    }

    if (!await _saveItems()) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;

    final repo = ref.read(qrOrderRepoProvider);
    final res = _req.isTable
        ? await repo.approveAndSendTable(
            requestId: _req.id,
            storeId: _storeId,
            version: _req.version,
          )
        : await repo.payAndSendCounter(
            requestId: _req.id,
            storeId: _storeId,
            version: _req.version,
            paymentMethod: _paymentMethod,
          );
    if (!mounted) return;

    if (res.isSuccess) {
      _finishSuccess();
      return;
    }
    await _handleFailure(res.errorCode, res.message, sending: true);
    if (mounted && !_closing) setState(() => _busy = false);
  }

  void _finishSuccess() {
    // _busy/_closing giữ true cho tới khi sheet pop xong: chống bấm đúp.
    _busy = true;
    _closing = true;
    QrSoundService.playNotificationSound();
    ref.invalidate(qrActivePipelineStreamProvider);
    widget.onApproved?.call();
    _toast(
      _req.isTable
          ? 'Đã gửi bếp đơn ${_req.tableName ?? "bàn"}.'
          : 'Đã thu tiền và gửi bếp đơn mang đi ${_req.displayPickupCode}.',
    );
    Navigator.of(context).pop();
  }

  Future<void> _handleFailure(
    String? code,
    String? message, {
    bool sending = false,
  }) async {
    switch (code) {
      case QrErrorCode.versionConflict:
        await _refresh();
        _toast(QrErrorCode.toUserMessage(code), error: true);
        return;
      case QrErrorCode.alreadyClaimed:
      case QrErrorCode.notClaimer:
        ref.invalidate(qrActivePipelineStreamProvider);
        _toast(QrErrorCode.toUserMessage(code), error: true);
        _closeSheet();
        return;
      case QrErrorCode.networkError:
        // Có thể đã commit mà mất phản hồi: đọc lại trạng thái thật.
        final ok = await _refresh(keepLocalItems: _dirty);
        if (!mounted) return;
        if (ok && _req.isSentKitchen) {
          _finishSuccess();
          return;
        }
        if (!ok) _needsSync = true;
        _toast(
          ok
              ? 'Mạng không ổn định. Đã tải lại đơn, vui lòng kiểm tra rồi bấm lại.'
              : 'Mất kết nối. Vui lòng kiểm tra mạng rồi thử lại.',
          error: true,
        );
        return;
      case QrErrorCode.alreadySent:
      case QrErrorCode.invalidState:
      case QrErrorCode.requestExpired:
        await _refresh();
        if (!mounted) return;
        if (_req.isSentKitchen && sending) {
          _finishSuccess();
          return;
        }
        _toast(QrErrorCode.toUserMessage(code, message), error: true);
        if (!_req.isOpen) _closeSheet();
        return;
      default:
        _toast(QrErrorCode.toUserMessage(code, message), error: true);
    }
  }

  // ── Từ chối ─────────────────────────────────────────────────────────────────
  Future<void> _handleReject() async {
    if (_busy || _closing) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (!mounted || reason == null) return;

    setState(() => _busy = true);
    final res = await ref
        .read(qrOrderRepoProvider)
        .cancelOrder(requestId: _req.id, storeId: _storeId, reason: reason);
    if (!mounted) return;
    if (res.isSuccess) {
      _busy = true;
      ref.invalidate(qrActivePipelineStreamProvider);
      widget.onRejected?.call();
      _toast('Đã từ chối đơn.');
      _closeSheet();
      return;
    }
    await _handleFailure(res.errorCode, res.message);
    if (mounted && !_closing) setState(() => _busy = false);
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Theo dõi đơn theo id từ hàng chờ.
    ref.listen<QrRequestModel?>(qrRequestByIdProvider(widget.request.id), (
      prev,
      next,
    ) {
      if (_busy || _closing || _initializing || _initError != null) return;
      if (next == null) {
        final p = ref.read(qrActivePipelineStreamProvider).asData?.value;
        if (p != null && p.isSuccess && !_goneHandled) {
          _goneHandled = true;
          _toast('Đơn này đã được xử lý ở thiết bị khác.', error: true);
          _closeSheet();
        }
        return;
      }
      if (next.version > _req.version) {
        if (_dirty) {
          setState(() => _remoteChanged = true);
        } else {
          _applyRemote(next);
        }
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
          ? _buildInitError()
          : _buildBody(),
    );
  }

  Widget _buildInitError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
        const SizedBox(height: 12),
        Text(_initError!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton(onPressed: _init, child: const Text('Thử lại')),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const Divider(height: 20),
        if (_req.isTable) _buildTableSelector() else _buildCounterInfo(),
        if (_remoteChanged)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Đơn vừa được cập nhật ở thiết bị khác. Lưu hoặc tải lại để đồng bộ.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_req.customerNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Khách ghi chú: ${_req.customerNote}',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Danh sách món (${_items.length}):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            TextButton.icon(
              onPressed: _editable && !_busy ? _openAddProductPicker : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm món'),
            ),
          ],
        ),
        Expanded(child: _buildItemsList()),
        const Divider(height: 20),
        _buildTotalSection(),
        const SizedBox(height: 12),
        _buildActions(),
      ],
    );
  }

  Widget _buildHeader() {
    final wait = _req.createdAt == null
        ? null
        : DateTime.now().difference(_req.createdAt!).inMinutes;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _req.isTable
                ? Icons.table_restaurant_rounded
                : Icons.shopping_bag_rounded,
            color: _kViolet,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _req.isTable ? 'ĐƠN GỌI MÓN TẠI BÀN' : 'ĐƠN MANG ĐI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                _req.displayTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (wait != null)
                Text(
                  'Chờ $wait phút',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _closing ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTableSelector() {
    final hasValue = _tables.any((t) => t.id == _req.tableId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bàn khách chọn: ${_req.tableName ?? "chưa có"}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.purple.shade900,
            ),
          ),
          if (_tables.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('tbl-${_req.tableId}'),
              initialValue: hasValue ? _req.tableId : null,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                labelText: 'Đổi sang bàn khác (nếu khách chọn sai)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: _tables
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(t.label),
                    ),
                  )
                  .toList(),
              onChanged: _busy || !_editable
                  ? null
                  : (v) {
                      if (v != null) _changeTable(v);
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterInfo() {
    final canPay = ref.canDo('pos.checkout');
    final code = _req.displayPickupCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            code.isEmpty ? 'Đơn mang đi' : 'Mã lấy món: $code',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _req.isPaid ? 'ĐÃ THANH TOÁN' : 'CHƯA THANH TOÁN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _req.isPaid
                  ? Colors.green.shade900
                  : Colors.orange.shade900,
            ),
          ),
          if (canPay && !_req.isPaid) ...[
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'cash',
                  icon: Icon(Icons.payments_rounded),
                  label: Text('Tiền mặt'),
                ),
                ButtonSegment(
                  value: 'transfer',
                  icon: Icon(Icons.qr_code_rounded),
                  label: Text('Chuyển khoản'),
                ),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() => _paymentMethod = s.first),
            ),
            if (_paymentMethod == 'transfer') ...[
              const SizedBox(height: 10),
              _buildTransferQr(),
            ],
          ],
          if (!canPay) ...[
            const SizedBox(height: 8),
            Text(
              'Chuyển thu ngân: tài khoản của bạn không có quyền thu tiền. '
              'Hãy nhờ thu ngân mở đơn này để thu tiền và gửi bếp.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferQr() {
    final settings = ref.watch(qrOrderSettingsProvider).asData?.value;
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (settings.transferAccountNo.trim().isEmpty) {
      return Text(
        'Chưa cấu hình tài khoản VietQR trong mục Thiết lập của module QR.',
        style: TextStyle(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }
    if (_dirty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Món đã thay đổi. Lưu thay đổi để tính lại tiền và hiện mã QR.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _onSavePressed,
            child: const Text('Lưu món'),
          ),
        ],
      );
    }

    final code = _req.displayPickupCode;
    final qrUrl = VietQrService.generateUrl(
      bankBin: settings.transferBankBin,
      accountNo: settings.transferAccountNo.trim(),
      accountName: settings.transferAccountName.trim(),
      amount: _req.totalAmount, // tổng do server tính
      addInfo: code.isEmpty ? 'QR' : 'QR $code',
    );
    final bankName =
        VietQrService.findByBin(settings.transferBankBin)?.shortName ??
        'Ngân hàng';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Image.network(
            qrUrl,
            width: 170,
            height: 170,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.qr_code_2_rounded,
              size: 100,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$bankName • ${settings.transferAccountNo}',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            currencyFmt.format(_req.totalAmount),
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'VietQR chỉ hỗ trợ chuyển khoản. Hãy kiểm tra tiền đã vào trước khi xác nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Đơn đang trống. Bấm "Thêm món" ở trên.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (item.modifiersJson.isNotEmpty)
                      Text(
                        '+ ${item.modifiersJson.map((m) => "${m['name'] ?? 'Topping'} (x${m['quantity'] ?? 1})").join(", ")}',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF6D28D9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      currencyFmt.format(item.unitPrice),
                      style: TextStyle(
                        fontSize: 12,
                        color: _kViolet,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.note.isNotEmpty)
                      Text(
                        'Ghi chú: ${item.note}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 22,
                  color: Colors.red,
                ),
                onPressed: _editable && !_busy
                    ? () => _updateItemQuantity(index, -1)
                    : null,
              ),
              Text(
                '${item.quantity}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 22,
                  color: Colors.green,
                ),
                onPressed: _editable && !_busy
                    ? () => _updateItemQuantity(index, 1)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dirty ? 'Tạm tính:' : 'Tổng tiền đơn:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            if (_dirty)
              GestureDetector(
                onTap: _busy ? null : _onSavePressed,
                child: Text(
                  'Chưa lưu thay đổi món - bấm để lưu',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        Text(
          currencyFmt.format(_dirty ? _localTotal : _req.totalAmount),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: _kViolet,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final canPay = _req.isTable || ref.canDo('pos.checkout');
    final ready = _editable && !_busy && canPay;
    final label = _needsSync
        ? 'THỬ LẠI'
        : _req.isTable
        ? 'DUYỆT & GỬI BẾP'
        : 'ĐÃ THU TIỀN & GỬI BẾP';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _busy || _closing ? null : _handleReject,
            child: Text(
              'Từ chối',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (canPay)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.restaurant_rounded),
              label: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              onPressed: ready ? _submit : null,
            ),
          ),
      ],
    );
  }
}

/// Hộp thoại nhập lý do từ chối (tự quản lý và dispose controller).
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController(text: 'Hết món');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Từ chối đơn gọi món',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Lý do (khách sẽ thấy)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy bỏ'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Từ chối đơn'),
        ),
      ],
    );
  }
}

/// Sheet chọn món từ thực đơn quán để thêm vào đơn review
class _ProductPickerSheet extends StatefulWidget {
  final String storeId;

  const _ProductPickerSheet({required this.storeId});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select()
          .eq('store_id', widget.storeId)
          .eq('is_active', true)
          .eq('is_deleted', false)
          .order('name');

      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      return _search.isEmpty || name.contains(_search.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chọn Món Thêm Vào Đơn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm món...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final price =
                          (p['sell_price'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        leading: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFF8B5CF6),
                        ),
                        title: Text(
                          p['name'] as String? ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          currencyFmt.format(price),
                          style: TextStyle(
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.green,
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
