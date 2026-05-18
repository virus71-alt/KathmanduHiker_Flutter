class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final String status;
  final bool isUnsent;
  final int? expiresAt;
  final Map<String, String> reactions;
  final List<String> deletedBy;

  const ChatMessage({
    this.id = '',
    this.senderId = '',
    this.text = '',
    this.timestamp = 0,
    this.status = 'sent',
    this.isUnsent = false,
    this.expiresAt,
    this.reactions = const {},
    this.deletedBy = const [],
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    int? timestamp,
    String? status,
    bool? isUnsent,
    int? expiresAt,
    Map<String, String>? reactions,
    List<String>? deletedBy,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        senderId: senderId ?? this.senderId,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
        isUnsent: isUnsent ?? this.isUnsent,
        expiresAt: expiresAt ?? this.expiresAt,
        reactions: reactions ?? this.reactions,
        deletedBy: deletedBy ?? this.deletedBy,
      );
}
