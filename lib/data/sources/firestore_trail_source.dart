import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trail_dto.dart';

class FirestoreTrailSource {
  final FirebaseFirestore _db;
  FirestoreTrailSource(this._db);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('trails');

  Stream<List<TrailDto>> watchApproved() => _col
      .where('isApproved', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(TrailDto.fromDoc).toList());

  Stream<List<TrailDto>> watchByAuthor(String uid) => _col
      .where('authorId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(TrailDto.fromDoc).toList());

  Stream<List<TrailDto>> watchPending() => _col
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(TrailDto.fromDoc).toList());

  Future<TrailDto?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? TrailDto.fromDoc(doc) : null;
  }

  Future<String> add(Map<String, dynamic> data) async {
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> set(String id, Map<String, dynamic> data) =>
      _col.doc(id).set(data);

  Future<void> update(String id, Map<String, dynamic> updates) =>
      _col.doc(id).update(updates);

  Future<void> delete(String id) => _col.doc(id).delete();

  // Used during account deletion — keeps community content but removes the
  // personal link. Page-size loop in case the user has many submissions.
  Future<void> anonymizeAuthor(String oldAuthorId) async {
    final snap = await _col.where('authorId', isEqualTo: oldAuthorId).get();
    for (final d in snap.docs) {
      await d.reference.update({
        'authorId': '',
        'authorName': 'Deleted user',
      });
    }
  }
}
