import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class LeaderboardScreen extends StatelessWidget {
  final VoidCallback onBack;
  const LeaderboardScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('totalXP', descending: true)
            .limit(50)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.requireData.docs;
          if (docs.isEmpty) return const Center(child: Text('No hikers yet 🌲'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final name = (d['displayName'] ?? 'Hiker') as String;
              final pic = (d['profilePic'] ?? '') as String;
              final xp = ((d['totalXP'] ?? 0) as num).toInt();
              final label = RankingManager.getLevelLabel(xp);
              final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
              return ListTile(
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(medal, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                    child: pic.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                ]),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(label),
                trailing: Text('$xp XP',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }
}
