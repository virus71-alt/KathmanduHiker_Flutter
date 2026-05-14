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
          _lastHikeKm = s.docs.isEmpty ? null : (s.docs.first['distanceKm'] as num?)?.toDouble();
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
      status = 'Hike Completed! 🎉';
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
      status = 'Hike too short! ❌';
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
      final ref = _storage.ref().child('gallery/${widget.trail.id}/${const Uuid().v4()}.jpg');
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
          // Fan-out notifications
          for (final friendId in widget.myFriends.where((f) => f != widget.currentUserId)) {
            await _db.collection('users').doc(friendId).collection('notifications').add({
              'message': '${widget.currentUserName} planned a hike to ${widget.trail.name} on $date.',
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
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone')),
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
        'sms:?body=${Uri.encodeComponent('Check out ${widget.trail.name} on Kathmandu Hiker! 🎒')}');
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
    final colors = Theme.of(context).colorScheme;
    final rating = widget.trail.ratingScore > 0
        ? widget.trail.ratingScore
        : widget.trail.userRating.toDouble();

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Image carousel
              Stack(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _imageCtl,
                      onPageChanged: (i) => setState(() => _imagePage = i),
                      itemCount: _images.length,
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: _images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  if (_images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _images.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _imagePage ? Colors.white : Colors.white54,
                            ),
                          ),
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
                        const Text('📍', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.trail.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (rating > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _stars(rating, 18),
                          const SizedBox(width: 8),
                          Text(
                            '${rating.toStringAsFixed(1)}/5 • ${_ratingEmotion(rating)}',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (_lastHikeKm != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '🥾 Last Hike: ${_lastHikeKm!.toStringAsFixed(3)} km',
                        style: TextStyle(color: colors.tertiary, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _hikeTrackingCard(),

                    if (_weather != null) _weatherCard(),

                    // Photo gallery + share button
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('📸 Community Photos',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        FilledButton(
                          onPressed: _uploadingPhoto ? null : _sharePhoto,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.tertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          ),
                          child: Text(_uploadingPhoto ? '⏳ Uploading…' : '📤 Share Photo'),
                        ),
                      ],
                    ),
                    if (_gallery.isNotEmpty)
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _gallery.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _gallery[i].url,
                              width: 120, height: 120, fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                    // Discovered by
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🧭 Discovered by',
                                    style: TextStyle(
                                        fontSize: 11, color: colors.onSurfaceVariant)),
                                Text(
                                    widget.trail.authorName.isEmpty
                                        ? 'Anonymous Hiker'
                                        : widget.trail.authorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (widget.trail.authorId.isNotEmpty &&
                                widget.trail.authorId != widget.currentUserId)
                              OutlinedButton(
                                onPressed: () {
                                  final friend = widget.myFriends.contains(widget.trail.authorId);
                                  final sent = widget.mySentRequests.contains(widget.trail.authorId);
                                  if (friend) return;
                                  if (sent) {
                                    widget.onCancelFriendRequest(widget.trail.authorId);
                                  } else {
                                    AppFeedback.success();
                                    widget.onSendFriendRequest(widget.trail.authorId);
                                  }
                                },
                                child: Text(
                                  widget.myFriends.contains(widget.trail.authorId)
                                      ? '👯 Friends'
                                      : widget.mySentRequests.contains(widget.trail.authorId)
                                          ? '↩️ Cancel'
                                          : '🤝 Add Friend',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Group hikes
                    if (_events.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('📅 Upcoming Group Hikes',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final e in _events) _eventCard(e),
                    ],

                    // Trail details card
                    const SizedBox(height: 16),
                    const Text('📋 Trail Details',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _infoLine('📍', 'Location', widget.trail.name),
                            _infoLine('🥾', 'Difficulty', widget.trail.difficulty),
                            _infoLine('🚩', 'Start Point', widget.trail.transportRoute),
                            _infoLine('💰', 'Estimated Cost', widget.trail.fare),
                            if (widget.trail.travelMode.isNotEmpty)
                              _infoLine('🚌', 'Travel Mode', widget.trail.travelMode),
                            if (widget.trail.busAccess.isNotEmpty)
                              _infoLine('🚏', 'Bus Pickup From', widget.trail.busAccess),
                            if (widget.trail.duration.isNotEmpty)
                              _infoLine('⏱️', 'Duration', widget.trail.duration),
                            if (widget.trail.facilities.isNotEmpty)
                              _infoLine('🏕️', 'Facilities', widget.trail.facilities.join(', ')),
                          ],
                        ),
                      ),
                    ),

                    // Description
                    if (widget.trail.description.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('✍️ Shared Experience',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        color: colors.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.trail.description,
                            style: TextStyle(color: colors.onSecondaryContainer, height: 1.6),
                          ),
                        ),
                      ),
                    ],

                    // Action buttons
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: _shareTrail,
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            child: const Text('📤 Share'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _openMaps,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.secondary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('🗺️ Get Directions'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _openComments,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.secondary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('💬 Discussion'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _events.any((e) => e.creatorId == widget.currentUserId)
                                ? null
                                : _openCreateEvent,
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            child: Text(
                              _events.any((e) => e.creatorId == widget.currentUserId)
                                  ? '📅 Planned'
                                  : '📅 Plan Hike',
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Reviews
                    const SizedBox(height: 32),
                    const Text('⭐ Reviews & Tips',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🌟 How was Your Hike?',
                                style: TextStyle(
                                    color: colors.primary, fontWeight: FontWeight.bold)),
                            Row(children: [
                              _stars(_newRating, 28),
                              const SizedBox(width: 8),
                              Text('${_newRating.toStringAsFixed(1)}/5',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            Slider(
                              value: _newRating,
                              min: 1,
                              max: 5,
                              divisions: 40,
                              activeColor: const Color(0xFFFFB300),
                              onChanged: (v) => setState(() => _newRating = (v * 10).roundToDouble() / 10),
                            ),
                            Text(_ratingEmotion(_newRating),
                                style: TextStyle(color: colors.tertiary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reviewCtl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: '✍️ Write your tips',
                                helperText: 'Was it crowded? Hidden spots? Tough part?',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _submittingReview ? null : _postReview,
                                child: const Text('📤 Post Review'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    for (final r in _reviews)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('👤 ${r.userName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    _stars(r.rating, 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${r.rating.toStringAsFixed(1)}/5 • ${_ratingEmotion(r.rating)}',
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(r.comment),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                onPressed: () {
                  AppFeedback.tap();
                  widget.onBack();
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subcomponents ──
  Widget _hikeTrackingCard() {
    final colors = Theme.of(context).colorScheme;
    final activeHere = _tracking && _activeTrailId == widget.trail.id;
    String mainText;
    if (activeHere) {
      mainText = '⏱️ Current Hike Progress';
    } else if (_finishedDistance > 0) {
      mainText = '🏁 Hike Finished Summary';
    } else {
      mainText = '🚀 Ready to start?';
    }
    final km = activeHere ? _distance / 1000.0 : _finishedDistance / 1000.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(mainText,
                style: TextStyle(
                    color: colors.primary, fontWeight: FontWeight.bold)),
            if (activeHere || _finishedDistance > 0)
              Text(
                '${km.toStringAsFixed(3)} km',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: activeHere ? colors.tertiary : colors.primary,
                minimumSize: const Size.fromHeight(54),
              ),
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
              child: Text(
                activeHere
                    ? '🏁 End Hike & Claim XP'
                    : _finishedDistance > 0
                        ? '♻️ Reset Hike Progress'
                        : '▶️ Start Real-Time Hike',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherCard() {
    final w = _weather!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        color: colors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🌤️ Live Weather',
                        style: TextStyle(color: Colors.white.withOpacity(0.85))),
                    Text('${w.temp.toInt()}°C',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    if (w.description.isNotEmpty)
                      Text(
                        w.description.replaceFirstChar(),
                        style: const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
              ),
              if (w.icon.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: 'https://openweathermap.org/img/wn/${w.icon}@2x.png',
                  width: 72, height: 72,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventCard(HikeEvent event) {
    final colors = Theme.of(context).colorScheme;
    final isGoing = event.attendees.contains(widget.currentUserId);
    final isCreator = event.creatorId == widget.currentUserId;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🗓️ ${event.dateText}',
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                  Text('👤 Hosted by ${event.creatorName}'),
                  Text('🏃 ${event.attendees.length}/${event.maxHikers} joined',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (isCreator)
              FilledButton(
                onPressed: () async {
                  AppFeedback.warning();
                  await _db.collection('events').doc(event.id).delete();
                },
                style: FilledButton.styleFrom(backgroundColor: colors.tertiary),
                child: const Text('❌ Cancel'),
              )
            else
              FilledButton(
                onPressed: () => isGoing ? _leaveEvent(event) : _joinEvent(event),
                style: FilledButton.styleFrom(
                  backgroundColor: isGoing ? Colors.grey : colors.primary,
                ),
                child: Text(isGoing ? '🚪 Leave' : '✅ Join'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String emoji, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
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
          icon = Icons.star;
        } else if (rating > i) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
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
