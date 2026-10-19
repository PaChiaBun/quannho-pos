import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bum_message.dart';
import 'bum_suggestion_chips.dart';
import 'bum_typing_indicator.dart';
import 'feedback_dialog.dart';

class BumMessageBubble extends StatelessWidget {
  final BumMessage message;
  final Function(String)? onSuggestionTap;
  final VoidCallback? onRetryTap;
  final Function(String rating, {String? reasonCode, String? proposedAnswer})?
  onFeedbackTap;
  final Function(String code)? onPairingRequest;
  final bool isOwnerOrManager;

  const BumMessageBubble({
    super.key,
    required this.message,
    this.onSuggestionTap,
    this.onRetryTap,
    this.onFeedbackTap,
    this.onPairingRequest,
    this.isOwnerOrManager = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    const kNavy = Color(0xFF1C2151);
    const kRed = Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? kNavy
                              : (message.isError
                                    ? const Color(0xFFFEEBEE)
                                    : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                          border: message.isError
                              ? Border.all(color: kRed.withValues(alpha: 0.3))
                              : null,
                          boxShadow: message.isError
                              ? null
                              : [
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
                                color: isUser
                                    ? Colors.white
                                    : (message.isError ? kRed : kNavy),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),

                            // Phase C: Feedback Bar for Bum completed responses (Owner/Manager only)
                            if (!isUser &&
                                message.status == MessageStatus.completed &&
                                !message.isError &&
                                isOwnerOrManager) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (message.isFeedbackSubmitting) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Đang gửi...',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ] else if (message.isFeedbackSubmitted) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Đã gửi phản hồi',
                                      key: const Key(
                                        'feedback_status_submitted',
                                      ),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else if (message
                                      .isFeedbackPairingRequired) ...[
                                    Flexible(
                                      child: Text(
                                        '🔒 Chưa ghép nối thiết bị',
                                        key: const Key(
                                          'feedback_status_pairing_required',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.orange[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      key: const Key('feedback_connect_device'),
                                      onTap: () async {
                                        final code = await PairingDialog.show(
                                          context,
                                        );
                                        if (code != null &&
                                            onPairingRequest != null) {
                                          onPairingRequest!(code);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: kNavy,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Kết nối thiết bị',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else if (message.isFeedbackFailed) ...[
                                    Text(
                                      '⚠️ Gửi thất bại',
                                      key: const Key('feedback_status_failed'),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: kRed,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      key: const Key('feedback_retry_button'),
                                      onTap: () {
                                        if (onFeedbackTap != null &&
                                            message.feedbackRating != null) {
                                          onFeedbackTap!(
                                            message.feedbackRating!,
                                            reasonCode: message.feedbackReason,
                                            proposedAnswer:
                                                message.proposedAnswer,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          'Thử lại',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: kRed,
                                            fontWeight: FontWeight.w700,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    InkWell(
                                      key: const Key('feedback_thumbs_up'),
                                      onTap: () {
                                        if (onFeedbackTap != null) {
                                          onFeedbackTap!('thumbs_up');
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          message.isThumbsUp
                                              ? Icons.thumb_up_rounded
                                              : Icons.thumb_up_alt_outlined,
                                          size: 16,
                                          color: message.isThumbsUp
                                              ? Colors.green
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      key: const Key('feedback_thumbs_down'),
                                      onTap: () async {
                                        final res = await FeedbackDialog.show(
                                          context,
                                          initialRating: 'thumbs_down',
                                          currentAnswer: message.content,
                                        );
                                        if (res != null &&
                                            onFeedbackTap != null) {
                                          onFeedbackTap!(
                                            res.rating,
                                            reasonCode: res.reasonCode,
                                            proposedAnswer: res.proposedAnswer,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          message.isThumbsDown
                                              ? Icons.thumb_down_rounded
                                              : Icons.thumb_down_alt_outlined,
                                          size: 16,
                                          color: message.isThumbsDown
                                              ? kRed
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      key: const Key('feedback_edit_proposed'),
                                      onTap: () async {
                                        final res = await FeedbackDialog.show(
                                          context,
                                          initialRating:
                                              message.feedbackRating ??
                                              'thumbs_down',
                                          currentAnswer: message.content,
                                        );
                                        if (res != null &&
                                            onFeedbackTap != null) {
                                          onFeedbackTap!(
                                            res.rating,
                                            reasonCode: res.reasonCode,
                                            proposedAnswer: res.proposedAnswer,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.edit_note_rounded,
                                          size: 18,
                                          color: message.proposedAnswer != null
                                              ? Colors.blue[700]
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            if (message.isError && onRetryTap != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: onRetryTap,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: kRed,
                                    ),
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
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // Suggestions dưới bubble của Bum
          if (!isUser &&
              message.suggestions != null &&
              message.suggestions!.isNotEmpty &&
              onSuggestionTap != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(
                left: 48,
              ), // Canh lề với bong bóng chat
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
