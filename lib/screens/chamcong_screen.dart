import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/session_provider.dart';
import '../core/services/staff_service.dart';
import '../core/services/drive_service.dart';
import '../modules/tinhluong/repository/shift_template_repository.dart';
import '../core/repositories/module_repository.dart';
import '../core/providers/app_providers.dart';

const _kNavy   = Color(0xFF1C2151);
const _kBg     = Color(0xFFF5F7FF);
const _kMuted  = Color(0xFF9E9085);
const _kGreen  = Color(0xFF16A34A);
const _kRed    = Color(0xFFDC2626);
const _kOrange = Color(0xFFEA580C);

// ── Providers ─────────────────────────────────────────────────────────────────

final _myShiftsProvider = FutureProvider.autoDispose<List<ShiftRecord>>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s?.storeId == null) {
    debugPrint('[ChamCong] ⚠️ storeId=null | userId=${s?.userId} | role=${s?.role} | isOwner=${s?.isOwner}');
    return [];
  }
  final isManager = s!.isOwner || 
      s.role == 'owner' || 
      s.role == 'manager' ||
      s.role.toLowerCase() == 'quản lý';
  debugPrint('[ChamCong] getShifts → storeId=${s.storeId} | isManager=$isManager | role=${s.role}');
  final result = await StaffService.getShifts(
    storeId: s.storeId!,
    userId: isManager ? null : s.userId,
    limit: isManager ? 300 : 30,
  );
  debugPrint('[ChamCong] getShifts ← ${result.length} ca');
  return result;
});

final _storeLocationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = AppSettingsRepository();
  final lat = await repo.attendanceLat;
  final lng = await repo.attendanceLng;
  final radius = await repo.attendanceRadius;
  return {
    'lat': lat,
    'lng': lng,
    'radius': radius,
  };
});

// ── Screen ────────────────────────────────────────────────────────────────────
class ChamCongScreen extends ConsumerStatefulWidget {
  const ChamCongScreen({super.key});
  @override ConsumerState<ChamCongScreen> createState() => _ChamCongScreenState();
}

