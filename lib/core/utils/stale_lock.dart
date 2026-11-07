/// Khóa chống bấm đôi nhưng TỰ MỞ nếu giữ quá lâu (tránh kẹt vĩnh viễn khi một lệnh treo).
class StaleLock {
  StaleLock({this.maxHold = const Duration(seconds: 45)});

  final Duration maxHold;
  DateTime? _since;

  bool get held => _since != null;

  /// true = lấy được khóa. Nếu khóa đang bị giữ quá [maxHold] thì coi là kẹt, báo qua
  /// [onStale] (để ghi log) rồi cho lấy khóa mới.
  bool tryAcquire(DateTime now, {void Function(Duration heldFor)? onStale}) {
    final since = _since;
    if (since != null) {
      final heldFor = now.difference(since);
      if (heldFor < maxHold) return false;
      onStale?.call(heldFor);
    }
    _since = now;
    return true;
  }

  void release() => _since = null;
}
