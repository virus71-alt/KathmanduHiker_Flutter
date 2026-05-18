import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/user_profile.dart';
import 'repositories.dart';

final leaderboardProvider = StreamProvider<List<UserProfile>>(
    (ref) => ref.watch(userRepositoryProvider).watchLeaderboard());

/// Watches any user's full profile document — used by public profile view.
/// Reuses the same Firestore path as [watchProfile]; only public fields
/// are surfaced in [PublicProfileScreen].
final publicUserProfileProvider = StreamProvider.family<UserProfile, String>(
    (ref, uid) => ref.watch(userRepositoryProvider).watchProfile(uid));
