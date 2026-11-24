import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hình ngành mà bộ biểu tượng Material không có. Vẽ trên lưới 24×24, một màu, nét bo tròn
/// để đặt cạnh biểu tượng Material không lệch tông.
enum NganhHinh { biDa, cauLong, bongBan, pickleball }

class NganhIcon extends StatelessWidget {
  final NganhHinh hinh;
  final double size;
  final Color color;

  const NganhIcon(this.hinh, {super.key, this.size = 24, this.color = Colors.black});

  // Center: khung biểu tượng của ô module ép con kín khung, không canh giữa thì hình bị kéo to bằng cả khung.
  @override
  Widget build(BuildContext context) => Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _NganhPainter(hinh, color)),
        ),
      );
}

/// Cụm bốn hình cho ô "Các hoạt động tính giờ": bi da, cầu lông, bóng đá, micro karaoke xếp 2×2.
/// [size] là cỡ biểu tượng thường của ô; cụm vẽ rộng gấp rưỡi để bốn hình con vẫn đọc được.
class NganhCumIcon extends StatelessWidget {
  final double size;
  final Color color;

  const NganhCumIcon({super.key, this.size = 24, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    final canh = size * 1.5;
    final con = canh * 0.46;
    Widget o(Widget w) => SizedBox.square(dimension: con, child: Center(child: w));
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: canh,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                o(NganhIcon(NganhHinh.biDa, size: con, color: color)),
                o(NganhIcon(NganhHinh.cauLong, size: con, color: color)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                o(Icon(Icons.sports_soccer_rounded, size: con, color: color)),
                o(Icon(Icons.mic_external_on_rounded, size: con, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dùng làm `iconBuilder` hằng cho ô module.
Widget cumIconTinhGio(double size, Color color) => NganhCumIcon(size: size, color: color);

class _NganhPainter extends CustomPainter {
  final NganhHinh hinh;
  final Color color;
  const _NganhPainter(this.hinh, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.save();
    canvas.scale(s);
    // Lớp riêng để "khoét" (BlendMode.clear) không ăn vào nền phía sau.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    final to = Paint()
      ..color = color
      ..isAntiAlias = true;
    final khoet = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    switch (hinh) {
      case NganhHinh.biDa:
        _biDa(canvas, to, khoet);
      case NganhHinh.cauLong:
        _cauLong(canvas, to, khoet);
      case NganhHinh.bongBan:
        _bongBan(canvas, to, khoet);
      case NganhHinh.pickleball:
        _pickleball(canvas, to, khoet);
    }
    canvas.restore();
    canvas.restore();
  }

  // Bi số 8: bi đặc, ô tròn trắng lệch lên trên, số 8 là hai vòng tròn chồng nhau.
  void _biDa(Canvas c, Paint to, Paint khoet) {
    c.drawCircle(const Offset(12, 12), 9.6, to);
    c.drawCircle(const Offset(12, 9.9), 5.0, khoet);
    c.drawCircle(const Offset(12, 7.9), 1.75, to);
    c.drawCircle(const Offset(12, 7.9), 0.7, khoet);
    c.drawCircle(const Offset(12, 11.55), 2.05, to);
    c.drawCircle(const Offset(12, 11.55), 0.9, khoet);
  }

  // Quả cầu lông: núm cao su ở dưới trái, tán lông xoè lên trên phải.
  void _cauLong(Canvas c, Paint to, Paint khoet) {
    c.translate(12, 12);
    c.rotate(35 * math.pi / 180);
    c.translate(-12, -12);
    final tan = Path()
      ..moveTo(9.9, 15.0)
      ..lineTo(14.1, 15.0)
      ..lineTo(18.0, 4.6)
      ..lineTo(6.0, 4.6)
      ..close();
    c.drawPath(tan, to);
    // viền bo tròn các góc của tán
    c.drawPath(
      tan,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    final ke = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(11.0, 13.4), const Offset(9.7, 6.0), ke); // khe lông trái
    c.drawLine(const Offset(13.0, 13.4), const Offset(14.3, 6.0), ke); // khe lông phải
    c.drawLine(const Offset(5.0, 16.15), const Offset(19.0, 16.15), ke..strokeWidth = 0.8); // tách tán với núm
    c.drawRRect(
      RRect.fromLTRBAndCorners(
        9.2, 16.55, 14.8, 21.9,
        topLeft: const Radius.circular(0.9),
        topRight: const Radius.circular(0.9),
        bottomLeft: const Radius.circular(2.8),
        bottomRight: const Radius.circular(2.8),
      ),
      to,
    );
  }

  // Vợt bóng bàn: mặt vợt tròn, cán chéo xuống phải, quả bóng nhỏ phía trên phải.
  void _bongBan(Canvas c, Paint to, Paint khoet) {
    c.save();
    c.translate(9.6, 10.2);
    c.rotate(45 * math.pi / 180);
    c.drawRRect(
      RRect.fromLTRBR(4.5, -1.75, 13.4, 1.75, const Radius.circular(1.6)),
      to,
    );
    c.restore();
    c.drawCircle(const Offset(9.6, 10.2), 6.9, to);
    // rãnh giữa mặt vợt và cán
    c.save();
    c.translate(9.6, 10.2);
    c.rotate(45 * math.pi / 180);
    c.drawLine(
      const Offset(7.9, -2.6),
      const Offset(7.9, 2.6),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    c.restore();
    c.drawCircle(const Offset(19.4, 5.4), 2.4, to);
  }

  // Vợt pickleball: mặt vợt chữ nhật bo góc, cán ngắn; quả bóng có lỗ phía trên phải.
  void _pickleball(Canvas c, Paint to, Paint khoet) {
    c.save();
    c.translate(10.0, 11.2);
    c.rotate(-45 * math.pi / 180);
    c.drawRRect(RRect.fromLTRBR(-1.6, 2.0, 1.6, 9.8, const Radius.circular(1.4)), to);
    c.drawRRect(RRect.fromLTRBR(-5.0, -8.2, 5.0, 3.2, const Radius.circular(3.6)), to);
    c.drawLine(
      const Offset(-2.6, 4.0),
      const Offset(2.6, 4.0),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    c.restore();
    c.drawCircle(const Offset(19.2, 5.2), 3.1, to);
    for (final o in const [Offset(18.1, 4.2), Offset(20.4, 4.5), Offset(19.1, 6.5)]) {
      c.drawCircle(o, 0.62, khoet);
    }
  }

  @override
  bool shouldRepaint(_NganhPainter old) => old.hinh != hinh || old.color != color;
}