class _ChamCongScreenState extends ConsumerState<ChamCongScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Cleanup ảnh điểm danh cũ > 60 ngày (chỉ Supabase fallback)
    // Google Drive giữ vĩnh viễn — là bằng chứng pháp lý dài hạn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionProvider);
      final storeId = session?.storeId;
      if (storeId != null) {
        // Supabase fallback cleanup
        SupabaseStorageFallbackCleanup.cleanupOldAttendancePhotos(
          storeId: storeId,
          retentionDays: 90,
        );
        // Google Drive cleanup (sử dụng cùng service account chấm công)
        DriveService.cleanupOldDrivePhotos(
          storeId: storeId,
          retentionDays: 90,
        );
      }
    });
  }

  void _startDurationTimer(DateTime clockIn) {
    if (_durationTimer?.isActive == true) return; // đã chạy rồi
    _elapsed = DateTime.now().difference(clockIn);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(clockIn));
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  bool get _isManager {
    final s = ref.read(sessionProvider);
    return s?.isOwner == true || 
        s?.role == 'owner' || 
        s?.role == 'manager' ||
        s?.role.toLowerCase() == 'quản lý';
  }

  Future<void> _showLocationSettingsDialog(BuildContext context) async {
    final repo = AppSettingsRepository();
    final initialLat = await repo.attendanceLat;
    final initialLng = await repo.attendanceLng;
    final initialAddr = await repo.attendanceAddress;
    final initialRadius = await repo.attendanceRadius;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        double? currentLat = initialLat;
        double? currentLng = initialLng;
        String? currentAddr = initialAddr;
        final radiusCtrl = TextEditingController(text: initialRadius.toInt().toString());
        bool isLocating = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.location_on_rounded, color: _kNavy),
                SizedBox(width: 8),
                Text('Định vị của quán', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _kNavy)),
              ]),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thiết lập toạ độ chuẩn của quán để xác thực khoảng cách chấm công của nhân viên.',
                      style: TextStyle(fontSize: 12, color: _kMuted),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kNavy.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kNavy.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VỊ TRÍ ĐÃ LƯU:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kNavy)),
                          const SizedBox(height: 6),
                          if (currentLat != null && currentLng != null) ...[
                            Text('Tọa độ: ${currentLat!.toStringAsFixed(6)}, ${currentLng!.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Địa chỉ: ${currentAddr ?? "Chưa lấy địa chỉ"}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                          ] else ...[
                            const Text('Chưa thiết lập vị trí.', style: TextStyle(fontSize: 12, color: _kRed)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nút cập nhật vị trí quán tại đây
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isLocating ? null : () async {
                          setDialogState(() => isLocating = true);
                          try {
                            final perm = await Geolocator.checkPermission();
                            if (perm == LocationPermission.denied) {
                              await Geolocator.requestPermission();
                            }
                            final pos = await Geolocator.getCurrentPosition(
                              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                            );
                            final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
                            String? addr;
                            if (marks.isNotEmpty) {
                              final m = marks.first;
                              addr = [m.street, m.subAdministrativeArea, m.administrativeArea]
                                  .where((s) => s?.isNotEmpty == true).join(', ');
                            }
                            setDialogState(() {
                              currentLat = pos.latitude;
                              currentLng = pos.longitude;
                              currentAddr = addr;
                              isLocating = false;
                            });
                          } catch (e) {
                            setDialogState(() => isLocating = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Lỗi lấy vị trí: $e')),
                              );
                            }
                          }
                        },
                        icon: isLocating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, size: 16),
                        label: Text(isLocating ? 'Đang lấy vị trí...' : 'Lấy vị trí hiện tại của quán'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bán kính cho phép (mét):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: radiusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Mặc định: 200',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy', style: TextStyle(color: _kMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (currentLat == null || currentLng == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Vui lòng lấy vị trí quán trước khi lưu.')),
                      );
                      return;
                    }
                    final radius = double.tryParse(radiusCtrl.text) ?? 200.0;
                    await repo.saveAttendanceConfig(
                      lat: currentLat!,
                      lng: currentLng!,
                      address: currentAddr ?? 'Tọa độ chuẩn của quán',
                      radius: radius,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã lưu cấu hình định vị của quán.')),
                      );
                      ref.invalidate(_myShiftsProvider);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lưu cài đặt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final name = session.displayName ?? '';
    final date = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now());

    final mainBody = CustomScrollView(
        slivers: [
          _buildAppBar(name, date),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: _isManager ? const _ManagerView() : _buildStaffView(),
            ),
          ),
        ],
      );

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainBody),
              SizedBox(
                width: 280,
                child: _ChamCongRightPanel(
                  shiftsAsync: ref.watch(_myShiftsProvider),
                ),
              ),
            ]);
          }
          return mainBody;
        },
      ),
    );
  }

  Widget _buildAppBar(String name, String date) => SliverAppBar(
    expandedHeight: 110,
    pinned: true,
    backgroundColor: _kNavy,
    actions: _isManager ? [
      IconButton(
        icon: const Icon(Icons.settings_outlined, color: Colors.white),
        tooltip: 'Cài đặt định vị quán',
        onPressed: () => _showLocationSettingsDialog(context),
      ),
    ] : null,
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chấm công',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(date, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
          ],
        )),
      ]),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C2151), Color(0xFF0284C7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
    ),
  );

  // ── Staff View ───────────────────────────────────────────────────────────────
  Widget _buildStaffView() {
    final openAsync = ref.watch(openShiftCCProvider);
    final shiftsAsync = ref.watch(_myShiftsProvider);

    return openAsync.when(
      loading: () => const _ClockSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (open) {
        if (open != null) {
          final clockIn = DateTime.parse(open['clock_in'] as String).toLocal();
          _startDurationTimer(clockIn);
        } else {
          _stopDurationTimer();
        }
        final isClockedIn = open != null;

        return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ── Circular clock button ──
          _ClockButton(
            isClockedIn: isClockedIn,
            elapsed: _elapsed,
            pulseAnim: _pulseAnim,
            loading: _loading,
            onTap: () => _handleClockAction(open),
          ),

          // ── Stats ──
          shiftsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => _StatsRow(shifts: list, openShift: open),
          ),
          const SizedBox(height: 24),
          // ── History ──
          Row(children: [
            const Text('Lịch sử ca',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
            const Spacer(),
            shiftsAsync.maybeWhen(
              data: (l) => Text('${l.length} ca',
                style: const TextStyle(fontSize: 12, color: _kMuted)),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 12),
          shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
            error: (e, _) => Text('Lỗi: $e'),
            data: (list) => list.isEmpty
                ? const _EmptyShifts()
                : Column(children: list.map((s) => _ShiftRow(shift: s)).toList()),
          ),
        ]);
      },
    );
  }

  // ── Clock in/out action ──────────────────────────────────────────────────────
  Future<void> _handleClockAction(Map<String, dynamic>? openShift) async {
    if (_loading) return;
    final isClockedIn = openShift != null;
    HapticFeedback.mediumImpact();

    // ── RA CA: chỉ cần xác nhận, không chụp ảnh ─────────────────────────────
    if (isClockedIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.logout_rounded, color: _kRed, size: 22),
            SizedBox(width: 8),
            Text('Xác nhận ra ca', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          content: Text(
            'Ra ca lúc ${DateFormat('HH:mm').format(DateTime.now())}?\nThời gian làm việc sẽ được ghi nhận tự động.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ', style: TextStyle(color: _kMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ra ca', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      setState(() => _loading = true);
      try {
        // ‼️ FIX Bug #21: đọc session TRƯỚC clockOut() — trước đây session đọc sau await,
        // nếu session null giữa chừng sẽ NPE khi dùng session.storeId trong broadcast
        final session = ref.read(sessionProvider);
        if (session == null) { setState(() => _loading = false); return; }
        await StaffService.clockOut(openShift['id'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Đã ra ca lúc ${DateFormat('HH:mm').format(DateTime.now())}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            backgroundColor: _kNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 2500),
            margin: const EdgeInsets.all(16),
          ));
        }
        ref.invalidate(openShiftCCProvider);
        ref.invalidate(_myShiftsProvider);
        // 📡 Broadcast — subscribe trước, send, rồi unsubscribe để tránh channel leak
        try {
          final ch = Supabase.instance.client.channel('shifts_sender_${session.storeId}');
          await ch.subscribe();
          await ch.sendBroadcastMessage(event: 'shift_changed', payload: {'action': 'clock_out'});
          await ch.unsubscribe();
        } catch (_) {}
      } catch (e) {
        setState(() => _loading = false);
      } finally {
        setState(() => _loading = false);
      }
      return;
    }

    // ── VÀO CA: chụp ảnh trực tiếp + GPS (BẮT BUỘC CÓ ẢNH LIVE) ──────────────
    setState(() => _loading = true);
    try {
      // 1. CHỤP ẢNH SỐNG TRỰC TIẾP QUA CAMERA (BẮT BUỘC - CHỐNG GIAN LẬN)
      File? file;
      Uint8List? bytes;
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 50,
          maxWidth: 600,
        ).timeout(const Duration(seconds: 45));
        if (xfile != null) {
          bytes = await xfile.readAsBytes();
          if (!kIsWeb) file = File(xfile.path);
        }
      } on TimeoutException {
        debugPrint('[ChamCong] Front camera timeout');
      } catch (e) {
        debugPrint('[ChamCong] Front camera error: $e');
      }

      // Fallback: Thử chụp bằng camera mặc định (nếu camera trước lỗi)
      if (bytes == null) {
        try {
          final picker = ImagePicker();
          final xfile = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 50,
            maxWidth: 600,
          );
          if (xfile != null) {
            bytes = await xfile.readAsBytes();
            if (!kIsWeb) file = File(xfile.path);
          }
        } catch (e2) {
          debugPrint('[ChamCong] Default camera error: $e2');
        }
      }

      // ❌ CHỐNG GIAN LẬN: BẮT BUỘC PHẢI CHỤP ẢNH TRỰC TIẾP BẰNG CAMERA
      // Cấm tuyệt đối chọn ảnh có sẵn từ thư viện hoặc điểm danh không có ảnh
      if (bytes == null) {
        setState(() => _loading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.gavel_rounded, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('Yêu cầu chụp ảnh trực tiếp'),
              ]),
              content: const Text(
                'Để chống gian lận điểm danh, hệ thống yêu cầu nhân viên bắt buộc phải chụp ảnh selfie trực tiếp từ camera tại quán.\n\n'
                '• Không hỗ trợ chọn ảnh sẵn từ thư viện.\n'
                '• Không hỗ trợ điểm danh không có ảnh.\n\n'
                'Vui lòng cấp quyền truy cập máy ảnh và thực hiện chụp ảnh thực tế để vào ca!'
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
        }
        return; // Dừng ngay lập tức — KHÔNG CHO PHÉP VÀO CA NẾU KHÔNG CÓ ẢNH LIVE
      }

      // 2. Lấy GPS — medium accuracy để nhanh hơn, timeout 5s
      String? address;
      double? lat, lng;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) await Geolocator.requestPermission();
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 5));
        lat = pos.latitude; lng = pos.longitude;
        final marks = await placemarkFromCoordinates(lat, lng)
            .timeout(const Duration(seconds: 3));
        if (marks.isNotEmpty) {
          final m = marks.first;
          address = [m.street, m.subAdministrativeArea, m.administrativeArea]
              .where((s) => s?.isNotEmpty == true).join(', ');
        }
      } catch (_) {} // GPS là optional

      // ── XÁC THỰC KHOẢNG CÁCH ──
      final repo = AppSettingsRepository();
      final storeLat = await repo.attendanceLat;
      final storeLng = await repo.attendanceLng;
      final storeRadius = await repo.attendanceRadius;
      
      if (storeLat != null && storeLng != null && lat != null && lng != null) {
        final distance = Geolocator.distanceBetween(lat, lng, storeLat, storeLng);
        if (distance > storeRadius) {
          if (mounted) {
            final confirmCC = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: _kOrange, size: 24),
                  SizedBox(width: 8),
                  Text('Định vị lệch phạm vi'),
                ]),
                content: Text(
                  'Hệ thống phát hiện bạn đang cách quán khoảng ${distance.toInt()}m '
                  '(vượt quá giới hạn ${storeRadius.toInt()}m).\n\n'
                  'Ca chấm công này của bạn sẽ bị gắn cờ "Lệch vị trí" gửi đến chủ quán. Bạn có muốn tiếp tục?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy', style: TextStyle(color: _kNavy)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Tiếp tục'),
                  ),
                ],
              ),
            );
            if (confirmCC != true) {
              setState(() => _loading = false);
              return;
            }
          }
        }
      }

      // ── ĐÓNG DẤU HÌNH ẢNH ──
      if (bytes != null) {
        try {
          final timeStr = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
          final locationStr = address ?? (lat != null && lng != null ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' : 'Không xác định vị trí');
          bytes = await _addWatermarkToImage(bytes, timeStr, locationStr);
          if (!kIsWeb) {
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/temp_clockin.jpg');
            await tempFile.writeAsBytes(bytes);
            file = tempFile;
          }
        } catch (e) {
          debugPrint('Lỗi đóng dấu hình ảnh: $e');
        }
      }

      final session = ref.read(sessionProvider)!;
      final ts = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final name = session.displayName.replaceAll(' ', '_');
      final fileName = '${ts}_$name.jpg';
      final subFolder = DateFormat('yyyy-MM').format(DateTime.now());

      // 3. Upload ảnh (chỉ upload nếu có bytes)
      String? photoUrl;
      String? driveFileId;
      if (bytes != null) {
        if (kIsWeb) {
          photoUrl = await SupabaseStorageFallback.uploadPhoto(
            storeId: session.storeId ?? '',
            photoBytes: bytes,
            fileName: fileName,
          );
        } else {
          if (file != null) {
            final driveResult = await DriveService.uploadPhoto(
              storeId: session.storeId ?? '',
              photoFile: file,
              fileName: fileName,
              subFolder: subFolder,
            );
            if (driveResult != null) {
              driveFileId = driveResult.fileId;
              photoUrl    = driveResult.viewLink;
            } else {
              photoUrl = await SupabaseStorageFallback.uploadPhoto(
                storeId: session.storeId ?? '',
                photoBytes: bytes,
                fileName: fileName,
              );
            }
          }
        }
      }

      // 4. Ghi DB vào ca
      final shiftId = await StaffService.clockIn(session.userId, session.storeId ?? '',
          photoUrl: photoUrl, latitude: lat, longitude: lng,
          address: address, driveFileId: driveFileId);

      // ‼️ FIX Bug #25: Phát hiện đi muộn ngay sau clockIn
      // detectLateArrival so sánh giờ vào ca với ca được phân công hôm đó
      if (shiftId != null) {
        try {
          final lateResult = await ShiftTemplateRepository.detectLateArrival(
            storeId:     session.storeId ?? '',
            userId:      session.userId,
            clockInTime: DateTime.now(), // giờ local
          );
          if (lateResult.isLate) {
            // Update is_late và late_minutes vào DB để aggregateShifts tính đúng
            await Supabase.instance.client.from('staff_shifts').update({
              'is_late':      true,
              'late_minutes': lateResult.lateMinutes,
              'assignment_id': lateResult.assignmentId,
            }).eq('id', shiftId);
          }
        } catch (_) {} // silent fail — late detection không block clock-in
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.login_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Đã vào ca lúc ${DateFormat('HH:mm').format(DateTime.now())}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2500),
          margin: const EdgeInsets.all(16),
        ));
      }

      ref.invalidate(openShiftCCProvider);
      ref.invalidate(_myShiftsProvider);

      // 📡 Broadcast — subscribe trước, send, rồi unsubscribe để tránh channel leak
      try {
        final ch = Supabase.instance.client.channel('shifts_sender_${session.storeId}');
        await ch.subscribe();
        await ch.sendBroadcastMessage(event: 'shift_changed', payload: {'action': 'clock_in'});
        await ch.unsubscribe();
      } catch (_) {}
    } catch (e) {
      setState(() => _loading = false);
    } finally {
      setState(() => _loading = false);
    }
  }
}

