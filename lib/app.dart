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
    return MaterialApp(
      title: 'Kathmandu Hiker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
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

  @override
  Widget build(BuildContext context) {
    // Overlay screens — they sit above the bottom nav.
    if (_viewingProfileId != null) {
      return PublicProfileScreen(
        userId: _viewingProfileId!,
        onBack: () => setState(() => _viewingProfileId = null),
        onRemoveFriend: () async {
          await _removeFriend(_viewingProfileId!);
          if (mounted) setState(() => _viewingProfileId = null);
        },
      );
    }
    if (_chatFriendId != null) {
      return ChatScreen(
        currentUserId: _uid,
        friendId: _chatFriendId!,
        friendName: _chatFriendName,
        onBack: () => setState(() => _chatFriendId = null),
        onProfileClick: () => setState(() {
          _viewingProfileId = _chatFriendId;
          _chatFriendId = null;
        }),
      );
    }
    if (_currentTrail != null) {
      return TrailDetailScreen(
        trail: _currentTrail!,
        currentUserId: _uid,
        currentUserName: _userName,
        currentUserPic: _userProfilePic,
        myFriends: _myFriends,
        mySentRequests: _mySentRequests,
        onBack: () => setState(() => _currentTrail = null),
        onSendFriendRequest: _sendFriendRequest,
        onCancelFriendRequest: _cancelFriendRequest,
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
          friends: _myFriends,
          unreadChatIds: _myUnreadChatIds,
          onAccept: _acceptRequest,
          onReject: _rejectRequest,
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

    return WillPopScope(
      onWillPop: () async {
        if (_currentTab != 'Home') {
          setState(() => _currentTab = _currentTab == 'Achievements' ? 'Profile' : 'Home');
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: showBottomBar ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final socialBadge = _myReceivedRequests.length + _myUnreadChatIds.length;
    final tabs = [
      ('Home', 'Home', Icons.home, 0),
      ('Social', 'Social', Icons.group, socialBadge),
      ('Favorites', 'Favorites',
          _currentTab == 'Favorites' ? Icons.favorite : Icons.favorite_border, 0),
      (_isAdmin && _currentTab == 'Admin' ? 'Admin' : 'Profile', 'Profile', Icons.person, 0),
    ];
    return NavigationBar(
      selectedIndex: switch (_currentTab) {
        'Home' => 0,
        'Social' => 1,
        'Favorites' => 2,
        'Profile' || 'Admin' => 3,
        _ => 0,
      },
      onDestinationSelected: (i) {
        AppFeedback.tap();
        setState(() => _currentTab = tabs[i].$1);
      },
      destinations: tabs
          .map((t) => NavigationDestination(
                icon: t.$4 > 0
                    ? Badge(label: Text('${t.$4}'), child: Icon(t.$3))
                    : Icon(t.$3),
                label: t.$2,
              ))
          .toList(),
    );
  }
}
