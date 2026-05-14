import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/trail.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/ranking_manager.dart';

class ProfileScreen extends StatefulWidget {
  final List<Trail> userSubmissions;
  final bool isAdmin;
  final String userName;
  final String userEmail;
  final String userDob;
  final String userBio;
  final String userLocation;
  final String userPhone;
  final String userInsta;
  final bool userShowPhone;
  final String userProfilePic;
  final int userXP;
  final String hikerLevel;
  final VoidCallback onLogout;
  final VoidCallback onAdminClick;
  final VoidCallback onAchievementsClick;
  final Future<void> Function({
    required String name,
    required String bio,
    required String location,
    required String phone,
    required String insta,
    required bool showPhone,
    File? newImage,
  }) onUpdateProfile;
  final Future<void> Function(String trailId) onDeletePending;

  const ProfileScreen({
    super.key,
    required this.userSubmissions,
    required this.isAdmin,
    required this.userName,
    required this.userEmail,
    required this.userDob,
    required this.userBio,
    required this.userLocation,
    required this.userPhone,
    required this.userInsta,
    required this.userShowPhone,
    required this.userProfilePic,
    required this.userXP,
    required this.hikerLevel,
    required this.onLogout,
    required this.onAdminClick,
    required this.onAchievementsClick,
    required this.onUpdateProfile,
    required this.onDeletePending,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  File? _newImage;
  final _picker = ImagePicker();

  late TextEditingController _name;
  late TextEditingController _bio;
  late TextEditingController _location;
  late TextEditingController _phone;
  late TextEditingController _insta;
  late bool _showPhone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.userName);
    _bio = TextEditingController(text: widget.userBio);
    _location = TextEditingController(text: widget.userLocation);
    _phone = TextEditingController(text: widget.userPhone);
    _insta = TextEditingController(text: widget.userInsta);
    _showPhone = widget.userShowPhone;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _name.text = widget.userName;
      _bio.text = widget.userBio;
      _location.text = widget.userLocation;
      _phone.text = widget.userPhone;
      _insta.text = widget.userInsta;
      _showPhone = widget.userShowPhone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    _phone.dispose();
    _insta.dispose();
    super.dispose();
  }

  Future<void> _saveOrEdit() async {
    if (_editing) {
      AppFeedback.success();
      await widget.onUpdateProfile(
        name: _name.text,
        bio: _bio.text,
        location: _location.text,
        phone: _phone.text,
        insta: _insta.text,
        showPhone: _showPhone,
        newImage: _newImage,
      );
      if (mounted) setState(() => _newImage = null);
    } else {
      AppFeedback.tap();
    }
    if (mounted) setState(() => _editing = !_editing);
  }

