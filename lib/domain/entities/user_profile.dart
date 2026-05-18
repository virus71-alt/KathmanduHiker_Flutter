class UserProfile {
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
  final bool isAdmin;
  final Set<String> favoriteTrailIds;
  final List<String> friends;
  final List<String> sentRequests;
  final List<String> receivedRequests;
  final List<String> unreadChatIds;

  const UserProfile({
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
    this.isAdmin = false,
    this.favoriteTrailIds = const {},
    this.friends = const [],
    this.sentRequests = const [],
    this.receivedRequests = const [],
    this.unreadChatIds = const [],
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? bio,
    String? location,
    String? profilePic,
    String? dob,
    String? phone,
    String? insta,
    bool? showPhone,
    int? totalXP,
    String? hikerLevel,
    bool? isAdmin,
    Set<String>? favoriteTrailIds,
    List<String>? friends,
    List<String>? sentRequests,
    List<String>? receivedRequests,
    List<String>? unreadChatIds,
  }) =>
      UserProfile(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        location: location ?? this.location,
        profilePic: profilePic ?? this.profilePic,
        dob: dob ?? this.dob,
        phone: phone ?? this.phone,
        insta: insta ?? this.insta,
        showPhone: showPhone ?? this.showPhone,
        totalXP: totalXP ?? this.totalXP,
        hikerLevel: hikerLevel ?? this.hikerLevel,
        isAdmin: isAdmin ?? this.isAdmin,
        favoriteTrailIds: favoriteTrailIds ?? this.favoriteTrailIds,
        friends: friends ?? this.friends,
        sentRequests: sentRequests ?? this.sentRequests,
        receivedRequests: receivedRequests ?? this.receivedRequests,
        unreadChatIds: unreadChatIds ?? this.unreadChatIds,
      );
}
