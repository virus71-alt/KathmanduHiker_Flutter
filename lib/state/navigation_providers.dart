import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/trail.dart';

/// Active bottom-nav / screen tab. Uses the same string keys as the old
/// _currentTab field so screen logic stays unchanged until PR 6 (go_router).
final selectedTabProvider = StateProvider<String>((ref) => 'Home');

/// Currently-open trail overlay. Null means no trail is being viewed.
/// Replaced by go_router in PR 6.
final currentTrailProvider = StateProvider<Trail?>((ref) => null);

/// Active chat target. Null means no chat is open.
/// Replaced by go_router in PR 6.
final currentChatProvider = StateProvider<({String id, String name})?>((ref) => null);

/// Profile overlay being viewed. Null means no profile is open.
/// Replaced by go_router in PR 6.
final viewingProfileProvider = StateProvider<String?>((ref) => null);
