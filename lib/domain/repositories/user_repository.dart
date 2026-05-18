import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/app_notification.dart';
import '../entities/public_profile.dart';
import '../entities/user_profile.dart';

abstract class UserRepository {
  // Streams — errors surface through Riverpod's error state.
  Stream<UserProfile> watchProfile(String uid);
  Stream<List<AppNotification>> watchNotifications(String uid);
  Stream<List<UserProfile>> watchLeaderboard();

  Future<Either<Failure, UserProfile>> getProfile(String uid);
  Future<Either<Failure, List<PublicProfile>>> searchUsers(
    String query, {
    String? excludeUid,
  });

  Future<Either<Failure, void>> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
    required String location,
    required String phone,
    required String insta,
    required bool showPhone,
    File? profileImage,
  });

  Future<Either<Failure, void>> toggleFavorite({
    required String uid,
    required String trailId,
    required bool add,
  });

  Future<Either<Failure, void>> sendFriendRequest({
    required String fromUid,
    required String toUid,
  });

  Future<Either<Failure, void>> cancelFriendRequest({
    required String fromUid,
    required String toUid,
  });

  // displayName is the accepting user's name — used in the notification sent to the sender.
  Future<Either<Failure, void>> acceptFriendRequest({
    required String uid,
    required String displayName,
    required String senderUid,
  });

  Future<Either<Failure, void>> rejectFriendRequest({
    required String uid,
    required String senderUid,
  });

  Future<Either<Failure, void>> removeFriend({
    required String uid,
    required String friendUid,
  });

  Future<Either<Failure, void>> markNotificationRead({
    required String uid,
    required String notificationId,
  });

  Future<Either<Failure, void>> clearAllNotifications(String uid);

  // Must be called while the user has a recent auth session; returns AuthFailure
  // with code 'requires-recent-login' if not.
  Future<Either<Failure, void>> deleteAccount(String uid);
}
