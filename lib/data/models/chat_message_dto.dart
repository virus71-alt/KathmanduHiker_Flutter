import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/chat_message.dart';

class ChatMessageDto {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final String status;
  final bool isUnsent;
  final int? expiresAt;
  final Map<String, String> reactions;
  final List<String> deletedBy;

  const ChatMessageDto({
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

  factory ChatMessageDto.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawReactions = (d['reactions'] as Map?) ?? const {};
    return ChatMessageDto(
      id: doc.id,
      senderId: (d['senderId'] ?? '') as String,
      text: (d['text'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
      status: (d['status'] ?? 'sent') as String,
      isUnsent: (d['isUnsent'] ?? false) as bool,
      expiresAt:
          d['expiresAt'] == null ? null : (d['expiresAt'] as num).toInt(),
      reactions: rawReactions
          .map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
      deletedBy: ((d['deletedBy'] as List?) ?? const []).cast<String>(),
    );
  }

  factory ChatMessageDto.fromEntity(ChatMessage m) => ChatMessageDto(
        id: m.id,
        senderId: m.senderId,
        text: m.text,
        timestamp: m.timestamp,
        status: m.status,
        isUnsent: m.isUnsent,
        expiresAt: m.expiresAt,
        reactions: m.reactions,
        deletedBy: m.deletedBy,
      );

  ChatMessage toEntity() => ChatMessage(
        id: id,
        senderId: senderId,
        text: text,
        timestamp: timestamp,
        status: status,
        isUnsent: isUnsent,
        expiresAt: expiresAt,
        reactions: reactions,
        deletedBy: deletedBy,
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp,
        'status': status,
        'isUnsent': isUnsent,
        if (expiresAt != null) 'expiresAt': expiresAt,
        'reactions': reactions,
        'deletedBy': deletedBy,
      };
}
