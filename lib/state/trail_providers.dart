import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/trail.dart';
import 'current_uid_provider.dart';
import 'repositories.dart';

final approvedTrailsProvider = StreamProvider<List<Trail>>(
  (ref) => ref.watch(trailRepositoryProvider).watchApprovedTrails(),
);

final mySubmissionsProvider = StreamProvider<List<Trail>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(trailRepositoryProvider).watchMySubmissions(uid);
});

final pendingTrailsProvider = StreamProvider<List<Trail>>(
  (ref) => ref.watch(trailRepositoryProvider).watchPendingTrails(),
);
