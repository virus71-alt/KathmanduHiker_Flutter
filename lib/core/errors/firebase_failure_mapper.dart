import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'failures.dart';

/// Maps Firebase exceptions to the [Failure] sealed hierarchy. Anything
/// unrecognised falls through to [UnknownFailure] so callers always get a
/// typed Left, never a raw exception.
Failure mapFirebaseError(Object e) {
  if (e is FirebaseAuthException) {
    return AuthFailure(e.code);
  }
  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        return NetworkFailure(e.message ?? '');
      case 'not-found':
        return const NotFoundFailure();
      default:
        return UnknownFailure(e);
    }
  }
  return UnknownFailure(e);
}
