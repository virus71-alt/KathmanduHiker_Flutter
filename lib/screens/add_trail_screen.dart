import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/image_utils.dart';
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
  final _startPoint = TextEditingController();
  final _duration = TextEditingController();
  final _busAccess = TextEditingController();
  final _extraNotes = TextEditingController();

  String _difficulty = 'Moderate';
  String _estimatedCost = 'Under Rs.500';
  String _travelMode = 'Bus';
  double _rating = 3.0;
  LatLng _pickedLocation = const LatLng(27.7172, 85.3240);
  List<File> _selectedImages = [];
  final Set<String> _facilities = {};

  bool _submitting = false;

  // Multi-choice experience answers
  final Set<String> _bestSeasons = {};
  String _crowdLevel = '';
  final Set<String> _hiddenSpots = {};
  final Set<String> _difficultParts = {};

  // Stepper state
  final PageController _pageCtl = PageController();
  int _step = 0; // 0..3

  final _difficulties = const ['Easy', 'Moderate', 'Hard', 'Challenging'];
  final _costs = const ['Under Rs.500', 'Rs.500-1500', 'Rs.1500-3000', 'Expensive'];
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
  void dispose() {
    _name.dispose();
    _startPoint.dispose();
    _duration.dispose();
    _busAccess.dispose();
    _extraNotes.dispose();
    _pageCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    AppFeedback.tap();
    final imgs = await _picker.pickMultiImage();
    if (imgs.isNotEmpty) {
      setState(() => _selectedImages = [..._selectedImages, ...imgs.map((x) => File(x.path))]);
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
    final start = _startPoint.text.trim();
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
      final urls = <String>[];
      for (final f in _selectedImages) {
        try {
          final bytes = await ImageUtils.compress(f);
          final ref =
              _storage.ref().child('trails/${const Uuid().v4()}.jpg');
          await ref.putData(bytes);
          urls.add(await ref.getDownloadURL());
        } catch (_) {
          // Skip individual failed uploads but keep going.
        }
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      String authorName = 'Anonymous Hiker';
      if (uid.isNotEmpty) {
        final doc = await _db.collection('users').doc(uid).get();
        authorName =
            (doc.data()?['displayName'] as String?) ?? authorName;
      }

      final rounded = _rating.round().clamp(1, 5);
      await _db.collection('trails').add({
        'name': name,
        'difficulty': _difficulty,
        'transportRoute': start,
        'fare': _estimatedCost,
        'food': '',
        'description': _buildExperience(),
        'userRating': rounded,
        'ratingScore': _rating,
        'travelMode': _travelMode,
        'busAccess': _busAccess.text.trim(),
        'duration': _duration.text.trim(),
        'facilities': _facilities.toList()..sort(),
        'latitude': _pickedLocation.latitude,
        'longitude': _pickedLocation.longitude,
        'imageUrls': urls,
        'isApproved': false,
        'authorId': uid,
        'authorName': authorName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (uid.isNotEmpty) {
        await _db.collection('users').doc(uid).update({
          'totalXP':
              FieldValue.increment(RankingManager.xpTrailSubmitted),
        });
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog(
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
        return _name.text.trim().isNotEmpty;
      case 1:
        return _difficulty.isNotEmpty;
      case 2:
        return _startPoint.text.trim().isNotEmpty;
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
                      child: const Text('Back'),
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
        _sectionTitle('Add Photos'),
        _sectionSubtitle(
            'Help others see what this trail looks like. You can add up to 5 photos.'),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _selectedImages.length + 1,
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
            final f = _selectedImages[i - 1];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Image.file(f, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImages.remove(f)),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
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

  // ── Step 3: Transport details (leg card + fare + duration + map) ────────
  Widget _stepTransport() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 24),
      children: [
        Text(
          'Add instructions on how to reach the starting point of this trail.',
          style: AppText.bodyMd(colors.onSurfaceVariant).copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        // Transport Leg Card
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(_modeIcon(_travelMode),
                        color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Leg 1',
                    style: AppText.labelLg(colors.onSurface)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: colors.outlineVariant, height: 1),
              const SizedBox(height: 16),

              _fieldLabel('Start Point *'),
              const SizedBox(height: 6),
              TextField(
                controller: _startPoint,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  hintText: 'e.g. Ratnapark Bus Station',
                ),
              ),

              if (_travelMode == 'Bus') ...[
                const SizedBox(height: 14),
                _fieldLabel('Bus Pickup / Boarding Stop'),
                const SizedBox(height: 6),
                TextField(
                  controller: _busAccess,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flag_outlined, size: 20),
                    hintText: 'e.g. Budhanilkantha Gate',
                  ),
                ),
              ],

              const SizedBox(height: 14),
              _fieldLabel('Estimated Fare'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _estimatedCost,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 6),
                    child: Text(
                      'NPR',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                items: _costs
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  AppFeedback.toggle();
                  setState(() => _estimatedCost = v);
                },
              ),

              const SizedBox(height: 14),
              _fieldLabel('Trail Duration'),
              const SizedBox(height: 6),
              TextField(
                controller: _duration,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.schedule_rounded, size: 20),
                  hintText: 'e.g. 4-5 Hours',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.stackMd),
        _sectionTitle('Pick the trailhead on the map'),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _pickedLocation, zoom: 12),
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
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),

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
                    Text(
                      f,
                      style: TextStyle(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
