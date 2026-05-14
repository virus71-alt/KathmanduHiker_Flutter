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
  int _listTab = 0; // 0 = Submissions (Saved), 1 = Pending (Plans)
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
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Settings', style: AppText.headlineMd(AppColors.onSurface)),
            const SizedBox(height: 12),
            _settingsTile(
              icon: Icons.emoji_events_outlined,
              label: 'My Achievements',
              onTap: () {
                AppFeedback.tap();
                Navigator.pop(sheetCtx);
                widget.onAchievementsClick();
              },
            ),
            const Divider(height: 1),
            _settingsTile(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              tint: AppColors.error,
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

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color tint = AppColors.primary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppText.labelLg(tint).copyWith(fontSize: 15)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelLabel = RankingManager.getLevelLabel(widget.userXP);
    final levelNum = RankingManager.getLevelNumber(widget.userXP);
    final nextXp = RankingManager.getNextLevelXp(widget.userXP);
    final progress = RankingManager.getLevelProgress(widget.userXP);
    final maxed = levelNum >= 100;
    final approvedCount = widget.userSubmissions.where((t) => t.isApproved).length;
    final pendingSubs =
        widget.userSubmissions.where((t) => !t.isApproved).toList();
    final approvedSubs =
        widget.userSubmissions.where((t) => t.isApproved).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackMd, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(child: _profileCard(levelLabel, approvedCount)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackMd, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(
            child: _achievementsCard(levelLabel, progress, nextXp, levelNum, maxed),
          ),
        ),
        if (_editing)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackMd, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(child: _editForm()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackMd, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(child: _detailsCard()),
          ),
        if (widget.isAdmin && !_editing)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
                AppSpacing.stackMd, AppSpacing.marginMobile, 0),
            sliver: SliverToBoxAdapter(
              child: FilledButton.icon(
                onPressed: () {
                  AppFeedback.tap();
                  widget.onAdminClick();
                },
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Admin Dashboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackMd, AppSpacing.marginMobile, 0),
          sliver: SliverToBoxAdapter(child: _listTabs(approvedSubs.length, pendingSubs.length)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile,
              AppSpacing.stackSm, AppSpacing.marginMobile, AppSpacing.stackLg),
          sliver: _listTab == 0
              ? _submissionsList(approvedSubs)
              : _submissionsList(pendingSubs, isPending: true),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chrome,
        border: Border(bottom: BorderSide(color: AppColors.chromeBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text('Profile',
                style: AppText.headlineMd(AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: _saveOrEdit,
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded,
                color: AppColors.primary),
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(String levelLabel, int approvedCount) {
    return Container(
      decoration: topoCardDecoration(radius: AppRadius.lg),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: ClipOval(
                  child: _newImage != null
                      ? Image.file(_newImage!, fit: BoxFit.cover)
                      : widget.userProfilePic.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.userProfilePic,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  color: AppColors.surfaceContainerHigh),
                              errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primaryFixed,
                                  child: const Center(
                                      child: Icon(Icons.person,
                                          size: 50, color: AppColors.primary))),
                            )
                          : Container(
                              color: AppColors.primaryFixed,
                              child: Center(
                                child: Text(
                                  widget.userName.isNotEmpty
                                      ? widget.userName[0].toUpperCase()
                                      : '?',
                                  style: AppText.headlineLg(AppColors.primary),
                                ),
                              ),
                            ),
                ),
              ),
              if (_editing)
                Positioned.fill(
                  child: Material(
                    color: Colors.black.withOpacity(0.25),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickImage,
                      child: const Icon(Icons.photo_camera_outlined,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Text(
                    levelLabel.split(' ').first,
                    style: AppText.labelSm(AppColors.primary)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.userName,
            style: AppText.headlineLg(AppColors.onSurface)
                .copyWith(fontSize: 26, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            '$levelLabel • ${widget.userLocation.isEmpty ? "Kathmandu, NP" : widget.userLocation}',
            style: AppText.bodyMd(AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _statTile('TOTAL XP', '${widget.userXP}')),
              const SizedBox(width: 12),
              Expanded(child: _statTile('TRAILS ADDED', '$approvedCount')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppText.labelSm(AppColors.onSurfaceVariant)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.headlineMd(AppColors.primary)
                .copyWith(fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _achievementsCard(
      String levelLabel, double progress, int nextXp, int levelNum, bool maxed) {
    return Material(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          widget.onAchievementsClick();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryContainer, AppColors.primary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEXT MILESTONE',
                            style: AppText.labelSm(Colors.white70)),
                        Text(levelLabel,
                            style: AppText.headlineMd(Colors.white)
                                .copyWith(fontSize: 20)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
              const SizedBox(height: 14),
              if (!maxed) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    color: AppColors.tertiaryFixed,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${widget.userXP} XP',
                        style: AppText.labelSm(Colors.white)),
                    const Spacer(),
                    Text(
                      '${nextXp - widget.userXP} XP to Lv ${levelNum + 1}',
                      style: AppText.labelSm(Colors.white),
                    ),
                  ],
                ),
              ] else
                Text('MAX LEVEL REACHED',
                    style: AppText.labelLg(Colors.white)
                        .copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _detailRow(Icons.alternate_email_rounded, widget.userEmail),
          _divider(),
          _detailRow(Icons.cake_outlined,
              widget.userDob.isEmpty ? 'Not provided' : widget.userDob),
          _divider(),
          _detailRow(
              Icons.phone_outlined,
              widget.userPhone.isEmpty ? 'Not provided' : widget.userPhone,
              trailing: Text(
                widget.userShowPhone ? 'Public' : 'Private',
                style: AppText.labelSm(AppColors.onSurfaceVariant),
              )),
          if (widget.userInsta.isNotEmpty) ...[
            _divider(),
            _detailRow(Icons.camera_alt_outlined, '@${widget.userInsta}'),
          ],
          _divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('BIO',
                style: AppText.labelSm(AppColors.primary)
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.userBio.isEmpty
                  ? 'Ready for adventure!'
                  : widget.userBio,
              style: AppText.bodyMd(AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: AppText.bodyMd(AppColors.onSurface))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 16, color: AppColors.outlineVariant);

  Widget _editForm() {
    return Container(
      decoration: topoCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: 12),
          TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('Show phone publicly')),
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
              decoration: const InputDecoration(labelText: 'Instagram')),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Display Name'),
          ),
        ],
      ),
    );
  }

  Widget _listTabs(int savedCount, int pendingCount) {
    Widget tab(String label, int count, int index) {
      final selected = _listTab == index;
      return Expanded(
        child: InkWell(
          onTap: () {
            AppFeedback.toggle();
            setState(() => _listTab = index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppText.labelLg(
                        selected ? AppColors.primary : AppColors.onSurfaceVariant)),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('My Submissions', savedCount, 0),
        tab('Pending Review', pendingCount, 1),
      ],
    );
  }

  SliverList _submissionsList(List<Trail> trails, {bool isPending = false}) {
    if (trails.isEmpty) {
      return SliverList.list(children: [
        const SizedBox(height: 24),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.terrain_rounded,
                      color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  isPending
                      ? 'No trails pending review.'
                      : 'No approved trails yet.\nTap + on Home to share one!',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd(AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ]);
    }
    return SliverList.separated(
      itemCount: trails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = trails[i];
        final imageUrl = t.imageUrls.isNotEmpty
            ? t.imageUrls[0]
            : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';
        final diff = difficultyColors(t.difficulty);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.base),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      width: 88, height: 88, color: AppColors.surfaceContainerHigh),
                  errorWidget: (_, __, ___) => Container(
                      width: 88, height: 88, color: AppColors.surfaceContainerHigh),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diff.bg,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                      ),
                      child: Text(
                        t.difficulty.toUpperCase(),
                        style: AppText.labelSm(diff.fg)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.name,
                      style: AppText.labelLg(AppColors.onSurface)
                          .copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.description.isEmpty
                          ? '${t.duration.isEmpty ? "Day trip" : t.duration} • ${t.transportRoute.isEmpty ? "Kathmandu" : t.transportRoute}'
                          : t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm(AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isPending)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  onPressed: () {
                    AppFeedback.warning();
                    widget.onDeletePending(t.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
