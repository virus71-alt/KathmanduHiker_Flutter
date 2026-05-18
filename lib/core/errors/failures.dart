sealed class Failure {
  const Failure();
}

class NetworkFailure extends Failure {
  final String message;
  const NetworkFailure([this.message = '']);
}

class AuthFailure extends Failure {
  final String code;
  const AuthFailure([this.code = '']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

class UnknownFailure extends Failure {
  final Object? error;
  const UnknownFailure([this.error]);
}
