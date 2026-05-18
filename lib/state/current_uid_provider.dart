import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_state_provider.dart';

part 'current_uid_provider.g.dart';

/// Derives the current user's UID from [authStateProvider].
///
/// Intentionally throws when read while logged out or while auth is still
/// loading — screens that consume this are only mounted inside RootShell,
/// which AuthGate only renders once a User is confirmed. No null-guards
/// needed at call sites.
@Riverpod(keepAlive: true)
String currentUid(Ref ref) {
  final user = ref.watch(authStateProvider).requireValue;
  if (user == null) throw StateError('currentUid read while logged out');
  return user.uid;
}
