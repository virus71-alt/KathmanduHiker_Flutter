import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/hike_event.dart';

class HikeEventDto {
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

  const HikeEventDto({
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

  factory HikeEventDto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return HikeEventDto(
      id: doc.id,
      trailId: (d['trailId'] ?? '') as String,
      trailName: (d['trailName'] ?? '') as String,
      creatorId: (d['creatorId'] ?? '') as String,
      creatorName: (d['creatorName'] ?? '') as String,
      dateText: (d['dateText'] ?? '') as String,
      maxHikers: ((d['maxHikers'] ?? 0) as num).toInt(),
      attendees: ((d['attendees'] as List?) ?? const []).cast<String>(),
      attendeeDetails: ((d['attendeeDetails'] as List?) ?? const [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
    );
  }

  factory HikeEventDto.fromEntity(HikeEvent e) => HikeEventDto(
        id: e.id,
        trailId: e.trailId,
        trailName: e.trailName,
        creatorId: e.creatorId,
        creatorName: e.creatorName,
        dateText: e.dateText,
        maxHikers: e.maxHikers,
        attendees: e.attendees,
        attendeeDetails: e.attendeeDetails,
        timestamp: e.timestamp,
      );

  HikeEvent toEntity() => HikeEvent(
        id: id,
        trailId: trailId,
        trailName: trailName,
        creatorId: creatorId,
        creatorName: creatorName,
        dateText: dateText,
        maxHikers: maxHikers,
        attendees: attendees,
        attendeeDetails: attendeeDetails,
        timestamp: timestamp,
      );

  Map<String, dynamic> toMap() => {
        'trailId': trailId,
        'trailName': trailName,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'dateText': dateText,
        'maxHikers': maxHikers,
        'attendees': attendees,
        'attendeeDetails': attendeeDetails,
        'timestamp': timestamp,
      };
}
