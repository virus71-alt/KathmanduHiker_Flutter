import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../repositories/trail_repository.dart';

// Justified use case: approveTrail triggers XP increment, author notification,
// and activity feed entry — cross-cutting side effects that belong behind a
// named boundary rather than scattered across the UI layer.
class ApproveTrailUseCase {
  final TrailRepository _repo;
  ApproveTrailUseCase(this._repo);

  Future<Either<Failure, void>> call(String trailId) =>
      _repo.approveTrail(trailId);
}
