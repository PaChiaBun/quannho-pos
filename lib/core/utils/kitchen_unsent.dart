import '../repositories/ban_repository.dart';

/// Món chưa gửi bếp quá chừng này thì cảnh báo.
const Duration kUnsentWarnAfter = Duration(minutes: 3);

/// Các món còn `chua_gui` mà đã thêm vào bàn từ [after] trở lên.
List<BanSessionItemModel> overdueUnsentItems(
  Iterable<BanSessionItemModel> items,
  DateTime now, {
  Duration after = kUnsentWarnAfter,
}) {
  final limit = now.millisecondsSinceEpoch - after.inMilliseconds;
  return items
      .where(
        (i) =>
            i.kitchenStatus == 'chua_gui' &&
            i.addedAt > 0 &&
            i.addedAt <= limit,
      )
      .toList();
}

/// Một bước gửi bếp quá hạn: nói rõ bước nào để log/thông báo không mơ hồ.
class KitchenStepTimeout implements Exception {
  KitchenStepTimeout(this.step, this.timeout);
  final String step;
  final Duration timeout;
  @override
  String toString() => 'Bước "$step" quá ${timeout.inSeconds} giây';
}

/// Chạy một bước gửi bếp có giới hạn thời gian.
Future<T> kitchenStep<T>(
  String step,
  Future<T> future, {
  Duration timeout = const Duration(seconds: 10),
}) => future.timeout(
  timeout,
  onTimeout: () => throw KitchenStepTimeout(step, timeout),
);
