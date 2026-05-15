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
  final String currentUserName;
  final String currentUserPic;
  final List<String> receivedRequests;
  final List<String> friends;
  final List<String> unreadChatIds;
  // Trail IDs that currently exist as approved trails. Used to filter out
  // stale events whose underlying trail has been deleted.
  final Set<String> validTrailIds;
  final Future<void> Function(String senderId) onAccept;
  final Future<void> Function(String senderId) onReject;
  final void Function(String id, String name) onChatClick;
  final void Function(String id) onProfileClick;
  final void Function(String trailId) onFeedItemClick;
  final void Function(String groupId) onOpenGroup;

  const SocialScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPic,
    required this.receivedRequests,
    required this.friends,
    required this.unreadChatIds,
    required this.onAccept,
    required this.onReject,
    required this.onChatClick,
    required this.onProfileClick,
    required this.onFeedItemClick,
    required this.onOpenGroup,
    this.validTrailIds = const {},
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _db = FirebaseFirestore.instance;
  final _pageCtl = PageController();
  int _page = 0;

  // Tab order: Community / Chats / Groups / Requests
  static const _tabs = ['Community', 'Chats', 'Groups', 'Requests'];

  List<SocialUser> _friendProfiles = [];
  List<SocialUser> _requestProfiles = [];
  List<HikeEvent> _communityEvents = [];
  List<_GroupRow> _myGroups = [];
  List<_GroupRow> _discoverGroups = [];
  List<_ActivityRow> _activities = [];
  bool _loading = true;
  StreamSubscription? _eventsSub;
  StreamSubscription? _groupsSub;
  StreamSubscription? _discoverSub;
  StreamSubscription? _activitySub;

  // Search state for the Requests tab.
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<SocialUser> _searchResults = [];
  bool _searching = false;

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
      // Drop events whose trail has been deleted — keeps the Upcoming Hikes
      // section clean when the app has no approved trails yet (stale events
      // from earlier testing get hidden automatically). If validTrailIds
      // hasn't been wired in by the caller, fall back to permissive mode.
      setState(() => _communityEvents = s.docs
          .map(HikeEvent.fromDoc)
          .where((e) => widget.validTrailIds.contains(e.trailId))
          .toList());
    });
    _groupsSub = _db
        .collection('groups')
        .where('members', arrayContains: widget.currentUserId)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      final list = s.docs.map(_groupRowFromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _myGroups = list);
    }, onError: (_) {
      // Groups can fail to load if rules block reads — fail quietly.
    });
    // Discover Groups — every public group, then we filter out the ones the
    // user is already a member of client-side. Limited so the listener stays
    // cheap; "See All" would page through more.
    _discoverSub = _db
        .collection('groups')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      final list = s.docs
          .map(_groupRowFromDoc)
          .where((g) => !g.isMember)
          .toList();
      setState(() => _discoverGroups = list);
    }, onError: (_) {});
    // Community feed: pulls the global `activities` stream that records when
    // admin approves trails. Each item links back to the trail.
    _activitySub = _db
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(40)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() => _activities = s.docs.map((d) {
            final m = d.data();
            return _ActivityRow(
              id: d.id,
              userId: (m['userId'] ?? '') as String,
              userName: (m['userName'] ?? 'A hiker') as String,
              userPic: (m['userPic'] ?? '') as String,
              actionType:
                  (m['actionType'] ?? 'shared something') as String,
              targetName: (m['targetName'] ?? '') as String,
              targetId: (m['targetId'] ?? '') as String,
              timestamp: ((m['timestamp'] ?? 0) as num).toInt(),
            );
          }).toList());
    }, onError: (_) {});
  }

  _GroupRow _groupRowFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final members = ((data['members'] as List?) ?? const []).cast<String>();
    return _GroupRow(
      id: d.id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      memberCount: members.length,
      createdAt: ((data['createdAt'] ?? 0) as num).toInt(),
      isHost: (data['creatorId'] ?? '') == widget.currentUserId,
      isMember: members.contains(widget.currentUserId),
    );
  }

  @override
  void didUpdateWidget(covariant SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friends != widget.friends ||
        oldWidget.receivedRequests != widget.receivedRequests) {
      _loadProfiles();
    }
    if (oldWidget.validTrailIds != widget.validTrailIds) {
      // Re-apply the trail-validity filter so stale events disappear the
      // moment the underlying trail list changes.
      setState(() => _communityEvents = _communityEvents
          .where((e) => widget.validTrailIds.contains(e.trailId))
          .toList());
    }
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    Future<List<SocialUser>> fetch(List<String> ids) async {
      if (ids.isEmpty) return const [];
      final futures = ids.map((id) async {
        try {
          final doc = await _db.collection('users').doc(id).get();
          return doc.exists ? SocialUser.fromDoc(doc) : null;
        } catch (_) {
          return null;
        }
      }).toList();
      final results = await Future.wait(futures);
      return results.whereType<SocialUser>().toList();
    }

    final pair = await Future.wait([
      fetch(widget.friends),
      fetch(widget.receivedRequests),
    ]);
    if (!mounted) return;
    setState(() {
      _friendProfiles = pair[0];
      _requestProfiles = pair[1];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _groupsSub?.cancel();
    _discoverSub?.cancel();
    _activitySub?.cancel();
    _pageCtl.dispose();
    _searchCtl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _goTo(int p) {
    AppFeedback.tap();
    _pageCtl.animateToPage(p,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchQuery = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchQuery = q;
    });
    try {
      final lower = q.toLowerCase();
      final snap = await _db
          .collection('users')
          .orderBy('displayName')
          .limit(50)
          .get();
      final results = snap.docs
          .map(SocialUser.fromDoc)
          .where((u) =>
              u.id != widget.currentUserId &&
              u.name.toLowerCase().contains(lower))
          .toList();
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendFriendRequest(SocialUser u) async {
    AppFeedback.success();
    try {
      await _db.collection('users').doc(u.id).update({
        'receivedRequests': FieldValue.arrayUnion([widget.currentUserId])
      });
      await _db.collection('users').doc(widget.currentUserId).update({
        'sentRequests': FieldValue.arrayUnion([u.id])
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${u.name}')),
        );
      }
    } catch (_) {}
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
              _groupsPage(),
              _requestsPage(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────
  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 16, AppSpacing.marginMobile, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _tabs[_page],
                  style: AppText.headlineLg(scheme.primary)
                      .copyWith(fontSize: 26, height: 1.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _subtitleForTab(_page),
            style: AppText.bodyMd(scheme.onSurfaceVariant)
                .copyWith(fontSize: 13, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _subtitleForTab(int p) {
    switch (p) {
      case 0:
        return 'See what your trail community is up to.';
      case 1:
        return 'Direct messages with your hiking friends.';
      case 2:
        return 'Trekking groups and upcoming hikes.';
      case 3:
        return 'Friend requests and new connections.';
      default:
        return '';
    }
  }

  // ─── Segmented pill tab bar ─────────────────────────────────────────────
  Widget _tabBar() {
    final scheme = Theme.of(context).colorScheme;
    final counts = <int>[
      _activities.length,
      widget.unreadChatIds.length,
      _myGroups.length,
      _requestProfiles.length,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _tabButton(
                  _tabs[i],
                  // Show badge only on tabs where a count is meaningful and
                  // non-trivial (we don't want the Groups tab badge to be
                  // distracting when the user is in a few groups).
                  i == 1 || i == 3 ? counts[i] : 0,
                  i,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int badge, int index) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _page == index;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => _goTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.onPrimary.withValues(alpha: 0.22)
                        : scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onTertiaryContainer,
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

  // ─── Community page (activity feed) ─────────────────────────────────────
  Widget _communityPage() {
    final scheme = Theme.of(context).colorScheme;
    if (_loading && _activities.isEmpty) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      children: [
        if (_communityEvents.isNotEmpty) ...[
          _sectionRow('Upcoming Hikes',
              '${_communityEvents.length} event${_communityEvents.length == 1 ? '' : 's'}'),
          const SizedBox(height: AppSpacing.stackSm),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _communityEvents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _featuredEventCard(_communityEvents[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
        ],
        _activitySectionHeader(),
        const SizedBox(height: AppSpacing.stackSm),
        if (_activities.isEmpty)
          _smallEmpty(Icons.dynamic_feed_rounded, 'No activity yet',
              'When friends discover trails, they will appear here.')
        else
          ..._activities.map(_activityCard),
      ],
    );
  }

  // Header for the Recent Activity section — includes a Clear text button on
  // the right when there are any activities to wipe.
  Widget _activitySectionHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text('Recent Activity',
              style: AppText.headlineMd(scheme.onSurface)
                  .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        if (_activities.isNotEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: _confirmClearActivities,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 14, color: scheme.error),
                    const SizedBox(width: 4),
                    Text('Clear',
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmClearActivities() async {
    AppFeedback.warning();
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear activity history?'),
        content: const Text(
            'This permanently removes every entry in the Recent Activity feed for everyone. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final snap = await _db.collection('activities').get();
      // Batched delete — Firestore caps at 500 ops per batch so we chunk.
      const chunkSize = 400;
      for (var i = 0; i < snap.docs.length; i += chunkSize) {
        final batch = _db.batch();
        for (final d in snap.docs.skip(i).take(chunkSize)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity history cleared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear activities: $e')),
        );
      }
    }
  }

  Widget _sectionRow(String title, String? trailing) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(title,
              style: AppText.headlineMd(scheme.onSurface)
                  .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        if (trailing != null)
          Text(trailing,
              style: AppText.labelSm(scheme.onSurfaceVariant)
                  .copyWith(letterSpacing: 0.5)),
      ],
    );
  }

  // Premium horizontal card for an upcoming community hike (used as a
  // "Featured" row at the top of the Community feed).
  Widget _featuredEventCard(HikeEvent e) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () {
        AppFeedback.tap();
        widget.onFeedItemClick(e.trailId);
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
                    height: 100,
                    color: scheme.primaryContainer,
                    child: Center(
                      child: Icon(Icons.landscape_rounded,
                          size: 48, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  right: 10,
                  child: Text(
                    e.trailName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineMd(Colors.white)
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${e.attendees.length}/${e.maxHikers}',
                      style: AppText.labelSm(scheme.primary)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hosted by ${e.creatorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm(scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard(_ActivityRow a) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            if (a.targetId.isNotEmpty) widget.onFeedItemClick(a.targetId);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: a.userId.isEmpty
                      ? null
                      : () => widget.onProfileClick(a.userId),
                  child: _avatar(a.userPic, a.userName, size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppText.bodyMd(scheme.onSurface)
                              .copyWith(fontSize: 14, height: 1.35),
                          children: [
                            TextSpan(
                              text: a.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: ' ${a.actionType} '),
                            TextSpan(
                              text: a.targetName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_relativeTime(a.timestamp),
                          style: AppText.labelSm(scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Chats page ─────────────────────────────────────────────────────────
  Widget _chatsPage() {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (_friendProfiles.isEmpty) {
      return _empty(Icons.chat_bubble_outline_rounded, 'No friends yet',
          'Explore trails and connect with hikers.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      itemCount: _friendProfiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = _friendProfiles[i];
        final chatId = widget.currentUserId.compareTo(f.id) < 0
            ? '${widget.currentUserId}_${f.id}'
            : '${f.id}_${widget.currentUserId}';
        final unread = widget.unreadChatIds.contains(chatId);
        return Material(
          color: scheme.surfaceContainerLowest,
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
                border: Border.all(
                  color: unread ? scheme.primary : scheme.outlineVariant,
                  width: unread ? 1.4 : 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar with green online dot — a stand-in for an actual
                  // presence indicator, kept always-on for now so the chat
                  // list still reads as "alive".
                  Stack(
                    children: [
                      _avatar(f.profilePic, f.name, size: 52),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.tertiary,
                            border: Border.all(
                              color: scheme.surfaceContainerLowest,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.labelLg(scheme.onSurface)
                                    .copyWith(
                                  fontSize: 15,
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f.bio.isEmpty ? 'Tap to send a message' : f.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(
                            unread
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ).copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Groups page ────────────────────────────────────────────────────────
  Widget _groupsPage() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      children: [
        // Create new group CTA — primary-tinted card with leading icon disc.
        Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _openCreateGroup,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded,
                        color: scheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create New Group',
                            style: AppText.labelLg(scheme.onSurface).copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'Start a community for your next trek',
                          style:
                              AppText.labelSm(scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.stackMd),
        _sectionRow('Your Groups',
            _myGroups.isEmpty ? null : '${_myGroups.length}'),
        const SizedBox(height: AppSpacing.stackSm),
        if (_myGroups.isEmpty)
          _smallEmpty(Icons.groups_2_rounded, 'No groups yet',
              'Tap Create New Group above to start one.')
        else
          ..._myGroups.map(_myGroupCard),

        const SizedBox(height: AppSpacing.stackMd),
        _sectionRow('Discover Groups',
            _discoverGroups.isEmpty ? null : '${_discoverGroups.length}'),
        const SizedBox(height: AppSpacing.stackSm),
        if (_discoverGroups.isEmpty)
          _smallEmpty(Icons.travel_explore_rounded, 'Nothing to discover yet',
              'Newly-created public groups will appear here for you to join.')
        else
          ..._discoverGroups.map(_discoverGroupCard),

        const SizedBox(height: AppSpacing.stackMd),
        _sectionRow('Upcoming Hikes',
            _communityEvents.isEmpty ? null : '${_communityEvents.length}'),
        const SizedBox(height: AppSpacing.stackSm),
        if (_communityEvents.isEmpty)
          _smallEmpty(Icons.terrain_rounded, 'No community hikes yet',
              'When someone hosts a hike, it will show up here.')
        else
          ..._communityEvents.map(_groupHikeCard),
      ],
    );
  }

  // Premium discover-group row: avatar disc, name, description preview,
  // member count + Join button. Tapping anywhere else opens the detail screen
  // (read-only when not yet a member).
  Widget _discoverGroupCard(_GroupRow g) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            widget.onOpenGroup(g.id);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        scheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: Icon(Icons.terrain_rounded,
                      color: scheme.onPrimary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name.isEmpty ? 'Unnamed group' : g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        g.description.isEmpty
                            ? '${g.memberCount} member${g.memberCount == 1 ? '' : 's'}'
                            : g.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelSm(scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _joinGroup(g.id),
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text('Join'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 38),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinGroup(String groupId) async {
    AppFeedback.success();
    try {
      await _db.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([widget.currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined the group.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join group: $e')),
        );
      }
    }
  }

  Widget _myGroupCard(_GroupRow g) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            widget.onOpenGroup(g.id);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        scheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: Icon(Icons.groups_2_rounded,
                      color: scheme.onPrimary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.name.isEmpty ? 'Unnamed group' : g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (g.isHost) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'HOST',
                                style: AppText.labelSm(
                                        scheme.onTertiaryContainer)
                                    .copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.5,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.group_rounded,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${g.memberCount} member${g.memberCount == 1 ? '' : 's'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.labelSm(scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupHikeCard(HikeEvent e) {
    final isHost = e.creatorId == widget.currentUserId;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            widget.onFeedItemClick(e.trailId);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
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
                        height: 110,
                        color: scheme.primaryContainer,
                        child: Center(
                          child: Icon(Icons.landscape_rounded,
                              size: 56, color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 10,
                      right: 14,
                      child: Text(
                        e.trailName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineMd(Colors.white)
                            .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${e.attendees.length}/${e.maxHikers}',
                          style: AppText.labelSm(scheme.primary)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e.dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isHost)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'You host',
                            style: AppText.labelSm(scheme.onTertiaryContainer)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
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

  // ─── Requests page ──────────────────────────────────────────────────────
  Widget _requestsPage() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
          AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: TextField(
            controller: _searchCtl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Find hikers by name...',
              prefixIcon: Icon(Icons.search_rounded, color: scheme.outline),
              suffixIcon: _searchCtl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.stackMd),

        // Search results section (only when actively searching)
        if (_searchQuery.isNotEmpty) ...[
          _sectionRow('Search results', null),
          const SizedBox(height: 8),
          if (_searching)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(color: scheme.primary)),
            )
          else if (_searchResults.isEmpty)
            _smallEmpty(Icons.person_search_rounded, 'No matches',
                'No hikers found for "$_searchQuery".')
          else
            ..._searchResults.map(_searchResultTile),
          const SizedBox(height: AppSpacing.stackMd),
        ],

        _sectionRow(
          'Friend Requests',
          _requestProfiles.isEmpty ? null : '${_requestProfiles.length}',
        ),
        const SizedBox(height: 8),
        if (_loading)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: scheme.primary)),
          )
        else if (_requestProfiles.isEmpty)
          _smallEmpty(Icons.person_add_alt_1_rounded, 'No pending requests',
              'Friend requests will appear here.')
        else
          ..._requestProfiles.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _requestTile(r),
              )),
      ],
    );
  }

  Widget _searchResultTile(SocialUser u) {
    final scheme = Theme.of(context).colorScheme;
    final isAlreadyFriend = widget.friends.contains(u.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => widget.onProfileClick(u.id),
              child: _avatar(u.profilePic, u.name, size: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      style: AppText.labelLg(scheme.onSurface)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(u.bio.isEmpty ? 'Tap to view profile' : u.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm(scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isAlreadyFriend)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                ),
                child: Text('Friends',
                    style: AppText.labelSm(scheme.onPrimaryContainer)
                        .copyWith(fontWeight: FontWeight.w800)),
              )
            else
              FilledButton.icon(
                onPressed: () => _sendFriendRequest(u),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 38),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Premium request tile — large avatar, name, "Wants to connect" caption,
  // and Accept (filled primary) / Decline (outlined) full-width buttons.
  Widget _requestTile(SocialUser r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => widget.onProfileClick(r.id),
                child: _avatar(r.profilePic, r.name, size: 52),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        style: AppText.labelLg(scheme.onSurface).copyWith(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      r.bio.isEmpty ? 'Wants to connect' : r.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm(scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    AppFeedback.success();
                    widget.onAccept(r.id);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    AppFeedback.warning();
                    widget.onReject(r.id);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Create Group sheet ─────────────────────────────────────────────────
  // Facebook-style: anyone can create a group. A name is required; description
  // is optional. Inviting friends is optional too — you can create an empty
  // group with just yourself, then others can discover and join from the
  // "Discover Groups" list.
  Future<void> _openCreateGroup() async {
    AppFeedback.tap();
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final invited = <String>{};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheet) {
          final scheme = Theme.of(sheetCtx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Create a new group',
                    style: AppText.headlineMd(scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  'Build a community around a route, peak, or interest. Anyone can join later.',
                  style: AppText.bodyMd(scheme.onSurfaceVariant)
                      .copyWith(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtl,
                  onChanged: (_) => setSheet(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Group name *',
                    hintText: 'e.g. Kathmandu Valley Sunrise Hikers',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText:
                        'What is this group about? Who should join?',
                  ),
                ),
                if (_friendProfiles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Invite friends (optional)',
                            style: AppText.labelLg(scheme.onSurface)
                                .copyWith(fontWeight: FontWeight.w800)),
                      ),
                      if (invited.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${invited.length} selected',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _friendProfiles.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (_, i) {
                        final f = _friendProfiles[i];
                        final isSel = invited.contains(f.id);
                        return InkWell(
                          onTap: () {
                            AppFeedback.toggle();
                            setSheet(() {
                              if (isSel) {
                                invited.remove(f.id);
                              } else {
                                invited.add(f.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                _avatar(f.profilePic, f.name, size: 36),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(f.name,
                                      style: AppText.bodyMd(scheme.onSurface)),
                                ),
                                Checkbox(
                                  value: isSel,
                                  onChanged: (_) {
                                    AppFeedback.toggle();
                                    setSheet(() {
                                      if (isSel) {
                                        invited.remove(f.id);
                                      } else {
                                        invited.add(f.id);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: nameCtl.text.trim().isEmpty
                      ? null
                      : () async {
                          AppFeedback.success();
                          final newId = await _createGroup(
                            name: nameCtl.text.trim(),
                            description: descCtl.text.trim(),
                            invitedFriendIds: invited.toList(),
                          );
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                            if (newId != null) widget.onOpenGroup(newId);
                          }
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Create Group'),
                ),
              ],
            ),
          );
        },
      ),
    );
    nameCtl.dispose();
    descCtl.dispose();
  }

  Future<String?> _createGroup({
    required String name,
    String description = '',
    List<String> invitedFriendIds = const [],
  }) async {
    if (name.isEmpty) return null;
    final members = <String>{widget.currentUserId, ...invitedFriendIds}.toList();
    final ref = await _db.collection('groups').add({
      'name': name,
      'description': description,
      'creatorId': widget.currentUserId,
      'creatorName': widget.currentUserName,
      'members': members,
      'isPublic': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(invitedFriendIds.isEmpty
                ? 'Group "$name" created — invite people to join.'
                : 'Group "$name" created with ${members.length} member${members.length == 1 ? '' : 's'}.')),
      );
    }
    return ref.id;
  }

  // ─── Shared primitives ──────────────────────────────────────────────────
  Widget _avatar(String url, String name, {double size = 40}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryFixed,
        border: Border.all(color: scheme.outlineVariant),
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

  Widget _smallEmpty(IconData icon, String title, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 28),
          const SizedBox(height: 8),
          Text(title,
              style: AppText.labelLg(scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(message,
              textAlign: TextAlign.center,
              style: AppText.labelSm(scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: AppText.headlineMd(scheme.onSurface)
                    .copyWith(fontSize: 18),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(message,
                style: AppText.bodyMd(scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _relativeTime(int millis) {
    if (millis <= 0) return '';
    final now = DateTime.now();
    final then = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = now.difference(then);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} week${diff.inDays >= 14 ? "s" : ""} ago';
    }
    if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} month${diff.inDays >= 60 ? "s" : ""} ago';
    }
    return '${(diff.inDays / 365).floor()} year${diff.inDays >= 730 ? "s" : ""} ago';
  }
}

class _GroupRow {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final int createdAt;
  final bool isHost;
  final bool isMember;
  const _GroupRow({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.createdAt,
    required this.isHost,
    required this.isMember,
  });
}

class _ActivityRow {
  final String id;
  final String userId;
  final String userName;
  final String userPic;
  final String actionType;
  final String targetName;
  final String targetId;
  final int timestamp;
  const _ActivityRow({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPic,
    required this.actionType,
    required this.targetName,
    required this.targetId,
    required this.timestamp,
  });
}
