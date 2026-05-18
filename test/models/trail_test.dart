// Per ULTIMATE.md §13 — the Firestore document parser is one of the highest
// crash-risk surfaces in the app: production documents tend to have missing
// fields, wrong types, or partial migrations. We don't have Firestore here,
// so we exercise `Trail.fromDoc` via a tiny in-memory fake snapshot.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yama/models/trail.dart';

void main() {
  group('Trail.fromDoc', () {
    test('full document is parsed into matching fields', () {
      final doc = _FakeDoc('trail-1', {
        'name': 'Nagarkot',
        'difficulty': 'Easy',
        'transportRoute': 'Bus from Bhaktapur',
        'fare': 'NPR 200',
        'food': 'Local tea shops',
        'description': 'Sunrise viewpoint',
        'imageUrls': ['a.jpg', 'b.jpg'],
        'userRating': 4,
        'ratingScore': 4.6,
        'travelMode': 'Public',
        'busAccess': 'Yes',
        'duration': '3 hours',
        'facilities': ['Toilet', 'Shop'],
        'latitude': 27.7172,
        'longitude': 85.5240,
        'isApproved': true,
        'authorId': 'u-1',
        'authorName': 'Ranjay',
      });

      final t = Trail.fromDoc(doc);
      expect(t.id, 'trail-1');
      expect(t.name, 'Nagarkot');
      expect(t.difficulty, 'Easy');
      expect(t.imageUrls, ['a.jpg', 'b.jpg']);
      expect(t.userRating, 4);
      expect(t.ratingScore, 4.6);
      expect(t.facilities, ['Toilet', 'Shop']);
      expect(t.latitude, 27.7172);
      expect(t.longitude, 85.5240);
      expect(t.isApproved, true);
      expect(t.authorName, 'Ranjay');
    });

    test('empty document maps to default values, never throws', () {
      final t = Trail.fromDoc(_FakeDoc('empty', const {}));
      expect(t.id, 'empty');
      expect(t.name, '');
      expect(t.imageUrls, isEmpty);
      expect(t.facilities, isEmpty);
      expect(t.latitude, 0.0);
      expect(t.isApproved, false);
    });

    test('null document data is treated like an empty map', () {
      final t = Trail.fromDoc(_FakeDoc('null-data', null));
      expect(t.id, 'null-data');
      expect(t.name, '');
    });

    test('integer lat/lng/rating are coerced to the declared types', () {
      final t = Trail.fromDoc(_FakeDoc('coerce', {
        'latitude': 27,
        'longitude': 85,
        'userRating': 3,
        'ratingScore': 4,
      }));
      expect(t.latitude, 27.0);
      expect(t.longitude, 85.0);
      expect(t.userRating, 3);
      expect(t.ratingScore, 4.0);
    });
  });

  group('Trail.toMap', () {
    test('round-trips back through fromDoc with the same values', () {
      final original = Trail(
        id: 'rt-1',
        name: 'Phulchowki',
        difficulty: 'Hard',
        ratingScore: 4.9,
        latitude: 27.5,
        longitude: 85.4,
        isApproved: true,
        imageUrls: const ['x.jpg'],
        facilities: const ['Water'],
      );
      // toMap deliberately omits id (Firestore provides it via doc.id).
      final round = Trail.fromDoc(_FakeDoc('rt-1', original.toMap()));
      expect(round.id, original.id);
      expect(round.name, original.name);
      expect(round.difficulty, original.difficulty);
      expect(round.ratingScore, original.ratingScore);
      expect(round.latitude, original.latitude);
      expect(round.longitude, original.longitude);
      expect(round.isApproved, original.isApproved);
      expect(round.imageUrls, original.imageUrls);
      expect(round.facilities, original.facilities);
    });
  });

  group('Trail.copyWith', () {
    test('overrides only the fields passed and keeps the rest', () {
      final base = Trail(id: 'cw', name: 'Base', userRating: 1);
      final updated = base.copyWith(name: 'New', userRating: 5);
      expect(updated.id, 'cw');
      expect(updated.name, 'New');
      expect(updated.userRating, 5);
    });

    test('called with no args returns an equivalent (not identical) instance', () {
      final base = Trail(id: 'cw2', name: 'X');
      final cloned = base.copyWith();
      expect(cloned.id, base.id);
      expect(cloned.name, base.name);
      expect(identical(cloned, base), isFalse);
    });
  });
}

/// Minimal stand-in for `DocumentSnapshot<Map<String, dynamic>>` so the
/// model parser can be unit-tested without a Firestore instance.
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