// ── Manager view ─────────────────────────────────────────────────────────────
class _ManagerView extends ConsumerStatefulWidget {
  const _ManagerView();
  @override
  ConsumerState<_ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends ConsumerState<_ManagerView> {
  int _filterIdx = 0;
  DateTime _weekStart = _mondayOf(DateTime.now());
  int _navYear  = DateTime.now().year;
  int _navMonth = DateTime.now().month;
  RealtimeChannel? _shiftsChannel;
  Timer? _liveTimer;

  // Helper: lấy thứ 2 của tuần chứa ngày d
  static DateTime _mondayOf(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _mondayOf(now);
    _navYear   = now.year;
    _navMonth  = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
    _liveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeRealtime() {
    final s = ref.read(sessionProvider);
    if (s?.storeId == null) return;
    _shiftsChannel = Supabase.instance.client
        .channel('mgr_shifts_${s!.storeId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staff_shifts',
          callback: (_) {
            if (mounted) ref.invalidate(_myShiftsProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _shiftsChannel?.unsubscribe();
    super.dispose();
  }

  // ── Mở date picker để chọn tuần ──
  Future<void> _pickWeek(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Chọn ngày trong tuần muốn xem',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _weekStart = _mondayOf(picked));
    }
  }

  // ── Mở date picker để chọn tháng ──
  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_navYear, _navMonth),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Chọn tháng muốn xem',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _navYear  = picked.year;
        _navMonth = picked.month;
      });
    }
  }

  List<ShiftRecord> _applyFilter(List<ShiftRecord> all) {
    final now = DateTime.now();
    return all.where((s) {
      final ci = s.clockIn.toLocal();
      switch (_filterIdx) {
        case 0: // Hôm nay — cố định
          return ci.year == now.year && ci.month == now.month && ci.day == now.day;
        case 1: // Tuần đã chọn
          final weekEnd = _weekStart.add(const Duration(days: 7));
          return !ci.isBefore(_weekStart) && ci.isBefore(weekEnd);
        case 2: // Tháng đã chọn
          return ci.year == _navYear && ci.month == _navMonth;
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(_myShiftsProvider);
    return shiftsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: _kNavy)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 40),
          const SizedBox(height: 8),
          Text('Lỗi tải dữ liệu:\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kMuted, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => ref.invalidate(_myShiftsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ]),
      ),
      data: (all) {
        final filtered = _applyFilter(all);
        // active = đang làm trong toàn bộ ca (không filter ngày)
        final activeAll = all.where((s) => s.isOpen).toList();
        final done     = filtered.where((s) => !s.isOpen).toList();
        // Group done by employee
        final Map<String, List<ShiftRecord>> grouped = {};
        for (final s in done) {
          grouped.putIfAbsent(s.userName, () => []).add(s);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nút làm mới
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref.invalidate(_myShiftsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kNavy),
              ),
            ),
            // Stats
            _ManagerStatsRow(allShifts: all, filtered: filtered, filterIdx: _filterIdx),
            const SizedBox(height: 16),
            // Tab Hôm nay / Tuần / Tháng
            _MgrFilterBar(
              selected: _filterIdx,
              onChanged: (i) => setState(() => _filterIdx = i),
            ),
            // Nav ← → (chỉ hiện khi Tuần hoặc Tháng)
            if (_filterIdx == 1) ...[
              const SizedBox(height: 8),
              _WeekNavBar(
                weekStart: _weekStart,
                canGoNext: _weekStart.add(const Duration(days: 7)).isBefore(
                  DateTime.now().add(const Duration(days: 1))),
                onPrev: () => setState(() =>
                  _weekStart = _weekStart.subtract(const Duration(days: 7))),
                onNext: () => setState(() =>
                  _weekStart = _weekStart.add(const Duration(days: 7))),
                onPick: () => _pickWeek(context),
              ),
            ],
            if (_filterIdx == 2) ...[
              const SizedBox(height: 8),
              _MonthNavBar(
                year: _navYear,
                month: _navMonth,
                canGoNext: !(_navYear == DateTime.now().year &&
                             _navMonth == DateTime.now().month),
                onPrev: () => setState(() {
                  if (_navMonth == 1) { _navYear--; _navMonth = 12; }
                  else { _navMonth--; }
                }),
                onNext: () => setState(() {
                  if (_navMonth == 12) { _navYear++; _navMonth = 1; }
                  else { _navMonth++; }
                }),
                onPick: () => _pickMonth(context),
              ),
            ],
            const SizedBox(height: 16),
            // ── Đang làm ──
            if (activeAll.isNotEmpty) ...[
              _MgrSectionHeader(
                icon: Icons.radio_button_checked_rounded,
                color: _kGreen,
                title: 'Đang làm ca',
                count: '${activeAll.length} người',
              ),
              const SizedBox(height: 8),
              ...activeAll.map((s) => _ShiftRow(shift: s, showName: true)),
              const SizedBox(height: 20),
            ],
            // ── Lịch sử theo nhân viên ──
            _MgrSectionHeader(
              icon: Icons.history_rounded,
              color: _kNavy,
              title: 'Lịch sử ca',
              count: '${done.length} ca',
            ),
            const SizedBox(height: 8),
            if (done.isEmpty)
              _EmptyShifts(message: _filterIdx == 0
                ? 'Chưa có ca nào hôm nay'
                : _filterIdx == 1
                  ? 'Không có ca trong tuần này'
                  : 'Không có ca trong tháng này')
            else ...grouped.entries.map((e) => _EmployeeGroup(
              name: e.key,
              shifts: e.value,
            )),
          ],
        );
      },
    );
  }
}

