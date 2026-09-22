import 'package:uuid/uuid.dart';

enum MessageRole { user, bum }

enum MessageStatus { loading, streaming, completed, error }

class BumMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime createdAt;
  final MessageStatus status;
  final List<String>? suggestions;

  // Phase C: Feedback Fields
  final String? feedbackRating; // 'thumbs_up', 'thumbs_down'
  final String?
  feedbackReason; // 'incorrect_data', 'misunderstood_question', etc.
  final String? proposedAnswer; // User-suggested correct answer
  final Map<String, dynamic>?
  evidenceReference; // Tool metadata (tool_name, latency_ms, status, route)
  final String? sourceMessageId; // ID of the user query message being answered
  final String?
  feedbackStatus; // 'initial', 'submitting', 'submitted', 'failed'

  BumMessage({
    String? id,
    required this.content,
    required this.role,
    DateTime? createdAt,
    this.status = MessageStatus.completed,
    this.suggestions,
    this.feedbackRating,
    this.feedbackReason,
    this.proposedAnswer,
    this.evidenceReference,
    this.sourceMessageId,
    this.feedbackStatus,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isBum => role == MessageRole.bum;
  bool get isError => status == MessageStatus.error;
  bool get isLoading => status == MessageStatus.loading;
  bool get isStreaming => status == MessageStatus.streaming;

  bool get hasFeedback => feedbackRating != null;
  bool get isThumbsUp => feedbackRating == 'thumbs_up';
  bool get isThumbsDown => feedbackRating == 'thumbs_down';

  bool get isFeedbackSubmitting => feedbackStatus == 'submitting';
  bool get isFeedbackSubmitted => feedbackStatus == 'submitted';
  bool get isFeedbackFailed => feedbackStatus == 'failed';
  bool get isFeedbackPairingRequired => feedbackStatus == 'pairing_required';

  BumMessage copyWith({
    String? content,
    MessageStatus? status,
    List<String>? suggestions,
    String? feedbackRating,
    String? feedbackReason,
    String? proposedAnswer,
    Map<String, dynamic>? evidenceReference,
    String? sourceMessageId,
    String? feedbackStatus,
  }) {
    return BumMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      createdAt: createdAt,
      status: status ?? this.status,
      suggestions: suggestions ?? this.suggestions,
      feedbackRating: feedbackRating ?? this.feedbackRating,
      feedbackReason: feedbackReason ?? this.feedbackReason,
      proposedAnswer: proposedAnswer ?? this.proposedAnswer,
      evidenceReference: evidenceReference ?? this.evidenceReference,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      feedbackStatus: feedbackStatus ?? this.feedbackStatus,
    );
  }
}
