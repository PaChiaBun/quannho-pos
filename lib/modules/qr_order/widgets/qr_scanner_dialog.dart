import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';

/// Hộp thoại quét QR Bàn Giao (Camera Thật + Nhập Mã Thủ Công Fallback)
/// Tích hợp mobile_scanner, debounce lock, và định dạng token chuẩn V4.
class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  static Future<QrRequestModel?> show(BuildContext context) {
    return showDialog<QrRequestModel>(
      context: context,
      builder: (_) => const QrScannerDialog(),
    );
  }

  /// Trích xuất và xác thực token chuẩn V4 từ chuỗi quét được
  static String? extractValidHandoffToken(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;
    final exactToken = RegExp(r'^QRN_[A-Fa-f0-9]{32}$');

    // 1. Raw token trực tiếp
    if (exactToken.hasMatch(trimmed)) {
      return trimmed;
    }

    // 2. Trích xuất từ URL query parameters
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final code = uri.queryParameters['code'] ?? uri.queryParameters['t'];
      if (code != null && exactToken.hasMatch(code)) {
        return code;
      }
    }

    // 3. Token SQL là 16 byte CSPRNG được encode thành đúng 32 ký tự hex.
    final match = RegExp(
      r'QRN_[A-Fa-f0-9]{32}(?![A-Fa-f0-9])',
    ).firstMatch(trimmed);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final QrOrderRepository _repo = QrOrderRepository();
  final TextEditingController _codeCtrl = TextEditingController();
  late final MobileScannerController _scannerController;

  bool _isCameraMode = true;
  bool _isLoading = false;
  bool _isScanLocked = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isScanLocked || _isLoading) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      final token = QrScannerDialog.extractValidHandoffToken(rawValue);
      if (token != null) {
        _processClaim(token);
        break;
      }
    }
  }

  Future<void> _processClaim(String token) async {
    if (_isScanLocked || _isLoading) return;

    setState(() {
      _isLoading = true;
      _isScanLocked = true;
      _errorMessage = null;
    });

    try {
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId = storeInfo['store_id'] ?? '';

      if (storeId.isEmpty) {
        setState(() {
          _errorMessage = 'Chưa chọn cửa hàng hiện tại.';
          _isLoading = false;
          _isScanLocked = false;
        });
        return;
      }

      // Gọi RPC claim_qr_handoff_v4
      final claimRes = await _repo.claimHandoffToken(
        rawHandoffToken: token,
        storeId: storeId,
      );

      if (!mounted) return;

      if (claimRes.isSuccess && claimRes.data != null) {
        Navigator.pop(
          context,
          claimRes.data!,
        ); // Claim trả về đầy đủ request; không tạo failure window bằng RPC thứ hai.
        return;
      }

      // Xử lý lỗi claim
      final errMsg =
          claimRes.message ??
          QrErrorCode.toUserMessage(
            claimRes.errorCode,
            'Không thể tiếp nhận đơn hàng này.',
          );

      setState(() {
        _errorMessage = errMsg;
        _isLoading = false;
      });

      // Mở lại scanner sau 2 giây nếu quét lỗi
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isScanLocked = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối máy chủ: $e';
          _isLoading = false;
          _isScanLocked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUÉT QR BÀN GIAO',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Tiếp Nhận Đơn Khách Gọi',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Mode Selector Toggle (Camera / Nhập tay)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Quét Camera'),
                    selected: _isCameraMode,
                    selectedColor: const Color(0xFF6D28D9),
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _isCameraMode ? Colors.white : Colors.black87,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _isCameraMode = true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.keyboard_rounded, size: 16),
                    label: const Text('Nhập Mã Tay'),
                    selected: !_isCameraMode,
                    selectedColor: const Color(0xFF6D28D9),
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: !_isCameraMode ? Colors.white : Colors.black87,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _isCameraMode = false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Scanner View / Manual Input View
            if (_isCameraMode)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 240,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _handleBarcodeDetected,
                        errorBuilder: (context, error) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white70,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Không thể mở camera.\nVui lòng chuyển sang "Nhập Mã Tay"',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Scanning viewfinder frame
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isLoading
                                ? Colors.orange
                                : const Color(0xFF6D28D9),
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),

                      if (_isLoading)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhập mã token bàn giao (VD: QRN_...):',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeCtrl,
                    decoration: InputDecoration(
                      hintText: 'QRN_A1B2C3D4E5...',
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    style: GoogleFonts.sourceCodePro(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              final token =
                                  QrScannerDialog.extractValidHandoffToken(
                                    _codeCtrl.text,
                                  );
                              if (token != null) {
                                _processClaim(token);
                              } else {
                                setState(() {
                                  _errorMessage =
                                      'Mã không đúng định dạng (phải bắt đầu bằng QRN_)';
                                });
                              }
                            },
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Nhận Đơn',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
