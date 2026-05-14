import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPic;
  final String text;
  final int timestamp;

  Comment({
    this.id = '',
    this.authorId = '',
    this.authorName = '',
    this.authorPic = '',
    this.text = '',
    this.timestamp = 0,
  });

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Comment(
      id: doc.id,
      authorId: (d['authorId'] ?? '') as String,
      authorName: (d['authorName'] ?? '') as String,
      authorPic: (d['authorPic'] ?? '') as String,
      text: (d['text'] ?? '') as String,
      timestamp: ((d['timestamp'] ?? 0) as num).toInt(),
    );
  }
}
