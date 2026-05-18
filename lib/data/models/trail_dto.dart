import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/journey.dart';
import '../../domain/entities/trail.dart';

class TrailDto {
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
  final List<JourneyLeg> journeyLegs;
  final String reachDifficulty;
  final String lastReturnVehicle;
  final String localGuidance;
  final int reviewCount;
  final String confidenceLabel;
  final Map<String, double> categoryAverages;

  const TrailDto({
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
    this.journeyLegs = const [],
    this.reachDifficulty = '',
    this.lastReturnVehicle = '',
    this.localGuidance = '',
    this.reviewCount = 0,
    this.confidenceLabel = 'Low Confidence',
    this.categoryAverages = const {},
  });

  factory TrailDto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TrailDto(
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
      journeyLegs: (d['journeyLegs'] as List<dynamic>?)
              ?.map((e) => JourneyLeg.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reachDifficulty: (d['reachDifficulty'] ?? '') as String,
      lastReturnVehicle: (d['lastReturnVehicle'] ?? '') as String,
      localGuidance: (d['localGuidance'] ?? '') as String,
      reviewCount: ((d['reviewCount'] ?? 0) as num).toInt(),
      confidenceLabel: (d['confidenceLabel'] ?? 'Low Confidence') as String,
      categoryAverages: (d['categoryAverages'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
    );
  }

  factory TrailDto.fromEntity(Trail t) => TrailDto(
        id: t.id,
        name: t.name,
        difficulty: t.difficulty,
        transportRoute: t.transportRoute,
        fare: t.fare,
        food: t.food,
        description: t.description,
        imageUrls: t.imageUrls,
        userRating: t.userRating,
        ratingScore: t.ratingScore,
        travelMode: t.travelMode,
        busAccess: t.busAccess,
        duration: t.duration,
        facilities: t.facilities,
        latitude: t.latitude,
        longitude: t.longitude,
        isApproved: t.isApproved,
        authorId: t.authorId,
        authorName: t.authorName,
        journeyLegs: t.journeyLegs,
        reachDifficulty: t.reachDifficulty,
        lastReturnVehicle: t.lastReturnVehicle,
        localGuidance: t.localGuidance,
        reviewCount: t.reviewCount,
        confidenceLabel: t.confidenceLabel,
        categoryAverages: t.categoryAverages,
      );

  Trail toEntity() => Trail(
        id: id,
        name: name,
        difficulty: difficulty,
        transportRoute: transportRoute,
        fare: fare,
        food: food,
        description: description,
        imageUrls: imageUrls,
        userRating: userRating,
        ratingScore: ratingScore,
        travelMode: travelMode,
        busAccess: busAccess,
        duration: duration,
        facilities: facilities,
        latitude: latitude,
        longitude: longitude,
        isApproved: isApproved,
        authorId: authorId,
        authorName: authorName,
        journeyLegs: journeyLegs,
        reachDifficulty: reachDifficulty,
        lastReturnVehicle: lastReturnVehicle,
        localGuidance: localGuidance,
        reviewCount: reviewCount,
        confidenceLabel: confidenceLabel,
        categoryAverages: categoryAverages,
      );

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
        'journeyLegs': journeyLegs.map((l) => l.toMap()).toList(),
        'reachDifficulty': reachDifficulty,
        'lastReturnVehicle': lastReturnVehicle,
        'localGuidance': localGuidance,
        'reviewCount': reviewCount,
        'confidenceLabel': confidenceLabel,
        'categoryAverages': categoryAverages,
      };
}
