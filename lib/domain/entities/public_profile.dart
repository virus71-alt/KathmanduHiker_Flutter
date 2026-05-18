class PublicProfile {
  final String uid;
  final String displayName;
  final String bio;
  final String profilePic;

  const PublicProfile({
    required this.uid,
    this.displayName = 'Hiker',
    this.bio = '',
    this.profilePic = '',
  });
}
