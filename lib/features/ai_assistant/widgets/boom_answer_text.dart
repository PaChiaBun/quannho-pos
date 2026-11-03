import 'package:flutter/material.dart';

// Câu trả lời của Boom có bố cục (03/11/2026): Chủ Quán xem trên Sunmi thấy chữ "lủng củng" — mọi dòng cùng một kiểu,
// tiêu đề mục không nổi, gạch đầu dòng xuống hàng không thụt. Máy chủ đã viết theo mục ("Vì sao:", "Việc tuần này:",
// "- …"), ở đây chỉ vẽ đúng các mục đó: kết luận đậm, tiêu đề mục đậm, gạch đầu dòng thụt treo, khoảng cách giữa mục.

enum BoomDongLoai { ketLuan, tieuDe, gach, chu, cach }

class BoomDong {
  final BoomDongLoai loai;
  final String nhan; // tiêu đề mục ("Vì sao") hoặc dấu đầu dòng ("•", "1.")
  final String chu;
  const BoomDong(this.loai, {this.nhan = '', this.chu = ''});
}

final _tieuDe = RegExp(
  r'^(Vì sao|Việc tuần này|Việc làm|Việc cần làm|Cần xem lại|Lưu ý|Gợi ý|Kết luận|Tuần \d+(?:\s*[–-]\s*\d+)?|Bước \d+)\s*:\s*(.*)$',
);
final _gach = RegExp(r'^\s*([-•*]|\d+[.)])\s+(.+)$');

/// Tách câu trả lời thành các dòng có loại. Kết luận (đoạn đầu) chỉ đậm khi câu có từ 2 đoạn trở lên.
List<BoomDong> tachBoomTraLoi(String text) {
  final doan = text.trim().split(RegExp(r'\n\s*\n'));
  final out = <BoomDong>[];
  for (var i = 0; i < doan.length; i++) {
    if (i > 0) out.add(const BoomDong(BoomDongLoai.cach));
    for (final raw in doan[i].split('\n')) {
      final d = raw.trimRight();
      if (d.trim().isEmpty) continue;
      final g = _gach.firstMatch(d);
      final t = _tieuDe.firstMatch(d.trim());
      if (g != null) {
        final m = g.group(1)!;
        out.add(
          BoomDong(
            BoomDongLoai.gach,
            nhan: RegExp(r'\d').hasMatch(m) ? m : '•',
            chu: g.group(2)!.trim(),
          ),
        );
      } else if (t != null) {
        out.add(
          BoomDong(
            BoomDongLoai.tieuDe,
            nhan: t.group(1)!,
            chu: t.group(2)!.trim(),
          ),
        );
      } else if (i == 0 && doan.length > 1) {
        out.add(BoomDong(BoomDongLoai.ketLuan, chu: d.trim()));
      } else {
        out.add(BoomDong(BoomDongLoai.chu, chu: d.trim()));
      }
    }
  }
  return out;
}

class BoomAnswerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const BoomAnswerText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final dam = style.copyWith(fontWeight: FontWeight.w700);
    final children = <Widget>[];
    for (final d in tachBoomTraLoi(text)) {
      switch (d.loai) {
        case BoomDongLoai.cach:
          children.add(const SizedBox(height: 10));
        case BoomDongLoai.ketLuan:
          children.add(
            Text(d.chu, style: style.copyWith(fontWeight: FontWeight.w600)),
          );
        case BoomDongLoai.tieuDe:
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${d.nhan}:', style: dam),
                    if (d.chu.isNotEmpty)
                      TextSpan(text: ' ${d.chu}', style: style),
                  ],
                ),
              ),
            ),
          );
        case BoomDongLoai.gach:
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: d.nhan == '•' ? 16 : 22,
                    child: Text(d.nhan, style: dam),
                  ),
                  Expanded(child: Text(d.chu, style: style)),
                ],
              ),
            ),
          );
        case BoomDongLoai.chu:
          children.add(Text(d.chu, style: style));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
