/// Entitlement vocabulary — identical to the backend's (doc §6.1,
/// backend doc §8.2).
enum EntitlementStatus {
  free('free'),
  premiumMonthly('premium_monthly'),
  premiumLifetime('premium_lifetime'),
  gracePeriod('grace_period'),
  onHold('on_hold'),
  paused('paused'),
  expired('expired');

  const EntitlementStatus(this.id);

  final String id;

  static EntitlementStatus fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => EntitlementStatus.free);

  /// Grace period is treated as premium; on-hold/paused/expired are free
  /// behavior with a fix-payment banner (doc §6.1).
  bool get isPremium =>
      this == premiumMonthly || this == premiumLifetime || this == gracePeriod;

  bool get needsPaymentFix => this == gracePeriod || this == onHold;
}
