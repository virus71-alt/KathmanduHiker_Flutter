import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class PublicProfileScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!(snap.data?.exists ?? false)) {
            return const Center(child: Text('User not found.'));
          }
          final d = snap.data!.data() ?? {};
          final name = (d['displayName'] ?? 'Hiker') as String;
          final bio = (d['bio'] ?? '') as String;
          final location = (d['location'] ?? '') as String;
          final phone = (d['phone'] ?? '') as String;
          final showPhone = (d['showPhone'] ?? false) as bool;
          final insta = (d['insta'] ?? '') as String;
          final pic = (d['profilePic'] ?? '') as String;
          final xp = ((d['totalXP'] ?? 0) as num).toInt();
          final label = RankingManager.getLevelLabel(xp);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                      child: pic.isEmpty
                          ? Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 40, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('🏅 $label',
                          style: TextStyle(color: colors.onPrimary, fontSize: 12)),
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
                      if (location.isNotEmpty) _row('📍', location),
                      if (showPhone && phone.isNotEmpty)
                        InkWell(
                          onTap: () => launchUrl(Uri.parse('tel:$phone')),
                          child: _row('📞', phone),
                        ),
                      if (insta.isNotEmpty) _row('📷', '@$insta'),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(bio),
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
                label: Text('Remove Friend', style: TextStyle(color: colors.error)),
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
        child: Row(children: [Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10), Text(text)]),
      );
}
