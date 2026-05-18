import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/current_uid_provider.dart';
import '../state/notifications_provider.dart';
import '../state/repositories.dart';
import '../utils/feedback.dart';

class NotificationsScreen extends ConsumerWidget {
  final VoidCallback onBack;
  const NotificationsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final uid = ref.watch(currentUidProvider);
    final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            onBack();
          },
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                AppFeedback.warning();
                ref.read(userRepositoryProvider).clearAllNotifications(uid);
              },
              child: Text('Clear all',
                  style: TextStyle(color: colors.onPrimary)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔕', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('No notifications yet',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return ListTile(
                  tileColor: n.isRead
                      ? null
                      : colors.primaryContainer.withOpacity(0.3),
                  leading: Icon(
                    n.isRead
                        ? Icons.mark_email_read
                        : Icons.mark_email_unread,
                    color: n.isRead
                        ? colors.onSurfaceVariant
                        : colors.primary,
                  ),
                  title: Text(n.message,
                      style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.normal
                              : FontWeight.bold)),
                  subtitle: Text(DateFormat('MMM d, HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(n.timestamp))),
                  onTap: () {
                    if (!n.isRead) {
                      AppFeedback.tap();
                      ref.read(userRepositoryProvider).markNotificationRead(
                            uid: uid,
                            notificationId: n.id,
                          );
                    }
                  },
                );
              },
            ),
    );
  }
}
