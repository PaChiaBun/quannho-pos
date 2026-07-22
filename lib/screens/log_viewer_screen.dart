import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/app_logger.dart';
import '../core/services/store_auth_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  bool _isLoading = false;
  bool _hasFetched = false;
  List<Map<String, dynamic>> _logs = [];
  List<String> _staffNames = ['Tất cả'];
  
  // Các bộ lọc
  String _selectedStaff = 'Tất cả';
  String _selectedLevel = 'Tất cả';
  String _selectedTag = 'Tất cả';
  DateTimeRange? _selectedDateRange;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);

  // Lọc theo tiếng Việt
  final List<String> _levels = [
    'Tất cả',
    'Thông tin hoạt động',
    'Cảnh báo hệ thống',
    'Lỗi nghiêm trọng',
    'Gỡ lỗi kỹ thuật'
  ];

  final Map<String, String> _levelsMap = {
    'Tất cả': 'Tất cả',
    'Thông tin hoạt động': 'INFO',
    'Cảnh báo hệ thống': 'WARNING',
    'Lỗi nghiêm trọng': 'ERROR',
    'Gỡ lỗi kỹ thuật': 'DEBUG',
  };

  final Map<String, String> _tags = {
    'Tất cả': 'Tất cả',
    'auth': '🔐 Tài khoản',
    'order': '🍽️ Đặt món',
    'checkout': '💳 Thanh toán',
    'settings': '⚙️ Cài đặt',
    'printer': '🖨️ Máy in',
    'system': '💻 Hệ thống',
  };

  @override
  void initState() {
    super.initState();
    // Mặc định khoảng ngày lọc là hôm nay
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _fetchStaffNames();
    _fetchLogs();
  }

  Future<void> _fetchStaffNames() async {
    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId == null) return;

      Supabase.instance.client.rest.headers['x-store-id'] = storeId;
      final staffData = await Supabase.instance.client
          .from('staff_members')
          .select('name')
          .eq('store_id', storeId);

      final Set<String> uniqueStaff = {'Tất cả'};
      for (final row in staffData) {
        final name = row['name'] as String?;
        if (name != null && name.isNotEmpty) {
          uniqueStaff.add(name);
        }
      }

      setState(() {
        _staffNames = uniqueStaff.toList()..sort();
      });
    } catch (_) {}
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _hasFetched = true;
    });

    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId == null) throw Exception('Chưa xác định được ID cửa hàng.');

      // Thiết lập header x-store-id cho RLS
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      var query = Supabase.instance.client
          .from('app_logs')
          .select()
          .eq('store_id', storeId);

      // Lọc khoảng ngày & giờ
      if (_selectedDateRange != null) {
        final startDateTime = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
          _startTime.hour,
          _startTime.minute,
        );
        final endDateTime = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          _endTime.hour,
          _endTime.minute,
        );
        query = query
            .gte('created_at', startDateTime.toUtc().toIso8601String())
            .lte('created_at', endDateTime.toUtc().toIso8601String());
      }

      // Lọc Level
      if (_selectedLevel != 'Tất cả') {
        final dbLevel = _levelsMap[_selectedLevel];
        if (dbLevel != null) {
          query = query.eq('level', dbLevel);
        }
      }

      // Lọc Tag
      if (_selectedTag != 'Tất cả') {
        query = query.eq('tag', _selectedTag);
      }

      // Lọc nhân viên
      if (_selectedStaff != 'Tất cả') {
        query = query.eq('staff_name', _selectedStaff);
      }

      final data = await query.order('created_at', ascending: false).limit(1000);
      final List<Map<String, dynamic>> fetchedLogs = List<Map<String, dynamic>>.from(data)
          .where((log) {
            final msg = log['message'] as String? ?? '';
            return !msg.contains('[Polling Orders]') && !msg.contains('[Polling Tickets]');
          }).toList();

      setState(() {
        _logs = fetchedLogs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải nhật ký: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa toàn bộ nhật ký lỗi trên máy này và đám mây không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final info = await StoreAuthService.getStoreInfo();
        final storeId = info['store_id'];
        if (storeId != null) {
          Supabase.instance.client.rest.headers['x-store-id'] = storeId;
          
          // Xoá theo lô (chunking 500 bản ghi/lần) để tránh lỗi PostgreSQL statement_timeout (57014)
          while (true) {
            final rows = await Supabase.instance.client
                .from('app_logs')
                .select('id')
                .eq('store_id', storeId)
                .limit(500);
            if (rows.isEmpty) break;

            final ids = rows.map((r) => r['id'] as String).toList();
            await Supabase.instance.client
                .from('app_logs')
                .delete()
                .inFilter('id', ids);

            if (ids.length < 500) break;
          }
        }
        await AppLogger.clearLocalLogs();
        await _fetchLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa sạch nhật ký!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa nhật ký: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard() {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhật ký để sao chép!')),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    for (final log in _logs) {
      final time = DateTime.parse(log['created_at'] as String).toLocal().toString();
      buffer.writeln('[$time] [${log['level']}] [${log['staff_name']}] [${log['tag']}] ${log['message']}');
      if (log['details'] != null) {
        buffer.writeln('Details: ${log['details']}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép toàn bộ nhật ký vào Clipboard!'), backgroundColor: Colors.green),
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final dateRangeWidget = InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: _selectedDateRange,
          firstDate: DateTime(2025),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) {
          setState(() {
            _selectedDateRange = DateTimeRange(
              start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
              end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
            );
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Khoảng thời gian',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _selectedDateRange == null
                    ? 'Chọn ngày...'
                    : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}',
                style: GoogleFonts.outfit(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 16),
          ],
        ),
      ),
    );

    final staffWidget = DropdownButtonFormField<String>(
      value: _selectedStaff,
      decoration: const InputDecoration(
        labelText: 'Nhân viên',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      items: _staffNames.map((name) {
        return DropdownMenuItem<String>(
          value: name,
          child: Text(name, style: GoogleFonts.outfit(fontSize: 14), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedStaff = val);
        }
      },
    );

    final startTimeWidget = InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _startTime,
        );
        if (picked != null) {
          setState(() {
            _startTime = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Giờ bắt đầu',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _startTime.format(context),
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            const Icon(Icons.access_time_rounded, size: 16),
          ],
        ),
      ),
    );

    final endTimeWidget = InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _endTime,
        );
        if (picked != null) {
          setState(() {
            _endTime = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Giờ kết thúc',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _endTime.format(context),
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            const Icon(Icons.access_time_rounded, size: 16),
          ],
        ),
      ),
    );

    final tagWidget = DropdownButtonFormField<String>(
      value: _selectedTag,
      decoration: const InputDecoration(
        labelText: 'Loại thao tác',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      items: _tags.entries.map((e) {
        return DropdownMenuItem<String>(
          value: e.key,
          child: Text(e.value, style: GoogleFonts.outfit(fontSize: 14), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedTag = val);
        }
      },
    );

    final levelWidget = DropdownButtonFormField<String>(
      value: _selectedLevel,
      decoration: const InputDecoration(
        labelText: 'Phân loại Log',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      items: _levels.map((level) {
        return DropdownMenuItem<String>(
          value: level,
          child: Text(level, style: GoogleFonts.outfit(fontSize: 14), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedLevel = val);
        }
      },
    );

    Widget filterLayout;
    if (isMobile) {
      filterLayout = Column(
        children: [
          dateRangeWidget,
          const SizedBox(height: 12),
          staffWidget,
          const SizedBox(height: 12),
          startTimeWidget,
          const SizedBox(height: 12),
          endTimeWidget,
          const SizedBox(height: 12),
          tagWidget,
          const SizedBox(height: 12),
          levelWidget,
        ],
      );
    } else {
      filterLayout = Column(
        children: [
          Row(
            children: [
              Expanded(child: dateRangeWidget),
              const SizedBox(width: 12),
              Expanded(child: staffWidget),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: startTimeWidget),
              const SizedBox(width: 12),
              Expanded(child: endTimeWidget),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: tagWidget),
              const SizedBox(width: 12),
              Expanded(child: levelWidget),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filterLayout,
          const SizedBox(height: 16),
          // NÚT TRUY XUẤT LOG
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _fetchLogs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2151),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: Text(
                'Truy xuất Log',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTag(String? tag) {
    switch (tag) {
      case 'auth':
        return Icons.lock_outline_rounded;
      case 'order':
        return Icons.restaurant_menu_rounded;
      case 'checkout':
        return Icons.payment_rounded;
      case 'settings':
        return Icons.settings_suggest_rounded;
      case 'printer':
        return Icons.print_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForLevel(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getTranslatedLevel(String dbLevel) {
    switch (dbLevel) {
      case 'INFO':
        return 'Thông tin';
      case 'WARNING':
        return 'Cảnh báo';
      case 'ERROR':
        return 'Lỗi hệ thống';
      case 'DEBUG':
        return 'Gỡ lỗi';
      default:
        return dbLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text('Nhật Ký Hoạt Động & Lỗi', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Sao chép Logs',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
            onPressed: _fetchLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa sạch',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFilterBar(),
            const SizedBox(height: 16),
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : !_hasFetched
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Vui lòng chọn bộ lọc và nhấn nút "Truy xuất Log" để tải nhật ký.',
                            style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                    : _logs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'Không tìm thấy bản ghi nhật ký nào.',
                                style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              final time = DateTime.parse(log['created_at'] as String).toLocal();
                              final timeStr = DateFormat('HH:mm:ss - dd/MM/yyyy').format(time);
                              final level = log['level'] as String? ?? 'INFO';
                              final tag = log['tag'] as String? ?? 'system';
                              final staff = log['staff_name'] as String? ?? 'Hệ thống';
                              final msg = log['message'] as String? ?? '';
                              final details = log['details'] as String?;

                              final levelColor = _getColorForLevel(level);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: levelColor.withOpacity(0.1),
                                    child: Icon(_getIconForTag(tag), color: levelColor, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        staff,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: levelColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _getTranslatedLevel(level),
                                          style: GoogleFonts.outfit(
                                            color: levelColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(msg, style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87)),
                                        const SizedBox(height: 2),
                                        Text(timeStr, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  childrenPadding: const EdgeInsets.all(16),
                                  expandedAlignment: Alignment.topLeft,
                                  children: [
                                    if (details != null && details.isNotEmpty)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Chi tiết kỹ thuật (Technical Details):',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade800),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: SelectableText(
                                              details,
                                              style: GoogleFonts.sourceCodePro(fontSize: 12, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text('Không có thông tin kỹ thuật bổ sung.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
          ],
        ),
      ),
    );
  }
}
