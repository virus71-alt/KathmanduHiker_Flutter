import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/trail.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class AdminScreen extends StatelessWidget {
  final List<Trail> pendingHikes;
  final String currentAdminId;
  final Future<void> Function(String trailId) onApprove;
  final Future<void> Function(String trailId) onDelete;
  final Future<void> Function(Trail trail) onUpdate;
  final VoidCallback onBack;

  const AdminScreen({
    super.key,
    required this.pendingHikes,
    required this.currentAdminId,
    required this.onApprove,
    required this.onDelete,
    required this.onUpdate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingHikes.where((t) => !t.isApproved).toList();
    final approved = pendingHikes.where((t) => t.isApproved).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppFeedback.tap();
            onBack();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 16,
            AppSpacing.marginMobile, AppSpacing.stackLg),
        children: [
          _sectionHeader(context, 'Pending Review', pending.length,
              accent: scheme.error),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            _emptyCard(context, 'All caught up — no trails pending review.')
          else
            ...pending
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _adminCard(context, t, pending: true),
                    )),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Approved', approved.length,
              accent: scheme.primary),
          const SizedBox(height: 12),
          if (approved.isEmpty)
            _emptyCard(context, 'No approved trails yet.')
          else
            ...approved.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _adminCard(context, t, pending: false),
                )),
          const SizedBox(height: 32),
          _dangerZone(context),
        ],
      ),
    );
  }

  // ─── Developer "danger zone" — Wipe Database ────────────────────────────
  // Lets an admin reset Firestore back to a clean state in one tap. This
  // deletes all docs in `users` (except the current admin), `trails`,
  // `events`, `activities`, and `hikes`. Firebase Auth accounts are NOT
  // touched — those have to be removed manually from the Firebase console
  // because the Admin SDK is the only way to delete Auth users
  // programmatically.
  Widget _dangerZone(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.error.withValues(alpha: 0.32)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: scheme.error, size: 22),
              const SizedBox(width: 8),
              Text('Danger zone',
                  style: AppText.headlineMd(scheme.error)
                      .copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Wipe every trail, event, activity, hike, and user document from Firestore so you can start clean. Your own admin user account stays. Auth accounts must be deleted from the Firebase Console.',
            style: AppText.bodyMd(scheme.onSurfaceVariant)
                .copyWith(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _confirmWipe(context),
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            label: const Text('Wipe Database'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context) async {
    AppFeedback.warning();
    final scheme = Theme.of(context).colorScheme;
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Wipe all data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'This permanently deletes every Firestore document for this app. Type WIPE below to confirm.'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtl,
                autofocus: true,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(
                  hintText: 'WIPE',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: confirmCtl.text.trim() == 'WIPE'
                  ? () => Navigator.pop(dCtx, true)
                  : null,
              child: const Text('Wipe everything'),
            ),
          ],
        ),
      ),
    );
    confirmCtl.dispose();
    if (ok != true) return;
    if (!context.mounted) return;

    // Progress dialog while the wipe runs — intentionally fire-and-forget;
    // we dismiss it ourselves with Navigator.pop below.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));
    final result = await _wipeAllData();
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  Future<String> _wipeAllData() async {
    final db = FirebaseFirestore.instance;
    try {
      // Top-level collections to wipe in full.
      const fullWipe = [
        'trails',
        'events',
        'activities',
        'hikes',
      ];
      for (final col in fullWipe) {
        final snap = await db.collection(col).get();
        await _batchDelete(db, snap.docs.map((d) => d.reference));
      }

      // Users: drop everyone except the current admin (so the admin can keep
      // using the app). Also clear each user's notifications subcollection.
      final usersSnap = await db.collection('users').get();
      for (final u in usersSnap.docs) {
        final notifs = await u.reference.collection('notifications').get();
        await _batchDelete(db, notifs.docs.map((d) => d.reference));
      }
      final usersToDelete = usersSnap.docs
          .where((d) => d.id != currentAdminId)
          .map((d) => d.reference);
      await _batchDelete(db, usersToDelete);

      return 'Database wiped. Delete Auth accounts manually from Firebase Console.';
    } catch (e) {
      return 'Wipe failed: $e';
    }
  }

  Future<void> _batchDelete(
      FirebaseFirestore db, Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    const chunkSize = 400; // Firestore caps batches at 500 ops.
    for (var i = 0; i < list.length; i += chunkSize) {
      final batch = db.batch();
      for (final r in list.skip(i).take(chunkSize)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  Widget _sectionHeader(BuildContext context, String label, int count,
      {required Color accent}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: AppText.headlineMd(scheme.onSurface).copyWith(fontSize: 20)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text('$count',
              style: AppText.labelSm(scheme.onSurfaceVariant)
                  .copyWith(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: topoCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Text(text, style: AppText.bodyMd(scheme.onSurfaceVariant)),
    );
  }

  Widget _adminCard(BuildContext context, Trail t, {required bool pending}) {
    final scheme = Theme.of(context).colorScheme;
    final image = t.imageUrls.isNotEmpty
        ? t.imageUrls[0]
        : 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b';
    final diff = difficultyColors(context, t.difficulty);
    return Container(
      decoration: topoCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.md)),
                child: CachedNetworkImage(
                  imageUrl: image,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 140, color: scheme.surfaceContainerHigh),
                  errorWidget: (_, __, ___) =>
                      Container(height: 140, color: scheme.surfaceContainerHigh),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: diff.bg,
                    borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                  ),
                  child: Text(t.difficulty.toUpperCase(),
                      style: AppText.labelSm(diff.fg)
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: AppText.bodyLg(scheme.onSurface)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${t.fare.isEmpty ? "Free" : t.fare} · by ${t.authorName.isEmpty ? "Anonymous" : t.authorName}',
                    style: AppText.labelSm(scheme.onSurfaceVariant)),
                if (t.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyMd(scheme.onSurface)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppFeedback.warning();
                          _confirmDelete(context, t);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(color: scheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditSheet(context, t),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            AppFeedback.success();
                            onApprove(t.id);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Trail t) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trail?'),
        content: Text('Permanently remove "${t.name}"? This cannot be undone.'),
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
    if (go == true) await onDelete(t.id);
  }

  Future<void> _showEditSheet(BuildContext context, Trail t) async {
    AppFeedback.tap();
    final name = TextEditingController(text: t.name);
    final start = TextEditingController(text: t.transportRoute);
    final fare = TextEditingController(text: t.fare);
    final duration = TextEditingController(text: t.duration);
    final busAccess = TextEditingController(text: t.busAccess);
    final description = TextEditingController(text: t.description);
    String difficulty = t.difficulty;
    final difficulties = const ['Easy', 'Moderate', 'Hard', 'Challenging'];

    await showModalBottomSheet<void>(
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
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 12),
                  Text('Edit Trail',
                      style: AppText.headlineMd(scheme.onSurface)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Trail Name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: start,
                      decoration:
                          const InputDecoration(labelText: 'Start Point')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                            controller: fare,
                            decoration: const InputDecoration(
                                labelText: 'Est. Cost')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                            controller: duration,
                            decoration:
                                const InputDecoration(labelText: 'Duration')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: busAccess,
                      decoration: const InputDecoration(
                          labelText: 'Bus Pickup From')),
                  const SizedBox(height: 14),
                  Text('Difficulty',
                      style: AppText.labelLg(scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: difficulties
                        .map((d) => ChoiceChip(
                              label: Text(d),
                              selected: difficulty == d,
                              onSelected: (_) {
                                AppFeedback.toggle();
                                setSheet(() => difficulty = d);
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            AppFeedback.success();
                            await onUpdate(t.copyWith(
                              name: name.text.trim(),
                              transportRoute: start.text.trim(),
                              fare: fare.text.trim(),
                              duration: duration.text.trim(),
                              busAccess: busAccess.text.trim(),
                              description: description.text.trim(),
                              difficulty: difficulty,
                            ));
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    name.dispose();
    start.dispose();
    fare.dispose();
    duration.dispose();
    busAccess.dispose();
    description.dispose();
  }
}
