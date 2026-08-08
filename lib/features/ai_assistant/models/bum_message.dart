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
  
  BumMessage({
    String? id,
    required this.content,
    required this.role,
    DateTime? createdAt,
    this.status = MessageStatus.completed,
    this.suggestions,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isBum => role == MessageRole.bum;
  bool get isError => status == MessageStatus.error;
  bool get isLoading => status == MessageStatus.loading;
  bool get isStreaming => status == MessageStatus.streaming;

  BumMessage copyWith({
    String? content,
    MessageStatus? status,
    List<String>? suggestions,
  }) {
    return BumMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      createdAt: createdAt,
      status: status ?? this.status,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}
