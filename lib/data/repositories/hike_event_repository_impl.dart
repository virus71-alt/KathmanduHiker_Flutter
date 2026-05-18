import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/firebase_failure_mapper.dart';
import '../../domain/entities/hike_event.dart';
import '../../domain/repositories/hike_event_repository.dart';
import '../models/hike_event_dto.dart';
import '../sources/firestore_hike_event_source.dart';

class HikeEventRepositoryImpl implements HikeEventRepository {
  final FirestoreHikeEventSource _events;

  HikeEventRepositoryImpl({required FirestoreHikeEventSource events})
      : _events = events;

  @override
  Stream<List<HikeEvent>> watchEventsForTrail(String trailId) => _events
      .watchByTrail(trailId)
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Stream<List<HikeEvent>> watchMyEvents(String uid) => _events
      .watchByAttendee(uid)
      .map((dtos) => dtos.map((d) => d.toEntity()).toList());

  @override
  Future<Either<Failure, HikeEvent>> getEvent(String id) async {
    try {
      final dto = await _events.getById(id);
      if (dto == null) return const Left(NotFoundFailure());
      return Right(dto.toEntity());
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, String>> createEvent(HikeEvent event) async {
    try {
      final dto = HikeEventDto.fromEntity(event);
      final id = await _events.add(dto.toMap());
      return Right(id);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> joinEvent({
    required String eventId,
    required String uid,
    required String displayName,
  }) async {
    try {
      await _events.update(eventId, {
        'attendees': FieldValue.arrayUnion([uid]),
        'attendeeDetails': FieldValue.arrayUnion([
          {'uid': uid, 'name': displayName},
        ]),
      });
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> leaveEvent({
    required String eventId,
    required String uid,
  }) async {
    try {
      await _events.update(eventId, {
        'attendees': FieldValue.arrayRemove([uid]),
      });
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEvent(String id) async {
    try {
      await _events.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(mapFirebaseError(e));
    }
  }
}