// ── Manager filter bar ────────────────────────────────────────────────────────
class _MgrFilterBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _MgrFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Hôm nay', 'Tuần này', 'Tháng này'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isOn = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isOn ? _kNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOn ? Colors.white : _kMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Week nav bar ← Tuần XX · dd/mm–dd/mm → ──────────────────────────────────
class _WeekNavBar extends StatelessWidget {
  final DateTime weekStart;
  final bool canGoNext;
  final VoidCallback onPrev, onNext, onPick;
  const _WeekNavBar({
    required this.weekStart, required this.canGoNext,
    required this.onPrev, required this.onNext, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd  = weekStart.add(const Duration(days: 6));
    final weekNum  = _isoWeek(weekStart);
    final startStr = DateFormat('dd/MM').format(weekStart);
    final endStr   = DateFormat('dd/MM').format(weekEnd);
    final label    = 'Tuần $weekNum · $startStr–$endStr';
    return _NavBar(label: label, canGoNext: canGoNext,
      onPrev: onPrev, onNext: onNext, onPick: onPick);
  }

  static int _isoWeek(DateTime d) {
    final dayOfYear = int.parse(DateFormat('D').format(d));
    return ((dayOfYear - d.weekday + 10) / 7).floor();
  }
}

// ── Month nav bar ← Tháng X/YYYY → ──────────────────────────────────────────
class _MonthNavBar extends StatelessWidget {
  final int year, month;
  final bool canGoNext;
  final VoidCallback onPrev, onNext, onPick;
  const _MonthNavBar({
    required this.year, required this.month, required this.canGoNext,
    required this.onPrev, required this.onNext, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final label = 'Tháng $month / $year';
    return _NavBar(label: label, canGoNext: canGoNext,
      onPrev: onPrev, onNext: onNext, onPick: onPick);
  }
}

// ── Shared nav bar UI — animated slide khi đổi label ─────────────────────────
class _NavBar extends StatefulWidget {
  final String label;
  final bool canGoNext;
  final VoidCallback onPrev, onNext, onPick;
  const _NavBar({
    required this.label, required this.canGoNext,
    required this.onPrev, required this.onNext, required this.onPick,
  });

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> {
  // +1 = đang đi tới (next), -1 = đang đi lui (prev)
  int _slideDir = 1;
  String _prevLabel = '';

  @override
  void didUpdateWidget(_NavBar old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label) {
      _prevLabel = old.label;
      // Không cần setState vì AnimatedSwitcher tự trigger khi key đổi
    }
  }

