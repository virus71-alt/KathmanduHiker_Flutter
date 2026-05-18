import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/firebase_failure_mapper.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../sources/firestore_trail_source.dart';
import '../sources/firestore_user_source.dart';

class UserRepositoryImpl implements UserRepository {
  final FirestoreUserSource _users;
  final FirestoreTrailSource _trails;
  final FirebaseAuth _auth;

  UserRepositoryImpl({
    required FirestoreUserSource users,
    required FirestoreTrailSource trails,
    required FirebaseAuth auth,
  })  : _users = users,
        _trails = trails,
        _auth = auth;

  @override
  Stream<UserProfile> watchProfile(String uid) =>
      _users.watchProfile(uid).map((dto) => dto.toEntity());

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) => _users
      .watchNotifications(uid)
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Future<Either<Failure, UserProfile>> getProfile(String uid) async {
    try {
      final dto = await _users.getProfile(uid);
      if (dto == null) return const Left(NotFoundFailure());
      return Right(dto.toEntity());
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, List<PublicProfile>>> searchUsers(
    String query, {
    String? excludeUid,
  }) async {
    try {
      final lower = query.toLowerCase();
      final dtos = await _users.searchByDisplayName(excludeUid: excludeUid);
      final results = dtos
          .where((u) => u.displayName.toLowerCase().contains(lower))
          .map((d) => d.toEntity())
          .toList();
      return Right(results);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
    required String location,
    required String phone,
    required String insta,
    required bool showPhone,
    File? profileImage,
  }) async {
    try {
      final updates = <String, dynamic>{
        'displayName': displayName,
        'bio': bio,
        'location': location,
        'phone': phone,
        'insta': insta,
        'showPhone': showPhone,
      };
      if (profileImage != null) {
        updates['profilePic'] =
            await _users.uploadProfilePic(uid, profileImage);
      }
      await _users.updateProfile(uid, updates);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFavorite({
    required String uid,
    required String trailId,
    required bool add,
  }) async {
    try {
      if (add) {
        await _users.addToArray(uid, 'favoriteTrails', trailId);
      } else {
        await _users.removeFromArray(uid, 'favoriteTrails', trailId);
      }
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    try {
      await _users.addToArray(toUid, 'receivedRequests', fromUid);
      await _users.addToArray(fromUid, 'sentRequests', toUid);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> cancelFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    try {
      await _users.removeFromArray(toUid, 'receivedRequests', fromUid);
      await _users.removeFromArray(fromUid, 'sentRequests', toUid);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> acceptFriendRequest({
    required String uid,
    required String displayName,
    required String senderUid,
  }) async {
    try {
      await _users.addToArray(uid, 'friends', senderUid);
      await _users.removeFromArray(uid, 'receivedRequests', senderUid);
      await _users.addToArray(senderUid, 'friends', uid);
      await _users.removeFromArray(senderUid, 'sentRequests', uid);
      await _users.addNotification(senderUid, {
        'message': '$displayName accepted your friend request! 🤝',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> rejectFriendRequest({
    required String uid,
    required String senderUid,
  }) async {
    try {
      await _users.removeFromArray(uid, 'receivedRequests', senderUid);
      await _users.removeFromArray(senderUid, 'sentRequests', uid);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    try {
      await _users.removeFromArray(uid, 'friends', friendUid);
      await _users.removeFromArray(friendUid, 'friends', uid);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> markNotificationRead({
    required String uid,
    required String notificationId,
  }) async {
    try {
      await _users.markNotificationRead(uid, notificationId);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllNotifications(String uid) async {
    try {
      await _users.clearAllNotifications(uid);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount(String uid) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const Left(AuthFailure('no-current-user'));
    }
    try {
      // Order matches ULTIMATE.md §11.1.4 — wipe data first, then the auth
      // user. If the user.delete() throws requires-recent-login, we've still
      // wiped the profile, but a fresh login will recreate a clean one.
      await _users.deleteProfileAndNotifications(uid);
      await _trails.anonymizeAuthor(uid);
      await _users.deleteProfilePic(uid);
      await user.delete();
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }
}
