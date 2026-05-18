import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/leaderboard_provider.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class LeaderboardScreen extends ConsumerWidget {
  final VoidCallback onBack;
  const LeaderboardScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            onBack();
          },
        ),
      ),
      body: leaderboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load leaderboard.')),
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No hikers yet 🌲'));
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = users[i];
              final label = RankingManager.getLevelLabel(u.totalXP);
              final medal = i == 0
                  ? '🥇'
                  : i == 1
                      ? '🥈'
                      : i == 2
                          ? '🥉'
                          : '${i + 1}';
              return ListTile(
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(medal, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: u.profilePic.isNotEmpty
                        ? CachedNetworkImageProvider(u.profilePic)
                        : null,
                    child: u.profilePic.isEmpty
                        ? Text(u.displayName.isNotEmpty
                            ? u.displayName[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                ]),
                title: Text(u.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(label),
                trailing: Text('${u.totalXP} XP',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }
}
