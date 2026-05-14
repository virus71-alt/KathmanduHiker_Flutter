import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/comment.dart';
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
import 'comments_bottom_sheet.dart';
import 'create_event_bottom_sheet.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final String currentUserId;
  final String currentUserName;
  final String currentUserPic;
  final List<String> myFriends;
  final List<String> mySentRequests;
  final VoidCallback onBack;
  final Future<void> Function(String authorId) onSendFriendRequest;
  final Future<void> Function(String authorId) onCancelFriendRequest;

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
  List<Comment> _comments = [];
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
          .collection('trails')
          .doc(widget.trail.id)
          .collection('comments')
          .orderBy('timestamp')
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() => _comments = s.docs.map(Comment.fromDoc).toList());
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
      final ref =
          _storage.ref().child('gallery/${widget.trail.id}/${const Uuid().v4()}.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _db.collection('trails').doc(widget.trail.id).collection('gallery').add({
        'userId': widget.currentUserId,
        'userName': widget.currentUserName,
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _db
          .collection('users')
          .doc(widget.currentUserId)
          .update({'totalXP': FieldValue.increment(RankingManager.xpCommunityPhoto)});
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _postReview() async {
    if (_reviewCtl.text.trim().isEmpty) return;
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
    if (!mounted) return;
    _reviewCtl.clear();
    setState(() => _submittingReview = false);
  }

  Future<void> _openComments() async {
    AppFeedback.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CommentsBottomSheet(
        comments: _comments,
        onSendComment: (text) async {
          await _db.collection('trails').doc(widget.trail.id).collection('comments').add({
            'authorId': widget.currentUserId,
            'authorName': widget.currentUserName,
            'text': text,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        },
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
    final uri = Uri.parse(
        'sms:?body=${Uri.encodeComponent('Check out ${widget.trail.name} on Kathmandu Hiker!')}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _openMaps() async {
    AppFeedback.tap();
    final loc = (widget.trail.latitude != 0 || widget.trail.longitude != 0)
        ? '${widget.trail.latitude},${widget.trail.longitude}'
        : '${widget.trail.name},+Kathmandu';
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$loc');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.trail.ratingScore > 0
        ? widget.trail.ratingScore
        : widget.trail.userRating.toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            backgroundColor: Colors.transparent,
            expandedHeight: 360,
            automaticallyImplyLeading: false,
            flexibleSpace: _heroSection(rating),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 0,
                AppSpacing.marginMobile, AppSpacing.stackLg),
            sliver: SliverList.list(
              children: [
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: _quickStatsBar(),
                ),
                _actionRow(),
                const SizedBox(height: AppSpacing.stackMd),
                _hikeTrackingCard(),
                if (_weather != null) ...[
                  const SizedBox(height: AppSpacing.stackMd),
                  _weatherCard(),
                ],
                const SizedBox(height: AppSpacing.stackMd),
                _discoveredByCard(),
                if (_events.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.stackMd),
                  _sectionTitle(Icons.event_rounded, 'Upcoming Group Hikes'),
                  const SizedBox(height: AppSpacing.stackSm),
                  for (final e in _events) _eventCard(e),
                ],
                const SizedBox(height: AppSpacing.stackMd),
                _sectionTitle(Icons.directions_bus_rounded, 'How to Get There'),
                const SizedBox(height: AppSpacing.stackSm),
                _howToGetThereCard(),
                const SizedBox(height: AppSpacing.stackMd),
                _sectionTitle(Icons.terrain_rounded, 'Trail Details'),
                const SizedBox(height: AppSpacing.stackSm),
                _detailsCard(),
                if (widget.trail.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.stackMd),
                  _sectionTitle(Icons.menu_book_rounded, 'Shared Experience'),
                  const SizedBox(height: AppSpacing.stackSm),
                  _descriptionCard(),
                ],
                const SizedBox(height: AppSpacing.stackMd),
                _sectionTitle(Icons.photo_library_outlined, 'Community Photos'),
                const SizedBox(height: AppSpacing.stackSm),
                _galleryCard(),
                const SizedBox(height: AppSpacing.stackMd),
                _secondaryActionGrid(),
                const SizedBox(height: AppSpacing.stackMd),
                _sectionTitle(Icons.reviews_outlined,
                    'Hiker Reviews ${_reviews.isEmpty ? "" : "(${_reviews.length})"}'),
                const SizedBox(height: AppSpacing.stackSm),
                _reviewForm(),
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
    final diff = difficultyColors(widget.trail.difficulty);
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imageCtl,
          onPageChanged: (i) => setState(() => _imagePage = i),
          itemCount: _images.length,
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: _images[i],
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: AppColors.surfaceContainerHigh),
            errorWidget: (_, __, ___) =>
                Container(color: AppColors.surfaceContainerHigh),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: [
                Colors.black.withOpacity(0.32),
                Colors.transparent,
                Colors.black.withOpacity(0.78),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _heroIconButton(Icons.arrow_back_rounded, () {
                AppFeedback.tap();
                widget.onBack();
              }),
              const Spacer(),
              _heroIconButton(Icons.share_outlined, _shareTrail),
            ],
          ),
        ),
        if (_images.length > 1)
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (i) {
                final selected = i == _imagePage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        Positioned(
          left: AppSpacing.marginMobile,
          right: AppSpacing.marginMobile,
          bottom: 60,
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
                    .copyWith(fontSize: 28, height: 1.15),
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
  Widget _quickStatsBar() {
    final duration =
        widget.trail.duration.isEmpty ? '—' : widget.trail.duration;
    final fare = widget.trail.fare.isEmpty ? 'Free' : widget.trail.fare;
    final mode = widget.trail.travelMode.isEmpty ? 'Trek' : widget.trail.travelMode;

    return Container(
      decoration: topoCardDecoration(radius: AppRadius.md),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _statColumn(Icons.timer_outlined, duration, 'Duration')),
          Container(width: 1, height: 40, color: AppColors.outlineVariant),
          Expanded(child: _statColumn(Icons.payments_outlined, fare, 'Est. Cost')),
          Container(width: 1, height: 40, color: AppColors.outlineVariant),
          Expanded(child: _statColumn(Icons.directions_walk_rounded, mode, 'Mode')),
        ],
      ),
    );
  }

  Widget _statColumn(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.labelLg(AppColors.onSurface)
              .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(label, style: AppText.labelSm(AppColors.onSurfaceVariant)),
      ],
    );
  }

  // ─── Primary actions ─────────────────────────────────────────────────────
  Widget _actionRow() {
    final activeHere = _tracking && _activeTrailId == widget.trail.id;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: activeHere ? _confirmEndHike : _startHike,
            icon: Icon(activeHere ? Icons.stop_circle_outlined : Icons.navigation_rounded),
            label: Text(activeHere ? 'End Hike' : 'Start Navigation'),
            style: FilledButton.styleFrom(
              backgroundColor: activeHere ? AppColors.error : AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _openMaps,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: AppColors.surfaceContainerLow,
            ),
            child: const Icon(Icons.map_outlined, color: AppColors.primary),
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
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: AppText.headlineMd(AppColors.onSurface)
                  .copyWith(fontSize: 20)),
        ),
      ],
    );
  }

  // ─── Hike tracking card ─────────────────────────────────────────────────
  Widget _hikeTrackingCard() {
    final activeHere = _tracking && _activeTrailId == widget.trail.id;
    final km = activeHere ? _distance / 1000.0 : _finishedDistance / 1000.0;
    final showKm = activeHere || _finishedDistance > 0;
    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeHere
                      ? AppColors.tertiaryFixed
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(
                  activeHere
                      ? Icons.gps_fixed_rounded
                      : Icons.directions_walk_rounded,
                  color: activeHere ? AppColors.tertiaryContainer : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeHere
                          ? 'Hike in Progress'
                          : _finishedDistance > 0
                              ? 'Last Tracked Hike'
                              : 'Track Your Hike',
                      style: AppText.labelLg(AppColors.onSurface)
                          .copyWith(fontSize: 15),
                    ),
                    if (_lastHikeKm != null && !showKm)
                      Text(
                        'Previous best: ${_lastHikeKm!.toStringAsFixed(2)} km',
                        style: AppText.labelSm(AppColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (showKm)
                Text(
                  '${km.toStringAsFixed(2)} km',
                  style: AppText.headlineMd(AppColors.primary)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    activeHere ? AppColors.error : AppColors.primaryContainer,
                foregroundColor: Colors.white,
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
                        : 'Start real-time tracking',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherCard() {
    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT CONDITIONS',
                    style: AppText.labelSm(Colors.white70)),
                const SizedBox(height: 2),
                Text('${w.temp.toInt()}°C',
                    style: AppText.headlineLg(Colors.white)
                        .copyWith(fontSize: 34)),
                if (w.description.isNotEmpty)
                  Text(w.description.replaceFirstChar(),
                      style: AppText.bodyMd(Colors.white)),
              ],
            ),
          ),
          if (w.icon.isNotEmpty)
            CachedNetworkImage(
              imageUrl: 'https://openweathermap.org/img/wn/${w.icon}@2x.png',
              width: 80,
              height: 80,
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
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryFixed,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Center(
              child: Text(
                authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                style: AppText.labelLg(AppColors.primary)
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
                    style: AppText.labelSm(AppColors.onSurfaceVariant)),
                Text(authorName,
                    style: AppText.labelLg(AppColors.onSurface)),
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
                    : AppColors.surfaceContainerLow,
              ),
              child: Text(
                friend ? 'Friends' : sent ? 'Cancel' : 'Add Friend',
                style: AppText.labelLg(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ─── How to Get There rail ─────────────────────────────────────────────
  Widget _howToGetThereCard() {
    final stops = <(String, String, String)>[
      (
        'Ratnapark Bus Station',
        'Catch a micro-bus toward ${widget.trail.busAccess.isEmpty ? "the trailhead" : widget.trail.busAccess}',
        widget.trail.fare.isEmpty ? '—' : widget.trail.fare,
      ),
      (
        widget.trail.busAccess.isEmpty ? 'Trailhead' : widget.trail.busAccess,
        widget.trail.transportRoute.isEmpty
            ? 'Park entry and start of the hike'
            : widget.trail.transportRoute,
        widget.trail.travelMode.isEmpty ? 'On foot' : widget.trail.travelMode,
      ),
    ];

    return Container(
      decoration: sunkenFieldDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 56, color: AppColors.outlineVariant),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  Text(stops[i].$1,
                      style: AppText.labelLg(AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(stops[i].$2,
                      style: AppText.labelSm(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(stops[i].$3,
                      style: AppText.labelSm(AppColors.primary)
                          .copyWith(fontWeight: FontWeight.w800)),
                  if (i < stops.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Details card ───────────────────────────────────────────────────────
  Widget _detailsCard() {
    final rows = <(IconData, String, String)>[
      (Icons.terrain_rounded, 'Difficulty', widget.trail.difficulty),
      if (widget.trail.fare.isNotEmpty)
        (Icons.payments_outlined, 'Est. Cost', widget.trail.fare),
      if (widget.trail.travelMode.isNotEmpty)
        (Icons.directions_bus_outlined, 'Travel Mode', widget.trail.travelMode),
      if (widget.trail.busAccess.isNotEmpty)
        (Icons.where_to_vote_outlined, 'Pickup Point', widget.trail.busAccess),
      if (widget.trail.duration.isNotEmpty)
        (Icons.schedule_rounded, 'Duration', widget.trail.duration),
      if (widget.trail.facilities.isNotEmpty)
        (Icons.local_cafe_outlined, 'Facilities', widget.trail.facilities.join(', ')),
    ];

    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 14, color: AppColors.outlineVariant),
            Row(
              children: [
                Icon(rows[i].$1, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].$2.toUpperCase(),
                          style: AppText.labelSm(AppColors.onSurfaceVariant)),
                      Text(rows[i].$3,
                          style: AppText.bodyMd(AppColors.onSurface)
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _descriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        widget.trail.description,
        style: AppText.bodyMd(AppColors.onSecondaryContainer)
            .copyWith(height: 1.55),
      ),
    );
  }

  // ─── Gallery + share photo ──────────────────────────────────────────────
  Widget _galleryCard() {
    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Hiker shots',
                    style: AppText.labelLg(AppColors.onSurface)),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 38),
                ),
                onPressed: _uploadingPhoto ? null : _sharePhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(_uploadingPhoto ? 'Uploading' : 'Share photo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_gallery.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: AppColors.onSurfaceVariant, size: 28),
                  const SizedBox(height: 6),
                  Text('Be the first to share a photo',
                      style: AppText.labelSm(AppColors.onSurfaceVariant)),
                ],
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _gallery.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  child: CachedNetworkImage(
                    imageUrl: _gallery[i].url,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Secondary actions: discussion + plan + share ───────────────────────
  Widget _secondaryActionGrid() {
    final iHost = _events.any((e) => e.creatorId == widget.currentUserId);
    return Row(
      children: [
        Expanded(
            child: _secondaryAction(
                Icons.forum_outlined, 'Discussion', _openComments)),
        const SizedBox(width: 10),
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
      color: enabled ? AppColors.surfaceContainerLow : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: enabled ? AppColors.primary : AppColors.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label,
                  style: AppText.labelSm(
                          enabled ? AppColors.primary : AppColors.onSurfaceVariant)
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
        decoration: topoCardDecoration(),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.dateText,
                      style: AppText.labelLg(AppColors.onSurface)),
                  Text(
                      'Hosted by ${event.creatorName} • ${event.attendees.length}/${event.maxHikers}',
                      style: AppText.labelSm(AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (isCreator)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
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
                      isGoing ? AppColors.surfaceContainerHigh : AppColors.primary,
                  foregroundColor:
                      isGoing ? AppColors.onSurfaceVariant : Colors.white,
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

  // ─── Review form + items ────────────────────────────────────────────────
  Widget _reviewForm() {
    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How was your hike?',
              style: AppText.labelLg(AppColors.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            _stars(_newRating, 26),
            const SizedBox(width: 8),
            Text('${_newRating.toStringAsFixed(1)} / 5',
                style: AppText.labelLg(AppColors.primary)),
          ]),
          Slider(
            value: _newRating,
            min: 1,
            max: 5,
            divisions: 40,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                setState(() => _newRating = (v * 10).roundToDouble() / 10),
          ),
          Text(_ratingEmotion(_newRating),
              style: AppText.labelSm(AppColors.tertiary)
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
    final initials = r.userName.isEmpty ? '?' : r.userName.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
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
                          style: AppText.labelLg(AppColors.onSurface)),
                      _stars(r.rating, 14),
                    ],
                  ),
                ),
                Text('${r.rating.toStringAsFixed(1)}',
                    style: AppText.labelLg(AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(r.comment,
                style: AppText.bodyMd(AppColors.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
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
