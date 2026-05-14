import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trail.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class HomeScreen extends StatefulWidget {
  final List<Trail> hikes;
  final Set<String> favoriteIds;
  final bool showOnlyFavorites;
  final int unreadNotificationCount;
  final String userName;
  final bool isLoading;
  final Future<void> Function(String trailId) onToggleFavorite;
  final void Function(Trail) onTrailClick;
  final VoidCallback onAddClick;
  final VoidCallback onNotificationClick;

  const HomeScreen({
    super.key,
    required this.hikes,
    required this.favoriteIds,
    required this.showOnlyFavorites,
    required this.unreadNotificationCount,
    required this.userName,
    required this.isLoading,
    required this.onToggleFavorite,
    required this.onTrailClick,
    required this.onAddClick,
    required this.onNotificationClick,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isMapView = false;
  Trail? _selectedMapTrail;
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  bool _showSos = false;
  bool _sirenPlaying = false;
  AudioPlayer? _sirenPlayer;

  static const _categoryImages = {
    'All':
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',
    'Easy':
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',
    'Moderate':
        'https://images.unsplash.com/photo-1517400508447-f8dd518b86db?w=900',
    'Hard':
        'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=900',
  };

  @override
  void dispose() {
    _sirenPlayer?.dispose();
    super.dispose();
  }

  List<Trail> get _filteredHikes {
    return widget.hikes.where((t) {
      if (widget.showOnlyFavorites && !widget.favoriteIds.contains(t.id)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!t.name.toLowerCase().contains(q) &&
            !t.transportRoute.toLowerCase().contains(q)) return false;
      }
      if (_selectedDifficulty != 'All' &&
          t.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Trail> get _featured {
    final sorted = [...widget.hikes];
    sorted.sort((a, b) {
      final ar = a.ratingScore > 0 ? a.ratingScore : a.userRating.toDouble();
      final br = b.ratingScore > 0 ? b.ratingScore : b.userRating.toDouble();
      return br.compareTo(ar);
    });
    return sorted.take(6).toList();
  }

  Future<void> _dialEmergency(String num) async {
    AppFeedback.warning();
    final uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _sendSosSms() async {
    AppFeedback.tap();
    final uri = Uri.parse(
        'sms:?body=${Uri.encodeComponent('SOS! I need help. Last known location: https://maps.google.com/?q=27.7172,85.3240')}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _toggleSiren() async {
    AppFeedback.warning();
    if (_sirenPlaying) {
      await _sirenPlayer?.stop();
      setState(() => _sirenPlaying = false);
      return;
    }
    _sirenPlayer ??= AudioPlayer();
    try {
      await _sirenPlayer!.setReleaseMode(ReleaseMode.loop);
      await _sirenPlayer!.play(AssetSource('siren.mp3'));
      setState(() => _sirenPlaying = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add assets/siren.mp3 to enable the siren.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _topBar(),
            Expanded(child: _buildBody()),
          ],
        ),
        if (!widget.showOnlyFavorites && !_isMapView)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                AppFeedback.tap();
                widget.onAddClick();
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Trail'),
            ),
          ),
        if (_showSos) _sosSheet(),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chrome,
        border: Border(bottom: BorderSide(color: AppColors.chromeBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: const Icon(Icons.terrain_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kathmandu Hiker',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
              ),
            ),
          ),
          if (!widget.showOnlyFavorites)
            _chromeIconButton(
              icon: _isMapView ? Icons.list_alt_rounded : Icons.map_outlined,
              onTap: () {
                AppFeedback.tap();
                setState(() => _isMapView = !_isMapView);
              },
            ),
          _chromeIconButton(
            icon: Icons.notifications_none_rounded,
            badge: widget.unreadNotificationCount,
            onTap: () {
              AppFeedback.tap();
              widget.onNotificationClick();
            },
          ),
          _chromeIconButton(
            icon: Icons.sos_rounded,
            tint: AppColors.error,
            onTap: () {
              AppFeedback.warning();
              setState(() => _showSos = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _chromeIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
    Color tint = AppColors.primary,
  }) {
    Widget child = Icon(icon, color: tint, size: 22);
    if (badge > 0) {
      child = Badge(
        label: Text('$badge'),
        backgroundColor: AppColors.error,
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
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_isMapView && !widget.showOnlyFavorites) {
      return _buildMapView(_filteredHikes);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile, AppSpacing.gutter, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(child: _searchField()),
        ),
        if (!widget.showOnlyFavorites && _searchQuery.isEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackMd, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(
              child: _sectionHeader('Quick Categories', trailing: null),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackSm, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(child: _quickCategories()),
          ),
          if (_featured.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                  AppSpacing.stackMd, AppSpacing.marginMobile, 0),
              sliver: SliverToBoxAdapter(child: _sectionHeader('Featured Trails')),
            ),
            SliverToBoxAdapter(child: _featuredScroller()),
          ],
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackMd, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(
            child: _sectionHeader(widget.showOnlyFavorites
                ? 'Your Saved Trails'
                : _selectedDifficulty == 'All'
                    ? 'All Trails'
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
                AppSpacing.stackSm, AppSpacing.marginMobile, 120),
            sliver: SliverList.separated(
              itemCount: _filteredHikes.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.gutter),
              itemBuilder: (_, i) => _trailCard(_filteredHikes[i]),
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title, style: AppText.headlineMd(AppColors.onSurface)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _quickCategories() {
    final tiles = ['All', 'Easy', 'Moderate', 'Hard'];
    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _categoryTile(tiles[0], height: double.infinity, large: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _categoryTile(tiles[1])),
                const SizedBox(height: 12),
                Expanded(child: _categoryTile(tiles[2])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(String label, {double? height, bool large = false}) {
    final selected = _selectedDifficulty == label;
    final image = _categoryImages[label]!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          AppFeedback.toggle();
          setState(() => _selectedDifficulty = label);
        },
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surfaceContainerHigh),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surfaceContainerHigh),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primaryFixed, width: 3),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Text(
                  label,
                  style: large
                      ? AppText.headlineMd(Colors.white)
                      : AppText.labelLg(Colors.white).copyWith(fontSize: 15),
                ),
              ),
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredScroller() {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.stackSm, AppSpacing.marginMobile, 4),
        itemCount: _featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gutter),
        itemBuilder: (_, i) => _featuredCard(_featured[i]),
      ),
    );
  }

  Widget _featuredCard(Trail trail) {
    final imageUrl = trail.imageUrls.isNotEmpty
        ? trail.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';
    final diff = difficultyColors(trail.difficulty);
    return SizedBox(
      width: 260,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            AppFeedback.tap();
            widget.onTrailClick(trail);
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
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            height: 140, color: AppColors.surfaceContainerHigh),
                        errorWidget: (_, __, ___) => Container(
                            height: 140, color: AppColors.surfaceContainerHigh),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: diff.bg,
                          borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Text(
                          trail.difficulty.toUpperCase(),
                          style: AppText.labelSm(diff.fg)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trail.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyLg(AppColors.onSurface)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 16, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            trail.duration.isEmpty ? 'Day Trip' : trail.duration,
                            style: AppText.labelSm(AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.terrain_rounded,
                              size: 16, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            trail.transportRoute.isEmpty
                                ? 'Trail route'
                                : trail.transportRoute,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelSm(AppColors.onSurfaceVariant),
                          ),
                        ],
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

  Widget _trailCard(Trail trail) {
    final isFav = widget.favoriteIds.contains(trail.id);
    final rating = trail.ratingScore > 0 ? trail.ratingScore : trail.userRating.toDouble();
    final imageUrl = trail.imageUrls.isNotEmpty
        ? trail.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';
    final diff = difficultyColors(trail.difficulty);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          AppFeedback.tap();
          widget.onTrailClick(trail);
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
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(
                          height: 180, color: AppColors.surfaceContainerHigh),
                      errorWidget: (_, __, ___) => Container(
                          height: 180, color: AppColors.surfaceContainerHigh),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: diff.bg,
                        borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: Text(
                        trail.difficulty.toUpperCase(),
                        style: AppText.labelSm(diff.fg).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          color: isFav ? AppColors.primary : AppColors.onSurfaceVariant,
                        ),
                        onPressed: () {
                          AppFeedback.toggle();
                          widget.onToggleFavorite(trail.id);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trail.name,
                            style: AppText.bodyLg(AppColors.onSurface)
                                .copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rating > 0) ...[
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFB300), size: 18),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppText.labelLg(AppColors.onSurface),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _metaPill(
                            Icons.location_on_outlined,
                            trail.transportRoute.isEmpty
                                ? 'Kathmandu'
                                : trail.transportRoute),
                        const SizedBox(width: 8),
                        _metaPill(Icons.payments_outlined,
                            trail.fare.isEmpty ? 'Free' : trail.fare),
                      ],
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

  Widget _metaPill(IconData icon, String text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AppText.labelSm(AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.terrain_rounded,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedDifficulty != 'All'
                  ? 'No trails match your search.'
                  : widget.showOnlyFavorites
                      ? 'No saved trails yet.\nStart exploring!'
                      : 'No trails found.',
              textAlign: TextAlign.center,
              style: AppText.bodyMd(AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(List<Trail> hikes) {
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
        if (_selectedMapTrail != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              elevation: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  AppFeedback.tap();
                  widget.onTrailClick(_selectedMapTrail!);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        child: CachedNetworkImage(
                          imageUrl: _selectedMapTrail!.imageUrls.isNotEmpty
                              ? _selectedMapTrail!.imageUrls[0]
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
                            Text(_selectedMapTrail!.name,
                                style: AppText.labelLg(AppColors.onSurface)),
                            Text('Difficulty: ${_selectedMapTrail!.difficulty}',
                                style: AppText.labelSm(AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary),
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
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSos = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppRadius.base),
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error),
                      ),
                      const SizedBox(width: 10),
                      Text('Emergency SOS',
                          style: AppText.headlineMd(AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use these lifelines only in a real emergency. They will use your phone\'s native services.',
                    style: AppText.bodyMd(AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _sosButton('Call Police', '100', Icons.local_police_outlined,
                      const Color(0xFFB3261E), () => _dialEmergency('100')),
                  const SizedBox(height: 10),
                  _sosButton('Call Ambulance', '102', Icons.local_hospital_outlined,
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
                    _sirenPlaying ? Icons.volume_off_rounded : Icons.campaign_rounded,
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
