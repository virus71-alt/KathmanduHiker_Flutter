import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/analytics.dart';
import 'core/logger.dart';
import 'state/auth_state_provider.dart';
import 'models/app_notification.dart';
import 'models/trail.dart';
import 'screens/achievements_screen.dart';
import 'screens/add_trail_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/force_update_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/social_screen.dart';
import 'screens/trail_detail_screen.dart';
import 'services/remote_config_service.dart';
import 'theme/app_theme.dart';
import 'utils/feedback.dart';
import 'utils/ranking_manager.dart';
import 'widgets/offline_banner.dart';

class KathmanduHikerApp extends StatelessWidget {
  const KathmanduHikerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (_, mode, __) => MaterialApp(
        title: 'Kathmandu Hiker',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        navigatorObservers: [Analytics.navObserver()],
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool? _outdated;
  String _updateMessage = '';

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final min = AppConfig.instance.minBuildNumber;
      if (mounted) {
        setState(() {
          _outdated = current < min;
          _updateMessage = AppConfig.instance.forceUpdateMessage;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _outdated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_outdated == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_outdated == true) {
      return ForceUpdateScreen(message: _updateMessage);
    }
    return ref.watch(authStateProvider).when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : const RootShell(),
    );
  }
}

/// Holds the global app state and orchestrates navigation between
/// Home / Social / Favorites / Profile (and overlays Trail / Chat / Profile views).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String _currentTab = 'Home';
  Trail? _currentTrail;
  String? _chatFriendId;
  String _chatFriendName = '';
  String? _viewingProfileId;

  // Live data
  List<Trail> _cloudHikes = [];
  Set<String> _favoriteIds = {};
  List<Trail> _mySubmissions = [];
  List<Trail> _adminPendingHikes = [];
  List<String> _myFriends = [];
  List<String> _mySentRequests = [];
  List<String> _myReceivedRequests = [];
  List<String> _myUnreadChatIds = [];
  List<AppNotification> _myNotifications = [];

  bool _isAdmin = false;
  bool _isLoading = true;

  // User profile
  String _userName = 'Hiker';
  String _userBio = '';
  String _userLocation = '';
  String _userProfilePic = '';
  String _userDob = '';
  String _userPhone = '';
  String _userInsta = '';
  bool _userShowPhone = false;
  int _userXP = 0;
  String _hikerLevel = 'Beginner';

  late final String _uid;

