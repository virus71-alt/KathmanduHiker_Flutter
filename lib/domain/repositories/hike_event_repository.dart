import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../entities/hike_event.dart';

abstract class HikeEventRepository {
  // Streams — errors surface through Riverpod's error state.
  Stream<List<HikeEvent>> watchEventsForTrail(String trailId);
  Stream<List<HikeEvent>> watchMyEvents(String uid);

  Future<Either<Failure, HikeEvent>> getEvent(String id);
  Future<Either<Failure, String>> createEvent(HikeEvent event);
  Future<Either<Failure, void>> joinEvent({
    required String eventId,
    required String uid,
    required String displayName,
  });
  Future<Either<Failure, void>> leaveEvent({
    required String eventId,
    required String uid,
  });
  Future<Either<Failure, void>> deleteEvent(String id);
}
