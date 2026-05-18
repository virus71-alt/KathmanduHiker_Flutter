import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_notification.dart';
import 'current_uid_provider.dart';
import 'repositories.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(userRepositoryProvider).watchNotifications(uid);
});
