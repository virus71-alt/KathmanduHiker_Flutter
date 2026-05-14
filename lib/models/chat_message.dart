import 'package:cloud_firestore/cloud_firestore.dart';

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

  ChatMessage({
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

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawReactions = (d['reactions'] as Map?) ?? const {};
    return ChatMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '') as String,
      text: (d['text'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
      status: (d['status'] ?? 'sent') as String,
      isUnsent: (d['isUnsent'] ?? false) as bool,
      expiresAt: d['expiresAt'] == null ? null : (d['expiresAt'] as num).toInt(),
      reactions: rawReactions
          .map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
      deletedBy: ((d['deletedBy'] as List?) ?? const []).cast<String>(),
    );
  }
}
