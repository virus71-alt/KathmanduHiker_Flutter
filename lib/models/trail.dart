import 'package:cloud_firestore/cloud_firestore.dart';

class Trail {
  final String id;
  final String name;
  final String difficulty;
  final String transportRoute;
  final String fare;
  final String food;
  final String description;
  final List<String> imageUrls;
  final int userRating;
  final double ratingScore;
  final String travelMode;
  final String busAccess;
  final String duration;
  final List<String> facilities;
  final double latitude;
  final double longitude;
  final bool isApproved;
  final String authorId;
  final String authorName;

  Trail({
    this.id = '',
    this.name = '',
    this.difficulty = '',
    this.transportRoute = '',
    this.fare = '',
    this.food = '',
    this.description = '',
    this.imageUrls = const [],
    this.userRating = 0,
    this.ratingScore = 0.0,
    this.travelMode = '',
    this.busAccess = '',
    this.duration = '',
    this.facilities = const [],
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.isApproved = false,
    this.authorId = '',
    this.authorName = '',
  });

  factory Trail.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Trail(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      difficulty: (d['difficulty'] ?? '') as String,
      transportRoute: (d['transportRoute'] ?? '') as String,
      fare: (d['fare'] ?? '') as String,
      food: (d['food'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      imageUrls: ((d['imageUrls'] as List?) ?? const []).cast<String>(),
      userRating: ((d['userRating'] ?? 0) as num).toInt(),
      ratingScore: ((d['ratingScore'] ?? 0) as num).toDouble(),
      travelMode: (d['travelMode'] ?? '') as String,
      busAccess: (d['busAccess'] ?? '') as String,
      duration: (d['duration'] ?? '') as String,
      facilities: ((d['facilities'] as List?) ?? const []).cast<String>(),
      latitude: ((d['latitude'] ?? 0) as num).toDouble(),
      longitude: ((d['longitude'] ?? 0) as num).toDouble(),
      isApproved: (d['isApproved'] ?? false) as bool,
      authorId: (d['authorId'] ?? '') as String,
      authorName: (d['authorName'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'difficulty': difficulty,
        'transportRoute': transportRoute,
        'fare': fare,
        'food': food,
        'description': description,
        'imageUrls': imageUrls,
        'userRating': userRating,
        'ratingScore': ratingScore,
        'travelMode': travelMode,
        'busAccess': busAccess,
        'duration': duration,
        'facilities': facilities,
        'latitude': latitude,
        'longitude': longitude,
        'isApproved': isApproved,
        'authorId': authorId,
        'authorName': authorName,
      };

  Trail copyWith({
    String? id,
    String? name,
    String? difficulty,
    String? transportRoute,
    String? fare,
    String? food,
    String? description,
    List<String>? imageUrls,
    int? userRating,
    double? ratingScore,
    String? travelMode,
    String? busAccess,
    String? duration,
    List<String>? facilities,
    double? latitude,
    double? longitude,
    bool? isApproved,
    String? authorId,
    String? authorName,
  }) =>
      Trail(
        id: id ?? this.id,
        name: name ?? this.name,
        difficulty: difficulty ?? this.difficulty,
        transportRoute: transportRoute ?? this.transportRoute,
        fare: fare ?? this.fare,
        food: food ?? this.food,
        description: description ?? this.description,
        imageUrls: imageUrls ?? this.imageUrls,
        userRating: userRating ?? this.userRating,
        ratingScore: ratingScore ?? this.ratingScore,
        travelMode: travelMode ?? this.travelMode,
        busAccess: busAccess ?? this.busAccess,
        duration: duration ?? this.duration,
        facilities: facilities ?? this.facilities,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        isApproved: isApproved ?? this.isApproved,
        authorId: authorId ?? this.authorId,
        authorName: authorName ?? this.authorName,
      );
}
