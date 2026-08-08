import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bum_message.dart';
import 'bum_suggestion_chips.dart';
import 'bum_typing_indicator.dart';

class BumMessageBubble extends StatelessWidget {
  final BumMessage message;
  final Function(String)? onSuggestionTap;
  final VoidCallback? onRetryTap;

  const BumMessageBubble({
    super.key,
    required this.message,
    this.onSuggestionTap,
    this.onRetryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    const kNavy = Color(0xFF1C2151);
    const kRed = Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                // Avatar Bum 🐘
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/logo_head.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // Bubble content
              Flexible(
                child: message.isLoading 
                ? const BumTypingIndicator()
                : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? kNavy : (message.isError ? const Color(0xFFFEEBEE) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: message.isError ? Border.all(color: kRed.withValues(alpha: 0.3)) : null,
                    boxShadow: message.isError ? null : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: GoogleFonts.outfit(
                          color: isUser ? Colors.white : (message.isError ? kRed : kNavy),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                      if (message.isError && onRetryTap != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onRetryTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 16, color: kRed),
                              const SizedBox(width: 4),
                              Text(
                                'Thử lại',
                                style: GoogleFonts.outfit(
                                  color: kRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Suggestions dưới bubble của Bum
          if (!isUser && message.suggestions != null && message.suggestions!.isNotEmpty && onSuggestionTap != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 48), // Canh lề với bong bóng chat
              child: BumSuggestionChips(
                suggestions: message.suggestions!,
                onSuggestionTap: onSuggestionTap!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
