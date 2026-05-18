import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  // Deterministic ID from two UIDs — sorts lexicographically so uid1_uid2 is
  // always the same regardless of which user opens the chat.
  String chatId(String uid1, String uid2);

  // Stream — errors surface through Riverpod's error state.
  // Already filters out messages soft-deleted by [viewerUid].
  Stream<List<ChatMessage>> watchMessages(String chatId, {required String viewerUid});

  // Sends the message and marks the chat as unread for [recipientUid].
  Future<Either<Failure, void>> sendMessage({
    required String chatId,
    required String recipientUid,
    required ChatMessage message,
  });

  // Sets [uid]'s reaction on the message to [emoji]. Replaces any prior
  // reaction from the same user. Screens compose toggle behaviour by calling
  // [removeReaction] when the tapped emoji matches the existing one.
  Future<Either<Failure, void>> setReaction({
    required String chatId,
    required String messageId,
    required String uid,
    required String emoji,
  });

  Future<Either<Failure, void>> removeReaction({
    required String chatId,
    required String messageId,
    required String uid,
  });

  Future<Either<Failure, void>> unsendMessage({
    required String chatId,
    required String messageId,
  });

  Future<Either<Failure, void>> deleteForMe({
    required String chatId,
    required String messageId,
    required String uid,
  });

  // Removes chatId from the current user's unreadChatIds.
  Future<Either<Failure, void>> markRead({
    required String chatId,
    required String uid,
  });
}
