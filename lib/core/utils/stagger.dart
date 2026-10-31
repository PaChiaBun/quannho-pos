/// Độ trễ hiện lần lượt cho dòng thứ [i] của danh sách: chỉ vài dòng đầu được trễ dần,
/// từ dòng [maxSteps] trở đi hiện ngay. Trước đây trễ `i × bước` không giới hạn nên dòng
/// thứ 60 phải chờ ~3 giây mới hiện khi cuộn tới (Bò Đen 29/10/2026).
Duration staggerDelay(int i, int stepMs, {int maxSteps = 8}) =>
    Duration(milliseconds: (i < maxSteps ? i : maxSteps) * stepMs);
