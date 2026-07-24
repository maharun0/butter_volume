/// Domain-level failure union (doc §14.1). Plain Dart sealed classes — no
/// codegen needed for a closed set this small.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network unavailable']);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Not authenticated']);
}

final class BillingFailure extends Failure {
  const BillingFailure(this.code, [super.message = 'Purchase failed']);

  final String code;
}

final class PlatformFailure extends Failure {
  const PlatformFailure(this.channel, this.code,
      [super.message = 'Platform call failed']);

  final String channel;
  final String code;
}

final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error']);
}
