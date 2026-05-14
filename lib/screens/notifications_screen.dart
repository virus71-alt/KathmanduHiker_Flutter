import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../utils/feedback.dart';

class NotificationsScreen extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onBack;
  final Future<void> Function(String id) onMarkAsRead;
  final Future<void> Function() onClearAll;

  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.onBack,
    required this.onMarkAsRead,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                onClearAll();
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
                    n.isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: n.isRead ? colors.onSurfaceVariant : colors.primary,
                  ),
                  title: Text(n.message,
                      style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(DateFormat('MMM d, HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(n.timestamp))),
                  onTap: () {
                    if (!n.isRead) {
                      AppFeedback.tap();
                      onMarkAsRead(n.id);
                    }
                  },
                );
              },
            ),
    );
  }
}
