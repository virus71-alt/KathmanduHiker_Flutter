import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';

class UserProfileDto {
  final String uid;
  final String displayName;
  final String bio;
  final String location;
  final String profilePic;
  final String dob;
  final String phone;
  final String insta;
  final bool showPhone;
  final int totalXP;
  final String hikerLevel;
  final String role;
  final List<String> favoriteTrails;
  final List<String> friends;
  final List<String> sentRequests;
  final List<String> receivedRequests;
  final List<String> unreadChatIds;

  const UserProfileDto({
    required this.uid,
    this.displayName = 'Hiker',
    this.bio = '',
    this.location = '',
    this.profilePic = '',
    this.dob = '',
    this.phone = '',
    this.insta = '',
    this.showPhone = false,
    this.totalXP = 0,
    this.hikerLevel = 'Beginner',
    this.role = '',
    this.favoriteTrails = const [],
    this.friends = const [],
    this.sentRequests = const [],
    this.receivedRequests = const [],
    this.unreadChatIds = const [],
  });

  factory UserProfileDto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserProfileDto(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Hiker') as String,
      bio: (d['bio'] ?? '') as String,
      location: (d['location'] ?? '') as String,
      profilePic: (d['profilePic'] ?? '') as String,
      dob: (d['dob'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      insta: (d['insta'] ?? '') as String,
      showPhone: (d['showPhone'] ?? false) as bool,
      totalXP: ((d['totalXP'] ?? 0) as num).toInt(),
      hikerLevel: (d['hikerLevel'] ?? 'Beginner') as String,
      role: (d['role'] ?? '') as String,
      favoriteTrails:
          ((d['favoriteTrails'] as List?) ?? const []).cast<String>(),
      friends: ((d['friends'] as List?) ?? const []).cast<String>(),
      sentRequests:
          ((d['sentRequests'] as List?) ?? const []).cast<String>(),
      receivedRequests:
          ((d['receivedRequests'] as List?) ?? const []).cast<String>(),
      unreadChatIds:
          ((d['unreadChatIds'] as List?) ?? const []).cast<String>(),
    );
  }

  UserProfile toEntity() => UserProfile(
        uid: uid,
        displayName: displayName,
        bio: bio,
        location: location,
        profilePic: profilePic,
        dob: dob,
        phone: phone,
        insta: insta,
        showPhone: showPhone,
        totalXP: totalXP,
        hikerLevel: hikerLevel,
        isAdmin: role == 'admin',
        favoriteTrailIds: favoriteTrails.toSet(),
        friends: friends,
        sentRequests: sentRequests,
        receivedRequests: receivedRequests,
        unreadChatIds: unreadChatIds,
      );
}
