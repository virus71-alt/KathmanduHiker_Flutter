import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/trail.dart';
import '../utils/feedback.dart';

class AdminScreen extends StatelessWidget {
  final List<Trail> pendingHikes;
  final Future<void> Function(String trailId) onApprove;
  final Future<void> Function(String trailId) onDelete;
  final Future<void> Function(Trail trail) onUpdate;
  final VoidCallback onBack;

  const AdminScreen({
    super.key,
    required this.pendingHikes,
    required this.onApprove,
    required this.onDelete,
    required this.onUpdate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingHikes.where((t) => !t.isApproved).toList();
    final approved = pendingHikes.where((t) => t.isApproved).toList();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            onBack();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('⏳ Pending review (${pending.length})',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.primary)),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('All caught up! 🎉',
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ),
            )
          else
            ...pending.map((t) => _adminCard(context, t, pending: true)),
          const SizedBox(height: 16),
          Text('✅ Approved (${approved.length})',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: colors.secondary)),
          const SizedBox(height: 8),
          ...approved.map((t) => _adminCard(context, t, pending: false)),
        ],
      ),
    );
  }

  Widget _adminCard(BuildContext context, Trail t, {required bool pending}) {
    final colors = Theme.of(context).colorScheme;
    final image = t.imageUrls.isNotEmpty
        ? t.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: image,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📍 ${t.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('🥾 ${t.difficulty} • 💰 ${t.fare}',
                    style: TextStyle(color: colors.onSurfaceVariant)),
                Text('🧭 by ${t.authorName}',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                if (t.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(t.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        AppFeedback.warning();
                        onDelete(t.id);
                      },
                      icon: Icon(Icons.delete, color: colors.error),
                      label: Text('Delete', style: TextStyle(color: colors.error)),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          AppFeedback.success();
                          onApprove(t.id);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
