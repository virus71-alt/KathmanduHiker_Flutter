import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

class AppNotificationDto {
  final String id;
  final String message;
  final int timestamp;
  final bool isRead;
  final String type;
  final String trailId;
  final String eventId;

  const AppNotificationDto({
    this.id = '',
    this.message = '',
    this.timestamp = 0,
    this.isRead = false,
    this.type = '',
    this.trailId = '',
    this.eventId = '',
  });

  factory AppNotificationDto.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotificationDto(
      id: doc.id,
      message: (d['message'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
      isRead: (d['isRead'] ?? false) as bool,
      type: (d['type'] ?? '') as String,
      trailId: (d['trailId'] ?? '') as String,
      eventId: (d['eventId'] ?? '') as String,
    );
  }

  AppNotification toEntity() => AppNotification(
        id: id,
        message: message,
        timestamp: timestamp,
        isRead: isRead,
        type: type,
        trailId: trailId,
        eventId: eventId,
      );
}
