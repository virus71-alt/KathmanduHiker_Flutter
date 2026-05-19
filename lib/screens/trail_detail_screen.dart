import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/analytics.dart';
import '../models/hike_event.dart';
import '../domain/entities/trail.dart';
import '../utils/permission_rationale.dart';
import '../models/trail_photo.dart';
import '../models/trail_review.dart';
import '../models/weather_response.dart';
import '../services/hike_tracking_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/image_utils.dart';
import '../utils/ranking_manager.dart';
import '../utils/rating_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/journey.dart';
import '../state/current_uid_provider.dart';
import '../state/journey_providers.dart';
import '../state/navigation_providers.dart';
import '../state/repositories.dart';
import '../state/user_profile_provider.dart';
import 'create_event_bottom_sheet.dart';
import 'journey_builder_screen.dart';
import 'journey_detail_screen.dart';

class TrailDetailScreen extends ConsumerStatefulWidget {
  const TrailDetailScreen({super.key});

  @override
  ConsumerState<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends ConsumerState<TrailDetailScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  // Provider-derived values seeded in initState via ref.read.
  late Trail _trail;
  String _uid = '';
  String _userName = '';
  String _userPic = '';
  List<String> _myFriends = [];
  List<String> _mySentRequests = [];

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

  // Categorical Ratings
  double _newScenery = 4.0;
  double _newDifficulty = 3.0;
  double _newSafety = 4.0;
  double _newBeginner = 3.0;
  double _newTransport = 3.0;
  double _newCrowd = 3.0;

  // Hike tracking
  bool _tracking = false;
  TrackingStatus _trackingStatus = TrackingStatus.idle;
  double _distance = 0;
  String? _activeTrailId;
  double _finishedDistance = 0;

  // Subscriptions
  final _subs = <StreamSubscription>[];

  // Page controller for image carousel
  final _imageCtl = PageController();
  int _imagePage = 0;

  List<String> get _images => _trail.imageUrls.isNotEmpty
      ? _trail.imageUrls
      : const ['https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'];

