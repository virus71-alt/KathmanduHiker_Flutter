import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kathmanduhiker/data/models/hike_event_dto.dart';
import 'package:kathmanduhiker/domain/entities/hike_event.dart';

void main() {
  group('HikeEventDto.fromDoc', () {
    test('full document is parsed into matching fields', () {
      final doc = _FakeDoc('ev-1', {
        'trailId': 'trail-1',
        'trailName': 'Nagarkot',
        'creatorId': 'u-1',
        'creatorName': 'Ranjay',
        'dateText': 'Sunday 10 AM',
        'maxHikers': 10,
        'attendees': ['u-1', 'u-2'],
        'attendeeDetails': [
          {'uid': 'u-1', 'name': 'Ranjay'},
          {'uid': 'u-2', 'name': 'Sita'},
        ],
        'timestamp': 1700000000,
      });

      final dto = HikeEventDto.fromDoc(doc);
      expect(dto.id, 'ev-1');
      expect(dto.trailId, 'trail-1');
      expect(dto.trailName, 'Nagarkot');
      expect(dto.creatorId, 'u-1');
      expect(dto.maxHikers, 10);
      expect(dto.attendees, ['u-1', 'u-2']);
      expect(dto.attendeeDetails.first['name'], 'Ranjay');
      expect(dto.timestamp, 1700000000);
    });

    test('empty document maps to default values, never throws', () {
      final dto = HikeEventDto.fromDoc(_FakeDoc('empty', const {}));
      expect(dto.id, 'empty');
      expect(dto.trailId, '');
      expect(dto.maxHikers, 0);
      expect(dto.attendees, isEmpty);
      expect(dto.attendeeDetails, isEmpty);
    });

    test('null document data is treated like an empty map', () {
      final dto = HikeEventDto.fromDoc(_FakeDoc('null-data', null));
      expect(dto.id, 'null-data');
      expect(dto.trailName, '');
    });

    test('integer timestamp coerced correctly', () {
      final dto = HikeEventDto.fromDoc(_FakeDoc('coerce', {
        'maxHikers': 5,
        'timestamp': 1700000000,
      }));
      expect(dto.maxHikers, 5);
      expect(dto.timestamp, 1700000000);
    });
  });

  group('HikeEventDto.toEntity / fromEntity round-trip', () {
    test('round-trips through fromEntity → toEntity with equal values', () {
      const original = HikeEvent(
        id: 'rt-1',
        trailId: 'trail-rt',
        trailName: 'Phulchowki',
        creatorId: 'u-rt',
        creatorName: 'Hari',
        dateText: 'Saturday 7 AM',
        maxHikers: 8,
        attendees: ['u-rt'],
        timestamp: 1700001234,
      );

      final dto = HikeEventDto.fromEntity(original);
      final entity = dto.toEntity();

      expect(entity.id, original.id);
      expect(entity.trailId, original.trailId);
      expect(entity.trailName, original.trailName);
      expect(entity.creatorId, original.creatorId);
      expect(entity.maxHikers, original.maxHikers);
      expect(entity.attendees, original.attendees);
      expect(entity.timestamp, original.timestamp);
    });
  });

  group('HikeEventDto.toMap', () {
    test('toMap does not include id (Firestore provides it via doc.id)', () {
      const event = HikeEvent(id: 'should-not-appear', trailName: 'Test');
      final map = HikeEventDto.fromEntity(event).toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map['trailName'], 'Test');
    });
  });
}

class _FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._id, this._data);
  final String _id;
  final Map<String, dynamic>? _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