  void _onPrev() {
    HapticFeedback.lightImpact();
    setState(() => _slideDir = -1);
    widget.onPrev();
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    setState(() => _slideDir = 1);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy.withValues(alpha: 0.06), _kNavy.withValues(alpha: 0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kNavy.withValues(alpha: 0.10), width: 1),
      ),
      child: Row(children: [
        // ── Nút Trước ──
        _NavBtn(
          icon: Icons.chevron_left_rounded,
          onTap: _onPrev,
        ),
        // ── Label với hiệu ứng slide ──
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onPick();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: Offset(_slideDir * 0.35, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: Container(
                key: ValueKey(widget.label),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _kNavy.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                        size: 11, color: _kNavy),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Nút Tiếp ──
        _NavBtn(
          icon: Icons.chevron_right_rounded,
          onTap: widget.canGoNext ? _onNext : null,
        ),
      ]),
    );
  }
}

class _NavBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _tap() {
    if (widget.onTap == null) return;
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return GestureDetector(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 40, height: 40,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active
              ? Colors.white
              : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [
              BoxShadow(
                color: _kNavy.withValues(alpha: 0.10),
                blurRadius: 6, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Icon(widget.icon, size: 20,
            color: active ? _kNavy : _kMuted.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _MgrSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, count;
  const _MgrSectionHeader({required this.icon, required this.color, required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: color),
    ),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    const Spacer(),
    Text(count, style: const TextStyle(fontSize: 12, color: _kMuted)),
  ]);
}

// ── Employee group (collapsible) ──────────────────────────────────────────────
class _EmployeeGroup extends StatefulWidget {
  final String name;
  final List<ShiftRecord> shifts;
  const _EmployeeGroup({required this.name, required this.shifts});
  @override
  State<_EmployeeGroup> createState() => _EmployeeGroupState();
}

class _EmployeeGroupState extends State<_EmployeeGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final totalMin = widget.shifts.fold<int>(0, (s, r) => s + r.duration.inMinutes);
    final totalStr = totalMin >= 60
        ? '${totalMin ~/ 60}h${(totalMin % 60).toString().padLeft(2,'0')}'
        : '${totalMin}p';
    final caCount = widget.shifts.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                // Avatar
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + summary
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _kNavy)),
                    const SizedBox(height: 2),
                    Text('$caCount ca · $totalStr làm việc',
                      style: const TextStyle(fontSize: 12, color: _kMuted)),
                  ],
                )),
                // Arrow
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 20),
                ),
              ]),
            ),
          ),
          // Expandable shifts
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: const Color(0xFFE5E7EB)),
                ...widget.shifts.map((s) => _ShiftRowCompact(shift: s)),
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ── Compact shift row (inside group) ─────────────────────────────────────────
class _ShiftRowCompact extends ConsumerWidget {
  final ShiftRecord shift;
  const _ShiftRowCompact({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ci = DateFormat('HH:mm').format(shift.clockIn.toLocal());
    final co = shift.clockOut != null
        ? DateFormat('HH:mm').format(shift.clockOut!.toLocal()) : 'Đang làm';
    final date = DateFormat('dd/MM').format(shift.clockIn.toLocal());

    return InkWell(
      onTap: () => _showPhotoAuditDialog(context, shift),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
        // Photo thumbnail
        if (shift.photoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(shift.photoUrl!, width: 36, height: 36, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _smallAvatar()),
          )
        else _smallAvatar(),
        const SizedBox(width: 10),
        // Time
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(date, style: const TextStyle(fontSize: 10, color: _kMuted)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (shift.isOpen ? _kGreen : _kNavy).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('$ci → $co',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: shift.isOpen ? _kGreen : _kNavy)),
              ),
              if (shift.isOpen) Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(4)),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
              _buildLocationBadge(ref),
            ]),
            if (shift.address != null)
              Text(shift.address!, style: const TextStyle(fontSize: 10, color: _kMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        // Duration
        Text(shift.durationStr,
          style: TextStyle(fontWeight: FontWeight.w800, color: shift.isOpen ? _kGreen : _kNavy, fontSize: 13)),
      ]),
    ),
  );
  }

  Widget _buildLocationBadge(WidgetRef ref) {
    final locAsync = ref.watch(_storeLocationProvider);
    return locAsync.maybeWhen(
      data: (config) {
        final storeLat = config['lat'] as double?;
        final storeLng = config['lng'] as double?;
        final storeRadius = config['radius'] as double? ?? 200.0;

        if (storeLat == null || storeLng == null) return const SizedBox.shrink();

        if (shift.latitude == null || shift.longitude == null) {
          return Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '⚠️ Không GPS',
              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          );
        }

        final distance = Geolocator.distanceBetween(
          shift.latitude!, shift.longitude!, storeLat, storeLng);
        
        final isOut = distance > storeRadius;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isOut ? _kRed.withOpacity(0.1) : _kGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isOut ? _kRed : _kGreen, width: 0.5),
          ),
          child: Text(
            isOut ? '⚠️ Lệch ${distance.toInt()}m' : '✓ Ở quán',
            style: TextStyle(
              color: isOut ? _kRed : _kGreen,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _smallAvatar() => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.person_rounded, color: _kNavy, size: 18),
  );
}

