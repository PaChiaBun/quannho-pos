import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/session_provider.dart';
import '../providers/bum_chat_provider.dart';
import '../services/feedback_service.dart';
import '../widgets/bum_message_bubble.dart';
import '../widgets/bum_suggestion_chips.dart';

class BumChatScreen extends ConsumerStatefulWidget {
  const BumChatScreen({super.key});

  @override
  ConsumerState<BumChatScreen> createState() => _BumChatScreenState();
}

class _BumChatScreenState extends ConsumerState<BumChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _kNavy = Color(0xFF1C2151);
  static const _kOrange = Color(0xFFFF6B35);
  static const _kCream = Color(0xFFFFF8F0);

  final List<String> _defaultSuggestions = [
    'Hôm nay bán được bao nhiêu?',
    'Món nào bán chạy nhất?',
    'Kho có gì sắp hết?',
    'Hôm nay ai đang làm?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage([String? text]) {
    final messageText = text ?? _textController.text;
    if (messageText.trim().isEmpty) return;

    ref.read(bumChatProvider.notifier).sendMessage(messageText);
    _textController.clear();
    _scrollToBottom();
  }

  void _retryMessage() {
    ref.read(bumChatProvider.notifier).retryLastMessage();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(bumChatProvider);
    final session = ref.watch(sessionProvider);

    final bool isOwnerOrManager =
        session?.isOwner == true ||
        session?.role == 'owner' ||
        session?.role == 'manager';

    final bool isTyping =
        messages.isNotEmpty &&
        (messages.last.isLoading || messages.last.isStreaming);

    ref.listen(bumChatProvider, (previous, next) {
      _scrollToBottom();
    });

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Scaffold(
        backgroundColor: _kCream,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kNavy,
              size: 32,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/branding/logo_head.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bum Trợ Lý',
                style: GoogleFonts.outfit(
                  color: _kNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kNavy),
              onPressed: () {
                ref.read(bumChatProvider.notifier).clearChat();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // Chat List
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return BumMessageBubble(
                          message: msg,
                          isOwnerOrManager: isOwnerOrManager,
                          onSuggestionTap: _sendMessage,
                          onRetryTap: _retryMessage,
                          onPairingRequest: (rawCode) async {
                            final res = await FeedbackService()
                                .exchangePairingCode(rawCode: rawCode);
                            if (!context.mounted) return;
                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ghép nối thiết bị thành công! Đang gửi lại phản hồi...',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              final subRes = await ref
                                  .read(bumChatProvider.notifier)
                                  .submitFeedbackForMessage(
                                    msg.id,
                                    rating: msg.feedbackRating ?? 'thumbs_down',
                                    reasonCode: msg.feedbackReason,
                                    proposedAnswer: msg.proposedAnswer,
                                  );
                              if (!context.mounted) return;
                              if (subRes['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã gửi để kiểm duyệt. AI Bum chưa tự học nội dung này.',
                                    ),
                                    backgroundColor: _kNavy,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Kết nối thiết bị thất bại: ${res['message'] ?? 'Mã ghép nối không hợp lệ'}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          onFeedbackTap: (rating, {reasonCode, proposedAnswer}) async {
                            final res = await ref
                                .read(bumChatProvider.notifier)
                                .submitFeedbackForMessage(
                                  msg.id,
                                  rating: rating,
                                  reasonCode: reasonCode,
                                  proposedAnswer: proposedAnswer,
                                );
                            if (!context.mounted) return;
                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã gửi để kiểm duyệt. AI Bum chưa tự học nội dung này.',
                                  ),
                                  backgroundColor: _kNavy,
                                ),
                              );
                            } else if (res['error'] == 'UNAUTHORIZED' ||
                                res['error'] == 'PAIRING_REQUIRED' ||
                                res['status'] == 401) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Phiên làm việc hết hạn hoặc chưa đăng nhập. Vui lòng đăng nhập lại.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else if (res['error'] == 'FORBIDDEN' ||
                                res['status'] == 403) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bạn không có quyền thực hiện thao tác này.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else if (res['error'] == 'CONFLICT' ||
                                res['status'] == 409) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Phản hồi cho câu trả lời này đã được gửi trước đó.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else if (res['error'] == 'RATE_LIMITED' ||
                                res['status'] == 429) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thao tác quá nhanh, vui lòng thử lại sau giây lát.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else if (res['error'] == 'NETWORK_ERROR') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Không thể kết nối máy chủ, vui lòng kiểm tra kết nối mạng.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gửi phản hồi thất bại: ${res['message'] ?? 'Lỗi hệ thống'}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),

                  // Input Area
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isTyping &&
                            (messages.isEmpty ||
                                messages.last.isUser ||
                                (messages.last.isBum &&
                                    (messages.last.suggestions == null ||
                                        messages.last.suggestions!.isEmpty))))
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: BumSuggestionChips(
                              suggestions: _defaultSuggestions,
                              onSuggestionTap: _sendMessage,
                            ),
                          ),

                        // Text Input
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: TextField(
                                    controller: _textController,
                                    style: GoogleFonts.outfit(
                                      color: _kNavy,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Hỏi Bum bất kỳ điều gì...',
                                      hintStyle: GoogleFonts.outfit(
                                        color: Colors.grey.shade500,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 14,
                                          ),
                                    ),
                                    onSubmitted: isTyping ? null : _sendMessage,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: isTyping ? null : () => _sendMessage(),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isTyping ? Colors.grey : _kOrange,
                                    shape: BoxShape.circle,
                                    boxShadow: isTyping
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: _kOrange.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
