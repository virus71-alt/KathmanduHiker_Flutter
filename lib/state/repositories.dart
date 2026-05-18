import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_repository_impl.dart';
import '../data/repositories/hike_event_repository_impl.dart';
import '../data/repositories/journey_repository_impl.dart';
import '../data/repositories/trail_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../data/sources/firestore_chat_source.dart';
import '../data/sources/firestore_hike_event_source.dart';
import '../data/sources/firestore_journey_source.dart';
import '../data/sources/firestore_trail_source.dart';
import '../data/sources/firestore_user_source.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/repositories/hike_event_repository.dart';
import '../domain/repositories/journey_repository.dart';
import '../domain/repositories/trail_repository.dart';
import '../domain/repositories/user_repository.dart';

/// Repository providers — stateless singletons, kept alive for the whole
/// session (non-autoDispose = keepAlive in Riverpod 2.x).
/// Override these in tests by passing fake repository implementations.

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return TrailRepositoryImpl(
    trails: FirestoreTrailSource(db),
    users: FirestoreUserSource(db, FirebaseStorage.instance),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return UserRepositoryImpl(
    users: FirestoreUserSource(db, FirebaseStorage.instance),
    trails: FirestoreTrailSource(db),
    auth: FirebaseAuth.instance,
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return ChatRepositoryImpl(
    chats: FirestoreChatSource(db),
    users: FirestoreUserSource(db, FirebaseStorage.instance),
  );
});

final hikeEventRepositoryProvider = Provider<HikeEventRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return HikeEventRepositoryImpl(
    events: FirestoreHikeEventSource(db),
  );
});

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  final db = FirebaseFirestore.instance;
  return JourneyRepositoryImpl(FirestoreJourneySource(db));
});
