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

  const HikeEvent({
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

  HikeEvent copyWith({
    String? id,
    String? trailId,
    String? trailName,
    String? creatorId,
    String? creatorName,
    String? dateText,
    int? maxHikers,
    List<String>? attendees,
    List<Map<String, String>>? attendeeDetails,
    int? timestamp,
  }) =>
      HikeEvent(
        id: id ?? this.id,
        trailId: trailId ?? this.trailId,
        trailName: trailName ?? this.trailName,
        creatorId: creatorId ?? this.creatorId,
        creatorName: creatorName ?? this.creatorName,
        dateText: dateText ?? this.dateText,
        maxHikers: maxHikers ?? this.maxHikers,
        attendees: attendees ?? this.attendees,
        attendeeDetails: attendeeDetails ?? this.attendeeDetails,
        timestamp: timestamp ?? this.timestamp,
      );
}
