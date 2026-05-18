import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/firebase_failure_mapper.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_message_dto.dart';
import '../sources/firestore_chat_source.dart';
import '../sources/firestore_user_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirestoreChatSource _chats;
  final FirestoreUserSource _users;

  ChatRepositoryImpl({
    required FirestoreChatSource chats,
    required FirestoreUserSource users,
  })  : _chats = chats,
        _users = users;

  @override
  String chatId(String uid1, String uid2) =>
      uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';

  @override
  Stream<List<ChatMessage>> watchMessages(
    String chatId, {
    required String viewerUid,
  }) =>
      _chats.watchMessages(chatId).map((dtos) => dtos
          .where((m) => !m.deletedBy.contains(viewerUid))
          .map((d) => d.toEntity())
          .toList());

  @override
  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String recipientUid,
    required ChatMessage message,
  }) async {
    try {
      await _chats.addMessage(
        chatId,
        ChatMessageDto.fromEntity(message).toMap(),
      );
      await _users.addToArray(recipientUid, 'unreadChatIds', chatId);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> setReaction({
    required String chatId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    try {
      // Dot-path update writes a single map entry — cheaper than rewriting
      // the entire reactions map and atomic against concurrent reactions
      // from other users.
      await _chats.updateMessage(chatId, messageId, {'reactions.$uid': emoji});
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> removeReaction({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    try {
      await _chats.updateMessage(
        chatId,
        messageId,
        {'reactions.$uid': FieldValue.delete()},
      );
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> unsendMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _chats.updateMessage(
        chatId,
        messageId,
        {'isUnsent': true, 'text': ''},
      );
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteForMe({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    try {
      await _chats.updateMessage(
        chatId,
        messageId,
        {'deletedBy': FieldValue.arrayUnion([uid])},
      );
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> markRead({
    required String chatId,
    required String uid,
  }) async {
    try {
      await _users.removeFromArray(uid, 'unreadChatIds', chatId);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }
}
