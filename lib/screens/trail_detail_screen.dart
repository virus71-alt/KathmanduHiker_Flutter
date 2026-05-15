import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/hike_event.dart';
import '../models/trail.dart';
import '../models/trail_photo.dart';
import '../models/trail_review.dart';
import '../models/weather_response.dart';
import '../services/hike_tracking_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/image_utils.dart';
import '../utils/ranking_manager.dart';
import 'create_event_bottom_sheet.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPic;
  final List<String> myFriends;
  final List<String> mySentRequests;
  final bool isFavorite;
  final VoidCallback onBack;
  final Future<void> Function(String authorId) onSendFriendRequest;
  final Future<void> Function(String authorId) onCancelFriendRequest;
  final Future<void> Function()? onToggleFavorite;

  const TrailDetailScreen({
    super.key,
    required this.trail,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPic,
    required this.myFriends,
    required this.mySentRequests,
    required this.onBack,
    required this.onSendFriendRequest,
    required this.onCancelFriendRequest,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  // Live data
  List<TrailReview> _reviews = [];
  List<HikeEvent> _events = [];
  List<TrailPhoto> _gallery = [];
  double? _lastHikeKm;
  WeatherResponse? _weather;

  // Review form
  final _reviewCtl = TextEditingController();
  double _newRating = 4.0;
  bool _submittingReview = false;
  bool _uploadingPhoto = false;

  // Hike tracking
  bool _tracking = false;
  double _distance = 0;
  String? _activeTrailId;
  double _finishedDistance = 0;

  // Subscriptions
  final _subs = <StreamSubscription>[];

  // Page controller for image carousel
  final _imageCtl = PageController();
  int _imagePage = 0;

  List<String> get _images => widget.trail.imageUrls.isNotEmpty
      ? widget.trail.imageUrls
      : const ['https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'];

  @override
  void initState() {
    super.initState();
    _wireFirestore();
    _wireTracking();
    _loadWeather();
  }

  void _wireFirestore() {
    _subs.add(
      _db
          .collection('hikes')
          .where('trailId', isEqualTo: widget.trail.id)
          .where('userId', isEqualTo: widget.currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() {
          _lastHikeKm = s.docs.isEmpty
              ? null
              : (s.docs.first['distanceKm'] as num?)?.toDouble();
        });
      }),
    );

    _subs.add(
      _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() => _reviews = s.docs.map(TrailReview.fromDoc).toList());
      }),
    );

    _subs.add(
      _db
          .collection('events')
          .where('trailId', isEqualTo: widget.trail.id)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() => _events = s.docs.map(HikeEvent.fromDoc).toList());
      }),
    );

    _subs.add(
      _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('gallery')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() => _gallery = s.docs.map(TrailPhoto.fromDoc).toList());
      }),
    );
  }

  void _wireTracking() {
    final t = HikeTrackingService.instance;
    _tracking = t.currentlyTracking;
    _distance = t.currentDistance;
    _activeTrailId = t.currentTrailId;
    _subs.add(t.isTracking.listen((v) => mounted ? setState(() => _tracking = v) : null));
    _subs.add(t.distanceTraveled.listen((d) => mounted ? setState(() => _distance = d) : null));
    _subs.add(t.activeTrailId.listen((id) => mounted ? setState(() => _activeTrailId = id) : null));
  }

  Future<void> _loadWeather() async {
    final w = await WeatherService.getWeather(widget.trail.name);
    if (mounted) setState(() => _weather = w);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _reviewCtl.dispose();
    _imageCtl.dispose();
    super.dispose();
  }

  Future<void> _startHike() async {
    AppFeedback.success();
    final ok = await HikeTrackingService.instance.start(widget.trail.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location to track your hike.')),
      );
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hike tracking started.')),
      );
    }
  }

  Future<void> _confirmEndHike() async {
    AppFeedback.warning();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Hike?'),
        content: const Text('Do you want to stop tracking and calculate your XP?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finish')),
        ],
      ),
    );
    if (go != true) return;

    final finalDistance = await HikeTrackingService.instance.stop();
    setState(() => _finishedDistance = finalDistance);
    final km = finalDistance / 1000.0;
    int xp = 0;
    String status;
    if (km >= 0.7) {
      xp = widget.trail.difficulty.toLowerCase() == 'easy'
          ? RankingManager.xpEasyHike
          : RankingManager.xpStandardHike;
      status = 'Hike Completed!';
      await _db.collection('hikes').add({
        'userId': widget.currentUserId,
        'trailId': widget.trail.id,
        'distanceKm': km,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _db
          .collection('users')
          .doc(widget.currentUserId)
          .update({'totalXP': FieldValue.increment(xp)});
    } else {
      status = 'Hike too short';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(status),
        content: Text('You walked ${km.toStringAsFixed(3)} km and earned +$xp XP.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _sharePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    AppFeedback.tap();
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await ImageUtils.compress(File(picked.path));
      final ref = _storage
          .ref()
          .child('gallery/${widget.trail.id}/${const Uuid().v4()}.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('gallery')
          .add({
        'userId': widget.currentUserId,
        'userName': widget.currentUserName,
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (widget.currentUserId.isNotEmpty) {
        await _db
            .collection('users')
            .doc(widget.currentUserId)
            .update({
          'totalXP':
              FieldValue.increment(RankingManager.xpCommunityPhoto)
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _postReview() async {
    if (_reviewCtl.text.trim().isEmpty) return;
    // Defensive guard: even if the composer is somehow visible, refuse to
    // write a second review for the same user.
    if (_myExistingReview() != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'You already reviewed this trail. Edit or delete your existing review first.')),
        );
      }
      return;
    }
    AppFeedback.success();
    setState(() => _submittingReview = true);
    await _db.collection('trails').doc(widget.trail.id).collection('reviews').add({
      'userId': widget.currentUserId,
      'userName': widget.currentUserName,
      'rating': _newRating,
      'comment': _reviewCtl.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _db
        .collection('users')
        .doc(widget.currentUserId)
        .update({'totalXP': FieldValue.increment(RankingManager.xpReview)});
    await _recalculateTrailRating();
    if (!mounted) return;
    _reviewCtl.clear();
    setState(() => _submittingReview = false);
  }

  // Recalculates the trail's aggregate rating from the author's seed rating
  // (set on AddTrail) + every review currently in `trails/{id}/reviews`, and
  // writes it back to the trail doc so the Home grid and the hero rating
  // chip stay in sync with what's actually being said.
  //
  // Score = average of (seed, review1, review2, ...) where seed is the
  // ratingScore the trail was created with. This means the very first hike
  // already shows a number, and subsequent reviews pull it toward the
  // collective opinion instead of being overwritten by whichever review
  // happened to be posted last.
  Future<void> _recalculateTrailRating() async {
    try {
      final snap = await _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('reviews')
          .get();
      final reviewRatings = snap.docs
          .map((d) => ((d.data()['rating'] ?? 0) as num).toDouble())
          .where((v) => v > 0)
          .toList();
      // Seed = the rating the trail author gave on AddTrail. We only fold it
      // in when no reviews exist yet (so a single user-given rating still
      // shows), otherwise the community average takes over.
      final seed = widget.trail.ratingScore > 0
          ? widget.trail.ratingScore
          : widget.trail.userRating.toDouble();
      final all = reviewRatings.isEmpty
          ? [if (seed > 0) seed]
          : reviewRatings;
      if (all.isEmpty) return;
      final avg = all.reduce((a, b) => a + b) / all.length;
      final rounded = avg.round().clamp(1, 5);
      await _db.collection('trails').doc(widget.trail.id).update({
        'ratingScore': double.parse(avg.toStringAsFixed(2)),
        'userRating': rounded,
      });
    } catch (_) {
      // Non-fatal — the next post/edit will try again.
    }
  }

  Future<void> _editReview(TrailReview r) async {
    AppFeedback.tap();
    final textCtl = TextEditingController(text: r.comment);
    double rating = r.rating;
    final saved = await showModalBottomSheet<bool>(
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
                Text('Edit your review',
                    style: AppText.headlineMd(scheme.onSurface)),
                const SizedBox(height: 12),
                Row(children: [
                  _stars(rating, 26),
                  const SizedBox(width: 8),
                  Text('${rating.toStringAsFixed(1)} / 5',
                      style: AppText.labelLg(scheme.primary)),
                ]),
                Slider(
                  value: rating,
                  min: 1,
                  max: 5,
                  divisions: 40,
                  activeColor: scheme.primary,
                  onChanged: (v) => setSheet(
                      () => rating = (v * 10).roundToDouble() / 10),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: textCtl,
                  minLines: 3,
                  maxLines: 6,
                  decoration:
                      const InputDecoration(hintText: 'Update your review…'),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      child: const Text('Save'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
    if (saved == true) {
      AppFeedback.success();
      await _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('reviews')
          .doc(r.id)
          .update({
        'rating': rating,
        'comment': textCtl.text.trim(),
        'editedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _recalculateTrailRating();
    }
    textCtl.dispose();
  }

  Future<void> _deleteReview(TrailReview r) async {
    AppFeedback.warning();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go == true) {
      await _db
          .collection('trails')
          .doc(widget.trail.id)
          .collection('reviews')
          .doc(r.id)
          .delete();
      await _recalculateTrailRating();
    }
  }

  /// Opens a swipeable, pinch-zoomable fullscreen viewer for the given image
  /// URLs, starting at [initialIndex]. Used for the hero carousel and the
  /// community gallery.
  void _openPhotoViewer(List<String> urls, int initialIndex) {
    if (urls.isEmpty) return;
    AppFeedback.tap();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) =>
            _PhotoViewerPage(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _openCreateEvent() async {
    AppFeedback.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => CreateEventBottomSheet(
        trailName: widget.trail.name,
        onCreate: (date, max) async {
          final eventData = {
            'trailId': widget.trail.id,
            'trailName': widget.trail.name,
            'creatorId': widget.currentUserId,
            'creatorName': widget.currentUserName,
            'dateText': date,
            'maxHikers': max,
            'attendees': [widget.currentUserId],
            'attendeeDetails': [
              {
                'id': widget.currentUserId,
                'name': widget.currentUserName,
                'phone': 'Organizer',
                'bloodGroup': 'N/A',
              },
            ],
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          final ref = await _db.collection('events').add(eventData);
          for (final friendId
              in widget.myFriends.where((f) => f != widget.currentUserId)) {
            await _db
                .collection('users')
                .doc(friendId)
                .collection('notifications')
                .add({
              'message':
                  '${widget.currentUserName} planned a hike to ${widget.trail.name} on $date.',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'isRead': false,
              'type': 'community_event',
              'trailId': widget.trail.id,
              'eventId': ref.id,
            });
          }
          await _db
              .collection('users')
              .doc(widget.currentUserId)
              .update({'totalXP': FieldValue.increment(RankingManager.xpHostHike)});
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  Future<void> _joinEvent(HikeEvent event) async {
    AppFeedback.tap();
    final nameCtl = TextEditingController(text: widget.currentUserName);
    final phoneCtl = TextEditingController();
    final bloodCtl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Hike'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(
                controller: phoneCtl,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: bloodCtl,
                decoration: const InputDecoration(labelText: 'Blood Group (e.g. O+)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (go != true || phoneCtl.text.isEmpty || bloodCtl.text.isEmpty) return;
    await _db.collection('events').doc(event.id).update({
      'attendees': FieldValue.arrayUnion([widget.currentUserId]),
      'attendeeDetails': FieldValue.arrayUnion([
        {
          'id': widget.currentUserId,
          'name': nameCtl.text,
          'phone': phoneCtl.text,
          'bloodGroup': bloodCtl.text,
        }
      ]),
    });
  }

  Future<void> _leaveEvent(HikeEvent event) async {
    AppFeedback.warning();
    final my = event.attendeeDetails.firstWhere(
      (d) => d['id'] == widget.currentUserId,
      orElse: () => const {},
    );
    if (my.isEmpty) return;
    await _db.collection('events').doc(event.id).update({
      'attendees': FieldValue.arrayRemove([widget.currentUserId]),
      'attendeeDetails': FieldValue.arrayRemove([my]),
    });
  }

  Future<void> _shareTrail() async {
    AppFeedback.tap();
    final body =
        'Check out ${widget.trail.name} on Kathmandu Hiker!';
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body)),
      );
    }
  }

  Future<void> _openMaps() async {
    AppFeedback.tap();
    final hasCoords =
        widget.trail.latitude != 0 || widget.trail.longitude != 0;
    final coordPair = hasCoords
        ? '${widget.trail.latitude},${widget.trail.longitude}'
        : null;
    final queryLabel = Uri.encodeComponent(
        widget.trail.name.isEmpty ? 'Kathmandu' : widget.trail.name);
    final webDestination = coordPair ?? '$queryLabel,Kathmandu';

    // Try, in order, the most specific Google Maps app intent → the generic
    // Android geo intent → the universal https URL. Each falls through if the
    // previous one cannot be launched. `mode: externalApplication` is critical
    // on Android — without it the system picks a webview and the chooser
    // never appears.
    final attempts = <Uri>[
      if (Platform.isAndroid && coordPair != null)
        Uri.parse('google.navigation:q=$coordPair&mode=w'),
      if (Platform.isAndroid)
        Uri.parse(coordPair != null
            ? 'geo:$coordPair?q=$coordPair($queryLabel)'
            : 'geo:0,0?q=$queryLabel'),
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$webDestination&travelmode=walking'),
    ];

    for (final uri in attempts) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri,
              mode: LaunchMode.externalApplication);
          if (ok) return;
        }
      } catch (_) {
        // Try the next strategy.
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not open Google Maps. Install Google Maps and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.trail.ratingScore > 0
        ? widget.trail.ratingScore
        : widget.trail.userRating.toDouble();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero with overlaid title + badges. Fixed height keeps the layout
          // predictable so the stats card can overlap cleanly below.
          SizedBox(
            height: 360,
            child: _heroSection(rating),
          ),
          // Floating stats card overlapping the hero by 28px — matches the
          // `-mt-8` pattern from the reference HTML. Wrapped in a Stack so
          // the overlap doesn't push the rest of the page upward.
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile),
              child: _quickStatsBar(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              0,
              AppSpacing.marginMobile,
              AppSpacing.stackLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _actionRow(),
                const SizedBox(height: AppSpacing.stackLg),
                // Trail Details — 2-col grid
                _sectionTitle(Icons.info_outline_rounded, 'Trail Details'),
                const SizedBox(height: AppSpacing.stackSm),
                _detailsCard(),
                // Shared Experiences (only shows if the trail description
                // has structured experience info).
                if (_hasExperience()) ...[
                  const SizedBox(height: AppSpacing.stackLg),
                  _sectionTitle(Icons.groups_rounded, 'Shared Experiences'),
                  const SizedBox(height: AppSpacing.stackSm),
                  _sharedExperiencesCard(),
                ],
                const SizedBox(height: AppSpacing.stackLg),
                _sectionTitle(
                    Icons.directions_bus_rounded, 'How to Get There'),
                const SizedBox(height: AppSpacing.stackSm),
                _howToGetThereCard(),
                if (_weather != null) ...[
                  const SizedBox(height: AppSpacing.stackMd),
                  _weatherCard(),
                ],
                const SizedBox(height: AppSpacing.stackMd),
                _secondaryActionGrid(),
                const SizedBox(height: AppSpacing.stackLg),
                _hikeTrackingCard(),
                const SizedBox(height: AppSpacing.stackLg),
                _sectionTitle(Icons.photo_library_outlined, 'Photos'),
                const SizedBox(height: AppSpacing.stackSm),
                _galleryCard(),
                const SizedBox(height: AppSpacing.stackLg),
                _discoveredByCard(),
                if (_events.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.stackLg),
                  _sectionTitle(Icons.event_rounded, 'Upcoming Group Hikes'),
                  const SizedBox(height: AppSpacing.stackSm),
                  for (final e in _events) _eventCard(e),
                ],
                const SizedBox(height: AppSpacing.stackLg),
                // Reviews header with rating count on the right — matches the
                // HTML reference's "Hiker Reviews · 4.8 (124)" pattern.
                _reviewsHeader(rating),
                const SizedBox(height: AppSpacing.stackSm),
                // Only show the composer if the user hasn't posted a review on
                // this trail yet. If they already did, show a hint card that
                // points them to their existing review (which has Edit /
                // Delete via the kebab menu).
                if (_myExistingReview() == null)
                  _reviewForm()
                else
                  _alreadyReviewedHint(),
                const SizedBox(height: 12),
                for (final r in _reviews) _reviewItem(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero with carousel + overlay ───────────────────────────────────────
  Widget _heroSection(double rating) {
    final diff = difficultyColors(context, widget.trail.difficulty);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imageCtl,
          onPageChanged: (i) => setState(() => _imagePage = i),
          itemCount: _images.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openPhotoViewer(_images, i),
            child: Hero(
              tag: 'trail-hero-${widget.trail.id}-$i',
              child: CachedNetworkImage(
                imageUrl: _images[i],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh),
                errorWidget: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.80),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: _heroIconButton(Icons.arrow_back_rounded, () {
            AppFeedback.tap();
            widget.onBack();
          }),
        ),
        if (_images.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_imagePage + 1}/${_images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        if (_images.length > 1)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _images.length.clamp(0, 8),
                  (i) {
                    final selected = i == _imagePage.clamp(0, 7);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        Positioned(
          left: AppSpacing.marginMobile,
          right: AppSpacing.marginMobile,
          // 44px leaves enough room for the stats-card overlap below without
          // squeezing the gradient against the title.
          bottom: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: diff.bg,
                      borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Text(
                      widget.trail.difficulty.toUpperCase(),
                      style: AppText.labelSm(diff.fg)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.trail.transportRoute.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          widget.trail.transportRoute,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.trail.name,
                style: AppText.headlineLg(Colors.white)
                    .copyWith(fontSize: 26, height: 1.15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (rating > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stars(rating, 16),
                    const SizedBox(width: 6),
                    Text(
                      '${rating.toStringAsFixed(1)} • ${_reviews.length} reviews',
                      style: AppText.labelSm(Colors.white.withOpacity(0.92)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // ─── Quick stats floating bar ───────────────────────────────────────────
  // Matches the reference HTML's 3-col `divide-x` info bar that overlaps the
  // hero by -mt-8.
  Widget _quickStatsBar() {
    final scheme = Theme.of(context).colorScheme;
    final duration = _shortDuration(widget.trail.duration);
    final fare = _shortFare(widget.trail.fare);
    final mode =
        widget.trail.travelMode.isEmpty ? 'Trek' : widget.trail.travelMode;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: _statColumn(Icons.timer_outlined, duration, 'Duration')),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            Expanded(
                child: _statColumn(Icons.payments_outlined, fare, 'Est. Cost')),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            Expanded(
                child: _statColumn(
                    Icons.directions_walk_rounded, mode, 'Mode')),
          ],
        ),
      ),
    );
  }

  // "1-2 Hours" → "1-2 hrs", "5 Hour" → "5 hr". Keeps non-standard text intact
  // so any custom value the user typed in still renders.
  String _shortDuration(String s) {
    if (s.trim().isEmpty) return '—';
    return s
        .replaceAll(RegExp(r'\bHours\b', caseSensitive: false), 'hrs')
        .replaceAll(RegExp(r'\bHour\b', caseSensitive: false), 'hr')
        .replaceAll(RegExp(r'\bMinutes\b', caseSensitive: false), 'min')
        .replaceAll(RegExp(r'\bMinute\b', caseSensitive: false), 'min')
        .trim();
  }

  // Maps the AddTrail cost dropdown values (legacy + new) to compact pill text
  // so the floating stats card never truncates ("Under Rs....." case).
  String _shortFare(String s) {
    if (s.isEmpty) return 'Free';
    switch (s) {
      case 'Under Rs.500':
      case '< Rs.500':
        return '<Rs500';
      case 'Rs.500-1500':
      case 'Rs.500-1.5k':
        return 'Rs500–1.5k';
      case 'Rs.1500-3000':
      case 'Rs.1.5k-3k':
        return 'Rs1.5–3k';
      case 'Expensive':
      case 'Premium':
        return 'Premium';
      default:
        return s;
    }
  }

  Widget _statColumn(IconData icon, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.headlineMd(scheme.onSurface)
                .copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppText.labelSm(scheme.onSurfaceVariant)
                  .copyWith(letterSpacing: 0.6)),
        ],
      ),
    );
  }

  // ─── Primary actions ─────────────────────────────────────────────────────
  // Mirrors the HTML reference: a wide primary "Start Navigation" CTA next to
  // a compact filled bookmark icon button.
  Widget _actionRow() {
    final scheme = Theme.of(context).colorScheme;
    final fav = widget.isFavorite;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _openMaps,
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text('Start Navigation'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 1.5,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: fav ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: widget.onToggleFavorite == null
                ? null
                : () {
                    AppFeedback.toggle();
                    widget.onToggleFavorite!();
                  },
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: fav ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Icon(
                fav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: fav ? scheme.onPrimary : scheme.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: AppText.headlineMd(Theme.of(context).colorScheme.onSurface)
                  .copyWith(fontSize: 20)),
        ),
      ],
    );
  }

  // ─── Hike tracking card ─────────────────────────────────────────────────
  Widget _hikeTrackingCard() {
    final scheme = Theme.of(context).colorScheme;
    final activeHere = _tracking && _activeTrailId == widget.trail.id;
    final km = activeHere ? _distance / 1000.0 : _finishedDistance / 1000.0;
    final showKm = activeHere || _finishedDistance > 0;

    final title = activeHere
        ? 'Hike in Progress'
        : _finishedDistance > 0
            ? 'Last Tracked Hike'
            : 'Track Your Hike';
    final subtitle = activeHere
        ? 'Live GPS distance — vehicle motion is filtered out.'
        : _finishedDistance > 0
            ? 'Tap reset to start fresh.'
            : 'Earn XP for trekking the trail on foot.';

    return Container(
      decoration: topoCardDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activeHere
                      ? scheme.tertiary.withValues(alpha: 0.18)
                      : scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  activeHere
                      ? Icons.gps_fixed_rounded
                      : Icons.directions_walk_rounded,
                  color: activeHere ? scheme.tertiary : scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.labelLg(scheme.onSurface)
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.labelSm(scheme.onSurfaceVariant)
                          .copyWith(height: 1.35),
                    ),
                    if (_lastHikeKm != null && !showKm) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Previous best: ${_lastHikeKm!.toStringAsFixed(2)} km',
                        style: AppText.labelSm(scheme.primary)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              if (showKm)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${km.toStringAsFixed(2)} km',
                    style: AppText.headlineMd(scheme.primary)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: activeHere
                    ? scheme.error
                    : _finishedDistance > 0
                        ? scheme.surfaceContainerHigh
                        : scheme.primary,
                foregroundColor: activeHere
                    ? scheme.onError
                    : _finishedDistance > 0
                        ? scheme.onSurface
                        : scheme.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: Icon(activeHere
                  ? Icons.flag_rounded
                  : _finishedDistance > 0
                      ? Icons.refresh_rounded
                      : Icons.play_arrow_rounded),
              onPressed: () {
                if (activeHere) {
                  _confirmEndHike();
                } else if (_finishedDistance > 0) {
                  AppFeedback.tap();
                  setState(() => _finishedDistance = 0);
                } else {
                  _startHike();
                }
              },
              label: Text(
                activeHere
                    ? 'End Hike & Claim XP'
                    : _finishedDistance > 0
                        ? 'Reset progress'
                        : 'Start Hike',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact "Current Weather" pill — primary-container background, with the
  // temperature + short description right-aligned. Matches the HTML reference.
  Widget _weatherCard() {
    final scheme = Theme.of(context).colorScheme;
    final w = _weather!;
    final desc = w.description.isEmpty
        ? 'Now'
        : w.description.replaceFirstChar();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (w.icon.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CachedNetworkImage(
                imageUrl:
                    'https://openweathermap.org/img/wn/${w.icon}@2x.png',
                width: 36,
                height: 36,
              ),
            )
          else
            Icon(Icons.cloud_outlined,
                color: scheme.onPrimaryContainer, size: 24),
          const SizedBox(width: 10),
          // Left column: label + condition. Right: temperature. Both wrapped in
          // Flexible so neither side can overflow on long descriptions
          // ("Partly cloudy", "Heavy intensity rain", etc.).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Weather',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelSm(scheme.onPrimaryContainer)
                      .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd(scheme.onPrimaryContainer)
                      .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${w.temp.toInt()}°C',
            style: AppText.headlineMd(scheme.onPrimaryContainer)
                .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ─── Discovered by card ─────────────────────────────────────────────────
  Widget _discoveredByCard() {
    final friend = widget.myFriends.contains(widget.trail.authorId);
    final sent = widget.mySentRequests.contains(widget.trail.authorId);
    final selfAuthor = widget.trail.authorId == widget.currentUserId;
    final authorName =
        widget.trail.authorName.isEmpty ? 'Anonymous Hiker' : widget.trail.authorName;

    return Container(
      decoration: topoCardDecoration(context),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryFixed,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                style: AppText.labelLg(Theme.of(context).colorScheme.primary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DISCOVERED BY',
                    style: AppText.labelSm(Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(authorName,
                    style: AppText.labelLg(Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          if (!selfAuthor && widget.trail.authorId.isNotEmpty)
            OutlinedButton(
              onPressed: () {
                if (friend) return;
                if (sent) {
                  widget.onCancelFriendRequest(widget.trail.authorId);
                } else {
                  AppFeedback.success();
                  widget.onSendFriendRequest(widget.trail.authorId);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                backgroundColor: friend
                    ? AppColors.primaryFixed
                    : Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Text(
                friend ? 'Friends' : sent ? 'Cancel' : 'Add Friend',
                style: AppText.labelLg(Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ─── How to Get There rail ─────────────────────────────────────────────
  // Renders the actual transport data the trail's author entered on the
  // AddTrail flow:
  //   `transportRoute` → start point of the trail (e.g. "Sundarijal")
  //   `busAccess`      → bus pickup / boarding stop (only set for Bus mode)
  //   `fare`           → estimated cost bracket
  //   `travelMode`     → Bus / Car / Motorcycle / Cycle
  //
  // For Bus + busAccess → two-stop rail (board at busAccess → arrive at the
  // trail start point). For everything else → single-stop rail (drive/ride
  // directly to the trail start point).
  Widget _howToGetThereCard() {
    final scheme = Theme.of(context).colorScheme;
    final start =
        widget.trail.transportRoute.isEmpty ? 'Trailhead' : widget.trail.transportRoute;
    final mode = widget.trail.travelMode;
    final modeLabel = mode.isEmpty ? 'On foot' : mode;
    final fare = widget.trail.fare.isEmpty ? null : widget.trail.fare;
    final hasBus = mode.toLowerCase() == 'bus' && widget.trail.busAccess.isNotEmpty;

    // Each stop: (icon, title, subtitle, fareOrNote, isStartCircle).
    final stops = <({IconData icon, String title, String subtitle, String? note, bool start})>[];
    if (hasBus) {
      stops.add((
        icon: Icons.directions_bus_rounded,
        title: widget.trail.busAccess,
        subtitle: 'Board your bus / micro toward $start',
        note: fare != null ? 'Fare: $fare' : null,
        start: true,
      ));
      stops.add((
        icon: Icons.flag_rounded,
        title: start,
        subtitle: widget.trail.duration.isEmpty
            ? 'Trail entry and start of the hike'
            : 'Trail entry • ${widget.trail.duration}',
        note: null,
        start: false,
      ));
    } else {
      stops.add((
        icon: _travelModeIcon(mode),
        title: start,
        subtitle: 'Reach the trailhead by $modeLabel',
        note: fare != null ? 'Approx. cost: $fare' : null,
        start: true,
      ));
    }

    return Container(
      decoration: sunkenFieldDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail on the left. Single-stop rail just shows one dot.
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (stops.length > 1) ...[
                Container(width: 2, height: 56, color: scheme.outlineVariant),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(stops[i].icon,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stops[i].title,
                              style: AppText.labelLg(scheme.onSurface)
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stops[i].subtitle,
                              style: AppText.labelSm(scheme.onSurfaceVariant)
                                  .copyWith(height: 1.35),
                            ),
                            if (stops[i].note != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                stops[i].note!,
                                style: AppText.labelSm(scheme.primary)
                                    .copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (i < stops.length - 1) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _travelModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'cycle':
        return Icons.pedal_bike_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }

  // ─── Details card ───────────────────────────────────────────────────────
  // Mirrors the reference HTML's 2-col `gap-y-4` Trail Details grid inside a
  // sunken card. Each cell is a labelled value pair.
  Widget _detailsCard() {
    final scheme = Theme.of(context).colorScheme;
    final pairs = <({String label, String value})>[
      (
        label: 'Difficulty',
        value: widget.trail.difficulty.isEmpty ? '—' : widget.trail.difficulty,
      ),
      (
        label: 'Est Cost',
        value: widget.trail.fare.isEmpty ? 'Free' : widget.trail.fare,
      ),
      (
        label: 'Travel Mode',
        value:
            widget.trail.travelMode.isEmpty ? 'Trek' : widget.trail.travelMode,
      ),
      (
        label: 'From Bus',
        value: widget.trail.busAccess.isEmpty
            ? (widget.trail.transportRoute.isEmpty
                ? '—'
                : widget.trail.transportRoute)
            : widget.trail.busAccess,
      ),
      (
        label: 'Duration',
        value: widget.trail.duration.isEmpty ? '—' : widget.trail.duration,
      ),
      (
        label: 'Availability',
        value: 'Year-round',
      ),
    ];

    return Container(
      decoration: sunkenFieldDecoration(context),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final colWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final p in pairs)
                SizedBox(
                  width: colWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.label.toUpperCase(),
                        style: AppText.labelSm(scheme.onSurfaceVariant)
                            .copyWith(letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.value,
                        style: AppText.labelLg(scheme.onSurface)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─── Shared Experiences card ────────────────────────────────────────────
  // Parses the four shared-experience fields out of the trail description
  // (which the AddTrail flow stores as `🗓️ Best Season: ...\n👥 Crowd Level:
  // ...\n✨ Hidden Spots: ...\n⚠️ Difficult Parts: ...`) and renders each as a
  // labelled icon row matching the HTML reference.
  Widget _sharedExperiencesCard() {
    final scheme = Theme.of(context).colorScheme;
    final parsed = _parseExperience(widget.trail.description);

    final rows = <({IconData icon, String label, String value})>[
      if (parsed.seasons.isNotEmpty)
        (icon: Icons.calendar_month_rounded, label: 'Best Seasons', value: parsed.seasons),
      if (parsed.crowd.isNotEmpty)
        (icon: Icons.group_add_rounded, label: 'Crowd Level', value: parsed.crowd),
      if (parsed.hiddenSpots.isNotEmpty)
        (icon: Icons.visibility_off_rounded, label: 'Hidden Spot', value: parsed.hiddenSpots),
      if (parsed.difficultParts.isNotEmpty)
        (icon: Icons.warning_amber_rounded, label: 'Difficult Part', value: parsed.difficultParts),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(rows[i].icon, color: scheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].label,
                          style: AppText.labelSm(scheme.onSurfaceVariant)),
                      const SizedBox(height: 1),
                      Text(rows[i].value,
                          style: AppText.labelLg(scheme.onSurface)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            if (i < rows.length - 1) const SizedBox(height: 14),
          ],
          if (parsed.tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    parsed.tips,
                    style: AppText.bodyMd(scheme.onSurfaceVariant)
                        .copyWith(height: 1.45, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasExperience() {
    final p = _parseExperience(widget.trail.description);
    return p.seasons.isNotEmpty ||
        p.crowd.isNotEmpty ||
        p.hiddenSpots.isNotEmpty ||
        p.difficultParts.isNotEmpty ||
        p.tips.isNotEmpty;
  }

  // Reviews section header — left: icon + title, right: aggregate rating in
  // primary color (`4.8 (124)` style).
  Widget _reviewsHeader(double rating) {
    final scheme = Theme.of(context).colorScheme;
    final hasRating = rating > 0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Icon(Icons.reviews_outlined,
              size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Hiker Reviews',
            style: AppText.headlineMd(scheme.onSurface).copyWith(fontSize: 20),
          ),
        ),
        if (hasRating)
          Text(
            '${rating.toStringAsFixed(1)} (${_reviews.length})',
            style: AppText.labelLg(scheme.primary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
      ],
    );
  }

  ({String seasons, String crowd, String hiddenSpots, String difficultParts, String tips})
      _parseExperience(String description) {
    String pick(String prefix) {
      for (final raw in description.split('\n')) {
        final line = raw.trim();
        if (line.startsWith(prefix)) {
          final i = line.indexOf(':');
          if (i >= 0 && i + 1 < line.length) return line.substring(i + 1).trim();
        }
      }
      return '';
    }

    return (
      seasons: pick('🗓️ Best Season'),
      crowd: pick('👥 Crowd Level'),
      hiddenSpots: pick('✨ Hidden Spots'),
      difficultParts: pick('⚠️ Difficult Parts'),
      tips: pick('📝 Tips'),
    );
  }

  // ─── Gallery + share photo ──────────────────────────────────────────────
  Widget _galleryCard() {
    final scheme = Theme.of(context).colorScheme;
    final trailPhotos = widget.trail.imageUrls.where((u) => u.isNotEmpty).toList();
    final communityPhotos = _gallery.where((g) => g.url.isNotEmpty).toList();
    final allUrls = <String>[
      ...trailPhotos,
      ...communityPhotos.map((g) => g.url),
    ];
    final isEmpty = allUrls.isEmpty;

    return Container(
      decoration: topoCardDecoration(context),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Photos',
                        style: AppText.labelLg(scheme.onSurface)
                            .copyWith(fontWeight: FontWeight.w800)),
                    if (allUrls.isNotEmpty)
                      Text(
                        '${allUrls.length} photo${allUrls.length == 1 ? '' : 's'}'
                        '${communityPhotos.isNotEmpty ? ' • ${communityPhotos.length} from community' : ''}',
                        style: AppText.labelSm(scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 38),
                ),
                onPressed: _uploadingPhoto ? null : _sharePhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(_uploadingPhoto ? 'Uploading' : 'Share'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_outlined,
                      color: scheme.onSurfaceVariant, size: 28),
                  const SizedBox(height: 6),
                  Text('Be the first to share a photo',
                      style: AppText.labelSm(scheme.onSurfaceVariant)),
                ],
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final url = allUrls[i];
                  final isTrailPhoto = i < trailPhotos.length;
                  return GestureDetector(
                    onTap: () => _openPhotoViewer(allUrls, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.base),
                      child: Stack(
                        children: [
                          Hero(
                            tag: 'gallery-$url-$i',
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 120,
                                height: 120,
                                color: scheme.surfaceContainerHigh,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: scheme.surfaceContainerHigh,
                                child: Icon(Icons.broken_image_outlined,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          if (isTrailPhoto)
                            Positioned(
                              left: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'TRAIL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── Secondary actions: plan + share (Discussion removed) ───────────────
  Widget _secondaryActionGrid() {
    final iHost = _events.any((e) => e.creatorId == widget.currentUserId);
    return Row(
      children: [
        Expanded(
          child: _secondaryAction(
            Icons.event_available_rounded,
            iHost ? 'Planned' : 'Plan Hike',
            iHost ? null : _openCreateEvent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _secondaryAction(
              Icons.ios_share_rounded, 'Share', _shareTrail),
        ),
      ],
    );
  }

  Widget _secondaryAction(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label,
                  style: AppText.labelSm(
                          enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Group hike (event) card ────────────────────────────────────────────
  Widget _eventCard(HikeEvent event) {
    final isGoing = event.attendees.contains(widget.currentUserId);
    final isCreator = event.creatorId == widget.currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: topoCardDecoration(context),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.dateText,
                      style: AppText.labelLg(Theme.of(context).colorScheme.onSurface)),
                  Text(
                      'Hosted by ${event.creatorName} • ${event.attendees.length}/${event.maxHikers}',
                      style: AppText.labelSm(Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (isCreator)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () async {
                  AppFeedback.warning();
                  await _db.collection('events').doc(event.id).delete();
                },
                child: const Text('Cancel'),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isGoing ? Theme.of(context).colorScheme.surfaceContainerHigh : Theme.of(context).colorScheme.primary,
                  foregroundColor:
                      isGoing ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () => isGoing ? _leaveEvent(event) : _joinEvent(event),
                child: Text(isGoing ? 'Leave' : 'Join'),
              ),
          ],
        ),
      ),
    );
  }

  // Returns the current user's existing review on this trail, if any.
  // Used to suppress the review composer (one review per user per trail) and
  // surface an edit/delete hint instead.
  TrailReview? _myExistingReview() {
    for (final r in _reviews) {
      if (r.userId == widget.currentUserId) return r;
    }
    return null;
  }

  // Shown in place of the composer when the user has already posted a review
  // on this trail. The Edit / Delete actions live inside the review item's
  // kebab menu, so we just point the user there.
  Widget _alreadyReviewedHint() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'ve already reviewed this trail',
                  style: AppText.labelLg(scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap the ⋮ menu on your review below to edit or delete it.',
                  style: AppText.labelSm(scheme.onSurfaceVariant)
                      .copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Review form + items ────────────────────────────────────────────────
  Widget _reviewForm() {
    return Container(
      decoration: topoCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How was your hike?',
              style: AppText.labelLg(Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            _stars(_newRating, 26),
            const SizedBox(width: 8),
            Text('${_newRating.toStringAsFixed(1)} / 5',
                style: AppText.labelLg(Theme.of(context).colorScheme.primary)),
          ]),
          Slider(
            value: _newRating,
            min: 1,
            max: 5,
            divisions: 40,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (v) =>
                setState(() => _newRating = (v * 10).roundToDouble() / 10),
          ),
          Text(_ratingEmotion(_newRating),
              style: AppText.labelSm(Theme.of(context).colorScheme.tertiary)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewCtl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Share your tips. Was it crowded? Hidden spots?',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submittingReview ? null : _postReview,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Post review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(TrailReview r) {
    final scheme = Theme.of(context).colorScheme;
    final initials =
        r.userName.isEmpty ? '?' : r.userName.trim()[0].toUpperCase();
    final isMine = r.userId == widget.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Match the reference HTML: name + relative timestamp on the left, the
    // star row on the right, italic comment below.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(initials,
                      style: AppText.labelLg(AppColors.primary)
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.userName,
                          style: AppText.labelLg(scheme.onSurface)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(_relativeTime(r.timestamp),
                          style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                _stars(r.rating, 14),
                if (isMine)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert_rounded,
                        color: scheme.onSurfaceVariant, size: 18),
                    onSelected: (v) {
                      if (v == 'edit') _editReview(r);
                      if (v == 'delete') _deleteReview(r);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '"${r.comment}"',
              style: AppText.bodyMd(scheme.onSurfaceVariant)
                  .copyWith(fontStyle: FontStyle.italic, height: 1.45),
            ),
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
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} week${diff.inDays >= 14 ? "s" : ""} ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} month${diff.inDays >= 60 ? "s" : ""} ago';
    return '${(diff.inDays / 365).floor()} year${diff.inDays >= 730 ? "s" : ""} ago';
  }

  Widget _stars(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        IconData icon;
        if (rating >= n) {
          icon = Icons.star_rounded;
        } else if (rating > i) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, color: const Color(0xFFFFB300), size: size);
      }),
    );
  }

  String _ratingEmotion(double rating) {
    final bucket = rating.floor();
    if (rating < 1.5) return 'Terrible';
    if (bucket == 1) return 'Rough';
    if (bucket == 2) return 'Okay';
    if (bucket == 3) return 'Good';
    if (rating < 4.7) return 'Great';
    return 'Excellent';
  }
}

extension on String {
  String replaceFirstChar() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/// Fullscreen, swipeable, pinch-zoomable photo viewer. Used for the trail
/// hero carousel and community photo gallery.
class _PhotoViewerPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewerPage({required this.urls, required this.initialIndex});

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _pc;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pc = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pc,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(widget.urls[i]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(
                tag: 'trail-hero-${widget.urls[i]}-$i',
              ),
            ),
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.urls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${_current + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
