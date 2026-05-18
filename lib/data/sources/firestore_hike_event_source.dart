import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hike_event_dto.dart';

class FirestoreHikeEventSource {
  final FirebaseFirestore _db;
  FirestoreHikeEventSource(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('events');

  Stream<List<HikeEventDto>> watchByTrail(String trailId) => _col
      .where('trailId', isEqualTo: trailId)
      .snapshots()
      .map((s) => s.docs.map(HikeEventDto.fromDoc).toList());

  Stream<List<HikeEventDto>> watchByAttendee(String uid) => _col
      .where('attendees', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(HikeEventDto.fromDoc).toList());

  Future<HikeEventDto?> getById(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? HikeEventDto.fromDoc(doc) : null;
  }

  Future<String> add(Map<String, dynamic> data) async {
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(String id, Map<String, dynamic> updates) =>
      _col.doc(id).update(updates);

  Future<void> delete(String id) => _col.doc(id).delete();
}
