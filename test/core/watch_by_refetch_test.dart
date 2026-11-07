import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/paged_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Máy chủ không tồn tại → realtime không kết nối được → hàm phải tự tải lại theo chu kỳ.
SupabaseClient deadClient() => SupabaseClient('http://127.0.0.1:9', 'test-key');

const _fast = Duration(milliseconds: 100);

void main() {
  test(
    'Phát dữ liệu lần đầu, mất realtime thì tự tải lại; đóng màn thì dừng hẳn',
    () async {
      var calls = 0;
      final client = deadClient();
      final stream = watchByRefetch<int>(
        table: 'orders',
        storeId: 's',
        client: client,
        retryEvery: _fast,
        fetch: () async => ++calls,
      );
      final got = <int>[];
      final sub = stream.listen(got.add);
      await Future.delayed(const Duration(milliseconds: 700));
      expect(got.first, 1);
      expect(
        calls,
        greaterThan(2),
        reason: 'không có realtime thì phải tải lại theo chu kỳ',
      );
      await sub.cancel();
      final after = calls;
      await Future.delayed(const Duration(milliseconds: 500));
      expect(calls, after, reason: 'đóng màn rồi không được tải thêm');
      await client.dispose();
    },
  );

  test('Lỗi lần tải đầu: báo lỗi rồi tự thử lại', () async {
    var calls = 0;
    final client = deadClient();
    final errors = <Object>[];
    final got = <String>[];
    final sub = watchByRefetch<String>(
      table: 'orders',
      storeId: 's',
      client: client,
      retryEvery: const Duration(milliseconds: 150),
      fetch: () async {
        calls++;
        if (calls == 1) throw StateError('mạng lỗi');
        return 'ok';
      },
    ).listen(got.add, onError: errors.add);
    await Future.delayed(const Duration(milliseconds: 500));
    expect(errors.length, 1, reason: 'báo lỗi đúng một lần');
    expect(got, contains('ok'), reason: 'tự thử lại và có dữ liệu');
    await sub.cancel();
    await client.dispose();
  });

  test('Màn bị che (tạm dừng): không tải dồn; mở lại tải lại ngay', () async {
    var calls = 0;
    final client = deadClient();
    final got = <int>[];
    final sub = watchByRefetch<int>(
      table: 'orders',
      storeId: 's',
      client: client,
      retryEvery: _fast,
      fetch: () async => ++calls,
    ).listen(got.add);
    await Future.delayed(const Duration(milliseconds: 150));
    sub.pause();
    final paused = calls;
    await Future.delayed(const Duration(milliseconds: 600));
    expect(calls, paused, reason: 'đang che màn thì không tải');
    sub.resume();
    await Future.delayed(const Duration(milliseconds: 50));
    // Tải lại ngay khi mở (có thể thêm 1 lần do chu kỳ 100 ms trùng lúc) — không dồn ~6 lần đã lỡ.
    expect(calls, inInclusiveRange(paused + 1, paused + 2));
    await sub.cancel();
    await client.dispose();
  });

  test(
    'Tải bị treo không làm đứng luồng (giới hạn thời gian mỗi lần tải)',
    () async {
      var calls = 0;
      final client = deadClient();
      final got = <int>[];
      final sub = watchByRefetch<int>(
        table: 'orders',
        storeId: 's',
        client: client,
        retryEvery: _fast,
        fetchTimeout: const Duration(milliseconds: 150),
        fetch: () {
          calls++;
          if (calls == 2) return Completer<int>().future; // treo mãi
          return Future.value(calls);
        },
      ).listen(got.add);
      await Future.delayed(const Duration(milliseconds: 900));
      expect(calls, greaterThan(3));
      expect(got.last, greaterThan(2));
      await sub.cancel();
      await client.dispose();
    },
  );
}
