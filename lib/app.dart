import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'models/app_notification.dart';
import 'models/trail.dart';
import 'screens/achievements_screen.dart';
import 'screens/add_trail_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/social_screen.dart';
import 'screens/trail_detail_screen.dart';
import 'theme/app_theme.dart';
import 'utils/feedback.dart';
import 'utils/ranking_manager.dart';

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
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const LoginScreen();
        return const RootShell();
      },
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
  String? _currentGroupId;

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

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser!.uid;
    _wireListeners();
  }

  void _wireListeners() {
    _db.collection('trails').where('isApproved', isEqualTo: true).snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        _cloudHikes = s.docs
            .map((d) => Trail.fromDoc(d).copyWith(isApproved: true))
            .toList();
        _isLoading = false;
      });
    });

    _db.collection('trails').where('authorId', isEqualTo: _uid).snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        _mySubmissions = s.docs.map(Trail.fromDoc).toList();
      });
    });

    _db.collection('trails').where('isApproved', isEqualTo: false).snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        _adminPendingHikes = s.docs.map(Trail.fromDoc).toList();
      });
    });

    _db
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
    });

    _db.collection('users').doc(_uid).snapshots().listen((doc) {
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
    });
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

  void _openTrail(Trail t) => setState(() => _currentTrail = t);
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
    if (_viewingProfileId != null) {
      return _withBackHandler(
        PublicProfileScreen(
          userId: _viewingProfileId!,
          onBack: () => setState(() => _viewingProfileId = null),
          onRemoveFriend: () async {
            await _removeFriend(_viewingProfileId!);
            if (mounted) setState(() => _viewingProfileId = null);
          },
        ),
        () => setState(() => _viewingProfileId = null),
      );
    }
    if (_chatFriendId != null) {
      return _withBackHandler(
        ChatScreen(
          currentUserId: _uid,
          friendId: _chatFriendId!,
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
    if (_currentGroupId != null) {
      return _withBackHandler(
        GroupDetailScreen(
          groupId: _currentGroupId!,
          currentUserId: _uid,
          currentUserName: _userName,
          currentUserPic: _userProfilePic,
          onBack: () => setState(() => _currentGroupId = null),
        ),
        () => setState(() => _currentGroupId = null),
      );
    }
    if (_currentTrail != null) {
      return _withBackHandler(
        TrailDetailScreen(
          trail: _currentTrail!,
          currentUserId: _uid,
          currentUserName: _userName,
          currentUserPic: _userProfilePic,
          myFriends: _myFriends,
          mySentRequests: _mySentRequests,
          isFavorite: _favoriteIds.contains(_currentTrail!.id),
          onBack: () => setState(() => _currentTrail = null),
          onSendFriendRequest: _sendFriendRequest,
          onCancelFriendRequest: _cancelFriendRequest,
          onToggleFavorite: () => _toggleFavorite(_currentTrail!.id),
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
          currentUserName: _userName,
          currentUserPic: _userProfilePic,
          receivedRequests: _myReceivedRequests,
          friends: _myFriends,
          unreadChatIds: _myUnreadChatIds,
          validTrailIds: {for (final t in _cloudHikes) t.id},
          onAccept: _acceptRequest,
          onReject: _rejectRequest,
          onChatClick: _openChat,
          onProfileClick: _openProfile,
          onOpenGroup: (groupId) =>
              setState(() => _currentGroupId = groupId),
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
        body: SafeArea(child: body),
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