  @override
  void initState() {
    super.initState();
    _trail = ref.read(currentTrailProvider)!;
    _uid = ref.read(currentUidProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    _userName = profile?.displayName ?? 'Hiker';
    _userPic = profile?.profilePic ?? '';
    _myFriends = profile?.friends ?? [];
    _mySentRequests = profile?.sentRequests ?? [];
    _wireFirestore();
    _wireTracking();
    _loadWeather();
  }

  void _wireFirestore() {
    _subs.add(
      _db
          .collection('hikes')
          .where('trailId', isEqualTo: _trail.id)
          .where('userId', isEqualTo: _uid)
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
          .doc(_trail.id)
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
          .where('trailId', isEqualTo: _trail.id)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() => _events = s.docs.map(HikeEvent.fromDoc).toList());
      }),
    );

    _subs.add(
      _db
          .collection('trails')
          .doc(_trail.id)
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
    _subs.add(t.trackingStatus.listen((s) => mounted ? setState(() => _trackingStatus = s) : null));
    _subs.add(t.distanceTraveled.listen((d) => mounted ? setState(() => _distance = d) : null));
    _subs.add(t.activeTrailId.listen((id) => mounted ? setState(() => _activeTrailId = id) : null));
  }

  Future<void> _loadWeather() async {
    final w = await WeatherService.getWeather(_trail.name);
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

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      if (!mounted) return;
      final go = await askPermissionRationale(
        context,
        icon: Icons.my_location_rounded,
        title: 'Track your hike with GPS',
        whyText:
            'Yama uses your location to measure distance, '
            'time, and your route while you hike. We never share or upload '
            'your location to other users.',
        continueLabel: 'Allow location',
      );
      if (!go) return;
    }

    final ok = await HikeTrackingService.instance.start(_trail);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location to track your hike.')),
      );
      return;
    }
    Analytics.hikeStarted(_trail.id);
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
    Analytics.hikeCompleted(_trail.id, km);
    int xp = 0;
    String status;
    if (km >= 0.7) {
      xp = _trail.difficulty.toLowerCase() == 'easy'
          ? RankingManager.xpEasyHike
          : RankingManager.xpStandardHike;
      status = 'Hike Completed!';
      await _db.collection('hikes').add({
        'userId': _uid,
        'trailId': _trail.id,
        'distanceKm': km,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _db
          .collection('users')
          .doc(_uid)
          .update({'totalXP': FieldValue.increment(xp)});
    } else {
      status = 'Hike too short';
    }
    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(status),
        content: Text('You walked ${km.toStringAsFixed(3)} km and earned +$xp XP.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    ));
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
          .child('gallery/${_trail.id}/${const Uuid().v4()}.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _db
          .collection('trails')
          .doc(_trail.id)
          .collection('gallery')
          .add({
        'userId': _uid,
        'userName': _userName,
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (_uid.isNotEmpty) {
        await _db
            .collection('users')
            .doc(_uid)
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
    
    final categories = {
      'scenery': _newScenery,
      'difficulty': _newDifficulty,
      'safety': _newSafety,
      'beginner': _newBeginner,
      'transport': _newTransport,
      'crowd': _newCrowd,
    };

    await _db.collection('trails').doc(_trail.id).collection('reviews').add({
      'userId': _uid,
      'userName': _userName,
      'rating': _newRating,
      'comment': _reviewCtl.text.trim(),
      'categories': categories,
      'isVerified': false, // can check if user has finished trail here later
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _db
        .collection('users')
        .doc(_uid)
        .update({'totalXP': FieldValue.increment(RankingManager.xpReview)});
    await _recalculateTrailRating();
    if (!mounted) return;
    _reviewCtl.clear();
    setState(() {
      _newRating = 4.0;
      _newScenery = 4.0;
      _newDifficulty = 3.0;
      _newSafety = 4.0;
      _newBeginner = 3.0;
      _newTransport = 3.0;
      _newCrowd = 3.0;
      _submittingReview = false;
    });
  }


  Future<void> _recalculateTrailRating() async {
    try {
      final snap = await _db
          .collection('trails')
          .doc(_trail.id)
          .collection('reviews')
          .get();
          
      final List<TrailReview> allReviews = snap.docs.map(TrailReview.fromDoc).toList();
      
      final updatedTrail = RatingCalculator.computeBayesian(_trail, allReviews);

      await _db.collection('trails').doc(_trail.id).update({
        'ratingScore': updatedTrail.ratingScore,
        'userRating': updatedTrail.userRating,
        'reviewCount': updatedTrail.reviewCount,
        'confidenceLabel': updatedTrail.confidenceLabel,
        'categoryAverages': updatedTrail.categoryAverages,
      });

      if (mounted) {
        setState(() {
          _trail = updatedTrail;
        });
      }
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
          .doc(_trail.id)
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
          .doc(_trail.id)
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
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => CreateEventBottomSheet(
        trailName: _trail.name,
        onCreate: (date, max) async {
          final eventData = {
            'trailId': _trail.id,
            'trailName': _trail.name,
            'creatorId': _uid,
            'creatorName': _userName,
            'dateText': date,
            'maxHikers': max,
            'attendees': [_uid],
            'attendeeDetails': [
              {
                'id': _uid,
                'name': _userName,
                'phone': 'Organizer',
                'bloodGroup': 'N/A',
              },
            ],
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          final ref = await _db.collection('events').add(eventData);
          for (final friendId
              in _myFriends.where((f) => f != _uid)) {
            await _db
                .collection('users')
                .doc(friendId)
                .collection('notifications')
                .add({
              'message':
                  '${_userName} planned a hike to ${_trail.name} on $date.',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'isRead': false,
              'type': 'community_event',
              'trailId': _trail.id,
              'eventId': ref.id,
            });
          }
          await _db
              .collection('users')
              .doc(_uid)
              .update({'totalXP': FieldValue.increment(RankingManager.xpHostHike)});
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        },
      ),
    ));
  }

  Future<void> _joinEvent(HikeEvent event) async {
    AppFeedback.tap();
    final nameCtl = TextEditingController(text: _userName);
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
      'attendees': FieldValue.arrayUnion([_uid]),
      'attendeeDetails': FieldValue.arrayUnion([
        {
          'id': _uid,
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
      (d) => d['id'] == _uid,
      orElse: () => const {},
    );
    if (my.isEmpty) return;
    await _db.collection('events').doc(event.id).update({
      'attendees': FieldValue.arrayRemove([_uid]),
      'attendeeDetails': FieldValue.arrayRemove([my]),
    });
  }

  bool get _isFavorite =>
      ref.read(userProfileProvider).valueOrNull?.favoriteTrailIds
          .contains(_trail.id) ??
      false;

  Future<void> _toggleFavorite() async {
    final isFav = _isFavorite;
    await ref.read(userRepositoryProvider).toggleFavorite(
          uid: _uid, trailId: _trail.id, add: !isFav);
  }

  Future<void> _sendFriendRequest(String toUid) async {
    await ref
        .read(userRepositoryProvider)
        .sendFriendRequest(fromUid: _uid, toUid: toUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend Request Sent! ⏳')));
    }
  }

  Future<void> _cancelFriendRequest(String toUid) async {
    await ref
        .read(userRepositoryProvider)
        .cancelFriendRequest(fromUid: _uid, toUid: toUid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend Request Cancelled ❌')));
    }
  }

  Future<void> _shareTrail() async {
    AppFeedback.tap();
    final t = _trail;
    final lines = <String>[
      '🏔️ ${t.name}',
      if (t.difficulty.isNotEmpty) 'Difficulty: ${t.difficulty}',
      if (t.duration.isNotEmpty) 'Duration: ${t.duration}',
      if (t.latitude != 0 || t.longitude != 0)
        'Map: https://www.google.com/maps/search/?api=1&query=${t.latitude},${t.longitude}',
      '',
      'Shared from Yama',
    ];
    await Share.share(
      lines.join('\n'),
      subject: 'Check out this trail: ${t.name}',
    );
  }

  Future<void> _openMaps() async {
    AppFeedback.tap();
    final hasCoords =
        _trail.latitude != 0 || _trail.longitude != 0;
    final coordPair = hasCoords
        ? '${_trail.latitude},${_trail.longitude}'
        : null;
    final queryLabel = Uri.encodeComponent(
        _trail.name.isEmpty ? 'Kathmandu' : _trail.name);
    final webDestination = coordPair ?? '$queryLabel,Kathmandu';


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
    ref.listen(userProfileProvider, (_, next) {
      final p = next.valueOrNull;
      setState(() {
        _myFriends = p?.friends ?? [];
        _mySentRequests = p?.sentRequests ?? [];
        _userName = p?.displayName ?? _userName;
        _userPic = p?.profilePic ?? _userPic;
      });
    });

    final rating = _trail.ratingScore > 0
        ? _trail.ratingScore
        : _trail.userRating.toDouble();

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
                _trail.journeyLegs.isNotEmpty
                    ? _modernJourneySection()
                    : _howToGetThereCard(),
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
                _journeysSection(),
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

  // ─── Journeys section (E11) ─────────────────────────────────────────────
  Widget _journeysSection() {
    final journeysAsync = ref.watch(journeysByTrailProvider(_trail.id));
    return journeysAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (journeys) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('How to Get Here',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Journey'),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => JourneyBuilderScreen(
                      attachedTrailId: _trail.id,
                      attachedTrailName: _trail.name,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ));
                },
              ),
            ],
          ),
          if (journeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No journeys yet. Be the first to share how to get here!',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
              ),
            )
          else
            for (final j in journeys)
              _journeyCard(j),
        ],
      ),
    );
  }

  Widget _journeyCard(Journey journey) {
    final scheme = Theme.of(context).colorScheme;
    final total = journey.totalDurationMin;
    final h = total ~/ 60;
    final m = total % 60;
    final durStr = total == 0
        ? null
        : h == 0
            ? '${m}m'
            : m == 0
                ? '${h}h'
                : '${h}h ${m}m';
    final fareStr = journey.totalFareMin == 0 && journey.totalFareMax == 0
        ? null
        : journey.totalFareMin == journey.totalFareMax
            ? 'Rs ${journey.totalFareMin}'
            : 'Rs ${journey.totalFareMin} – ${journey.totalFareMax}';

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => JourneyDetailScreen(
              journey: journey,
              onBack: () => Navigator.of(context).pop(),
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(journey.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              // leg mode icon strip
              Row(
                children: journey.legs
                    .take(5)
                    .map((l) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            _legIcon(l.mode),
                            size: 16,
                            color: scheme.primary,
                          ),
                        ))
                    .toList(),
              ),
              if (durStr != null || fareStr != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (durStr != null) ...[
                      Icon(Icons.schedule_outlined,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(durStr,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      const SizedBox(width: 12),
                    ],
                    if (fareStr != null) ...[
                      Icon(Icons.payments_outlined,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(fareStr,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text('By ${journey.creatorName}',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _legIcon(TransportMode mode) => switch (mode) {
        TransportMode.bus            => Icons.directions_bus_rounded,
        TransportMode.micro          => Icons.airport_shuttle_rounded,
        TransportMode.tempo          => Icons.directions_transit_rounded,
        TransportMode.taxi           => Icons.local_taxi_rounded,
        TransportMode.bike           => Icons.directions_bike_rounded,
        TransportMode.walk           => Icons.directions_walk_rounded,
        TransportMode.privateVehicle => Icons.directions_car_rounded,
        TransportMode.cableCar       => Icons.cable_rounded,
      };

  // ─── Hero with carousel + overlay ───────────────────────────────────────
  Widget _heroSection(double rating) {
    final diff = difficultyColors(context, _trail.difficulty);
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
              tag: 'trail-hero-${_trail.id}-$i',
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
            ref.read(currentTrailProvider.notifier).state = null;
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
                      _trail.difficulty.toUpperCase(),
                      style: AppText.labelSm(diff.fg)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_trail.transportRoute.isNotEmpty)
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
                          _trail.transportRoute,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _trail.name,
                style: AppText.headlineLg(Colors.white)
                    .copyWith(fontSize: 26, height: 1.15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (rating > 0) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _stars(rating, 16),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppText.labelSm(Colors.white).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_trail.reviewCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _trail.confidenceLabel == 'Low Confidence' 
                              ? Colors.black.withOpacity(0.3)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _trail.confidenceLabel == 'Low Confidence'
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _trail.confidenceLabel,
                          style: AppText.labelSm(Colors.white).copyWith(
                            fontSize: 10,
                            fontWeight: _trail.confidenceLabel == 'Low Confidence' ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
    final duration = _shortDuration(_trail.duration);
    final fare = _shortFare(_trail.fare);
    final mode =
        _trail.travelMode.isEmpty ? 'Trek' : _trail.travelMode;

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
    final fav = _isFavorite;
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
            onTap: () {
                AppFeedback.toggle();
                _toggleFavorite();
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
    final activeHere = _tracking && _activeTrailId == _trail.id;
    final km = activeHere ? _distance / 1000.0 : _finishedDistance / 1000.0;
    final showKm = activeHere || _finishedDistance > 0;

    String title;
    String subtitle;
    Color iconColor;
    Color bgColor;
    IconData icon;

    if (activeHere) {
      if (_trackingStatus == TrackingStatus.pausedForSpeed) {
        title = 'Vehicle Movement Detected';
        subtitle = 'Tracking paused automatically due to unrealistic hiking speed.';
        iconColor = scheme.error;
        bgColor = scheme.errorContainer;
        icon = Icons.directions_car_rounded;
      } else if (_trackingStatus == TrackingStatus.pausedOffTrail) {
        title = 'Off Trail';
        subtitle = 'Tracking paused because you are too far from the trail region.';
        iconColor = scheme.error;
        bgColor = scheme.errorContainer;
        icon = Icons.wrong_location_rounded;
      } else if (_trackingStatus == TrackingStatus.pausedLowAccuracy) {
        title = 'Poor GPS Signal';
        subtitle = 'Finding location... ensuring accurate distance tracking.';
        iconColor = scheme.error;
        bgColor = scheme.errorContainer;
        icon = Icons.gps_off_rounded;
      } else {
        title = 'Hike in Progress';
        subtitle = 'Live validated distance — GPS noise and vehicle motion are filtered.';
        iconColor = scheme.tertiary;
        bgColor = scheme.tertiary.withValues(alpha: 0.18);
        icon = Icons.gps_fixed_rounded;
      }
    } else if (_finishedDistance > 0) {
      title = 'Last Tracked Hike';
      subtitle = 'Tap reset to start fresh.';
      iconColor = scheme.primary;
      bgColor = scheme.primary.withValues(alpha: 0.10);
      icon = Icons.directions_walk_rounded;
    } else {
      title = 'Track Your Hike';
      subtitle = 'Earn XP for trekking the trail on foot.';
      iconColor = scheme.primary;
      bgColor = scheme.primary.withValues(alpha: 0.10);
      icon = Icons.directions_walk_rounded;
    }

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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(icon, color: iconColor, size: 22),
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
                    if (_lastHikeKm case final km? when !showKm) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Previous best: ${km.toStringAsFixed(2)} km',
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
    final friend = _myFriends.contains(_trail.authorId);
    final sent = _mySentRequests.contains(_trail.authorId);
    final selfAuthor = _trail.authorId == _uid;
    final authorName =
        _trail.authorName.isEmpty ? 'Anonymous Hiker' : _trail.authorName;

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
          if (!selfAuthor && _trail.authorId.isNotEmpty)
            OutlinedButton(
              onPressed: () {
                if (friend) return;
                if (sent) {
                  _cancelFriendRequest(_trail.authorId);
                } else {
                  AppFeedback.success();
                  _sendFriendRequest(_trail.authorId);
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
        _trail.transportRoute.isEmpty ? 'Trailhead' : _trail.transportRoute;
    final mode = _trail.travelMode;
    final modeLabel = mode.isEmpty ? 'On foot' : mode;
    final fare = _trail.fare.isEmpty ? null : _trail.fare;
    final hasBus = mode.toLowerCase() == 'bus' && _trail.busAccess.isNotEmpty;

    // Each stop: (icon, title, subtitle, fareOrNote, isStartCircle).
    final stops = <({IconData icon, String title, String subtitle, String? note, bool start})>[];
    if (hasBus) {
      stops.add((
        icon: Icons.directions_bus_rounded,
        title: _trail.busAccess,
        subtitle: 'Board your bus / micro toward $start',
        note: fare != null ? 'Fare: $fare' : null,
        start: true,
      ));
      stops.add((
        icon: Icons.flag_rounded,
        title: start,
        subtitle: _trail.duration.isEmpty
            ? 'Trail entry and start of the hike'
            : 'Trail entry • ${_trail.duration}',
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
                            if (stops[i].note case final note?) ...[
                              const SizedBox(height: 4),
                              Text(
                                note,
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

  // ─── Modern Journey Section ──────────────────────────────────────────────
  Widget _modernJourneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_trail.reachDifficulty.isNotEmpty ||
            _trail.lastReturnVehicle.isNotEmpty ||
            _trail.localGuidance.isNotEmpty) ...[
          _journeyContextCard(),
          const SizedBox(height: 16),
        ],
        _journeyTimeline(),
      ],
    );
  }

  Widget _journeyContextCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.secondaryContainer.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trail.reachDifficulty.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 16, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text('Difficulty to reach: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer)),
                Expanded(
                  child: Text(_trail.reachDifficulty,
                      style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer)),
                ),
              ],
            ),
          ],
          if (_trail.lastReturnVehicle.isNotEmpty) ...[
            if (_trail.reachDifficulty.isNotEmpty) const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_filled_rounded, size: 16, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text('Last return vehicle: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer)),
                Expanded(
                  child: Text(_trail.lastReturnVehicle,
                      style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer)),
                ),
              ],
            ),
          ],
          if (_trail.localGuidance.isNotEmpty) ...[
            if (_trail.reachDifficulty.isNotEmpty || _trail.lastReturnVehicle.isNotEmpty) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_circle_rounded, size: 16, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${_trail.localGuidance}"',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: scheme.onSecondaryContainer, height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _journeyTimeline() {
    final legs = _trail.journeyLegs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < legs.length; i++)
          _timelineNode(legs[i], isLast: i == legs.length - 1),
      ],
    );
  }

  Widget _timelineNode(JourneyLeg leg, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    final isWalk = leg.mode == TransportMode.walk;
    final iconColor = isWalk ? Colors.green.shade600 : scheme.primary;
    final iconBg = isWalk ? Colors.green.shade50 : scheme.primaryContainer;
    
    final fareStr = leg.fareMin == 0 && leg.fareMax == 0
        ? 'Free'
        : leg.fareMin == leg.fareMax
            ? 'Rs. ${leg.fareMin}'
            : 'Rs. ${leg.fareMin} - ${leg.fareMax}';

    final durStr = leg.durationMin == 0
        ? ''
        : leg.durationMin < 60
            ? '${leg.durationMin} mins'
            : '${leg.durationMin ~/ 60}h ${leg.durationMin % 60 == 0 ? '' : '${leg.durationMin % 60}m'}'.trim();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line & Icon
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_legIcon(leg.mode), size: 20, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: scheme.outlineVariant,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
                else
                  const SizedBox(height: 16), // Bottom padding for last item
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leg.mode.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (leg.mode.hasFromTo) ...[
                      Text(leg.from, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Icon(Icons.arrow_downward_rounded, size: 16, color: scheme.outline),
                      ),
                      Text(leg.to, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
                    ] else ...[
                      Text(leg.from.isNotEmpty ? leg.from : 'Trailhead', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                    if (durStr.isNotEmpty || fareStr != 'Free' || leg.notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (fareStr != 'Free' && fareStr.isNotEmpty)
                            _journeyChip(Icons.payments_outlined, fareStr),
                          if (durStr.isNotEmpty)
                            _journeyChip(Icons.schedule_outlined, durStr),
                        ],
                      ),
                      if (leg.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(leg.notes, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.45)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyChip(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ─── Details card ───────────────────────────────────────────────────────
  // Mirrors the reference HTML's 2-col `gap-y-4` Trail Details grid inside a
  // sunken card. Each cell is a labelled value pair.
  Widget _detailsCard() {
    final scheme = Theme.of(context).colorScheme;
    final pairs = <({String label, String value})>[
      (
        label: 'Difficulty',
        value: _trail.difficulty.isEmpty ? '—' : _trail.difficulty,
      ),
      (
        label: 'Est Cost',
        value: _trail.fare.isEmpty ? 'Free' : _trail.fare,
      ),
      (
        label: 'Travel Mode',
        value:
            _trail.travelMode.isEmpty ? 'Trek' : _trail.travelMode,
      ),
      (
        label: 'From Bus',
        value: _trail.busAccess.isEmpty
            ? (_trail.transportRoute.isEmpty
                ? '—'
                : _trail.transportRoute)
            : _trail.busAccess,
      ),
      (
        label: 'Duration',
        value: _trail.duration.isEmpty ? '—' : _trail.duration,
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
    final parsed = _parseExperience(_trail.description);

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
    final p = _parseExperience(_trail.description);
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
            '${rating.toStringAsFixed(1)} (${_trail.reviewCount} reviews • ${_trail.confidenceLabel})',
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
    final trailPhotos = _trail.imageUrls.where((u) => u.isNotEmpty).toList();
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
    final iHost = _events.any((e) => e.creatorId == _uid);
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
    final isGoing = event.attendees.contains(_uid);
    final isCreator = event.creatorId == _uid;
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
      if (r.userId == _uid) return r;
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
          const SizedBox(height: 12),
          _categorySlider('Overall Experience', _newRating, (v) => setState(() => _newRating = v), isMain: true),
          const Divider(height: 24),
          Text('Categorical Ratings', style: AppText.labelSm(Theme.of(context).colorScheme.onSurfaceVariant).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _categorySlider('Scenery', _newScenery, (v) => setState(() => _newScenery = v)),
          _categorySlider('Difficulty', _newDifficulty, (v) => setState(() => _newDifficulty = v)),
          _categorySlider('Safety', _newSafety, (v) => setState(() => _newSafety = v)),
          _categorySlider('Beginner Friendly', _newBeginner, (v) => setState(() => _newBeginner = v)),
          _categorySlider('Accessibility', _newTransport, (v) => setState(() => _newTransport = v)),
          _categorySlider('Crowd Level', _newCrowd, (v) => setState(() => _newCrowd = v)),
          const SizedBox(height: 16),
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

  Widget _categorySlider(String label, double value, ValueChanged<double> onChanged, {bool isMain = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppText.labelSm(scheme.onSurface).copyWith(
                fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
                fontSize: isMain ? 14 : 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: isMain ? 6 : 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: isMain ? 10 : 8),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: isMain ? scheme.primary : scheme.secondary,
                thumbColor: isMain ? scheme.primary : scheme.secondary,
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: AppText.labelSm(scheme.onSurfaceVariant).copyWith(fontWeight: FontWeight.w700),
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
    final isMine = r.userId == _uid;
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
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${r.comment}"',
                style: AppText.bodyMd(scheme.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic, height: 1.45),
              ),
            ],
            if (r.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: r.categories.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.key.toUpperCase()} ',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          e.value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
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
