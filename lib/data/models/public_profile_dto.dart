import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/public_profile.dart';

class PublicProfileDto {
  final String uid;
  final String displayName;
  final String bio;
  final String profilePic;

  const PublicProfileDto({
    required this.uid,
    this.displayName = 'Hiker',
    this.bio = '',
    this.profilePic = '',
  });

  factory PublicProfileDto.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PublicProfileDto(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Hiker') as String,
      bio: (d['bio'] ?? '') as String,
      profilePic: (d['profilePic'] ?? '') as String,
    );
  }

  PublicProfile toEntity() => PublicProfile(
        uid: uid,
        displayName: displayName,
        bio: bio,
        profilePic: profilePic,
      );
}
