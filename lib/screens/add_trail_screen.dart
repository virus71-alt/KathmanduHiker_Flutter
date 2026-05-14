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
  String _hiddenSpot = '';
  String _difficultPart = '';

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

  @override
  void dispose() {
    _name.dispose();
    _startPoint.dispose();
    _duration.dispose();
    _busAccess.dispose();
    _extraNotes.dispose();
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
    if (_hiddenSpot.isNotEmpty) parts.add('✨ Hidden Spot: $_hiddenSpot');
    if (_difficultPart.isNotEmpty) parts.add('⚠️ Difficult Part: $_difficultPart');
    if (_extraNotes.text.trim().isNotEmpty) parts.add('📝 Tips: ${_extraNotes.text.trim()}');
    return parts.join('\n');
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _startPoint.text.isEmpty) return;
    AppFeedback.success();
    setState(() => _submitting = true);

    final urls = <String>[];
    for (final f in _selectedImages) {
      try {
        final bytes = await ImageUtils.compress(f);
        final ref = _storage.ref().child('trails/${const Uuid().v4()}.jpg');
        await ref.putData(bytes);
        urls.add(await ref.getDownloadURL());
      } catch (_) {}
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    String authorName = 'Anonymous Hiker';
    if (uid.isNotEmpty) {
      final doc = await _db.collection('users').doc(uid).get();
      authorName = (doc.data()?['displayName'] as String?) ?? authorName;
    }

    final rounded = _rating.round().clamp(1, 5);
    await _db.collection('trails').add({
      'name': _name.text,
      'difficulty': _difficulty,
      'transportRoute': _startPoint.text,
      'fare': _estimatedCost,
      'food': '',
      'description': _buildExperience(),
      'userRating': rounded,
      'ratingScore': _rating,
      'travelMode': _travelMode,
      'busAccess': _busAccess.text,
      'duration': _duration.text,
      'facilities': _facilities.toList()..sort(),
      'latitude': _pickedLocation.latitude,
      'longitude': _pickedLocation.longitude,
      'imageUrls': urls,
      'isApproved': false,
      'authorId': uid,
      'authorName': authorName,
    });

    if (uid.isNotEmpty) {
      await _db.collection('users').doc(uid).update({
        'totalXP': FieldValue.increment(RankingManager.xpTrailSubmitted),
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
            'Your trail suggestion for ${_name.text} has been submitted for review. You earned +${RankingManager.xpTrailSubmitted} XP.'),
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('🥾 Suggest a New Trail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            widget.onBack();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _stepHeader(1, 'Photos'),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 132,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: AppColors.primary),
                        SizedBox(height: 6),
                        Text('Add photos',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                for (final f in _selectedImages)
                  Stack(
                    children: [
                      Container(
                        width: 132,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: FileImage(f), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.remove(f)),
                          child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _stepHeader(2, 'Trail Info'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Trail Name')),
          const SizedBox(height: 10),
          TextField(
              controller: _startPoint,
              decoration: const InputDecoration(labelText: 'Start Point')),
          const SizedBox(height: 14),

          _sectionLabel('🚗 How did you go?'),
          _chipRow(_modes, _travelMode, (m) {
            AppFeedback.toggle();
            setState(() => _travelMode = m);
          }),
          if (_travelMode == 'Bus') ...[
            const SizedBox(height: 10),
            TextField(
                controller: _busAccess,
                decoration: const InputDecoration(labelText: 'From where to get bus')),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _estimatedCost,
            decoration: const InputDecoration(labelText: 'Estimated Cost'),
            items: _costs.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v == null) return;
              AppFeedback.toggle();
              setState(() => _estimatedCost = v);
            },
          ),
          const SizedBox(height: 10),
          TextField(controller: _duration, decoration: const InputDecoration(labelText: 'Duration')),
          const SizedBox(height: 14),

          _sectionLabel('🥾 Difficulty Level'),
          _chipRow(_difficulties, _difficulty, (d) {
            AppFeedback.toggle();
            setState(() => _difficulty = d);
          }),
          const SizedBox(height: 14),

          _sectionLabel('📍 Location Picker'),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 12),
                onTap: (pos) => setState(() => _pickedLocation = pos),
                markers: {Marker(markerId: const MarkerId('pick'), position: _pickedLocation)},
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
          const SizedBox(height: 16),

          _sectionLabel('🏕️ Facilities'),
          Wrap(
            spacing: 8,
            children: _facilityOptions
                .map((f) => FilterChip(
                      label: Text(f),
                      selected: _facilities.contains(f),
                      onSelected: (sel) {
                        AppFeedback.toggle();
                        setState(() => sel ? _facilities.add(f) : _facilities.remove(f));
                      },
                    ))
                .toList(),
          ),

          const SizedBox(height: 22),
          _stepHeader(3, 'Experience'),
          _sectionLabel('🌟 How was Your Hike?'),
          _ratingRow(),
          const SizedBox(height: 18),

          _question('🗓️ Best Season to visit?', 'Pick one or more'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _seasons
                .map((s) => FilterChip(
                      label: Text(s),
                      selected: _bestSeasons.contains(s),
                      onSelected: (sel) {
                        AppFeedback.toggle();
                        setState(() => sel ? _bestSeasons.add(s) : _bestSeasons.remove(s));
                      },
                    ))
                .toList(),
          ),

          const SizedBox(height: 14),
          _question('👥 How crowded was it?', 'Pick the closest match'),
          _singleChoiceWrap(_crowds, _crowdLevel, (v) => setState(() => _crowdLevel = v == _crowdLevel ? '' : v)),

          const SizedBox(height: 14),
          _question('✨ Any hidden spot?', 'Tap what fits best'),
          _singleChoiceWrap(_hidden, _hiddenSpot, (v) => setState(() => _hiddenSpot = v == _hiddenSpot ? '' : v)),

          const SizedBox(height: 14),
          _question('⚠️ Any difficult part?', 'Pick the closest match'),
          _singleChoiceWrap(_difficulties2, _difficultPart,
              (v) => setState(() => _difficultPart = v == _difficultPart ? '' : v)),

          const SizedBox(height: 14),
          TextField(
            controller: _extraNotes,
            decoration: const InputDecoration(
              labelText: '✍️ Anything else? (optional)',
              helperText: 'Any quick tip you want to share with future hikers',
            ),
            minLines: 3,
            maxLines: 5,
          ),

          const SizedBox(height: 22),
          _stepHeader(4, 'Submit'),
          if (_submitting)
            const LinearProgressIndicator()
          else
            FilledButton.icon(
              icon: const Icon(Icons.check),
              onPressed: (_name.text.isEmpty || _startPoint.text.isEmpty) ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              label: const Text('🚀 Submit for Review', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stepHeader(int step, String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.primary,
            child: Text('$step',
                style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(text,
          style: TextStyle(
              color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _question(String q, String hint) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(hint, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _chipRow(List<String> opts, String selected, void Function(String) onSel) {
    return Wrap(
      spacing: 8,
      children: opts
          .map((o) => FilterChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (_) => onSel(o),
              ))
          .toList(),
    );
  }

  Widget _singleChoiceWrap(List<String> options, String selected, void Function(String) onSel) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options
          .map((o) => FilterChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (_) {
                  AppFeedback.toggle();
                  onSel(o);
                },
              ))
          .toList(),
    );
  }

  Widget _ratingRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              _rating >= i ? Icons.star : (_rating > i - 1 ? Icons.star_half : Icons.star_border),
              color: const Color(0xFFFFB300),
              size: 30,
            ),
          const SizedBox(width: 10),
          Text('${_rating.toStringAsFixed(1)}/5', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: _rating,
          min: 1,
          max: 5,
          divisions: 40,
          activeColor: const Color(0xFFFFB300),
          onChanged: (v) => setState(() => _rating = (v * 10).roundToDouble() / 10),
        ),
      ],
    );
  }
}