// ── Circular pulse button ─────────────────────────────────────────────────────
class _ClockButton extends StatelessWidget {
  final bool isClockedIn, loading;
  final Duration elapsed;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;
  const _ClockButton({
    required this.isClockedIn, required this.elapsed,
    required this.pulseAnim, required this.loading, required this.onTap,
  });

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2,'0')}m ${s.toString().padLeft(2,'0')}s';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = isClockedIn ? _kRed : _kGreen;
    final label = isClockedIn ? 'RA CA' : 'VÀO CA';
    final icon  = isClockedIn ? Icons.logout_rounded : Icons.login_rounded;

    return Column(children: [
      // Pulse ring + button
      GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: pulseAnim.value,
            child: child,
          ),
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 32, spreadRadius: 8),
                BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 20),
              ],
            ),
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: Colors.white, size: 36),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Sub-label
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isClockedIn
            ? Column(key: const ValueKey('in'), children: [
                Text(_fmtElapsed(elapsed),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: _kNavy, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Thời gian đang làm',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              ])
            : Column(key: const ValueKey('out'), children: [
                const Text('Chưa vào ca',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy)),
                const SizedBox(height: 4),
                const Text('Nhấn để bắt đầu ca làm việc',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              ]),
      ),
    ]);
  }
}

// ── Stats row (employee) ──────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<ShiftRecord> shifts;
  final Map<String, dynamic>? openShift;
  const _StatsRow({required this.shifts, required this.openShift});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayShifts = shifts.where((s) =>
      s.clockIn.year == now.year && s.clockIn.month == now.month && s.clockIn.day == now.day
    ).toList();
    // ‼️ FIX: truncate weekStart về 00:00:00 để không loại ca vào thứ 2 sáng sớm
    final nowMon = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(nowMon.year, nowMon.month, nowMon.day); // midnight
    final weekMin = shifts
        .where((s) => !s.clockIn.isBefore(weekStart))
        .fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
    final todayMin = todayShifts.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);

    return Row(children: [
      _StatChip('Ca hôm nay', '${todayShifts.length}', Icons.today_rounded, _kNavy),
      const SizedBox(width: 10),
      _StatChip('Giờ hôm nay', '${todayMin ~/ 60}h${(todayMin % 60).toString().padLeft(2,'0')}', Icons.timer_rounded, _kOrange),
      const SizedBox(width: 10),
      _StatChip('Giờ tuần', '${weekMin ~/ 60}h${(weekMin % 60).toString().padLeft(2,'0')}', Icons.date_range_rounded, _kGreen),
    ]);
  }
}

