import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BumSuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const BumSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    const kNavy = Color(0xFF1C2151);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ActionChip(
            backgroundColor: Colors.white,
            side: BorderSide(color: kNavy.withValues(alpha: 0.15), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: Text(
              suggestion,
              style: GoogleFonts.outfit(
                color: kNavy,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            onPressed: () => onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }
}
