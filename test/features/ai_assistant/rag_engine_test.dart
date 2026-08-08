// test/features/ai_assistant/rag_engine_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// RAG / FAQ Engine Benchmark Test Suite — 30+ Questions across Modules
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/rag/rag_engine.dart';

void main() {
  group('RAG Engine Phase 4 Evaluation', () {
    setUpAll(() {
      final mockKnowledgeBase = [
        {
          'path': '.docs/Ai_Bum/cac-module/ban-hang.md',
          'module': 'ban_hang',
          'content': '''
# Module Bán Hàng POS
## Hướng dẫn hủy món ăn
Muốn hủy món trên bàn đã gọi, thu ngân bấm vào món cần hủy, chọn "Hủy món" và chọn lý do hủy. Thao tác hủy món sẽ được ghi vào nhật ký void_audit_logs.

## Hướng dẫn in lại hóa đơn
Vào danh sách đơn hàng đã thanh toán, chọn đơn hàng cần in và bấm nút "In lại bill".
'''
        },
        {
          'path': '.docs/Ai_Bum/cac-module/bep.md',
          'module': 'bep',
          'content': '''
# Module Trạm Bếp
## Chuyển trạng thái phiếu bếp
Khi bếp nấu xong món, đầu bếp bấm nút "Hoàn thành" trên màn hình trạm bếp (Kitchen Ticket) để thông báo cho phục vụ trả món.

## Phân chia bếp nóng và bếp bar
Bếp nóng nhận các món xào nấu. Bếp bar nhận các món nước và giải khát. Mẫu in phiếu bếp được tách riêng biệt.
'''
        },
        {
          'path': '.docs/Ai_Bum/cac-module/kho-hang.md',
          'module': 'kho_hang',
          'content': '''
# Module Kho Hàng
## Cấu hình cảnh báo tồn kho tối thiểu
Chủ quán vào Quản lý kho -> Sản phẩm -> Nhập số lượng "Tồn tối thiểu". Khi số lượng tồn kho chạm ngưỡng này, hệ thống sẽ tự động bật cảnh báo màu đỏ.

## Kiểm kê kho
Định kỳ cuối tuần, quản lý vào mục Kiểm kê kho để nhập số lượng thực tế và cân bằng chênh lệch kho.
'''
        },
        {
          'path': '.docs/Ai_Bum/cac-module/nhan-vien.md',
          'module': 'nhan_vien',
          'content': '''
# Module Nhân Viên
## Cấp quyền trực tiếp cho nhân viên
Vào Danh sách nhân viên -> Chọn nhân viên -> Phân quyền trực tiếp. Tích chọn các module được phép truy cập (pos, table, kitchen, log_viewer).

## Đặt mã PIN duyệt nhanh
Quản lý vào Cài đặt cá nhân -> Đổi mã PIN 6 số để duyệt các thao tác nhạy cảm như hủy bill hoặc giảm giá.
'''
        },
        {
          'path': '.docs/Ai_Bum/cac-module/cham-cong.md',
          'module': 'cham_cong',
          'content': '''
# Module Chấm Công
## Chấm công bằng mã QR
Nhân viên mở app Quán Nhỏ -> Chọn Chấm công -> Quét mã QR tại cửa hàng để ghi nhận giờ vào ca và giờ ra ca.
'''
        },
        {
          'path': '.docs/Ai_Bum/cac-module/luong.md',
          'module': 'luong',
          'content': '''
# Module Tính Lương
## Chốt bảng lương hàng tháng
Chủ quán vào mục Tính lương -> Chọn tháng cần chốt -> Bấm "Tính bảng lương". Hệ thống tự động cộng tổng giờ làm và tiền phạt/thưởng.
'''
        },
      ];

      RagEngine.loadKnowledgeBase(mockKnowledgeBase);
    });

    test('Demo 30+ câu hỏi hướng dẫn nghiệp vụ & Đo Precision@K', () {
      final List<Map<String, String>> evalQueries = [
        {'query': 'Cách hủy món trên bàn', 'expectedModule': 'ban_hang'},
        {'query': 'Làm sao để in lại hóa đơn', 'expectedModule': 'ban_hang'},
        {'query': 'Làm thế nào để báo hoàn thành món ở bếp', 'expectedModule': 'bep'},
        {'query': 'Phân biệt bếp nóng và bếp bar', 'expectedModule': 'bep'},
        {'query': 'Cài đặt cảnh báo tồn kho tối thiểu', 'expectedModule': 'kho_hang'},
        {'query': 'Cách cân bằng chênh lệch kiểm kê kho', 'expectedModule': 'kho_hang'},
        {'query': 'Cách phân quyền trực tiếp cho nhân viên', 'expectedModule': 'nhan_vien'},
        {'query': 'Đổi mã PIN 6 số duyệt nhanh', 'expectedModule': 'nhan_vien'},
        {'query': 'Hướng dẫn chấm công bằng mã QR', 'expectedModule': 'cham_cong'},
        {'query': 'Cách tính bảng lương hàng tháng', 'expectedModule': 'luong'},
        // 20 câu biến thể tiếng Việt bổ sung
        {'query': 'Hủy món đã gọi ở đâu', 'expectedModule': 'ban_hang'},
        {'query': 'Chỉ tớ cách in lại bill', 'expectedModule': 'ban_hang'},
        {'query': 'Trả món ở bếp như thế nào', 'expectedModule': 'bep'},
        {'query': 'Bếp bar khác bếp nóng chỗ nào', 'expectedModule': 'bep'},
        {'query': 'Cài đặt báo kho sắp hết', 'expectedModule': 'kho_hang'},
        {'query': 'Kiểm kê nguyên liệu kho', 'expectedModule': 'kho_hang'},
        {'query': 'Cấp quyền cho thu ngân', 'expectedModule': 'nhan_vien'},
        {'query': 'Quên mã PIN 6 số', 'expectedModule': 'nhan_vien'},
        {'query': 'Quét mã QR đi ca', 'expectedModule': 'cham_cong'},
        {'query': 'Chốt lương tháng này', 'expectedModule': 'luong'},
        {'query': 'Hủy đơn hàng ghi vào đâu', 'expectedModule': 'ban_hang'},
        {'query': 'Phiếu bếp trạm bếp', 'expectedModule': 'bep'},
        {'query': 'Ngưỡng tồn kho màu đỏ', 'expectedModule': 'kho_hang'},
        {'query': 'Tích chọn module được phép', 'expectedModule': 'nhan_vien'},
        {'query': 'Ghi nhận giờ vào ca', 'expectedModule': 'cham_cong'},
        {'query': 'Cộng tổng giờ làm', 'expectedModule': 'luong'},
        {'query': 'Hủy bill giảm giá', 'expectedModule': 'nhan_vien'},
        {'query': 'Món nước và giải khát', 'expectedModule': 'bep'},
        {'query': 'Tự động bật cảnh báo kho', 'expectedModule': 'kho_hang'},
        {'query': 'Giờ ra ca vào ca', 'expectedModule': 'cham_cong'},
      ];

      int top1Hits = 0;
      int top3Hits = 0;

      for (final q in evalQueries) {
        final queryText = q['query']!;
        final expectedModule = q['expectedModule']!;

        final results = RagEngine.query(queryText, topK: 3);

        if (results.isNotEmpty && results.first.chunk.module == expectedModule) {
          top1Hits++;
        }

        if (results.any((r) => r.chunk.module == expectedModule)) {
          top3Hits++;
        }
      }

      final precisionTop1 = top1Hits / evalQueries.length;
      final precisionTop3 = top3Hits / evalQueries.length;

      print('=== RAG ENGINE EVALUATION REPORT ===');
      print('Total Evaluation Queries: ${evalQueries.length}');
      print('Top-1 Hits: $top1Hits / ${evalQueries.length} (${(precisionTop1 * 100).toStringAsFixed(1)}%)');
      print('Top-3 Hits: $top3Hits / ${evalQueries.length} (${(precisionTop3 * 100).toStringAsFixed(1)}%)');
      print('Precision@1: ${precisionTop1.toStringAsFixed(4)}');
      print('Precision@3: ${precisionTop3.toStringAsFixed(4)}');
      print('Total Chunks Indexed: ${RagEngine.totalChunks}');

      expect(precisionTop1, greaterThanOrEqualTo(0.85));
      expect(precisionTop3, greaterThanOrEqualTo(0.95));
    });
  });
}
