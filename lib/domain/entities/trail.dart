import 'journey.dart';

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
  final List<JourneyLeg> journeyLegs;
  final String reachDifficulty;
  final String lastReturnVehicle;
  final String localGuidance;
  final int reviewCount;
  final String confidenceLabel;
  final Map<String, double> categoryAverages;

  const Trail({
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
    List<JourneyLeg>? journeyLegs,
    String? reachDifficulty,
    String? lastReturnVehicle,
    String? localGuidance,
    int? reviewCount,
    String? confidenceLabel,
    Map<String, double>? categoryAverages,
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
        journeyLegs: journeyLegs ?? this.journeyLegs,
        reachDifficulty: reachDifficulty ?? this.reachDifficulty,
        lastReturnVehicle: lastReturnVehicle ?? this.lastReturnVehicle,
        localGuidance: localGuidance ?? this.localGuidance,
        reviewCount: reviewCount ?? this.reviewCount,
        confidenceLabel: confidenceLabel ?? this.confidenceLabel,
        categoryAverages: categoryAverages ?? this.categoryAverages,
      );
}
