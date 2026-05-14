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

  final _difficulties = const ['All', 'Easy', 'Moderate', 'Hard', 'Challenging'];
  final _quotes = const [
    '"Leave the road, take the trails." 🌲',
    '"Hike more, worry less." 🎒',
    '"The mountains are calling." 🏔️',
    '"Adventure awaits on the trail." 🗺️',
    '"Nature is not a place to visit, it is home." 🌿',
    '"Every mountain top is within reach." ⛰️',
  ];

  @override
  void dispose() {
    _sirenPlayer?.dispose();
    super.dispose();
  }

  String get _quote => _quotes[DateTime.now().hour % _quotes.length];

  List<Trail> get _displayHikes {
    return widget.hikes.where((t) {
      if (widget.showOnlyFavorites && !widget.favoriteIds.contains(t.id)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!t.name.toLowerCase().contains(q) &&
            !t.transportRoute.toLowerCase().contains(q)) return false;
      }
      if (_selectedDifficulty != 'All' &&
          t.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) return false;
      return true;
    }).toList();
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
      // Bundled siren asset; falls back gracefully if missing.
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
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.showOnlyFavorites
                              ? '❤️ Explore'
                              : '👋 Hello, ${widget.userName}',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                        Text(
                          widget.showOnlyFavorites ? 'My Favorite Trails' : _quote,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!widget.showOnlyFavorites)
                    IconButton(
                      onPressed: () {
                        AppFeedback.tap();
                        setState(() => _isMapView = !_isMapView);
                      },
                      icon: Icon(_isMapView ? Icons.list : Icons.map, color: colors.primary),
                    ),
                  IconButton(
                    onPressed: () {
                      AppFeedback.tap();
                      widget.onNotificationClick();
                    },
                    icon: widget.unreadNotificationCount > 0
                        ? Badge(
                            label: Text('${widget.unreadNotificationCount}'),
                            child: Icon(Icons.notifications, color: colors.primary),
                          )
                        : Icon(Icons.notifications, color: colors.primary),
                  ),
                  IconButton(
                    onPressed: () {
                      AppFeedback.warning();
                      setState(() => _showSos = true);
                    },
                    icon: const Text('🚨', style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
            ),

            // Search + filter chips
            if (!widget.showOnlyFavorites) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: '🔎 Search trails or locations...',
                    prefixIcon: Icon(Icons.search, color: colors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _difficulties.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _difficulties[i];
                    final sel = _selectedDifficulty == d;
                    return ChoiceChip(
                      label: Text(d),
                      selected: sel,
                      onSelected: (_) {
                        AppFeedback.toggle();
                        setState(() => _selectedDifficulty = d);
                      },
                      selectedColor: colors.primary,
                      labelStyle: TextStyle(
                        color: sel ? colors.onPrimary : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ],

            // List
            Expanded(child: _buildBody()),
          ],
        ),

        // FAB
        if (!widget.showOnlyFavorites && !_isMapView)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                AppFeedback.tap();
                widget.onAddClick();
              },
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),

        // SOS sheet
        if (_showSos) _sosSheet(colors),
      ],
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).colorScheme;
    if (widget.isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    final hikes = _displayHikes;
    if (hikes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.showOnlyFavorites ? '💔' : '🌲', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedDifficulty != 'All'
                  ? 'No trails match your search.'
                  : widget.showOnlyFavorites
                      ? 'No favorites yet. Start exploring!'
                      : 'No trails found.',
              style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_isMapView && !widget.showOnlyFavorites) {
      return _buildMapView(hikes);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: hikes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _trailCard(hikes[i]),
    );
  }

  Widget _trailCard(Trail trail) {
    final colors = Theme.of(context).colorScheme;
    final isFav = widget.favoriteIds.contains(trail.id);
    final rating = trail.ratingScore > 0 ? trail.ratingScore : trail.userRating.toDouble();
    final imageUrl = trail.imageUrls.isNotEmpty
        ? trail.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AppFeedback.tap();
          widget.onTrailClick(trail);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(height: 180, color: AppColors.surfaceVariant),
                    errorWidget: (_, __, ___) =>
                        Container(height: 180, color: AppColors.surfaceVariant),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? colors.tertiary : colors.onSurfaceVariant,
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
                      const Text('📍', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trail.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.star, color: Color(0xFFFFB300), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('🥾 Difficulty: ${trail.difficulty}',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('💰 Estimated Cost: ${trail.fare}',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(List<Trail> hikes) {
    final colors = Theme.of(context).colorScheme;
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
          initialCameraPosition: const CameraPosition(target: LatLng(27.7172, 85.3240), zoom: 10.5),
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
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              elevation: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  AppFeedback.tap();
                  widget.onTrailClick(_selectedMapTrail!);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
                            Text('📍 ${_selectedMapTrail!.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('🥾 ${_selectedMapTrail!.difficulty}',
                                style: TextStyle(
                                    color: colors.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sosSheet(ColorScheme colors) {
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
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '🚨 Emergency SOS',
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Use these lifelines only in a real emergency. They will use your phone\'s native services.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _sosButton('🚓 Call Police (100)', const Color(0xFFB3261E), () => _dialEmergency('100')),
                  const SizedBox(height: 10),
                  _sosButton('🚑 Call Ambulance (102)', const Color(0xFF005DBA), () => _dialEmergency('102')),
                  const SizedBox(height: 10),
                  _sosButton('👮 Call Tourist Police (1144)', const Color(0xFF006B5F), () => _dialEmergency('1144')),
                  const SizedBox(height: 10),
                  _sosButton('📲 Send GPS SMS', const Color(0xFFFF8A00), _sendSosSms),
                  const SizedBox(height: 10),
                  _sosButton(
                    _sirenPlaying ? '🔇 Stop Siren' : '📢 Activate Loud Siren',
                    _sirenPlaying ? const Color(0xFF3F4844) : const Color(0xFF7D2E00),
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

  Widget _sosButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
