import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_notification_dto.dart';
import '../models/public_profile_dto.dart';
import '../models/user_profile_dto.dart';

class FirestoreUserSource {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  FirestoreUserSource(this._db, this._storage);

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> _notifs(String uid) =>
      _users.doc(uid).collection('notifications');

  // ─── Profile reads ──────────────────────────────────────────────────────────
  Stream<UserProfileDto> watchProfile(String uid) =>
      _users.doc(uid).snapshots().map(UserProfileDto.fromDoc);

  Future<UserProfileDto?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserProfileDto.fromDoc(doc) : null;
  }

  Future<List<PublicProfileDto>> searchByDisplayName({
    String? excludeUid,
    int limit = 50,
  }) async {
    final snap = await _users.orderBy('displayName').limit(limit).get();
    final all = snap.docs.map(PublicProfileDto.fromDoc);
    return excludeUid == null
        ? all.toList()
        : all.where((u) => u.uid != excludeUid).toList();
  }

  // ─── Profile writes ─────────────────────────────────────────────────────────
  Future<void> updateProfile(String uid, Map<String, dynamic> updates) =>
      _users.doc(uid).update(updates);

  Future<String> uploadProfilePic(String uid, File file) async {
    final ref = _storage.ref().child('profiles/$uid.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  // ─── Array field helpers ────────────────────────────────────────────────────
  Future<void> addToArray(String uid, String field, String value) =>
      _users.doc(uid).update({field: FieldValue.arrayUnion([value])});

  Future<void> removeFromArray(String uid, String field, String value) =>
      _users.doc(uid).update({field: FieldValue.arrayRemove([value])});

  Future<void> incrementXP(String uid, int amount) =>
      _users.doc(uid).update({'totalXP': FieldValue.increment(amount)});

  // ─── Notifications subcollection ────────────────────────────────────────────
  Future<void> addNotification(String uid, Map<String, dynamic> notification) =>
      _notifs(uid).add(notification);

  Stream<List<AppNotificationDto>> watchNotifications(String uid) => _notifs(uid)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AppNotificationDto.fromDoc).toList());

  Future<void> markNotificationRead(String uid, String notifId) =>
      _notifs(uid).doc(notifId).update({'isRead': true});

  Future<void> clearAllNotifications(String uid) async {
    final snap = await _notifs(uid).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // ─── Account deletion ───────────────────────────────────────────────────────
  Future<void> deleteProfileAndNotifications(String uid) async {
    final notifs = await _notifs(uid).get();
    final batch = _db.batch();
    for (final d in notifs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_users.doc(uid));
    await batch.commit();
  }

  Future<void> deleteProfilePic(String uid) async {
    try {
      await _storage.ref().child('profiles/$uid.jpg').delete();
    } catch (_) {
      // Common case: user never uploaded a pic. Swallow.
    }
  }

  // ─── Activity feed ──────────────────────────────────────────────────────────
  Future<void> addActivity(Map<String, dynamic> activity) =>
      _db.collection('activities').add(activity);
}
