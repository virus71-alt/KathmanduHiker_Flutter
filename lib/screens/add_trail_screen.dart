import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/analytics.dart';
import '../domain/entities/journey.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/image_utils.dart';
import '../utils/permission_rationale.dart';
import '../services/trail_upload_service.dart';
import '../utils/ranking_manager.dart';

class AddTrailScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onBack;
  const AddTrailScreen({super.key, required this.onSuccess, required this.onBack});

  @override
  State<AddTrailScreen> createState() => _AddTrailScreenState();
}

class _AddTrailScreenState extends State<AddTrailScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _name = TextEditingController();
  final _duration = TextEditingController();
  final _busAccess = TextEditingController();
  final _extraNotes = TextEditingController();
  final _locationSearchCtl = TextEditingController();
  GoogleMapController? _mapController;
  bool _locating = false;

  String _difficulty = 'Moderate';
  String _estimatedCost = '< Rs.500';
  String _travelMode = 'Bus';
  double _rating = 3.0;
  LatLng _pickedLocation = const LatLng(27.7172, 85.3240);
  late final TrailUploadService _uploadService;
  int _mainImageIndex = 0;
  final Set<String> _facilities = {};

  bool _submitting = false;

  // Multi-choice experience answers
  final Set<String> _bestSeasons = {};
  String _crowdLevel = '';
  final Set<String> _hiddenSpots = {};
  final Set<String> _difficultParts = {};

  // Journey Builder — Step 3 structured legs
  final List<_JourneyLegDraft> _legs = [_JourneyLegDraft()];
  String _reachDifficulty = '';
  String _lastReturnVehicle = '';
  final _localGuidance = TextEditingController();

  // Stepper state
  final PageController _pageCtl = PageController();
  int _step = 0; // 0..3

  final _difficulties = const ['Easy', 'Moderate', 'Hard', 'Challenging'];
  // Compact display labels for the cost dropdown — match what's rendered on
  // the Trail Detail quick-stats card so nothing truncates ("Under Rs.....").
  final _costs = const ['< Rs.500', 'Rs.500-1.5k', 'Rs.1.5k-3k', 'Premium'];
  final _modes = const ['Bus', 'Motorcycle', 'Car', 'Cycle'];
  final _facilityOptions = const ['Parking', 'Cafe', 'Hotels', 'Toilets', 'Camping'];

  final _seasons = const ['🌸 Spring', '☀️ Summer', '🍂 Autumn', '❄️ Winter', '🌧️ Monsoon'];
  final _crowds = const ['🤫 Very Quiet', '🙂 Calm', '👥 Moderate', '🎉 Busy', '🚧 Crowded'];
  final _hidden = const [
    '🌊 Waterfall', '🏞️ Viewpoint', '🛕 Temple',
    '🪨 Cave / Rock', '🏕️ Camp Spot', '🤷 None'
  ];
  final _difficulties2 = const [
    '📈 Steep Climb', '🪨 Rocky Path', '🌫️ Slippery Section',
    '🌳 Dense Forest', '🐾 Long Walk', '👌 No Tough Part'
  ];

  // Step labels mirror the mock's right-aligned caption.
  static const _stepLabels = ['Basics', 'Difficulty', 'Transport Details', 'Final Details'];

  @override
  void initState() {
    super.initState();
    _uploadService = TrailUploadService();
    _name.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _busAccess.dispose();
    _extraNotes.dispose();
    _locationSearchCtl.dispose();
    _localGuidance.dispose();
    for (final leg in _legs) {
      leg.dispose();
    }
    _pageCtl.dispose();
    _uploadService.dispose();
    super.dispose();
  }

  // Resolves a free-text query to coordinates via the platform geocoder, then
  // animates the map + moves the marker. The query is biased to Nepal by
  // appending ", Nepal" if it isn't already country-qualified.
  Future<void> _searchLocation(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    setState(() => _locating = true);
    try {
      final biased = query.toLowerCase().contains('nepal')
          ? query
          : '$query, Nepal';
      final results = await geo.locationFromAddress(biased);
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No results for "$query".')),
          );
        }
        return;
      }
      final loc = results.first;
      final target = LatLng(loc.latitude, loc.longitude);
      setState(() => _pickedLocation = target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickImages() async {
    AppFeedback.tap();
    final imgs = await _picker.pickMultiImage();
    if (imgs.isNotEmpty) {
      for (final x in imgs) {
        _uploadService.addFile(File(x.path));
      }
    }
  }

  String _buildExperience() {
    final parts = <String>[];
    if (_bestSeasons.isNotEmpty) parts.add('🗓️ Best Season: ${_bestSeasons.join(", ")}');
    if (_crowdLevel.isNotEmpty) parts.add('👥 Crowd Level: $_crowdLevel');
    if (_hiddenSpots.isNotEmpty) {
      parts.add('✨ Hidden Spots: ${_hiddenSpots.join(", ")}');
    }
    if (_difficultParts.isNotEmpty) {
      parts.add('⚠️ Difficult Parts: ${_difficultParts.join(", ")}');
    }
    if (_extraNotes.text.trim().isNotEmpty) parts.add('📝 Tips: ${_extraNotes.text.trim()}');
    return parts.join('\n');
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final firstLeg = _legs.isNotEmpty ? _legs.first : null;
    final start = firstLeg != null
        ? (firstLeg.mode.hasFromTo ? firstLeg.from.text.trim() : firstLeg.landmark.text.trim())
        : '';
    if (name.isEmpty || start.isEmpty) {
      AppFeedback.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trail name and start point are required.')),
      );
      return;
    }
    AppFeedback.success();
    setState(() => _submitting = true);
    try {
      final baseUrls = await _uploadService.finalizeUploads();
      final urls = <String>[...baseUrls];
      if (urls.isNotEmpty && _mainImageIndex != 0 && _mainImageIndex < urls.length) {
        final mainUrl = urls.removeAt(_mainImageIndex);
        urls.insert(0, mainUrl);
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      String authorName = 'Anonymous Hiker';
      if (uid.isNotEmpty) {
        final doc = await _db.collection('users').doc(uid).get();
        authorName =
            (doc.data()?['displayName'] as String?) ?? authorName;
      }

      final rounded = _rating.round().clamp(1, 5);

      // Derive backward-compat flat fields from structured legs.
      final firstLeg = _legs.isNotEmpty ? _legs.first : null;
      final legEntities = _legs.map((d) => d.toEntity().toMap()).toList();
      final totalFareMin = _legs.fold(0, (s, l) => s + l.fareMin);
      final totalFareMax = _legs.fold(0, (s, l) => s + l.fareMax);
      final fareStr = totalFareMin == 0 && totalFareMax == 0
          ? 'Free'
          : totalFareMin == totalFareMax
              ? 'Rs $totalFareMin'
              : 'Rs $totalFareMin–$totalFareMax';
      final totalDur = _legs.fold(0, (s, l) => s + l.durationMin);
      final durStr = totalDur == 0
          ? ''
          : totalDur < 60
              ? '${totalDur} min'
              : '${totalDur ~/ 60}h ${totalDur % 60 == 0 ? '' : '${totalDur % 60}m'}'.trim();

      await _db.collection('trails').add({
        'name': name,
        'difficulty': _difficulty,
        // Legacy flat fields — auto-derived from structured legs for old readers.
        'transportRoute': firstLeg?.mode.hasFromTo == true
            ? firstLeg!.from.text.trim()
            : firstLeg?.landmark.text.trim() ?? start,
        'fare': fareStr,
        'food': '',
        'description': _buildExperience(),
        'userRating': rounded,
        'ratingScore': _rating,
        'travelMode': firstLeg?.mode.label ?? _travelMode,
        'busAccess': firstLeg?.mode.hasFromTo == true
            ? firstLeg!.to.text.trim()
            : '',
        'duration': durStr.isEmpty ? _duration.text.trim() : durStr,
        'facilities': _facilities.toList()..sort(),
        'latitude': _pickedLocation.latitude,
        'longitude': _pickedLocation.longitude,
        'imageUrls': urls,
        'isApproved': false,
        'authorId': uid,
        'authorName': authorName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        // Structured journey data — consumed by TrailDetailScreen journey section.
        'journeyLegs': legEntities,
        'reachDifficulty': _reachDifficulty,
        'lastReturnVehicle': _lastReturnVehicle,
        'localGuidance': _localGuidance.text.trim(),
      });

      if (uid.isNotEmpty) {
        await _db.collection('users').doc(uid).update({
          'totalXP':
              FieldValue.increment(RankingManager.xpTrailSubmitted),
        });
      }
      Analytics.trailSubmitted();

      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Trail submitted 🎉'),
          content: Text(
              'Your trail suggestion for $name has been submitted for review. You earned +${RankingManager.xpTrailSubmitted} XP.'),
          actions: [
            FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSuccess();
                },
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit trail: $e')),
      );
    }
  }

  // ── Step navigation ────────────────────────────────────────────────────
  bool _canAdvance() {
    switch (_step) {
      case 0:
        // Photo is now mandatory — the trail card on the home grid loads
        // imageUrls[0], so allowing no-photo submissions left the feed
        // showing a stock fallback. Require at least one upload.
        return _name.text.trim().isNotEmpty && _uploadService.tasks.isNotEmpty;
      case 1:
        return _difficulty.isNotEmpty;
      case 2:
        // At least one leg with a from-location (or landmark for Walk)
        return _legs.isNotEmpty &&
            (_legs.first.mode.hasFromTo
                ? _legs.first.from.text.trim().isNotEmpty
                : _legs.first.landmark.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  void _goTo(int next) {
    AppFeedback.tap();
    setState(() => _step = next);
    _pageCtl.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleBack() {
    if (_step == 0) {
      widget.onBack();
      return;
    }
    _goTo(_step - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              _progressBar(),
              Expanded(
                child: PageView(
                  controller: _pageCtl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    _stepBasics(),
                    _stepDifficulty(),
                    _stepTransport(),
                    _stepFinalDetails(),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar (back + centered title) ─────────────────────────────────────
  Widget _topBar() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.touchTarget,
              height: AppSpacing.touchTarget,
              child: InkResponse(
                radius: 22,
                onTap: _handleBack,
                child: Icon(Icons.arrow_back_rounded,
                    color: colors.primary, size: 24),
              ),
            ),
            Expanded(
              child: Text(
                'Suggest a Trail',
                textAlign: TextAlign.center,
                style: AppText.headlineMd(colors.primary)
                    .copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: AppSpacing.touchTarget),
          ],
        ),
      ),
    );
  }

  // ── Progress bar — 4 segments + caption row ─────────────────────────────
  Widget _progressBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_step + 1} of 4',
                style: AppText.labelSm(colors.primary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _stepLabels[_step],
                style: AppText.labelSm(colors.onSurfaceVariant)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sticky bottom footer (Back / Next or Submit) ────────────────────────
  Widget _footer() {
    final colors = Theme.of(context).colorScheme;
    final isLast = _step == 3;
    final advanceOk = _canAdvance();
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(),
            )
          else if (isLast)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.publish_rounded, size: 22),
                label: const Text('Submit for Review'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goTo(_step - 1),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: _step == 0 ? 1 : 2,
                  child: FilledButton.icon(
                    onPressed: advanceOk ? () => _goTo(_step + 1) : null,
                    icon: const SizedBox.shrink(),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Next: ${_stepLabels[_step + 1]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      disabledBackgroundColor: colors.surfaceContainerHigh,
                      disabledForegroundColor: colors.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Step 1: Basics (photos + name + travel modes) ───────────────────────
  Widget _stepBasics() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 24),
      children: [
        _sectionTitle('Add Photos *'),
        _sectionSubtitle(
            'At least one photo is required so other hikers can see the trail. You can add up to 5.'),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: _uploadService,
          builder: (context, _) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _uploadService.tasks.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  // Upload tile
                  return InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: DottedBorderBox(
                      color: colors.outlineVariant,
                      radius: AppRadius.lg,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded,
                                size: 30, color: colors.primary),
                            const SizedBox(height: 8),
                            Text(
                              'Upload',
                              style: AppText.labelLg(colors.primary)
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final task = _uploadService.tasks[i - 1];
                final isMain = (i - 1) == _mainImageIndex;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        decoration: BoxDecoration(
                          border: isMain ? Border.all(color: colors.primary, width: 3) : null,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Image.file(task.file, fit: BoxFit.cover),
                      ),
                    ),
                    if (task.status == UploadStatus.uploading || task.status == UploadStatus.pending)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: task.status == UploadStatus.uploading && task.progress > 0 ? task.progress : null,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    if (task.status == UploadStatus.failed)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 32),
                              onPressed: () => _uploadService.retry(task),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          final idx = i - 1;
                          _uploadService.removeFile(task);
                          setState(() {
                            if (_uploadService.tasks.isEmpty) {
                              _mainImageIndex = 0;
                            } else if (idx == _mainImageIndex) {
                              _mainImageIndex = 0; // reset to first if main is removed
                            } else if (idx < _mainImageIndex) {
                              _mainImageIndex--; // shift main index if an earlier image is removed
                            }
                          });
                        },
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    if (isMain)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('COVER', style: AppText.labelSm(colors.onPrimary).copyWith(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      )
                    else
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _mainImageIndex = i - 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Set Cover', style: AppText.labelSm(Colors.white).copyWith(fontSize: 9)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.stackLg),
        _sectionTitle('Trail Info'),
        const SizedBox(height: 10),
        _fieldLabel('Trail Name *'),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'e.g. Hidden Valley Loop',
          ),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        _sectionTitle('How did you go?'),
        _sectionSubtitle(
            'Select the mode of transport you used to reach the trailhead.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _modes.map((m) {
            final selected = _travelMode == m;
            return _modeChip(
              icon: _modeIcon(m),
              label: m,
              selected: selected,
              onTap: () {
                AppFeedback.toggle();
                setState(() => _travelMode = m);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _modeIcon(String m) {
    switch (m) {
      case 'Bus':
        return Icons.directions_bus_rounded;
      case 'Motorcycle':
        return Icons.two_wheeler_rounded;
      case 'Car':
        return Icons.directions_car_rounded;
      case 'Cycle':
        return Icons.pedal_bike_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }

  Widget _modeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? colors.onPrimary : colors.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Difficulty (vertical stacked cards) ─────────────────────────
  Widget _stepDifficulty() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 24),
      children: [
        Text('Difficulty Level',
            style: AppText.headlineLg(colors.onSurface).copyWith(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          'Select the difficulty level that best describes this trail to help future trekkers prepare.',
          style: AppText.bodyMd(colors.onSurfaceVariant).copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        for (final d in _difficulties) ...[
          _difficultyCard(d),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _difficultyCard(String level) {
    final colors = Theme.of(context).colorScheme;
    final selected = _difficulty == level;
    final info = _difficultyInfo(level);
    return InkWell(
      onTap: () {
        AppFeedback.toggle();
        setState(() => _difficulty = level);
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.06 : 0.03),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Faint watermark icon bottom-right
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.06,
                child: Icon(info.icon, size: 100, color: info.tint),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: info.tint.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(info.icon, color: info.tint, size: 26),
                    ),
                    const Spacer(),
                    // Selection indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? colors.primary : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded,
                              size: 16, color: colors.onPrimary)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  level,
                  style: AppText.headlineMd(
                          selected ? colors.onPrimaryContainer : colors.onSurface)
                      .copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  info.description,
                  style: AppText.bodyMd(selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant)
                      .copyWith(height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color tint, String description}) _difficultyInfo(String level) {
    final scheme = Theme.of(context).colorScheme;
    switch (level) {
      case 'Easy':
        return (
          icon: Icons.directions_walk_rounded,
          tint: const Color(0xFF82997E),
          description:
              'Relatively flat, well-maintained paths. Suitable for beginners and families.',
        );
      case 'Moderate':
        return (
          icon: Icons.hiking_rounded,
          tint: const Color(0xFFD48B55),
          description:
              'Uneven terrain, moderate elevation changes. Requires some fitness.',
        );
      case 'Hard':
        return (
          icon: Icons.landscape_rounded,
          tint: const Color(0xFF7B8B9A),
          description:
              'Steep ascents, rugged trails. Good physical fitness required.',
        );
      case 'Challenging':
      default:
        return (
          icon: Icons.terrain_rounded,
          tint: scheme.error,
          description:
              'Extreme elevation, technical sections. For experienced trekkers only.',
        );
    }
  }

  // ── Step 3: Journey Builder ───────────────────────────────────────────────

  static const _commonLocations = [
    'Ratnapark', 'Kalanki', 'Gongabu', 'Chabahil', 'Lagankhel',
    'Balkhu', 'Koteshwor', 'Budhanilkantha', 'Maharajgunj',
    'Boudha', 'Patan', 'Bhaktapur', 'Kirtipur', 'Naikap',
  ];

  static const _farePresets = [
    (label: 'Free',       min: 0,   max: 0),
    (label: 'Rs 20–30',  min: 20,  max: 30),
    (label: 'Rs 40–50',  min: 40,  max: 50),
    (label: 'Rs 80–100', min: 80,  max: 100),
    (label: 'Rs 150–200',min: 150, max: 200),
    (label: 'Rs 300+',   min: 300, max: 500),
  ];

  static const _durationPresets = [
    (label: '10m', min: 10),
    (label: '15m', min: 15),
    (label: '30m', min: 30),
    (label: '45m', min: 45),
    (label: '1h',  min: 60),
    (label: '1.5h',min: 90),
    (label: '2h+', min: 120),
  ];

  static const _reachOptions = [
    'Easy', 'Confusing', 'Multiple vehicles', 'No public transport', 'Remote',
  ];

  static const _returnTimePresets = [
    '4:00 PM', '5:00 PM', '5:30 PM', '6:00 PM', '7:00 PM',
  ];

  IconData _transportIcon(TransportMode m) => switch (m) {
        TransportMode.bus            => Icons.directions_bus_rounded,
        TransportMode.micro          => Icons.airport_shuttle_rounded,
        TransportMode.tempo          => Icons.directions_transit_rounded,
        TransportMode.taxi           => Icons.local_taxi_rounded,
        TransportMode.bike           => Icons.directions_bike_rounded,
        TransportMode.walk           => Icons.directions_walk_rounded,
        TransportMode.privateVehicle => Icons.directions_car_rounded,
        TransportMode.cableCar       => Icons.cable_rounded,
      };

  Widget _stepTransport() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 24),
      children: [
        Text('Journey Builder',
            style: AppText.headlineMd(colors.onSurface)
                .copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Build the route to the trailhead step by step — other hikers will thank you.',
          style: AppText.bodyMd(colors.onSurfaceVariant)
              .copyWith(height: 1.45, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.stackMd),

        // ── Leg cards ─────────────────────────────────────────────────────
        for (var i = 0; i < _legs.length; i++) ...[
          _buildLegCard(i),
          if (i < _legs.length - 1) _legConnector(),
        ],

        // Final node: trail start
        _trailStartNode(),

        const SizedBox(height: 14),

        // Add leg button
        OutlinedButton.icon(
          onPressed: () {
            AppFeedback.tap();
            setState(() => _legs.add(_JourneyLegDraft()));
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add another leg'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            side: BorderSide(color: colors.primary),
            foregroundColor: colors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),

        // ── Journey summary strip (shown when >1 leg) ─────────────────────
        if (_legs.length > 1) ...[
          const SizedBox(height: 16),
          _journeySummaryStrip(),
        ],

        // ── Reach difficulty ──────────────────────────────────────────────
        const SizedBox(height: AppSpacing.stackMd),
        _sectionTitle('How hard to reach?'),
        _sectionSubtitle('Helps hikers plan ahead.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reachOptions.map((opt) {
            final sel = _reachDifficulty == opt;
            return InkWell(
              onTap: () {
                AppFeedback.toggle();
                setState(() => _reachDifficulty = sel ? '' : opt);
              },
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? colors.primary : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: sel ? colors.primary : colors.outlineVariant,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(opt,
                    style: TextStyle(
                      color: sel ? colors.onPrimary : colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ),
            );
          }).toList(),
        ),

        // ── Last return vehicle ────────────────────────────────────────────
        const SizedBox(height: AppSpacing.stackMd),
        _sectionTitle('Last return vehicle'),
        _sectionSubtitle('When does the last public transport leave?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _returnTimePresets.map((t) {
            final sel = _lastReturnVehicle == t;
            return InkWell(
              onTap: () {
                AppFeedback.toggle();
                setState(() => _lastReturnVehicle = sel ? '' : t);
              },
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? colors.primaryContainer : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: sel ? colors.primary : colors.outlineVariant,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(t,
                    style: TextStyle(
                      color: sel ? colors.onPrimaryContainer : colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ),
            );
          }).toList(),
        ),

        // ── Local guidance note ────────────────────────────────────────────
        const SizedBox(height: AppSpacing.stackMd),
        Row(children: [
          _sectionTitle('Local tip'),
          const SizedBox(width: 8),
          Icon(Icons.tips_and_updates_outlined,
              size: 18, color: colors.primary),
        ]),
        _sectionSubtitle(
            'A short hint to find the right vehicle or stop. (Optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _localGuidance,
          maxLength: 120,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '"Ask for Shivapuri gate" or "Get off at army checkpoint"',
            prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
          ),
        ),

        // ── Trailhead map (unchanged) ─────────────────────────────────────
        const SizedBox(height: AppSpacing.stackMd),
        _sectionTitle('Pick the trailhead'),
        _sectionSubtitle(
            'Type a place name or tap directly on the map to drop a pin.'),
        const SizedBox(height: 10),
        TextField(
          controller: _locationSearchCtl,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchLocation,
          decoration: InputDecoration(
            hintText: 'e.g. Shivapuri, Nagarkot, Champadevi…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _locating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.travel_explore_rounded, size: 20),
                    onPressed: () => _searchLocation(_locationSearchCtl.text),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _pickedLocation, zoom: 12),
              onMapCreated: (c) => _mapController = c,
              onTap: (pos) => setState(() => _pickedLocation = pos),
              markers: {
                Marker(
                    markerId: const MarkerId('pick'),
                    position: _pickedLocation)
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Selected: ${_pickedLocation.latitude.toStringAsFixed(5)}, ${_pickedLocation.longitude.toStringAsFixed(5)}',
            style:
                TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),

        // ── Facilities (unchanged) ─────────────────────────────────────────
        const SizedBox(height: AppSpacing.stackMd),
        _sectionTitle('Facilities Available'),
        _sectionSubtitle('Tap all that apply'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _facilityOptions.map((f) {
            final selected = _facilities.contains(f);
            return InkWell(
              onTap: () {
                AppFeedback.toggle();
                setState(() {
                  selected ? _facilities.remove(f) : _facilities.add(f);
                });
              },
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary
                      : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      size: 16,
                      color: selected ? colors.onPrimary : colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(f,
                        style: TextStyle(
                          color: selected
                              ? colors.onPrimary
                              : colors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Leg card ──────────────────────────────────────────────────────────────
  Widget _buildLegCard(int i) {
    final draft = _legs[i];
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            _legNumberBadge(i + 1, colors),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Leg ${i + 1}',
                  style: AppText.labelLg(colors.onSurface)
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (_legs.length > 1)
              GestureDetector(
                onTap: () => setState(() {
                  _legs[i].dispose();
                  _legs.removeAt(i);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.remove_circle_outline_rounded,
                      color: colors.error, size: 22),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Divider(color: colors.outlineVariant, height: 1),
          const SizedBox(height: 14),

          // Transport mode selector
          _modeSelector(draft),
          const SizedBox(height: 14),

          // From / To fields or Landmark (Walk)
          if (draft.mode.hasFromTo) ...[
            _fieldLabel('From'),
            const SizedBox(height: 6),
            TextField(
              controller: draft.from,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.trip_origin_rounded, size: 18),
                hintText: 'e.g. Ratnapark',
              ),
            ),
            const SizedBox(height: 6),
            _locationSuggestions(draft.from),
            const SizedBox(height: 12),
            _fieldLabel('To'),
            const SizedBox(height: 6),
            TextField(
              controller: draft.to,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.place_rounded, size: 18),
                hintText: 'e.g. Budhanilkantha Gate',
              ),
            ),
            const SizedBox(height: 6),
            _locationSuggestions(draft.to),
          ] else ...[
            _fieldLabel('Landmark / Direction'),
            const SizedBox(height: 6),
            TextField(
              controller: draft.landmark,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.flag_outlined, size: 18),
                hintText: 'e.g. Shivapuri Gate',
              ),
            ),
            const SizedBox(height: 6),
            _locationSuggestions(draft.landmark),
          ],

          // Fare chips (not shown for Walk)
          if (draft.mode.hasFare) ...[
            const SizedBox(height: 14),
            _fieldLabel('Fare per person'),
            const SizedBox(height: 8),
            _fareChipsRow(draft),
          ],

          // Duration chips
          const SizedBox(height: 14),
          _fieldLabel('Duration'),
          const SizedBox(height: 8),
          _durationChipsRow(draft),

          // Optional notes
          const SizedBox(height: 12),
          TextField(
            controller: draft.notes,
            maxLength: 100,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Optional note, e.g. "Get off at army checkpoint"',
              counterStyle: TextStyle(
                  fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legNumberBadge(int n, ColorScheme colors) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text('$n',
            style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );

  Widget _legConnector() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 2,
              height: 14,
              color: colors.primary.withValues(alpha: 0.35)),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: colors.primary.withValues(alpha: 0.55)),
          Container(
              width: 2,
              height: 14,
              color: colors.primary.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _trailStartNode() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.tertiary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.hiking_rounded,
              color: colors.onTertiary, size: 16),
        ),
        const SizedBox(width: 10),
        Text('Trail Start',
            style: AppText.labelLg(colors.onSurface)
                .copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _journeySummaryStrip() {
    final colors = Theme.of(context).colorScheme;
    final totalMin = _legs.fold(0, (s, l) => s + l.durationMin);
    final fareMin = _legs.fold(0, (s, l) => s + l.fareMin);
    final fareMax = _legs.fold(0, (s, l) => s + l.fareMax);
    String durStr = totalMin == 0
        ? '—'
        : totalMin < 60
            ? '${totalMin}m'
            : '${totalMin ~/ 60}h${totalMin % 60 > 0 ? ' ${totalMin % 60}m' : ''}';
    String fareStr = fareMin == 0 && fareMax == 0
        ? '—'
        : fareMin == fareMax
            ? 'Rs $fareMin'
            : 'Rs $fareMin–$fareMax';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _summaryCell('Legs', '${_legs.length}', colors),
        Container(width: 1, height: 28, color: colors.outlineVariant),
        _summaryCell('Total time', durStr, colors),
        Container(width: 1, height: 28, color: colors.outlineVariant),
        _summaryCell('Total fare', fareStr, colors),
      ]),
    );
  }

  Widget _summaryCell(String label, String val, ColorScheme colors) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: colors.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: colors.onSurfaceVariant)),
        ],
      );

  Widget _modeSelector(_JourneyLegDraft draft) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TransportMode.values.map((m) {
          final sel = draft.mode == m;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () {
                AppFeedback.toggle();
                setState(() => draft.mode = m);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? colors.primary
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: sel ? colors.primary : colors.outlineVariant,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_transportIcon(m),
                      size: 15,
                      color: sel ? colors.onPrimary : colors.onSurface),
                  const SizedBox(width: 5),
                  Text(m.label,
                      style: TextStyle(
                        color: sel ? colors.onPrimary : colors.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _locationSuggestions(TextEditingController ctl) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _commonLocations.map((loc) {
          final active = ctl.text.trim() == loc;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                AppFeedback.tap();
                setState(() => ctl.text = loc);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: active
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(loc,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? colors.primary : colors.onSurfaceVariant,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fareChipsRow(_JourneyLegDraft draft) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _farePresets.map((p) {
        final sel = draft.fareMin == p.min && draft.fareMax == p.max;
        return GestureDetector(
          onTap: () {
            AppFeedback.toggle();
            setState(() {
              draft.fareMin = p.min;
              draft.fareMax = p.max;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: sel ? colors.primary : colors.outlineVariant,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(p.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      sel ? colors.onPrimaryContainer : colors.onSurface,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _durationChipsRow(_JourneyLegDraft draft) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _durationPresets.map((p) {
        final sel = draft.durationMin == p.min;
        return GestureDetector(
          onTap: () {
            AppFeedback.toggle();
            setState(() => draft.durationMin = p.min);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: sel ? colors.primary : colors.outlineVariant,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(p.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      sel ? colors.onPrimaryContainer : colors.onSurface,
                )),
          ),
        );
      }).toList(),
    );
  }

  // ── Step 4: Final details (seasons + crowd + features + tips) ───────────
  Widget _stepFinalDetails() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 24),
      children: [
        // Rating
        _sectionTitle('How was your hike?'),
        _sectionSubtitle('Share your overall rating'),
        const SizedBox(height: 10),
        _ratingRow(),

        const SizedBox(height: AppSpacing.stackLg),
        _sectionTitle('Best Season to Visit'),
        _sectionSubtitle('Select all that apply to help others plan.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _seasons.map((s) {
            final selected = _bestSeasons.contains(s);
            return _checkPill(
              label: s,
              selected: selected,
              onTap: () {
                AppFeedback.toggle();
                setState(() {
                  selected ? _bestSeasons.remove(s) : _bestSeasons.add(s);
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.stackLg),
        _sectionTitle('How crowded was it?'),
        _sectionSubtitle('Pick the closest match.'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
          ),
          itemCount: _crowds.length,
          itemBuilder: (_, i) {
            final c = _crowds[i];
            final selected = _crowdLevel == c;
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () {
                AppFeedback.toggle();
                setState(() => _crowdLevel = selected ? '' : c);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    if (selected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.check_circle_rounded,
                            size: 18, color: colors.primary),
                      ),
                    Center(
                      child: Text(
                        c,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.stackLg),
        _sectionTitle('Trail Characteristics'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _multiSelectGroup(
                label: 'Notable Features',
                options: _hidden,
                selected: _hiddenSpots,
                exclusive: '🤷 None',
              ),
              const SizedBox(height: 12),
              Divider(color: colors.outlineVariant, height: 1),
              const SizedBox(height: 12),
              _multiSelectGroup(
                label: 'Hazards & Difficulties',
                options: _difficulties2,
                selected: _difficultParts,
                exclusive: '👌 No Tough Part',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.stackLg),
        Row(
          children: [
            _sectionTitle('Quick Tips'),
            const SizedBox(width: 8),
            Icon(Icons.lightbulb_outline_rounded,
                size: 20, color: colors.primary),
          ],
        ),
        _sectionSubtitle('Any specific advice for future hikers? (Optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _extraNotes,
          minLines: 4,
          maxLines: 6,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText:
                'e.g., Bring an extra layer, it gets windy at the summit.',
          ),
        ),
      ],
    );
  }

  Widget _ratingRow() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  _rating >= i
                      ? Icons.star_rounded
                      : (_rating > i - 1
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded),
                  color: const Color(0xFFFFB300),
                  size: 28,
                ),
              const SizedBox(width: 10),
              Text(
                '${_rating.toStringAsFixed(1)}/5',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 40,
            activeColor: const Color(0xFFFFB300),
            onChanged: (v) =>
                setState(() => _rating = (v * 10).roundToDouble() / 10),
          ),
        ],
      ),
    );
  }

  // Pill with check-circle icon — used for Best Seasons (multi-select).
  Widget _checkPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(selected),
                size: 18,
                color: selected
                    ? colors.primary
                    : colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? colors.onPrimaryContainer : colors.onSurface,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable multi-select group with "n selected" badge and exclusive option.
  Widget _multiSelectGroup({
    required String label,
    required List<String> options,
    required Set<String> selected,
    String? exclusive,
  }) {
    final colors = Theme.of(context).colorScheme;
    void toggle(String o) {
      AppFeedback.toggle();
      setState(() {
        if (selected.contains(o)) {
          selected.remove(o);
          return;
        }
        if (exclusive != null) {
          if (o == exclusive) {
            selected
              ..clear()
              ..add(o);
          } else {
            selected
              ..remove(exclusive)
              ..add(o);
          }
        } else {
          selected.add(o);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.labelLg(colors.onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (selected.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${selected.length} selected',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final isSel = selected.contains(o);
            return InkWell(
              onTap: () => toggle(o),
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      isSel ? colors.primary : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isSel ? colors.primary : colors.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSel ? Icons.check_rounded : Icons.add_rounded,
                      size: 14,
                      color: isSel ? colors.onPrimary : colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o,
                      style: TextStyle(
                        color: isSel ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Reusable section primitives ─────────────────────────────────────────
  Widget _sectionTitle(String text) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: AppText.headlineMd(colors.onSurface)
          .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
    );
  }

  Widget _sectionSubtitle(String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: AppText.bodyMd(colors.onSurfaceVariant)
            .copyWith(height: 1.4, fontSize: 13),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: AppText.labelLg(colors.onSurface)
          .copyWith(fontWeight: FontWeight.w800),
    );
  }
}

// ── Leg draft ─────────────────────────────────────────────────────────────────

class _JourneyLegDraft {
  final TextEditingController from = TextEditingController();
  final TextEditingController to = TextEditingController();
  final TextEditingController landmark = TextEditingController();
  final TextEditingController notes = TextEditingController();
  TransportMode mode = TransportMode.bus;
  int fareMin = 0;
  int fareMax = 0;
  int durationMin = 0;

  JourneyLeg toEntity() => JourneyLeg(
        from: mode.hasFromTo ? from.text.trim() : landmark.text.trim(),
        to: mode.hasFromTo ? to.text.trim() : '',
        mode: mode,
        fareMin: fareMin,
        fareMax: fareMax,
        durationMin: durationMin,
        notes: notes.text.trim(),
      );

  void dispose() {
    from.dispose();
    to.dispose();
    landmark.dispose();
    notes.dispose();
  }
}

/// Lightweight dashed-border wrapper for the photo upload tile. Flutter has
/// no built-in dashed-border so we paint it ourselves with `CustomPaint`.
class DottedBorderBox extends StatelessWidget {
  final Color color;
  final double radius;
  final Widget child;
  const DottedBorderBox({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
