import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yama/core/errors/failures.dart';
import 'package:yama/data/repositories/hike_event_repository_impl.dart';
import 'package:yama/data/sources/firestore_hike_event_source.dart';
import 'package:yama/domain/entities/hike_event.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late HikeEventRepositoryImpl repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = HikeEventRepositoryImpl(
      events: FirestoreHikeEventSource(fakeDb),
    );
  });

  group('HikeEventRepositoryImpl.createEvent', () {
    test('returns Right(id) and event is retrievable afterwards', () async {
      const event = HikeEvent(
        trailId: 'trail-1',
        trailName: 'Nagarkot',
        creatorId: 'u-1',
        creatorName: 'Ranjay',
        dateText: 'Sunday 10 AM',
        maxHikers: 6,
        timestamp: 1700000000,
      );

      final result = await repo.createEvent(event);

      expect(result.isRight(), true);
      final id = result.getRight().toNullable()!;
      expect(id, isNotEmpty);

      // Verify the event is actually stored.
      final fetched = await repo.getEvent(id);
      expect(fetched.isRight(), true);
      expect(fetched.getRight().toNullable()?.trailName, 'Nagarkot');
      expect(fetched.getRight().toNullable()?.creatorId, 'u-1');
    });
  });

  group('HikeEventRepositoryImpl.getEvent', () {
    test('returns Left(NotFoundFailure) for a missing document', () async {
      final result = await repo.getEvent('non-existent-id');

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
    });
  });

  group('HikeEventRepositoryImpl.joinEvent / leaveEvent', () {
    test('join adds uid to attendees; leave removes it', () async {
      const event = HikeEvent(
        trailId: 'trail-2',
        trailName: 'Phulchowki',
        creatorId: 'creator',
        maxHikers: 10,
      );
      final createResult = await repo.createEvent(event);
      final eventId = createResult.getRight().toNullable()!;

      final joinResult = await repo.joinEvent(
        eventId: eventId,
        uid: 'u-2',
        displayName: 'Sita',
      );
      expect(joinResult.isRight(), true);

      final afterJoin = await repo.getEvent(eventId);
      expect(afterJoin.getRight().toNullable()?.attendees, contains('u-2'));

      final leaveResult = await repo.leaveEvent(eventId: eventId, uid: 'u-2');
      expect(leaveResult.isRight(), true);

      final afterLeave = await repo.getEvent(eventId);
      expect(afterLeave.getRight().toNullable()?.attendees, isNot(contains('u-2')));
    });
  });

  group('HikeEventRepositoryImpl.deleteEvent', () {
    test('returns Right(null) and event is gone afterwards', () async {
      const event = HikeEvent(trailId: 't', trailName: 'Delete me');
      final id = (await repo.createEvent(event)).getRight().toNullable()!;

      final deleteResult = await repo.deleteEvent(id);
      expect(deleteResult.isRight(), true);

      final fetched = await repo.getEvent(id);
      expect(fetched.isLeft(), true);
      expect(fetched.getLeft().toNullable(), isA<NotFoundFailure>());
    });
  });

  group('HikeEventRepositoryImpl.watchEventsForTrail', () {
    test('emits events for the given trail', () async {
      const ev1 = HikeEvent(trailId: 'trail-watch', trailName: 'Trail A');
      const ev2 = HikeEvent(trailId: 'other-trail', trailName: 'Trail B');
      await repo.createEvent(ev1);
      await repo.createEvent(ev2);

      final events = await repo.watchEventsForTrail('trail-watch').first;

      expect(events.length, 1);
      expect(events.first.trailId, 'trail-watch');
    });
  });
}