  Future<void> _pickImage() async {
    AppFeedback.tap();
    final p = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null) setState(() => _newImage = File(p.path));
  }

  Future<void> _showSettings() async {
    AppFeedback.tap();
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('⚙️ Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 22)),
              title: const Text('My Achievements',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppFeedback.tap();
                Navigator.pop(sheetCtx);
                widget.onAchievementsClick();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: colors.error),
              title: Text('Log Out',
                  style: TextStyle(color: colors.error, fontWeight: FontWeight.bold)),
              onTap: () {
                AppFeedback.warning();
                Navigator.pop(sheetCtx);
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final levelLabel = RankingManager.getLevelLabel(widget.userXP);
    final levelNum = RankingManager.getLevelNumber(widget.userXP);
    final nextXp = RankingManager.getNextLevelXp(widget.userXP);
    final progress = RankingManager.getLevelProgress(widget.userXP);
    final maxed = levelNum >= 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Profile 👤',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(children: [
                IconButton(
                  onPressed: _saveOrEdit,
                  icon: Icon(_editing ? Icons.check : Icons.edit),
                ),
                IconButton(
                  onPressed: _showSettings,
                  icon: Icon(Icons.settings, color: colors.primary),
                ),
              ]),
            ],
          ),

          // Avatar + name
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _editing ? _pickImage : null,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage: _newImage != null
                            ? FileImage(_newImage!) as ImageProvider
                            : (widget.userProfilePic.isNotEmpty
                                ? CachedNetworkImageProvider(widget.userProfilePic)
                                : null),
                        child: _newImage == null && widget.userProfilePic.isEmpty
                            ? Text(
                                widget.userName.isNotEmpty
                                    ? widget.userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary),
                              )
                            : null,
                      ),
                    ),
                    if (_editing)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black26,
                          child: Icon(Icons.photo_camera, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _editing
                    ? SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _name,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Display Name'),
                        ),
                      )
                    : Column(
                        children: [
                          Text(widget.userName,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('🏅 $levelLabel',
                                style: TextStyle(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _editing
                  ? Column(
                      children: [
                        TextField(
                            controller: _location,
                            decoration:
                                const InputDecoration(labelText: '📍 Location')),
                        const SizedBox(height: 10),
                        TextField(
                            controller: _phone,
                            decoration: const InputDecoration(labelText: '📞 Phone')),
                        Row(
                          children: [
                            const Expanded(child: Text('Show Phone Publicly')),
                            Switch(
                              value: _showPhone,
                              onChanged: (v) {
                                AppFeedback.toggle();
                                setState(() => _showPhone = v);
                              },
                            ),
                          ],
                        ),
                        TextField(
                            controller: _insta,
                            decoration:
                                const InputDecoration(labelText: '📷 Instagram')),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _bio,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: '✍️ Bio'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _detailRow('📧', widget.userEmail),
                        const Divider(height: 16),
                        _detailRow('🎂', widget.userDob.isEmpty ? 'Not provided' : widget.userDob),
                        const Divider(height: 16),
                        _detailRow('📍',
                            widget.userLocation.isEmpty ? 'Kathmandu, Nepal' : widget.userLocation),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Text('📞', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    widget.userPhone.isEmpty ? 'Not provided' : widget.userPhone)),
                            Text(widget.userShowPhone ? 'Public' : 'Private',
                                style: TextStyle(
                                    fontSize: 11, color: colors.onSurfaceVariant)),
                          ],
                        ),
                        if (widget.userInsta.isNotEmpty) ...[
                          const Divider(height: 16),
                          _detailRow('📷', '@${widget.userInsta}'),
                        ],
                        const Divider(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('✍️ Bio',
                              style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(widget.userBio.isEmpty
                              ? 'Ready for adventure! 🏔️'
                              : widget.userBio),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Achievements card (clickable)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              AppFeedback.tap();
              widget.onAchievementsClick();
            },
            child: Container(
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(children: [
                    const Text('🏆', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text('My Achievements',
                        style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: colors.onPrimary),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rank 🏅',
                              style: TextStyle(
                                  color: colors.onPrimary.withOpacity(0.8),
                                  fontSize: 12)),
                          Text(levelLabel,
                              style: TextStyle(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total XP ✨',
                              style: TextStyle(
                                  color: colors.onPrimary.withOpacity(0.8),
                                  fontSize: 12)),
                          Text('${widget.userXP} XP',
                              style: TextStyle(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!maxed) ...[
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colors.onPrimary.withOpacity(0.25),
                      color: colors.onPrimary,
                      minHeight: 10,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          '${nextXp - widget.userXP} XP to Level ${levelNum + 1}',
                          style:
                              TextStyle(color: colors.onPrimary, fontSize: 11)),
                    ),
                  ] else
                    Text('MAX LEVEL REACHED! 🏆',
                        style: TextStyle(
                            color: colors.onPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Tap to view all levels and rewards →',
                      style: TextStyle(
                          color: colors.onPrimary.withOpacity(0.85), fontSize: 11)),
                ],
              ),
            ),
          ),

          if (widget.isAdmin && !_editing) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                AppFeedback.tap();
                widget.onAdminClick();
              },
              icon: const Icon(Icons.shield),
              label: const Text('Admin Dashboard 🛡️'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.secondary,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('🥾 Submissions', widget.userSubmissions.length.toString()),
              _stat('✅ Approved',
                  widget.userSubmissions.where((t) => t.isApproved).length.toString()),
            ],
          ),

          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('🥾 My Submissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          if (widget.userSubmissions.isEmpty)
            Card(
              color: AppColors.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("No trails suggested yet. 🌲 Tap '+' on Home to share one!",
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ),
            )
          else
            ...widget.userSubmissions.map((t) => Card(
                  child: ListTile(
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      t.isApproved ? '✅ Approved' : '⏳ Pending Review',
                      style: TextStyle(color: t.isApproved ? colors.primary : colors.tertiary),
                    ),
                    trailing: t.isApproved
                        ? null
                        : IconButton(
                            icon: Icon(Icons.delete, color: colors.error),
                            onPressed: () {
                              AppFeedback.warning();
                              widget.onDeletePending(t.id);
                            },
                          ),
                  ),
                )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _detailRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _stat(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
