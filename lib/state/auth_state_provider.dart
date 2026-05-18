import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of truth for auth state across the app.
///
/// keepAlive: auth must never drop its listener between rebuilds — losing
/// it means we miss sign-out events from other devices.
final authStateProvider = StreamProvider<User?>(
  (_) => FirebaseAuth.instance.authStateChanges(),
);