  // Every Firestore stream subscription is captured here so we can cancel
  // them all in dispose. Without this, signing out and signing back in (or
  // any future hot-restart of the shell) would leak listeners on stale
  // Firestore connections and burn quota.
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    // Defensive: RootShell is only mounted by AuthGate when a User is
    // present, but we never trust a `!` against an external source. If
    // somehow currentUser is null we sign out and let AuthGate re-route
    // back to LoginScreen instead of crashing on the bang.
    final user = _auth.currentUser;
    if (user == null) {
      AppLog.e('shell.boot.noUser');
      // Trigger an immediate signOut so AuthGate's StreamBuilder rebuilds
      // and lands on LoginScreen on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _auth.signOut();
      });
      _uid = '';
      return;
    }
    _uid = user.uid;
    AppLog.setUser(_uid);
    Analytics.setUser(_uid);
    _wireListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  void _wireListeners() {
    _subs.add(_db
        .collection('trails')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _cloudHikes = s.docs
            .map((d) => Trail.fromDoc(d).copyWith(isApproved: true))
            .toList();
        _isLoading = false;
      });
    }));

    _subs.add(_db
        .collection('trails')
        .where('authorId', isEqualTo: _uid)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _mySubmissions = s.docs.map(Trail.fromDoc).toList();
      });
    }));

    _subs.add(_db
        .collection('trails')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _adminPendingHikes = s.docs.map(Trail.fromDoc).toList();
      });
    }));

    _subs.add(_db
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() {
        _myNotifications = s.docs.map(AppNotification.fromDoc).toList();
      });
    }));

    _subs.add(_db.collection('users').doc(_uid).snapshots().listen((doc) {
      if (!mounted || !doc.exists) return;
      final d = doc.data() ?? {};
      setState(() {
        _isAdmin = (d['role'] ?? '') == 'admin';
        _userName = (d['displayName'] ?? 'Hiker') as String;
        _userBio = (d['bio'] ?? '') as String;
        _userLocation = (d['location'] ?? '') as String;
        _userProfilePic = (d['profilePic'] ?? '') as String;
        _userDob = (d['dob'] ?? '') as String;
        _userPhone = (d['phone'] ?? '') as String;
        _userInsta = (d['insta'] ?? '') as String;
        _userShowPhone = (d['showPhone'] ?? false) as bool;
        _userXP = ((d['totalXP'] ?? 0) as num).toInt();
        _hikerLevel = (d['hikerLevel'] ?? 'Beginner') as String;
        _favoriteIds = ((d['favoriteTrails'] as List?) ?? const []).cast<String>().toSet();
        _myFriends = ((d['friends'] as List?) ?? const []).cast<String>();
        _mySentRequests = ((d['sentRequests'] as List?) ?? const []).cast<String>();
        _myReceivedRequests = ((d['receivedRequests'] as List?) ?? const []).cast<String>();
        _myUnreadChatIds = ((d['unreadChatIds'] as List?) ?? const []).cast<String>();
      });
    }));
  }

  // ─── Profile + Friends actions ────────────────────────────────────────────
  Future<void> _updateProfile({
    required String name,
    required String bio,
    required String location,
    required String phone,
    required String insta,
    required bool showPhone,
    File? newImage,
  }) async {
    final userRef = _db.collection('users').doc(_uid);
    final updates = <String, dynamic>{
      'displayName': name,
      'bio': bio,
      'location': location,
      'phone': phone,
      'insta': insta,
      'showPhone': showPhone,
    };
    if (newImage != null) {
      final ref = _storage.ref().child('profiles/$_uid.jpg');
      await ref.putFile(newImage);
      updates['profilePic'] = await ref.getDownloadURL();
    }
    await userRef.update(updates);
  }

  Future<void> _toggleFavorite(String trailId) async {
    final userRef = _db.collection('users').doc(_uid);
    if (_favoriteIds.contains(trailId)) {
      await userRef.update({'favoriteTrails': FieldValue.arrayRemove([trailId])});
    } else {
      await userRef.update({'favoriteTrails': FieldValue.arrayUnion([trailId])});
    }
  }

  Future<void> _sendFriendRequest(String targetId) async {
    await _db.collection('users').doc(targetId).update({
      'receivedRequests': FieldValue.arrayUnion([_uid])
    });
    await _db.collection('users').doc(_uid).update({
      'sentRequests': FieldValue.arrayUnion([targetId])
    });
    _toast('Friend Request Sent! ⏳');
  }

  Future<void> _cancelFriendRequest(String targetId) async {
    await _db.collection('users').doc(targetId).update({
      'receivedRequests': FieldValue.arrayRemove([_uid])
    });
    await _db.collection('users').doc(_uid).update({
      'sentRequests': FieldValue.arrayRemove([targetId])
    });
    _toast('Friend Request Cancelled ❌');
  }

  Future<void> _acceptRequest(String senderId) async {
    await _db.collection('users').doc(_uid).update({
      'friends': FieldValue.arrayUnion([senderId]),
      'receivedRequests': FieldValue.arrayRemove([senderId]),
    });
    await _db.collection('users').doc(senderId).update({
      'friends': FieldValue.arrayUnion([_uid]),
      'sentRequests': FieldValue.arrayRemove([_uid]),
    });
    await _db.collection('users').doc(senderId).collection('notifications').add({
      'message': '$_userName accepted your friend request! 🤝',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });
    _toast('Friend Request Accepted! 🎉');
  }

  Future<void> _rejectRequest(String senderId) async {
    await _db.collection('users').doc(_uid).update({
      'receivedRequests': FieldValue.arrayRemove([senderId])
    });
    await _db.collection('users').doc(senderId).update({
      'sentRequests': FieldValue.arrayRemove([_uid])
    });
  }

  Future<void> _removeFriend(String friendId) async {
    await _db.collection('users').doc(_uid).update({
      'friends': FieldValue.arrayRemove([friendId])
    });
    await _db.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([_uid])
    });
  }

  Future<void> _deleteTrail(String trailId) async {
    await _db.collection('trails').doc(trailId).delete();
  }

  /// Removes every piece of data associated with the current user, then
  /// deletes the Auth user itself. Per ULTIMATE.md §11.1.4 / §10.3 this is
  /// the in-app account-deletion path Google Play requires.
  ///
  /// Returns `null` on success or a user-facing message on failure. The
  /// common failure is `requires-recent-login` (Firebase requires a fresh
  /// re-auth before a delete) — in that case we ask the user to log out
  /// and back in, then try again.
  Future<String?> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return 'You are already signed out.';
    final uid = user.uid;
    AppLog.breadcrumb('account.delete.start');
    try {
      // 1) Wipe the Firestore profile + notifications subcollection.
      final notifs = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      final batch = _db.batch();
      for (final d in notifs.docs) {
        batch.delete(d.reference);
      }
      batch.delete(_db.collection('users').doc(uid));
      await batch.commit();

      // 2) Mark the user's trail submissions as anonymous so other
      //    users don't see a dangling "by ?" — we don't delete trails
      //    because they're shared community content.
      final mine = await _db
          .collection('trails')
          .where('authorId', isEqualTo: uid)
          .get();
      for (final d in mine.docs) {
        await d.reference.update({
          'authorId': '',
          'authorName': 'Deleted user',
        });
      }

      // 3) Best-effort wipe of the profile picture in Storage. The user
      //    may not have uploaded one; ignore "object not found".
      try {
        await _storage.ref().child('profiles/$uid.jpg').delete();
      } catch (_) {}

      // 4) Finally, delete the Auth user. AuthGate will route to login
      //    on the next StreamBuilder rebuild.
      await user.delete();
      AppLog.i('account.delete.success');
      Analytics.accountDeleted();
      return null;
    } on FirebaseAuthException catch (e) {
      AppLog.w('account.delete.authError', data: {'code': e.code});
      if (e.code == 'requires-recent-login') {
        return 'For security, please log out, log back in, and try again.';
      }
      return 'Could not delete account: ${e.code}';
    } catch (e, s) {
      AppLog.e('account.delete.fail', error: e, stack: s);
      return 'Could not delete account. Please try again.';
    }
  }

  Future<void> _approveTrail(String id) async {
    final doc = await _db.collection('trails').doc(id).get();
    final authorId = doc.data()?['authorId'] as String? ?? '';
    final trailName = doc.data()?['name'] as String? ?? 'Trail';
    final authorName = doc.data()?['authorName'] as String? ?? 'A Hiker';
    if (authorId.isNotEmpty) {
      await _db.collection('users').doc(authorId).collection('notifications').add({
        'message': "Your trail '$trailName' was approved by an Admin! 🎉",
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
      await _db
          .collection('users')
          .doc(authorId)
          .update({'totalXP': FieldValue.increment(RankingManager.xpTrailApproved)});
      await _db.collection('activities').add({
        'userId': authorId,
        'userName': authorName,
        'userPic': '',
        'actionType': 'discovered a new trail:',
        'targetName': trailName,
        'targetId': id,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _db.collection('trails').doc(id).update({'isApproved': true});
  }

  Future<void> _updatePendingTrail(Trail t) async {
    await _db.collection('trails').doc(t.id).set(t.toMap());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openTrail(Trail t) {
    Analytics.trailView(t.id);
    setState(() => _currentTrail = t);
  }
  void _openChat(String id, String name) => setState(() {
        _chatFriendId = id;
        _chatFriendName = name;
      });
  void _openProfile(String id) => setState(() => _viewingProfileId = id);

  /// Wraps an overlay screen in a `PopScope` so the system back button
  /// dismisses the overlay (returns to whatever shell was beneath) instead of
  /// exiting the app.
  Widget _withBackHandler(Widget child, VoidCallback onBack) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onBack();
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Overlay screens — they sit above the bottom nav. Each is wrapped in
    // PopScope so OS back is intercepted and routed to its close callback,
    // preventing the app from exiting unexpectedly.
    final viewingProfileId = _viewingProfileId;
    if (viewingProfileId != null) {
      return _withBackHandler(
        PublicProfileScreen(
          userId: viewingProfileId,
          onBack: () => setState(() => _viewingProfileId = null),
          onRemoveFriend: () async {
            await _removeFriend(viewingProfileId);
            if (mounted) setState(() => _viewingProfileId = null);
          },
        ),
        () => setState(() => _viewingProfileId = null),
      );
    }
    final chatFriendId = _chatFriendId;
    if (chatFriendId != null) {
      return _withBackHandler(
        ChatScreen(
          currentUserId: _uid,
          friendId: chatFriendId,
          friendName: _chatFriendName,
          onBack: () => setState(() => _chatFriendId = null),
          onProfileClick: () => setState(() {
            _viewingProfileId = _chatFriendId;
            _chatFriendId = null;
          }),
        ),
        () => setState(() => _chatFriendId = null),
      );
    }
    final currentTrail = _currentTrail;
    if (currentTrail != null) {
      return _withBackHandler(
        TrailDetailScreen(
          trail: currentTrail,
          currentUserId: _uid,
          currentUserName: _userName,
          currentUserPic: _userProfilePic,
          myFriends: _myFriends,
          mySentRequests: _mySentRequests,
          isFavorite: _favoriteIds.contains(currentTrail.id),
          onBack: () => setState(() => _currentTrail = null),
          onSendFriendRequest: _sendFriendRequest,
          onCancelFriendRequest: _cancelFriendRequest,
          onToggleFavorite: () => _toggleFavorite(currentTrail.id),
        ),
        () => setState(() => _currentTrail = null),
      );
    }

    final showBottomBar =
        _currentTab != 'AddTrail' && _currentTab != 'Notifications' && _currentTab != 'Achievements';

    Widget body;
    switch (_currentTab) {
      case 'Home':
      case 'Favorites':
        body = HomeScreen(
          hikes: _cloudHikes,
          favoriteIds: _favoriteIds,
          showOnlyFavorites: _currentTab == 'Favorites',
          unreadNotificationCount: _myNotifications.where((n) => !n.isRead).length,
          userName: _userName,
          userProfilePic: _userProfilePic,
          isLoading: _isLoading,
          onToggleFavorite: _toggleFavorite,
          onTrailClick: _openTrail,
          onAddClick: () => setState(() => _currentTab = 'AddTrail'),
          onNotificationClick: () => setState(() => _currentTab = 'Notifications'),
        );
        break;
      case 'Notifications':
        body = NotificationsScreen(
          notifications: _myNotifications,
          onBack: () => setState(() => _currentTab = 'Home'),
          onMarkAsRead: (id) => _db
              .collection('users')
              .doc(_uid)
              .collection('notifications')
              .doc(id)
              .update({'isRead': true}),
          onClearAll: () async {
            for (final n in _myNotifications) {
              await _db
                  .collection('users')
                  .doc(_uid)
                  .collection('notifications')
                  .doc(n.id)
                  .delete();
            }
          },
        );
        break;
      case 'AddTrail':
        body = AddTrailScreen(
          onSuccess: () => setState(() => _currentTab = 'Home'),
          onBack: () => setState(() => _currentTab = 'Home'),
        );
        break;
      case 'Social':
        body = SocialScreen(
          currentUserId: _uid,
          receivedRequests: _myReceivedRequests,
          sentRequests: _mySentRequests,
          friends: _myFriends,
          unreadChatIds: _myUnreadChatIds,
          validTrailIds: {for (final t in _cloudHikes) t.id},
          onAccept: _acceptRequest,
          onReject: _rejectRequest,
          onSendFriendRequest: _sendFriendRequest,
          onCancelFriendRequest: _cancelFriendRequest,
          onChatClick: _openChat,
          onProfileClick: _openProfile,
          onFeedItemClick: (trailId) async {
            final d = await _db.collection('trails').doc(trailId).get();
            if (d.exists) _openTrail(Trail.fromDoc(d));
          },
        );
        break;
      case 'Profile':
        body = ProfileScreen(
          userSubmissions: _mySubmissions,
          isAdmin: _isAdmin,
          userName: _userName,
          userEmail: _auth.currentUser?.email ?? '',
          userDob: _userDob,
          userBio: _userBio,
          userLocation: _userLocation,
          userPhone: _userPhone,
          userInsta: _userInsta,
          userShowPhone: _userShowPhone,
          userProfilePic: _userProfilePic,
          userXP: _userXP,
          hikerLevel: _hikerLevel,
          onLogout: () async {
            await _auth.signOut();
            if (mounted) setState(() => _currentTab = 'Home');
          },
          onAdminClick: () => setState(() => _currentTab = 'Admin'),
          onAchievementsClick: () => setState(() => _currentTab = 'Achievements'),
          onUpdateProfile: _updateProfile,
          onDeletePending: _deleteTrail,
          onDeleteAccount: _deleteAccount,
        );
        break;
      case 'Achievements':
        body = AchievementsScreen(
          userXP: _userXP,
          approvedSubmissions: _mySubmissions.where((t) => t.isApproved).length,
          onBack: () => setState(() => _currentTab = 'Profile'),
        );
        break;
      case 'Admin':
        body = _isAdmin
            ? AdminScreen(
                pendingHikes: {
                  for (final t in [..._adminPendingHikes, ..._cloudHikes]) t.id: t,
                }.values.toList(),
                currentAdminId: _uid,
                onApprove: _approveTrail,
                onDelete: _deleteTrail,
                onUpdate: _updatePendingTrail,
                onBack: () => setState(() => _currentTab = 'Profile'),
              )
            : const SizedBox.shrink();
        break;
      default:
        body = const SizedBox.shrink();
    }

    final isOnHome = _currentTab == 'Home';
    return PopScope(
      canPop: isOnHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          _currentTab = _currentTab == 'Achievements' ? 'Profile' : 'Home';
        });
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
        bottomNavigationBar: showBottomBar ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final socialBadge = _myReceivedRequests.length + _myUnreadChatIds.length;
    final selectedIndex = switch (_currentTab) {
      'Home' => 0,
      'Social' => 1,
      'Favorites' => 2,
      'Profile' || 'Admin' => 3,
      _ => 0,
    };

    final tabs = <_StitchNavTab>[
      _StitchNavTab(
        key: 'Home',
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _StitchNavTab(
        key: 'Social',
        label: 'Social',
        icon: Icons.group_outlined,
        activeIcon: Icons.group_rounded,
        badge: socialBadge,
      ),
      _StitchNavTab(
        key: 'Favorites',
        label: 'Saved',
        icon: Icons.bookmark_outline_rounded,
        activeIcon: Icons.bookmark_rounded,
      ),
      _StitchNavTab(
        key: _isAdmin && _currentTab == 'Admin' ? 'Admin' : 'Profile',
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    final chrome = AppChromeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: chrome.chrome,
        border: Border(
          top: BorderSide(color: chrome.chromeBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _StitchNavItem(
                  tab: tabs[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    AppFeedback.tap();
                    setState(() => _currentTab = tabs[i].key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StitchNavTab {
  final String key;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badge;
  const _StitchNavTab({
    required this.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });
}

class _StitchNavItem extends StatelessWidget {
  final _StitchNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _StitchNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7);
    final iconWidget = Icon(
      selected ? tab.activeIcon : tab.icon,
      color: color,
      size: 24,
    );
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    return InkWell(
      onTap: onTap,
      enableFeedback: false,
      borderRadius: BorderRadius.circular(AppRadius.base),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? highlight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.base),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tab.badge > 0
                ? Badge(
                    label: Text('${tab.badge}'),
                    backgroundColor: scheme.tertiaryContainer,
                    textColor: scheme.onTertiaryContainer,
                    child: iconWidget,
                  )
                : iconWidget,
            const SizedBox(height: 2),
            Text(
              tab.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