Widget _StatChip(String label, String value, IconData icon, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.15)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 9, fontWeight: FontWeight.w600)),
    ]),
  ),
);

// ── Manager stats ─────────────────────────────────────────────────────────────
class _ManagerStatsRow extends StatelessWidget {
  final List<ShiftRecord> allShifts;   // toàn bộ ca — để tính 'Đang làm'
  final List<ShiftRecord> filtered;    // ca đã filter theo period
  final int filterIdx;                 // 0=hôm nay, 1=tuần, 2=tháng
  const _ManagerStatsRow({
    required this.allShifts,
    required this.filtered,
    required this.filterIdx,
  });

  @override
  Widget build(BuildContext context) {
    // Đang làm: luôn lấy từ tất cả ca (không bị filter ngày)
    final active = allShifts.where((s) => s.isOpen).length;
    // ‼️ FIX: chỉ tính tổng giờ ca đã đóng (isOpen=false)
    // Ca đang mở có duration không ổn định (tăng theo thời gian), gây số nhảy mỗi 60s do _liveTimer
    final doneFiltered = filtered.where((s) => !s.isOpen).toList();
    int totalMin = 0;
    for (final s in doneFiltered) {
      totalMin += s.duration.inMinutes;
    }
    final periodLabels = ['Ca hôm nay', 'Ca tuần', 'Ca tháng'];
    final label = periodLabels[filterIdx];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2D3180)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _MgrStat('$active', 'Đang làm', Icons.people_rounded, Colors.white),
        _divider(),
        _MgrStat('${filtered.length}', label, Icons.today_rounded, Colors.white),
        _divider(),
        _MgrStat('${totalMin ~/ 60}h${(totalMin % 60).toString().padLeft(2, '0')}',
          'Tổng giờ', Icons.timer_rounded, Colors.white),
      ]),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 36,
    color: Colors.white.withValues(alpha: 0.2),
    margin: const EdgeInsets.symmetric(horizontal: 12),
  );
}

Widget _MgrStat(String value, String label, IconData icon, Color color) => Expanded(
  child: Column(children: [
    Icon(icon, color: color.withValues(alpha: 0.8), size: 16),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
    Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
  ]),
);

// ── Shift history row ─────────────────────────────────────────────────────────
class _ShiftRow extends ConsumerWidget {
  final ShiftRecord shift;
  final bool showName;
  const _ShiftRow({required this.shift, this.showName = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clockIn  = DateFormat('HH:mm').format(shift.clockIn.toLocal());
    final clockOut = shift.clockOut != null
        ? DateFormat('HH:mm').format(shift.clockOut!.toLocal()) : null;
    final date = DateFormat('dd/MM').format(shift.clockIn.toLocal());
    final isOpen = shift.isOpen;
    final borderColor = isOpen ? _kGreen : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: () => _showPhotoAuditDialog(context, shift),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(children: [
              // Left accent
              Container(width: 4, color: isOpen ? _kGreen : const Color(0xFFE5E7EB)),
              // Photo
              Padding(
                padding: const EdgeInsets.all(12),
                child: shift.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(shift.photoUrl!, width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _AvatarPh()))
                    : const _AvatarPh(),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (showName) Text(shift.userName.trim().isNotEmpty ? shift.userName : 'Nhân viên',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kNavy)),
                    Row(children: [
                      Text(date, style: const TextStyle(fontSize: 11, color: _kMuted)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isOpen ? _kGreen : _kNavy).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOpen ? '$clockIn → Đang làm' : '$clockIn → ${clockOut ?? ''}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: isOpen ? _kGreen : _kNavy),
                        ),
                      ),
                      if (isOpen) Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kGreen, borderRadius: BorderRadius.circular(5)),
                        child: const Text('LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                      _buildLocationBadge(ref),
                    ]),
                    if (shift.address != null) ...[
                      const SizedBox(height: 3),
                      Text(shift.address!,
                        style: const TextStyle(fontSize: 10, color: _kMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
              ),
              // Duration
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(shift.durationStr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isOpen ? _kGreen : _kNavy,
                    fontSize: 15)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBadge(WidgetRef ref) {
    final locAsync = ref.watch(_storeLocationProvider);
    return locAsync.maybeWhen(
      data: (config) {
        final storeLat = config['lat'] as double?;
        final storeLng = config['lng'] as double?;
        final storeRadius = config['radius'] as double? ?? 200.0;

        if (storeLat == null || storeLng == null) return const SizedBox.shrink();

        if (shift.latitude == null || shift.longitude == null) {
          return Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '⚠️ Không GPS',
              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          );
        }

        final distance = Geolocator.distanceBetween(
          shift.latitude!, shift.longitude!, storeLat, storeLng);
        
        final isOut = distance > storeRadius;
        return Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: isOut ? _kRed.withOpacity(0.1) : _kGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isOut ? _kRed : _kGreen, width: 0.5),
          ),
          child: Text(
            isOut ? '⚠️ Lệch ${distance.toInt()}m' : '✓ Ở quán',
            style: TextStyle(
              color: isOut ? _kRed : _kGreen,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _AvatarPh extends StatelessWidget {
  const _AvatarPh();
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: _kNavy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.person_rounded, color: _kNavy, size: 22),
  );
}

class _ClockSkeleton extends StatelessWidget {
  const _ClockSkeleton();
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
    ),
    const SizedBox(height: 12),
    Container(width: 100, height: 14,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(7))),
  ]);
}

