import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/user_profile.dart';
import 'current_uid_provider.dart';
import 'repositories.dart';

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(userRepositoryProvider).watchProfile(uid);
});
