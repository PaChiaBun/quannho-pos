import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BoomSuggestionChips extends StatefulWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const BoomSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  State<BoomSuggestionChips> createState() => _BoomSuggestionChipsState();
}

class _BoomSuggestionChipsState extends State<BoomSuggestionChips> {
  // Phông Google tải xong SAU khi nút đã đo kích thước (đo bằng phông tạm, hẹp hơn) → nút giữ bề rộng cũ, chữ bị
  // cắt (Chủ Quán thấy trên web 24/10). Chờ phông tải xong rồi dựng lại danh sách để nút đo lại đúng bề rộng.
  int _fontsGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await GoogleFonts.pendingFonts();
      } catch (_) {
        return; // không tải được phông → giữ phông tạm, không cắt chữ
      }
      if (mounted) setState(() => _fontsGen++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    const kNavy = Color(0xFF1C2151);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: ValueKey(_fontsGen),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ActionChip(
            backgroundColor: Colors.white,
            side: BorderSide(color: kNavy.withValues(alpha: 0.15), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            label: Text(
              suggestion,
              style: GoogleFonts.plusJakartaSans(
                color: kNavy,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            onPressed: () => widget.onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }
}
