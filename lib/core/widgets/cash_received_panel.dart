import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/money_formatter.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);

/// "Tiền mặt của khách" + nút tiền nhanh + "Tiền thối lại / Còn thiếu" khi thu tiền mặt. Chỉ giúp thu
/// ngân tính tiền thối, không bắt nhập, không gửi máy chủ. Dùng chung cho thu tiền ở bàn và bán quầy
/// (trước chỉ màn Bàn có).
class CashReceivedPanel extends StatelessWidget {
  const CashReceivedPanel({
    super.key,
    required this.controller,
    required this.total,
  });

  final TextEditingController controller;
  final double total;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final entered = double.tryParse(value.text) ?? 0;
        final List<int> suggestions = [];
        if (total > 0) {
          suggestions.add(total.toInt());
          for (final val in const [10000, 20000, 50000, 100000, 200000, 500000]) {
            if (val > total && suggestions.length < 5 && !suggestions.contains(val)) {
              suggestions.add(val);
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiền mặt của khách',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kNavy.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kNavy,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập tiền khách đưa...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
                    color: _kNavy.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kOrange, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Lớp Material riêng: nền nút (Ink) vẽ ngay đây — bảng thanh toán quầy có nền màu đè lên
            // Material bên dưới nên trước nút mất nền, ô vừa chọn chữ trắng trên nền trắng.
            Material(
              type: MaterialType.transparency,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((sug) {
                  // Sáng theo số vừa chọn/nhập (trước luôn sáng ô "đúng tiền" dù đã chọn ô khác).
                  final selected = sug == entered;
                  return InkWell(
                    onTap: () => controller.text = '$sug',
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _kOrange : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _kOrange : _kNavy.withValues(alpha: 0.12),
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: _kOrange.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        fmtVnd(sug),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _kNavy,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (entered > 0) ...[
              const SizedBox(height: 14),
              _changeBox(entered - total),
            ],
          ],
        );
      },
    );
  }

  Widget _changeBox(double change) {
    final enough = change >= 0;
    final fg = enough ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enough ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enough ? const Color(0xFFA5D6A7) : const Color(0xFFFFB74D),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                enough ? Icons.change_circle_rounded : Icons.warning_amber_rounded,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                enough ? 'TIỀN THỐI LẠI:' : 'Còn thiếu:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: fg,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            fmtVnd(enough ? change : -change),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: fg,
              fontSize: enough ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
