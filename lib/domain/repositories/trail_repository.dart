import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/trail.dart';

abstract class TrailRepository {
  // Streams — errors surface through Riverpod's error state.
  Stream<List<Trail>> watchApprovedTrails();
  Stream<List<Trail>> watchMySubmissions(String uid);
  Stream<List<Trail>> watchPendingTrails();

  Future<Either<Failure, Trail>> getTrail(String id);
  Future<Either<Failure, void>> addTrail(Trail trail);
  Future<Either<Failure, void>> updateTrail(Trail trail);
  Future<Either<Failure, void>> deleteTrail(String id);

  // Handles XP increment, author notification, and activity feed entry.
  Future<Either<Failure, void>> approveTrail(String id);
}
