import 'package:cloud_firestore/cloud_firestore.dart';

class TrailReview {
  final String id;
  final String userId;
  final String userName;
  final String userPic;
  final double rating;
  final String comment;
  final int timestamp;
  final Map<String, double> categories;
  final bool isVerified;

  TrailReview({
    this.id = '',
    this.userId = '',
    this.userName = '',
    this.userPic = '',
    this.rating = 5.0,
    this.comment = '',
    this.timestamp = 0,
    this.categories = const {},
    this.isVerified = false,
  });

  factory TrailReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TrailReview(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      userName: (d['userName'] ?? '') as String,
      userPic: (d['userPic'] ?? '') as String,
      rating: ((d['rating'] ?? 5) as num).toDouble(),
      comment: (d['comment'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
      categories: (d['categories'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
      isVerified: (d['isVerified'] ?? false) as bool,
    );
  }
}