class _EmptyShifts extends StatelessWidget {
  final String? message;
  const _EmptyShifts({this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.fingerprint_rounded, size: 52, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(message ?? 'Chưa có ca nào',
        style: const TextStyle(color: _kMuted, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Nhấn nút để bắt đầu ca làm việc đầu tiên',
        style: TextStyle(color: _kMuted, fontSize: 11), textAlign: TextAlign.center),
    ]),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Chamcong Stats Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _ChamCongRightPanel extends StatelessWidget {
  final AsyncValue<List<ShiftRecord>> shiftsAsync;
  const _ChamCongRightPanel({required this.shiftsAsync});

  @override
  Widget build(BuildContext context) {
    final shifts = shiftsAsync.value ?? [];
    final now = DateTime.now();
    final todayShifts = shifts.where((s) {
      final ci = s.clockIn.toLocal();
      return ci.year == now.year && ci.month == now.month && ci.day == now.day;
    }).toList();
    final activeCount = shifts.where((s) => s.isOpen).length;
    final totalHours = shifts.where((s) => !s.isOpen).fold<double>(0, (sum, s) {
      final dur = s.clockOut!.difference(s.clockIn);
      return sum + dur.inMinutes / 60;
    });

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          _CCCard(
            title: 'Tổng quan',
            icon: Icons.fingerprint_rounded,
            child: Column(children: [
              _CCRow(label: 'Tổng ca', value: '${shifts.length}', color: _kNavy),
              const Divider(height: 1),
              _CCRow(label: 'Đang làm', value: '$activeCount', color: _kGreen),
              const Divider(height: 1),
              _CCRow(label: 'Hôm nay', value: '${todayShifts.length} ca', color: _kOrange),
              const Divider(height: 1),
              _CCRow(label: 'Tổng giờ', value: '${totalHours.toStringAsFixed(1)}h', color: _kNavy),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CCCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _CCCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: _kNavy.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _CCRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CCRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kNavy))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

Future<Uint8List> _addWatermarkToImage(
  Uint8List originalImageBytes,
  String dateTimeText,
  String locationText,
) async {
  final ui.Codec codec = await ui.instantiateImageCodec(originalImageBytes);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image image = frameInfo.image;

  final double originalWidth = image.width.toDouble();
  final double originalHeight = image.height.toDouble();

  // Tối ưu RAM cho thiết bị yếu: giới hạn chiều rộng ảnh tối đa là 480px
  double targetWidth = originalWidth;
  double targetHeight = originalHeight;
  if (originalWidth > 480) {
    targetWidth = 480;
    targetHeight = (originalHeight * 480) / originalWidth;
  }

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Vẽ hình ảnh đã được thu nhỏ (downscaled) để tiết kiệm bộ nhớ khi render & encode PNG
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, originalWidth, originalHeight),
    Rect.fromLTWH(0, 0, targetWidth, targetHeight),
    Paint()..filterQuality = ui.FilterQuality.medium,
  );

  final double overlayHeight = targetHeight * 0.12;
  final Paint backgroundPaint = Paint()
    ..color = Colors.black.withOpacity(0.5)
    ..style = PaintingStyle.fill;

  canvas.drawRect(
    Rect.fromLTWH(0, targetHeight - overlayHeight, targetWidth, overlayHeight),
    backgroundPaint,
  );

  final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: (targetWidth * 0.035).clamp(10.0, 20.0),
      maxLines: 2,
    ),
  );

  builder.pushStyle(ui.TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  ));
  builder.addText('⏰ $dateTimeText\n');
  builder.addText('📍 $locationText');

  final ui.Paragraph paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: targetWidth - 20));

  canvas.drawParagraph(
    paragraph,
    Offset(10, targetHeight - overlayHeight + (overlayHeight - paragraph.height) / 2),
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image watermarkedImage = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
  
  // PNG encoding lúc này sẽ tốn rất ít RAM do size ảnh đã nhỏ đi nhiều lần (~480px width)
  final ByteData? byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

  // Giải phóng đối tượng Image gốc để giải phóng RAM ngay lập tức
  image.dispose();
  watermarkedImage.dispose();

  return byteData!.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG KIỂM TRA NGẪU NHIÊN ẢNH CHỤP ĐIỂM DANH LIVE CỦA NHÂN VIÊN
// ─────────────────────────────────────────────────────────────────────────────
void _showPhotoAuditDialog(BuildContext context, ShiftRecord shift) {
  final clockInStr = DateFormat('HH:mm dd/MM/yyyy').format(shift.clockIn.toLocal());
  final clockOutStr = shift.clockOut != null
      ? DateFormat('HH:mm dd/MM/yyyy').format(shift.clockOut!.toLocal())
      : 'Đang trong ca (LIVE)';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: _kNavy, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.userName.isNotEmpty ? shift.userName : 'Nhân viên',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy),
                      ),
                      Text(
                        shift.isOpen ? '🟢 Đang làm việc' : '⚪ Đã kết thúc ca',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: shift.isOpen ? _kGreen : _kMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ảnh kiểm tra ngẫu nhiên
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: shift.photoUrl != null
                  ? AspectRatio(
                      aspectRatio: 1.1,
                      child: Image.network(
                        shift.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Không tải được ảnh', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.grey.shade100,
                      child: const Column(
                        children: [
                          Icon(Icons.no_photography_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 10),
                          Text(
                            'Chưa có ảnh chụp selfie ca này',
                            style: TextStyle(fontWeight: FontWeight.w700, color: _kNavy, fontSize: 13),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ca làm việc tạo trước khi áp dụng bắt buộc chụp ảnh live',
                            style: TextStyle(color: _kMuted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Chi tiết ca
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _auditDetailRow(Icons.login_rounded, 'Vào ca:', clockInStr),
                  const SizedBox(height: 6),
                  _auditDetailRow(Icons.logout_rounded, 'Ra ca:', clockOutStr),
                  if (shift.address != null) ...[
                    const SizedBox(height: 6),
                    _auditDetailRow(Icons.location_on_rounded, 'Vị trí:', shift.address!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _auditDetailRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 11, color: _kMuted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
