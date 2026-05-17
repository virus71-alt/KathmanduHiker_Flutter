import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kathmanduhiker/models/app_notification.dart';

void main() {
  group('AppNotification.fromDoc', () {
    test('parses a complete notification document', () {
      final n = AppNotification.fromDoc(_FakeDoc('notif-1', {
        'message': 'Trail approved!',
        'timestamp': 1700000000000,
        'isRead': false,
        'type': 'trail_approved',
        'trailId': 't-1',
        'eventId': 'e-1',
      }));
      expect(n.id, 'notif-1');
      expect(n.message, 'Trail approved!');
      expect(n.timestamp, 1700000000000);
      expect(n.isRead, false);
      expect(n.type, 'trail_approved');
      expect(n.trailId, 't-1');
      expect(n.eventId, 'e-1');
    });

    test('empty document returns sensible defaults, no crash', () {
      final n = AppNotification.fromDoc(_FakeDoc('empty', const {}));
      expect(n.id, 'empty');
      expect(n.message, '');
      expect(n.timestamp, 0);
      expect(n.isRead, false);
    });

    test('integer timestamp from a Firestore int field is preserved', () {
      final n = AppNotification.fromDoc(_FakeDoc('ts', {
        'timestamp': 1234567890,
      }));
      expect(n.timestamp, 1234567890);
    });

    test('null document data does not throw', () {
      expect(
        () => AppNotification.fromDoc(_FakeDoc('null', null)),
        returnsNormally,
      );
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
