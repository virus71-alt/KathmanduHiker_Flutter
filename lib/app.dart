import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/analytics.dart';
import 'core/logger.dart';
import 'screens/achievements_screen.dart';
import 'screens/add_trail_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/force_update_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/social_screen.dart';
import 'screens/trail_detail_screen.dart';
import 'services/remote_config_service.dart';
import 'state/auth_state_provider.dart';
import 'state/current_uid_provider.dart';
import 'state/navigation_providers.dart';
import 'state/repositories.dart';
import 'state/trail_providers.dart';
import 'state/user_profile_provider.dart';
import 'theme/app_theme.dart';
import 'utils/feedback.dart';
import 'widgets/offline_banner.dart';

class YamaApp extends StatelessWidget {
  const YamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (_, mode, __) => MaterialApp(
        title: 'Yama',
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

/// Thin router shell — all state lives in Riverpod providers.
/// Navigation overlays (trail, chat, profile) are replaced by go_router
/// in PR 6; until then StateProviders serve as the source of truth.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ─── Provider reads ───────────────────────────────────────────────────
    final uid              = ref.watch(currentUidProvider);

    // Wire analytics user on login / uid change.
    ref.listen<String>(currentUidProvider, (_, newUid) {
      AppLog.setUser(newUid);
      Analytics.setUser(newUid);
    });
    AppLog.setUser(uid);
    Analytics.setUser(uid);
    final profile          = ref.watch(userProfileProvider).valueOrNull;
    final trails           = ref.watch(approvedTrailsProvider).valueOrNull ?? [];
    final mySubmissions    = ref.watch(mySubmissionsProvider).valueOrNull ?? [];
    final pendingTrails    = ref.watch(pendingTrailsProvider).valueOrNull ?? [];
    final currentTab       = ref.watch(selectedTabProvider);
    final currentTrail     = ref.watch(currentTrailProvider);
    final currentChat      = ref.watch(currentChatProvider);
    final viewingProfileId = ref.watch(viewingProfileProvider);

    final isAdmin           = profile?.isAdmin ?? false;
    final userName          = profile?.displayName ?? 'Hiker';
    final userProfilePic    = profile?.profilePic ?? '';
    final myReceivedRequests = profile?.receivedRequests ?? [];
    final myUnreadChatIds   = profile?.unreadChatIds ?? [];

    // ─── Navigation helpers ───────────────────────────────────────────────
    void setTab(String tab) =>
        ref.read(selectedTabProvider.notifier).state = tab;

    Widget withBackHandler(Widget child, VoidCallback onBack) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            onBack();
          },
          child: child,
        );

    // ─── Repository actions ───────────────────────────────────────────────
    Future<void> removeFriend(String friendId) =>
        ref.read(userRepositoryProvider).removeFriend(
          uid: uid,
          friendUid: friendId,
        );

    Future<void> updateProfile({
      required String name,
      required String bio,
      required String location,
      required String phone,
      required String insta,
      required bool showPhone,
      File? newImage,
    }) =>
        ref.read(userRepositoryProvider).updateProfile(
          uid: uid,
          displayName: name,
          bio: bio,
          location: location,
          phone: phone,
          insta: insta,
          showPhone: showPhone,
          profileImage: newImage,
        );

    Future<String?> deleteAccount() async {
      AppLog.breadcrumb('account.delete.start');
      final result = await ref.read(userRepositoryProvider).deleteAccount(uid);
      return result.fold(
        (failure) {
          AppLog.w('account.delete.fail', data: {'failure': failure.toString()});
          if (failure.toString().contains('requires-recent-login')) {
            return 'For security, please log out, log back in, and try again.';
          }
          return 'Could not delete account. Please try again.';
        },
        (_) {
          AppLog.i('account.delete.success');
          Analytics.accountDeleted();
          return null;
        },
      );
    }

    // ─── Overlay screens (replaced by go_router in PR 6) ─────────────────
    if (viewingProfileId != null) {
      return withBackHandler(
        PublicProfileScreen(
          userId: viewingProfileId,
          onBack: () => ref.read(viewingProfileProvider.notifier).state = null,
          onRemoveFriend: () async {
            await removeFriend(viewingProfileId);
            ref.read(viewingProfileProvider.notifier).state = null;
          },
        ),
        () => ref.read(viewingProfileProvider.notifier).state = null,
      );
    }

    if (currentChat != null) {
      return withBackHandler(
        const ChatScreen(),
        () => ref.read(currentChatProvider.notifier).state = null,
      );
    }

    if (currentTrail != null) {
      return withBackHandler(
        const TrailDetailScreen(),
        () => ref.read(currentTrailProvider.notifier).state = null,
      );
    }

    // ─── Tab body ─────────────────────────────────────────────────────────
    final showBottomBar = currentTab != 'AddTrail' &&
        currentTab != 'Notifications' &&
        currentTab != 'Achievements' &&
        currentTab != 'Leaderboard';

    final Widget body = switch (currentTab) {
      'Home' || 'Favorites' => const HomeScreen(),
      'Notifications' => NotificationsScreen(onBack: () => setTab('Home')),
      'AddTrail' => AddTrailScreen(
          onSuccess: () => setTab('Home'),
          onBack: () => setTab('Home'),
        ),
      'Social' => const SocialScreen(),
      'Profile' => ProfileScreen(
          userSubmissions: mySubmissions,
          isAdmin: isAdmin,
          userName: userName,
          userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
          userDob: profile?.dob ?? '',
          userBio: profile?.bio ?? '',
          userLocation: profile?.location ?? '',
          userPhone: profile?.phone ?? '',
          userInsta: profile?.insta ?? '',
          userShowPhone: profile?.showPhone ?? false,
          userProfilePic: userProfilePic,
          userXP: profile?.totalXP ?? 0,
          hikerLevel: profile?.hikerLevel ?? 'Beginner',
          onLogout: () => FirebaseAuth.instance.signOut(),
          onAdminClick: () => setTab('Admin'),
          onAchievementsClick: () => setTab('Achievements'),
          onLeaderboardClick: () => setTab('Leaderboard'),
          onUpdateProfile: updateProfile,
          onDeletePending: (id) => ref.read(trailRepositoryProvider).deleteTrail(id),
          onDeleteAccount: deleteAccount,
        ),
      'Achievements' => AchievementsScreen(onBack: () => setTab('Profile')),
      'Leaderboard' => LeaderboardScreen(onBack: () => setTab('Profile')),
      'Admin' when isAdmin => AdminScreen(
          pendingHikes: {
            for (final t in [...pendingTrails, ...trails]) t.id: t,
          }.values.toList(),
          currentAdminId: uid,
          onApprove: (id) => ref.read(trailRepositoryProvider).approveTrail(id),
          onDelete: (id) => ref.read(trailRepositoryProvider).deleteTrail(id),
          onUpdate: (t) => ref.read(trailRepositoryProvider).updateTrail(t),
          onBack: () => setTab('Profile'),
        ),
      _ => const SizedBox.shrink(),
    };

    final isOnHome = currentTab == 'Home';
    return PopScope(
      canPop: isOnHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setTab(currentTab == 'Achievements' || currentTab == 'Leaderboard'
            ? 'Profile'
            : 'Home');
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
        bottomNavigationBar: showBottomBar
            ? _BottomBar(
                currentTab: currentTab,
                isAdmin: isAdmin,
                socialBadge: myReceivedRequests.length + myUnreadChatIds.length,
                onTab: setTab,
              )
            : null,
      ),
    );
  }
}

// ── Bottom navigation ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final String currentTab;
  final bool isAdmin;
  final int socialBadge;
  final void Function(String) onTab;

  const _BottomBar({
    required this.currentTab,
    required this.isAdmin,
    required this.socialBadge,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (currentTab) {
      'Home'               => 0,
      'Social'             => 1,
      'Favorites'          => 2,
      'Profile' || 'Admin' => 3,
      _                    => 0,
    };

    final tabs = <_StitchNavTab>[
      const _StitchNavTab(key: 'Home',      label: 'Home',    icon: Icons.home_outlined,          activeIcon: Icons.home_rounded),
      _StitchNavTab(      key: 'Social',    label: 'Social',  icon: Icons.group_outlined,         activeIcon: Icons.group_rounded, badge: socialBadge),
      const _StitchNavTab(key: 'Favorites', label: 'Saved',   icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded),
      _StitchNavTab(      key: isAdmin && currentTab == 'Admin' ? 'Admin' : 'Profile',
                          label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
    ];

    final chrome = AppChromeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: chrome.chrome,
        border: Border(top: BorderSide(color: chrome.chromeBorder)),
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
                    onTab(tabs[i].key);
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
