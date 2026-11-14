// Bò Đen 30/10/2026: để mở màn "Thanh toán thành công" qua đêm, app hỏi món của bàn đã đóng
// suốt 3 tiếng (cả khi tắt màn hình); thêm món luôn gọi thử RPC add_session_items không tồn tại (404).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = File('lib/core/repositories/ban_repository.dart').readAsStringSync();
  final screen = File('lib/screens/ban_screen.dart').readAsStringSync();

  test('vòng hỏi món bỏ qua lượt hỏi khi app chạy nền', () {
    final loop = repo.substring(repo.indexOf('watchSessionItems(String sessionId)'));
    final skip = loop.indexOf('AppLifecycleState.resumed');
    expect(skip, isNot(-1));
    expect(skip, lessThan(loop.indexOf('_querySessionItems(sessionId)')));
  });

  // Bò Đen 11/11: vòng cũ bị hủy (invalidate) vẫn hỏi thêm một lượt → 3 lượt trùng trên 5G.
  test('vòng hỏi món dừng ngay khi bị hủy, không hỏi/ghi lỗi thêm', () {
    final loop = repo.substring(repo.indexOf('watchSessionItems(String sessionId)'));
    expect(loop, contains('out.onCancel = () => active = false;'));
    expect(loop, contains('while (active())'));
    final query = loop.indexOf('await _querySessionItems(sessionId)');
    final stop = loop.indexOf('if (!active()) break;', query);
    expect(stop, greaterThan(query));
    expect(stop, lessThan(loop.indexOf('out.add(items)')));
    final caught = loop.indexOf('} catch (e) {', query);
    expect(loop.indexOf('if (!active()) break;', caught), lessThan(loop.indexOf('failures++', caught)));
  });

  test('vòng trạng thái bàn: dừng khi bị hủy, có hạn chót, lỗi mạng không xóa trắng sơ đồ', () {
    final loop = repo.substring(
      repo.indexOf('watchActiveSessions()'),
      repo.indexOf('Future<BanSessionModel> openSession('),
    );
    expect(loop, contains('out.onCancel = () => active = false;'));
    expect(loop, contains('.timeout(_sessionItemsTimeout)'));
    expect(loop, contains('out.add(lastGood ?? {});'));
    expect(loop, isNot(contains('async*')));
  });

  test('bàn đã thanh toán thì màn bàn thôi theo dõi món', () {
    final ok = screen.indexOf('setState(() => _settledItems = items);');
    expect(ok, greaterThan(screen.indexOf("'Atomic V5 settlement")));
    expect(screen, contains('final itemsAsync = settled != null'));
  });

  test('không gọi RPC add_session_items (máy chủ không có)', () {
    expect(repo, isNot(contains("'add_session_items'")));
  });
}
