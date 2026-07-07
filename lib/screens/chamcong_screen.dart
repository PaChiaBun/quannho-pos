import 'dart:async';
import 'dart:io';
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

const _kNavy   = Color(0xFF1C2151);
const _kBg     = Color(0xFFF5F7FF);
const _kMuted  = Color(0xFF9E9085);
const _kGreen  = Color(0xFF16A34A);
const _kRed    = Color(0xFFDC2626);
const _kOrange = Color(0xFFEA580C);

// ── Providers ─────────────────────────────────────────────────────────────────
final _openShiftCCProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s == null) return null;
  try {
    return await Supabase.instance.client
        .from('staff_shifts').select('id,clock_in')
        .eq('user_id', s.userId).eq('store_id', s.storeId ?? '')
        .isFilter('clock_out', null).maybeSingle();
  } catch (_) { return null; }
});

final _myShiftsProvider = FutureProvider.autoDispose<List<ShiftRecord>>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s?.storeId == null) {
    debugPrint('[ChamCong] ⚠️ storeId=null | userId=${s?.userId} | role=${s?.role} | isOwner=${s?.isOwner}');
    return [];
  }
  final isManager = s!.isOwner || s.role == 'owner' || s.role == 'manager';
  debugPrint('[ChamCong] getShifts → storeId=${s.storeId} | isManager=$isManager | role=${s.role}');
  final result = await StaffService.getShifts(
    storeId: s.storeId!,
    userId: isManager ? null : s.userId,
    limit: isManager ? 300 : 30,
  );
  debugPrint('[ChamCong] getShifts ← ${result.length} ca');
  return result;
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
    return s?.isOwner == true || s?.role == 'owner' || s?.role == 'manager';
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
    final openAsync = ref.watch(_openShiftCCProvider);
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
        ref.invalidate(_openShiftCCProvider);
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

    // ── VÀO CA: chụp ảnh + GPS ───────────────────────────────────────────────
    setState(() => _loading = true);
    try {
      // 1. Chụp ảnh selfie — timeout 60s để tránh ANR nếu camera chậm mở
      File? file;
      Uint8List? bytes;
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 70,
          maxWidth: 800,
        ).timeout(const Duration(seconds: 60));
        if (xfile == null) { setState(() => _loading = false); return; }
        bytes = await xfile.readAsBytes();
        if (!kIsWeb) {
          file = File(xfile.path);
        }
      } on TimeoutException {
        if (mounted) setState(() => _loading = false);
        return;
      } catch (e) {
        if (mounted) setState(() => _loading = false);
        return;
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

      final session = ref.read(sessionProvider)!;
      final ts = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final name = session.displayName.replaceAll(' ', '_');
      final fileName = '${ts}_$name.jpg';
      final subFolder = DateFormat('yyyy-MM').format(DateTime.now());

      // 3. Upload ảnh
      String? photoUrl;
      String? driveFileId;
      if (kIsWeb) {
        photoUrl = await SupabaseStorageFallback.uploadPhoto(
          storeId: session.storeId ?? '',
          photoBytes: bytes,
          fileName: fileName,
        );
      } else {
        final driveResult = await DriveService.uploadPhoto(
          storeId: session.storeId ?? '',
          photoFile: file!,
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

      ref.invalidate(_openShiftCCProvider);
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
class _ShiftRowCompact extends StatelessWidget {
  final ShiftRecord shift;
  const _ShiftRowCompact({required this.shift});

  @override
  Widget build(BuildContext context) {
    final ci = DateFormat('HH:mm').format(shift.clockIn.toLocal());
    final co = shift.clockOut != null
        ? DateFormat('HH:mm').format(shift.clockOut!.toLocal()) : 'Đang làm';
    final date = DateFormat('dd/MM').format(shift.clockIn.toLocal());

    return Padding(
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
    final totalMin = doneFiltered.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
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
class _ShiftRow extends StatelessWidget {
  final ShiftRecord shift;
  final bool showName;
  const _ShiftRow({required this.shift, this.showName = false});

  @override
  Widget build(BuildContext context) {
    final clockIn  = DateFormat('HH:mm').format(shift.clockIn.toLocal());
    final clockOut = shift.clockOut != null
        ? DateFormat('HH:mm').format(shift.clockOut!.toLocal()) : null;
    final date = DateFormat('dd/MM').format(shift.clockIn.toLocal());
    final isOpen = shift.isOpen;
    final borderColor = isOpen ? _kGreen : const Color(0xFFE5E7EB);

    return Container(
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
                  if (showName) Text(shift.userName,
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
