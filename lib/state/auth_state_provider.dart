import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state_provider.g.dart';

/// Source of truth for auth state across the app.
///
/// keepAlive: auth must never drop its listener between rebuilds — losing
/// it means we miss sign-out events from other devices.
@Riverpod(keepAlive: true)
Stream<User?> authState(Ref ref) =>
    FirebaseAuth.instance.authStateChanges();
