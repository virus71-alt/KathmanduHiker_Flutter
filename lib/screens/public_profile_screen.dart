import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/leaderboard_provider.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.onBack,
    required this.onRemoveFriend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(publicUserProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('👤 Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            onBack();
          },
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('User not found.')),
        data: (profile) {
          final label = RankingManager.getLevelLabel(profile.totalXP);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: profile.profilePic.isNotEmpty
                          ? CachedNetworkImageProvider(profile.profilePic)
                          : null,
                      child: profile.profilePic.isEmpty
                          ? Text(profile.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 40, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(profile.displayName,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('🏅 $label',
                          style:
                              TextStyle(color: colors.onPrimary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.location.isNotEmpty)
                        _row('📍', profile.location),
                      if (profile.showPhone && profile.phone.isNotEmpty)
                        InkWell(
                          onTap: () =>
                              launchUrl(Uri.parse('tel:${profile.phone}')),
                          child: _row('📞', profile.phone),
                        ),
                      if (profile.insta.isNotEmpty)
                        _row('📷', '@${profile.insta}'),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(profile.bio),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  AppFeedback.warning();
                  onRemoveFriend();
                },
                icon: Icon(Icons.person_remove, color: colors.error),
                label: Text('Remove Friend',
                    style: TextStyle(color: colors.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String emoji, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(text)
        ]),
      );
}
