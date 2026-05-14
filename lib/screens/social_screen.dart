import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/hike_event.dart';
import '../models/social_user.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class SocialScreen extends StatefulWidget {
  final String currentUserId;
  final List<String> receivedRequests;
  final List<String> friends;
  final List<String> unreadChatIds;
  final Future<void> Function(String senderId) onAccept;
  final Future<void> Function(String senderId) onReject;
  final void Function(String id, String name) onChatClick;
  final void Function(String id) onProfileClick;
  final void Function(String trailId) onFeedItemClick;

  const SocialScreen({
    super.key,
    required this.currentUserId,
    required this.receivedRequests,
    required this.friends,
    required this.unreadChatIds,
    required this.onAccept,
    required this.onReject,
    required this.onChatClick,
    required this.onProfileClick,
    required this.onFeedItemClick,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _db = FirebaseFirestore.instance;
  final _pageCtl = PageController();
  int _page = 0;

  List<SocialUser> _friendProfiles = [];
  List<SocialUser> _requestProfiles = [];
  List<HikeEvent> _communityEvents = [];
  bool _loading = true;
  StreamSubscription? _eventsSub;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _eventsSub = _db
        .collection('events')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() => _communityEvents = s.docs.map(HikeEvent.fromDoc).toList());
    });
  }

  @override
  void didUpdateWidget(covariant SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friends != widget.friends ||
        oldWidget.receivedRequests != widget.receivedRequests) {
      _loadProfiles();
    }
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    Future<List<SocialUser>> fetch(List<String> ids) async {
      final out = <SocialUser>[];
      for (final id in ids) {
        try {
          final doc = await _db.collection('users').doc(id).get();
          if (doc.exists) out.add(SocialUser.fromDoc(doc));
        } catch (_) {}
      }
      return out;
    }

    final f = await fetch(widget.friends);
    final r = await fetch(widget.receivedRequests);
    if (!mounted) return;
    setState(() {
      _friendProfiles = f;
      _requestProfiles = r;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _pageCtl.dispose();
    super.dispose();
  }

  void _goTo(int p) {
    AppFeedback.tap();
    _pageCtl.animateToPage(p,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.primary,
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('👥 Social',
                      style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  tabBarTheme: TabBarThemeData(
                    labelColor: colors.onPrimary,
                    unselectedLabelColor: colors.onPrimary.withOpacity(0.7),
                    indicatorColor: colors.onPrimary,
                  ),
                ),
                child: DefaultTabController(
                  length: 3,
                  initialIndex: _page,
                  child: TabBar(
                    onTap: _goTo,
                    tabs: [
                      _tab('🌍 Community', _communityEvents.length),
                      _tab('💬 Chats', widget.unreadChatIds.length),
                      _tab('🤝 Requests', _requestProfiles.length),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageCtl,
            onPageChanged: (p) {
              AppFeedback.light();
              setState(() => _page = p);
            },
            children: [
              _communityPage(),
              _chatsPage(),
              _requestsPage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tab(String text, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: AppColors.onTertiaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _communityPage() {
    if (_communityEvents.isEmpty) {
      return _empty('🗺️', 'No community hikes yet',
          'When someone hosts a hike, it will show up here.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _communityEvents.length,
      itemBuilder: (_, i) {
        final e = _communityEvents[i];
        final isHost = e.creatorId == widget.currentUserId;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('📅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.trailName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                            '🗓️ ${e.dateText} • 👤 ${e.creatorName}${isHost ? " (you)" : ""}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(label: Text('🏃 ${e.attendees.length}/${e.maxHikers}')),
                    FilledButton.tonal(
                      onPressed: () {
                        AppFeedback.tap();
                        widget.onFeedItemClick(e.trailId);
                      },
                      child: const Text('🥾 View Trail'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chatsPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_friendProfiles.isEmpty) {
      return _empty('👥', 'No friends yet', 'Explore trails and connect with hikers.');
    }
    return ListView.builder(
      itemCount: _friendProfiles.length,
      itemBuilder: (_, i) {
        final f = _friendProfiles[i];
        final chatId = widget.currentUserId.compareTo(f.id) < 0
            ? '${widget.currentUserId}_${f.id}'
            : '${f.id}_${widget.currentUserId}';
        final unread = widget.unreadChatIds.contains(chatId);
        return ListTile(
          onTap: () {
            AppFeedback.tap();
            widget.onChatClick(f.id, f.name);
          },
          leading: _avatar(f.profilePic, f.name),
          title: Text(f.name,
              style: TextStyle(
                  fontWeight: unread ? FontWeight.w900 : FontWeight.w600)),
          subtitle: Text(f.bio.isEmpty ? 'Available' : f.bio,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: unread
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.tertiary),
                )
              : null,
        );
      },
    );
  }

  Widget _requestsPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_requestProfiles.isEmpty) {
      return _empty('🤝', 'No pending requests', 'Friend requests will appear here.');
    }
    return ListView.builder(
      itemCount: _requestProfiles.length,
      itemBuilder: (_, i) {
        final r = _requestProfiles[i];
        return ListTile(
          onTap: () => widget.onProfileClick(r.id),
          leading: _avatar(r.profilePic, r.name),
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Wants to connect'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  AppFeedback.warning();
                  widget.onReject(r.id);
                },
                icon: const Icon(Icons.close),
              ),
              IconButton(
                onPressed: () {
                  AppFeedback.success();
                  widget.onAccept(r.id);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatar(String url, String name) {
    return CircleAvatar(
      backgroundColor: AppColors.surfaceVariant,
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty ? const Icon(Icons.person) : null,
    );
  }

  Widget _empty(String emoji, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(message,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
