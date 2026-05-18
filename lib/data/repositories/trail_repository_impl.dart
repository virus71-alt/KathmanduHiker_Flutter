import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/firebase_failure_mapper.dart';
import '../../domain/entities/trail.dart';
import '../../domain/repositories/trail_repository.dart';
import '../../utils/ranking_manager.dart' show RankingManager;
import '../models/trail_dto.dart';
import '../sources/firestore_trail_source.dart';
import '../sources/firestore_user_source.dart';

class TrailRepositoryImpl implements TrailRepository {
  final FirestoreTrailSource _trails;
  final FirestoreUserSource _users;

  TrailRepositoryImpl({
    required FirestoreTrailSource trails,
    required FirestoreUserSource users,
  })  : _trails = trails,
        _users = users;

  @override
  Stream<List<Trail>> watchApprovedTrails() => _trails
      .watchApproved()
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Stream<List<Trail>> watchMySubmissions(String uid) => _trails
      .watchByAuthor(uid)
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Stream<List<Trail>> watchPendingTrails() => _trails
      .watchPending()
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Future<Either<Failure, Trail>> getTrail(String id) async {
    try {
      final dto = await _trails.getById(id);
      if (dto == null) return const Left(NotFoundFailure());
      return Right(dto.toEntity());
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> addTrail(Trail trail) async {
    try {
      await _trails.add(TrailDto.fromEntity(trail).toMap());
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> updateTrail(Trail trail) async {
    try {
      final dto = TrailDto.fromEntity(trail);
      await _trails.set(dto.id, dto.toMap());
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTrail(String id) async {
    try {
      await _trails.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> approveTrail(String id) async {
    try {
      final dto = await _trails.getById(id);
      if (dto == null) return const Left(NotFoundFailure());

      // Side effects only run if we know who to credit. A trail with empty
      // authorId means the author deleted their account — we still approve
      // the trail but skip notification/XP/activity.
      if (dto.authorId.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await _users.addNotification(dto.authorId, {
          'message': "Your trail '${dto.name}' was approved by an Admin! 🎉",
          'timestamp': nowMs,
          'isRead': false,
        });
        await _users.incrementXP(dto.authorId, RankingManager.xpTrailApproved);
        await _users.addActivity({
          'userId': dto.authorId,
          'userName': dto.authorName.isNotEmpty ? dto.authorName : 'A Hiker',
          'userPic': '',
          'actionType': 'discovered a new trail:',
          'targetName': dto.name,
          'targetId': id,
          'timestamp': nowMs,
        });
      }
      await _trails.update(id, {'isApproved': true});
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }
}
