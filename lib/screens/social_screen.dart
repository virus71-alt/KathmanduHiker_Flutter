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
    return Column(
      children: [
        _header(),
        _tabBar(),
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

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chrome,
        border: Border(bottom: BorderSide(color: AppColors.chromeBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Community',
              style: AppText.headlineLg(AppColors.primary)
                  .copyWith(fontSize: 30, height: 1.1)),
          const SizedBox(height: 6),
          Text(
            'Connect with fellow trekkers and manage your hiking expeditions.',
            style: AppText.bodyMd(AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    final tabs = [
      ('Community', _communityEvents.length, Icons.public_rounded),
      ('Chats', widget.unreadChatIds.length, Icons.chat_bubble_outline_rounded),
      ('Requests', _requestProfiles.length, Icons.person_add_alt_1_rounded),
    ];
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 16, AppSpacing.marginMobile, 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            Expanded(child: _tabButton(tabs[i].$1, tabs[i].$2, tabs[i].$3, i)),
            if (i < tabs.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, int badge, IconData icon, int index) {
    final selected = _page == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _goTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.labelLg(
                    selected ? AppColors.onPrimary : AppColors.onSurfaceVariant),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.22)
                        : AppColors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Community page ─────────────────────────────────────────────────────
  Widget _communityPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      children: [
        _ctaRow(),
        const SizedBox(height: AppSpacing.stackMd),
        Row(
          children: [
            Expanded(
                child: Text('My Groups',
                    style: AppText.headlineMd(AppColors.onSurface))),
            if (_communityEvents.isNotEmpty)
              Text('View All',
                  style: AppText.labelLg(AppColors.primary)),
          ],
        ),
        const SizedBox(height: AppSpacing.stackSm),
        if (_communityEvents.isEmpty)
          _empty(Icons.terrain_rounded, 'No community hikes yet',
              'When someone hosts a hike, it will show up here.')
        else
          ..._communityEvents.map(_groupCard),
      ],
    );
  }

  Widget _ctaRow() {
    return Row(
      children: [
        Expanded(child: _cta(
          'Add Friend',
          Icons.person_add_alt_1_rounded,
          primary: true,
          onTap: () => _goTo(2),
        )),
        const SizedBox(width: 12),
        Expanded(child: _cta(
          'Create Group',
          Icons.groups_2_rounded,
          primary: false,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open a trail to host a group hike.')),
            );
          },
        )),
      ],
    );
  }

  Widget _cta(String label, IconData icon,
      {required bool primary, required VoidCallback onTap}) {
    return Material(
      color: primary ? AppColors.primary : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: primary ? Colors.transparent : AppColors.outlineVariant),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: primary ? AppColors.onPrimary : AppColors.primary,
                  size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppText.labelLg(
                    primary ? AppColors.onPrimary : AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupCard(HikeEvent e) {
    final isHost = e.creatorId == widget.currentUserId;
    final diff = difficultyColors('moderate'); // events default to moderate visual
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            widget.onFeedItemClick(e.trailId);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md)),
                      child: Container(
                        height: 120,
                        color: AppColors.primaryContainer,
                        child: const Center(
                          child: Icon(Icons.landscape_rounded,
                              size: 64, color: Color(0xFF9DD090)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 12,
                      right: 14,
                      child: Text(
                        e.trailName,
                        style: AppText.headlineMd(Colors.white)
                            .copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                        ),
                        child: Text(
                          '${e.attendees.length}/${e.maxHikers}',
                          style: AppText.labelSm(AppColors.primary)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: diff.bg,
                          borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                        ),
                        child: Text(
                          'Group Hike',
                          style: AppText.labelSm(diff.fg)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e.dateText,
                          style: AppText.labelSm(AppColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHost)
                        Text('You host',
                            style: AppText.labelSm(AppColors.primary)
                                .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Chats page ─────────────────────────────────────────────────────────
  Widget _chatsPage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_friendProfiles.isEmpty) {
      return _empty(Icons.chat_bubble_outline_rounded, 'No friends yet',
          'Explore trails and connect with hikers.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      itemCount: _friendProfiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final f = _friendProfiles[i];
        final chatId = widget.currentUserId.compareTo(f.id) < 0
            ? '${widget.currentUserId}_${f.id}'
            : '${f.id}_${widget.currentUserId}';
        final unread = widget.unreadChatIds.contains(chatId);
        return Material(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () {
              AppFeedback.tap();
              widget.onChatClick(f.id, f.name);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _avatar(f.profilePic, f.name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            style: AppText.labelLg(AppColors.onSurface)
                                .copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w600)),
                        Text(
                          f.bio.isEmpty ? 'Tap to message' : f.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: unread
                          ? AppColors.primary
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: unread ? Colors.white : AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Requests page ──────────────────────────────────────────────────────
  Widget _requestsPage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_requestProfiles.isEmpty) {
      return _empty(Icons.person_add_alt_1_rounded, 'No pending requests',
          'Friend requests will appear here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      itemCount: _requestProfiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = _requestProfiles[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InkWell(
                onTap: () => widget.onProfileClick(r.id),
                child: _avatar(r.profilePic, r.name, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: AppText.labelLg(AppColors.onSurface)),
                    Text('Wants to connect',
                        style: AppText.labelSm(AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  AppFeedback.warning();
                  widget.onReject(r.id);
                },
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  foregroundColor: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () {
                  AppFeedback.success();
                  widget.onAccept(r.id);
                },
                icon: const Icon(Icons.check_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatar(String url, String name, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryFixed,
        border: Border.all(color: AppColors.outlineVariant),
        image: url.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url.isEmpty
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppText.labelLg(AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  Widget _empty(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: AppText.headlineMd(AppColors.onSurface)
                    .copyWith(fontSize: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(message,
                style: AppText.bodyMd(AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
