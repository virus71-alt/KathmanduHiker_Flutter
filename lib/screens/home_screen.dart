import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics.dart';
import '../domain/entities/trail.dart';
import '../models/weather_response.dart';
import '../services/weather_service.dart';
import '../state/current_uid_provider.dart';
import '../state/navigation_providers.dart';
import '../state/notifications_provider.dart';
import '../state/repositories.dart';
import '../state/trail_providers.dart';
import '../state/user_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isMapView = false;
  Trail? _selectedMapTrail;
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  bool _showSos = false;
  bool _sirenPlaying = false;
  WeatherResponse? _ribbonWeather;

  // Provider-derived values, refreshed at the top of each build() call.
  List<Trail> _hikes = [];
  Set<String> _favoriteIds = {};
  bool _showOnlyFavorites = false;
  int _unreadCount = 0;
  String _userName = '';
  String _userProfilePic = '';
  bool _isProviderLoading = false;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    // Fetch weather for the Kathmandu Valley ribbon. Quietly skips on failure
    // so the ribbon is just hidden instead of showing an error.
    WeatherService.getWeather('Kathmandu').then((w) {
      if (mounted && w != null) setState(() => _ribbonWeather = w);
    });
  }

  @override
  void dispose() {
    if (_sirenPlaying) FlutterRingtonePlayer().stop();
    super.dispose();
  }

  List<Trail> get _filteredHikes {
    return _hikes.where((t) {
      if (_showOnlyFavorites && !_favoriteIds.contains(t.id)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!t.name.toLowerCase().contains(q) &&
            !t.transportRoute.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedDifficulty != 'All' &&
          t.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _dialEmergency(String num) async {
    AppFeedback.warning();
    final uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) unawaited(launchUrl(uri));
  }

  Future<void> _sendSosSms() async {
    AppFeedback.tap();
    final uri = Uri.parse(
        'sms:?body=${Uri.encodeComponent('SOS! I need help. Last known location: https://maps.google.com/?q=27.7172,85.3240')}');
    if (await canLaunchUrl(uri)) unawaited(launchUrl(uri));
  }

  Future<void> _toggleSiren() async {
    AppFeedback.warning();
    if (_sirenPlaying) {
      await FlutterRingtonePlayer().stop();
      setState(() => _sirenPlaying = false);
      return;
    }
    // Uses the phone's built-in alarm sound — no bundled asset required.
    await FlutterRingtonePlayer().play(
      android: AndroidSounds.alarm,
      ios: IosSounds.alarm,
      looping: true,
      volume: 1.0,
      asAlarm: true,
    );
    setState(() => _sirenPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final trailsAsync = ref.watch(approvedTrailsProvider);
    final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
    final currentTab = ref.watch(selectedTabProvider);

    _hikes = trailsAsync.valueOrNull ?? [];
    _favoriteIds = profile?.favoriteTrailIds ?? {};
    _showOnlyFavorites = currentTab == 'Favorites';
    _unreadCount = notifications.where((n) => !n.isRead).length;
    _userName = profile?.displayName ?? 'Hiker';
    _userProfilePic = profile?.profilePic ?? '';
    _isProviderLoading = trailsAsync.isLoading;
    _uid = ref.read(currentUidProvider);

    return Stack(
      children: [
        Column(
          children: [
            _topBar(),
            Expanded(child: _buildBody()),
          ],
        ),
        if (!_showOnlyFavorites && !_isMapView)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                AppFeedback.tap();
                ref.read(selectedTabProvider.notifier).state = 'AddTrail';
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Trail'),
            ),
          ),
        if (_showSos) _sosSheet(),
      ],
    );
  }

  Widget _topBar() {
    final chrome = AppChromeColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: chrome.chrome,
        border: Border(bottom: BorderSide(color: chrome.chromeBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          // Circular avatar — shows the user's profile picture; falls back to
          // their initial on a primary-tinted disc when no pic is set.
          _userAvatar(scheme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hi,',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                Text(
                  _userName.isEmpty
                      ? 'Hiker'
                      : _userName.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.15,
                    fontFamily:
                        Theme.of(context).textTheme.titleLarge?.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          if (!_showOnlyFavorites)
            _chromeIconButton(
              icon: _isMapView ? Icons.list_alt_rounded : Icons.map_outlined,
              tint: scheme.primary,
              onTap: () {
                AppFeedback.tap();
                setState(() => _isMapView = !_isMapView);
              },
            ),
          _chromeIconButton(
            icon: Icons.notifications_none_rounded,
            tint: scheme.primary,
            badge: _unreadCount,
            onTap: () {
              AppFeedback.tap();
              ref.read(selectedTabProvider.notifier).state = 'Notifications';
            },
          ),
          _chromeIconButton(
            icon: Icons.sos_rounded,
            tint: scheme.error,
            onTap: () {
              AppFeedback.warning();
              setState(() => _showSos = true);
            },
          ),
        ],
      ),
    );
  }

  // Circular profile-pic avatar shown in the top-left chrome bar. Falls back
  // to the user's initial on a primary-tinted disc when no pic URL is set
  // (or while it's loading / errored).
  Widget _userAvatar(ColorScheme scheme) {
    final pic = _userProfilePic;
    final initial = _userName.trim().isEmpty
        ? 'H'
        : _userName.trim()[0].toUpperCase();
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (pic.isEmpty) return fallback;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: pic,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Widget _chromeIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
    required Color tint,
  }) {
    Widget child = Icon(icon, color: tint, size: 22);
    if (badge > 0) {
      child = Badge(
        label: Text('$badge'),
        backgroundColor: Theme.of(context).colorScheme.error,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg * 1.5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    if (_isProviderLoading) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }
    if (_isMapView && !_showOnlyFavorites) {
      return _buildMapView(_filteredHikes);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile, AppSpacing.gutter, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(child: _searchField()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(child: _filterChipsRow()),
        ),
        if (_ribbonWeather != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackMd, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(child: _weatherRibbon()),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackMd, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(
            child: _sectionHeader(_showOnlyFavorites
                ? 'Your Saved Trails'
                : _selectedDifficulty == 'All'
                    ? 'Explore Hikes'
                    : '$_selectedDifficulty Trails'),
          ),
        ),
        if (_filteredHikes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackSm, AppSpacing.marginMobile, 140),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                // 560 keeps phones at 1 column (no empty 2nd-column slot)
                // and switches to 2 cols only on tablets / large foldables.
                maxCrossAxisExtent: 560,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                // Taller than 300 to fit the 160-px photo + 14-px padding +
                // title + subtitle + divider + 3-stat footer without the
                // bottom-overflow stripe.
                mainAxisExtent: 332,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _trailCard(_filteredHikes[i]),
                childCount: _filteredHikes.length,
              ),
            ),
          ),
      ],
    );
  }

  // Horizontal filter chip row — "All" (Filters icon style), Easy, Moderate,
  // Hard, Challenging. Selected chip uses primary-container fill.
  Widget _filterChipsRow() {
    final scheme = Theme.of(context).colorScheme;
    final chips = const ['All', 'Easy', 'Moderate', 'Hard', 'Challenging'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = chips[i];
          final selected = _selectedDifficulty == label;
          final isAllPrimary = i == 0;
          return InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () {
              AppFeedback.toggle();
              setState(() => _selectedDifficulty = label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer
                    : (isAllPrimary && _selectedDifficulty == 'All')
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAllPrimary) ...[
                    Icon(Icons.tune_rounded,
                        size: 16,
                        color: selected || _selectedDifficulty == 'All'
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Weather ribbon — primary-container background, mountain icon on the left,
  // temp + "x km/h" on the right. Mirrors the HTML's "Shivapuri Range" pill.
  Widget _weatherRibbon() {
    final scheme = Theme.of(context).colorScheme;
    final w = _ribbonWeather!;
    final desc = w.description.isEmpty
        ? 'Kathmandu Valley'
        : '${w.description[0].toUpperCase()}${w.description.substring(1)}';
    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.filter_hdr_rounded,
              size: 28, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CURRENT CONDITIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  w.name.isEmpty ? 'Kathmandu' : w.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headlineMd(scheme.onPrimaryContainer)
                      .copyWith(fontSize: 17, height: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${w.temp.toInt()}°C',
                style: AppText.headlineMd(scheme.onPrimaryContainer)
                    .copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.air_rounded,
                      size: 12,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Find your next trail...',
          prefixIcon: Icon(Icons.search_rounded, color: scheme.outline),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title, style: AppText.headlineMd(scheme.onSurface)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // Bento-style trail card: hero photo with floating difficulty pill +
  // rating chip + bookmark; 3-stat footer (Cost / Duration / Mode) split by
  // hairline dividers. Mirrors the HTML reference.
  Widget _trailCard(Trail trail) {
    final scheme = Theme.of(context).colorScheme;
    final isFav = _favoriteIds.contains(trail.id);
    final rating = trail.ratingScore > 0
        ? trail.ratingScore
        : trail.userRating.toDouble();
    final imageUrl = trail.imageUrls.isNotEmpty
        ? trail.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900';
    final diff = difficultyColors(context, trail.difficulty);

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          AppFeedback.tap();
          Analytics.trailView(trail.id);
          ref.read(currentTrailProvider.notifier).state = trail;
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero photo ────────────────────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 160,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                          height: 160, color: scheme.surfaceContainerHigh),
                      errorWidget: (_, __, ___) => Container(
                          height: 160, color: scheme.surfaceContainerHigh),
                    ),
                  ),
                  // Difficulty pill — top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: diff.bg,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        trail.difficulty.isEmpty
                            ? '—'
                            : trail.difficulty.toUpperCase(),
                        style: AppText.labelSm(diff.fg)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  // Rating chip — bottom-right glassmorphic
                  if (rating > 0)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AppRadius.base),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFB300), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Bookmark — top-right
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          AppFeedback.toggle();
                          ref.read(userRepositoryProvider).toggleFavorite(
                            uid: _uid, trailId: trail.id,
                            add: !_favoriteIds.contains(trail.id),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            isFav
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            size: 18,
                            color: isFav
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // ── Title + 3-stat footer ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trail.name,
                      style: AppText.headlineMd(scheme.onSurface)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trail.transportRoute.isEmpty
                          ? 'Kathmandu Valley'
                          : trail.transportRoute,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm(scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _trailStatCell(
                              'COST',
                              trail.fare.isEmpty ? 'Free' : trail.fare,
                            ),
                          ),
                          VerticalDivider(
                              width: 1, color: scheme.outlineVariant),
                          Expanded(
                            child: _trailStatCell(
                              'DURATION',
                              trail.duration.isEmpty ? '—' : trail.duration,
                            ),
                          ),
                          VerticalDivider(
                              width: 1, color: scheme.outlineVariant),
                          Expanded(
                            child: _trailStatCell(
                              'MODE',
                              trail.travelMode.isEmpty
                                  ? 'Trek'
                                  : trail.travelMode,
                            ),
                          ),
                        ],
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
  }

  Widget _trailStatCell(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.labelLg(scheme.onSurface)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.terrain_rounded,
                  size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedDifficulty != 'All'
                  ? 'No trails match your search.'
                  : _showOnlyFavorites
                      ? 'No saved trails yet.\nStart exploring!'
                      : 'No trails found.',
              textAlign: TextAlign.center,
              style: AppText.bodyMd(scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(List<Trail> hikes) {
    final scheme = Theme.of(context).colorScheme;
    // Capture the nullable field into a local for §19.8 — within this
    // build method `_selectedMapTrail` could theoretically be set null by
    // a concurrent setState, so we read it once into a non-null local.
    final selected = _selectedMapTrail;
    final markers = <Marker>{};
    for (final t in hikes) {
      final hasPicked = t.latitude != 0.0 || t.longitude != 0.0;
      final pos = hasPicked
          ? LatLng(t.latitude, t.longitude)
          : LatLng(27.7172 + (t.name.length % 15) * 0.015 - 0.1,
              85.3240 + (t.name.hashCode.abs() % 15) * 0.015 - 0.1);
      markers.add(Marker(
        markerId: MarkerId(t.id),
        position: pos,
        infoWindow: InfoWindow(title: t.name, snippet: 'Difficulty: ${t.difficulty}'),
        onTap: () => setState(() => _selectedMapTrail = t),
      ));
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              const CameraPosition(target: LatLng(27.7172, 85.3240), zoom: 10.5),
          mapType: MapType.satellite,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: markers,
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              elevation: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  AppFeedback.tap();
                  Analytics.trailView(selected.id);
                  ref.read(currentTrailProvider.notifier).state = selected;
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        child: CachedNetworkImage(
                          imageUrl: selected.imageUrls.isNotEmpty
                              ? selected.imageUrls[0]
                              : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selected.name,
                                style: AppText.labelLg(scheme.onSurface)),
                            Text(
                                'Difficulty: ${selected.difficulty}',
                                style: AppText.labelSm(
                                    scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sosSheet() {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSos = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.base),
                        ),
                        child: Icon(Icons.warning_amber_rounded,
                            color: scheme.error),
                      ),
                      const SizedBox(width: 10),
                      Text('Emergency SOS',
                          style: AppText.headlineMd(scheme.error)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use these lifelines only in a real emergency. They will use your phone\'s native services.',
                    style: AppText.bodyMd(scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _sosButton('Call Police', '100', Icons.local_police_outlined,
                      const Color(0xFFB3261E), () => _dialEmergency('100')),
                  const SizedBox(height: 10),
                  _sosButton('Call Ambulance', '102',
                      Icons.local_hospital_outlined,
                      const Color(0xFF005DBA), () => _dialEmergency('102')),
                  const SizedBox(height: 10),
                  _sosButton(
                      'Tourist Police',
                      '1144',
                      Icons.support_agent_outlined,
                      const Color(0xFF006B5F),
                      () => _dialEmergency('1144')),
                  const SizedBox(height: 10),
                  _sosButton('Send GPS SMS', null, Icons.sms_outlined,
                      const Color(0xFFFF8A00), _sendSosSms),
                  const SizedBox(height: 10),
                  _sosButton(
                    _sirenPlaying ? 'Stop Siren' : 'Activate Siren',
                    null,
                    _sirenPlaying
                        ? Icons.volume_off_rounded
                        : Icons.campaign_rounded,
                    _sirenPlaying
                        ? const Color(0xFF3F4844)
                        : const Color(0xFF7D2E00),
                    _toggleSiren,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _showSos = false),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sosButton(
      String text, String? number, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (number != null)
              Text(number,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
