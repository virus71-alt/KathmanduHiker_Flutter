import 'package:cloud_firestore/cloud_firestore.dart';

class SocialUser {
  final String id;
  final String name;
  final String bio;
  final String profilePic;

  SocialUser({
    this.id = '',
    this.name = '',
    this.bio = '',
    this.profilePic = '',
  });

  factory SocialUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SocialUser(
      id: doc.id,
      name: (d['displayName'] ?? 'Hiker') as String,
      bio: (d['bio'] ?? '') as String,
      profilePic: (d['profilePic'] ?? '') as String,
    );
  }
}
