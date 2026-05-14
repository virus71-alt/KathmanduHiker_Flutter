import 'package:cloud_firestore/cloud_firestore.dart';

class HikeEvent {
  final String id;
  final String trailId;
  final String trailName;
  final String creatorId;
  final String creatorName;
  final String dateText;
  final int maxHikers;
  final List<String> attendees;
  final List<Map<String, String>> attendeeDetails;
  final int timestamp;

  HikeEvent({
    this.id = '',
    this.trailId = '',
    this.trailName = '',
    this.creatorId = '',
    this.creatorName = '',
    this.dateText = '',
    this.maxHikers = 0,
    this.attendees = const [],
    this.attendeeDetails = const [],
    this.timestamp = 0,
  });

  factory HikeEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawDetails = (d['attendeeDetails'] as List?) ?? const [];
    return HikeEvent(
      id: doc.id,
      trailId: (d['trailId'] ?? '') as String,
      trailName: (d['trailName'] ?? '') as String,
      creatorId: (d['creatorId'] ?? '') as String,
      creatorName: (d['creatorName'] ?? '') as String,
      dateText: (d['dateText'] ?? '') as String,
      maxHikers: ((d['maxHikers'] ?? 0) as num).toInt(),
      attendees: ((d['attendees'] as List?) ?? const []).cast<String>(),
      attendeeDetails: rawDetails
          .map((e) => (e as Map).map(
                (k, v) => MapEntry(k.toString(), (v ?? '').toString()),
              ))
          .toList(),
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
    );
  }
}
