/// Cross-cutting signal: set before an expected external navigation
/// (permission settings round trip) so the ad manager suppresses the
/// App Open Ad on return (doc §11.3).
abstract final class NavSignals {
  static DateTime? lastExternalNav;

  static void notifyExternalNav() => lastExternalNav = DateTime.now();
}
