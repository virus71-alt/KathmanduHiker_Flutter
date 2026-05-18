import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_dto.dart';

class FirestoreChatSource {
  final FirebaseFirestore _db;
  FirestoreChatSource(this._db);

  CollectionReference<Map<String, dynamic>> _msgs(String chatId) =>
      _db.collection('chats').doc(chatId).collection('messages');

  Stream<List<ChatMessageDto>> watchMessages(String chatId) => _msgs(chatId)
      .orderBy('timestamp')
      .snapshots()
      .map((s) => s.docs.map(ChatMessageDto.fromDoc).toList());

  Future<void> addMessage(String chatId, Map<String, dynamic> data) =>
      _msgs(chatId).add(data);

  Future<void> updateMessage(
    String chatId,
    String messageId,
    Map<String, dynamic> updates,
  ) =>
      _msgs(chatId).doc(messageId).update(updates);
}
