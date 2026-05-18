class AppNotification {
  final String id;
  final String message;
  final int timestamp;
  final bool isRead;
  final String type;
  final String trailId;
  final String eventId;

  const AppNotification({
    this.id = '',
    this.message = '',
    this.timestamp = 0,
    this.isRead = false,
    this.type = '',
    this.trailId = '',
    this.eventId = '',
  });

  AppNotification copyWith({
    String? id,
    String? message,
    int? timestamp,
    bool? isRead,
    String? type,
    String? trailId,
    String? eventId,
  }) =>
      AppNotification(
        id: id ?? this.id,
        message: message ?? this.message,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        type: type ?? this.type,
        trailId: trailId ?? this.trailId,
        eventId: eventId ?? this.eventId,
      );
}
