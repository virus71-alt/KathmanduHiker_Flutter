import 'package:cloud_firestore/cloud_firestore.dart';

class TrailPhoto {
  final String id;
  final String userId;
  final String userName;
  final String url;
  final int timestamp;

  TrailPhoto({
    this.id = '',
    this.userId = '',
    this.userName = '',
    this.url = '',
    this.timestamp = 0,
  });

  factory TrailPhoto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TrailPhoto(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      userName: (d['userName'] ?? '') as String,
      url: (d['url'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
    );
  }
}
