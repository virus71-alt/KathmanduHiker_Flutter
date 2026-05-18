import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/trail_providers.dart';
import '../state/user_profile_provider.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class _Milestone {
  final int level;
  final String title;
  final String emoji;
  final int xpRequired;
  final String reward;
  const _Milestone(this.level, this.title, this.emoji, this.xpRequired, this.reward);
}

class AchievementsScreen extends ConsumerWidget {
  final VoidCallback onBack;
  const AchievementsScreen({super.key, required this.onBack});

  static const _milestones = <_Milestone>[
    _Milestone(1, 'New Hiker', '🌱', 0, 'Welcome badge'),
    _Milestone(2, 'Beginner', '🥾', 100, 'Beginner badge'),
    _Milestone(5, 'Trail Spotter', '🔍', 400, 'Profile frame: Sprout'),
    _Milestone(10, 'Trail Walker', '🚶', 900, 'Custom map marker'),
    _Milestone(15, 'Photo Hunter', '📸', 1400, 'Photo gallery boost'),
    _Milestone(20, 'Route Reader', '🗺️', 1900, 'Highlighted reviews'),
    _Milestone(25, 'Pathfinder', '🧭', 2400, 'Pathfinder badge'),
    _Milestone(35, 'Bridge Builder', '🌉', 3400, 'Featured profile spot'),
    _Milestone(50, 'Explorer', '🎒', 4900, 'Explorer aura'),
    _Milestone(65, 'Summit Seeker', '⛰️', 6400, 'Verified trail badge'),
    _Milestone(75, 'Mountain Guide', '🏔️', 7400, 'Mentor badge'),
    _Milestone(85, 'Wayfarer', '🧭', 8400, 'Wayfarer crest'),
    _Milestone(100, 'Trail Master', '🏆', 9900, 'Trail Master crown'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final mySubmissions = ref.watch(mySubmissionsProvider).valueOrNull ?? [];

    final userXP = profile?.totalXP ?? 0;
    final approvedSubmissions =
        mySubmissions.where((t) => t.isApproved).length;

    final levelNum = RankingManager.getLevelNumber(userXP);
    final levelTitle = RankingManager.getLevelTitle(userXP);
    final next = RankingManager.getNextLevelXp(userXP);
    final progress = RankingManager.getLevelProgress(userXP);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Achievements'),
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
          // Hero card
          Container(
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colors.onPrimary.withOpacity(0.15),
                  child: Icon(Icons.emoji_events,
                      color: colors.onPrimary, size: 44),
                ),
                const SizedBox(height: 10),
                Text('Level $levelNum',
                    style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                Text(levelTitle, style: TextStyle(color: colors.onPrimary)),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  color: colors.onPrimary,
                  backgroundColor: colors.onPrimary.withOpacity(0.25),
                ),
                const SizedBox(height: 6),
                Text(
                  levelNum >= 100 ? 'MAX LEVEL — 🏆' : '$userXP / $next XP',
                  style: TextStyle(color: colors.onPrimary, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Quick Stats',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('Total XP', userXP.toString(), '✨'),
                      _stat('Trails Approved', approvedSubmissions.toString(),
                          '✅'),
                      _stat('Level', levelNum.toString(), '🎯'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 How XP works',
                      style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _xpRow('🥾 Suggest a trail',
                      '+${RankingManager.xpTrailSubmitted} XP'),
                  _xpRow('✅ Trail approved',
                      '+${RankingManager.xpTrailApproved} XP'),
                  _xpRow('📝 Post a review', '+${RankingManager.xpReview} XP'),
                  _xpRow('📸 Share a photo',
                      '+${RankingManager.xpCommunityPhoto} XP'),
                  _xpRow('📅 Host a hike', '+${RankingManager.xpHostHike} XP'),
                  _xpRow('🥾 Complete easy hike',
                      '+${RankingManager.xpEasyHike} XP'),
                  _xpRow('🔥 Complete standard hike',
                      '+${RankingManager.xpStandardHike} XP'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('🗺️ Level Roadmap',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final m in _milestones)
            _milestoneRow(context, m, userXP >= m.xpRequired,
                levelNum == m.level),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _xpRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _milestoneRow(
      BuildContext context, _Milestone m, bool unlocked, bool isCurrent) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isCurrent
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      color: isCurrent
          ? colors.primaryContainer
          : unlocked
              ? colors.surface
              : colors.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: unlocked ? colors.primary : colors.outline,
              child: unlocked
                  ? Text(m.emoji, style: const TextStyle(fontSize: 24))
                  : Icon(Icons.lock, color: colors.surface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Level ${m.level}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('• ${m.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  Text('🎯 Reward: ${m.reward}',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12)),
                  Text(
                    unlocked
                        ? '✨ Unlocked at ${m.xpRequired} XP'
                        : '🔒 Unlocks at ${m.xpRequired} XP',
                    style: TextStyle(
                      color: unlocked ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (unlocked) Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
