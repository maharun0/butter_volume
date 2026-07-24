/// Floating-button behavior settings (doc §8.6 Behavior section).
/// Serialized into the `overlay.behavior` pref as JSON; the overlay engine
/// receives it via the window channel.
class OverlayBehavior {
  const OverlayBehavior({
    this.stream = 'media',
    this.sensitivity = 1.0,
    this.edgeSnap = true,
    this.freePlacement = false,
    this.peekMode = false,
    this.longPressHaptic = true,
    this.hapticTicks = true,
    this.animationSpeed = 1.0,
  });

  /// Default volume stream id (doc: media default, user-switchable).
  final String stream;

  /// Drag sensitivity multiplier (0.5–1.5; 1.0 = full range over 60% of
  /// screen height, doc §6.2.2).
  final double sensitivity;

  final bool edgeSnap;
  final bool freePlacement;
  final bool peekMode;
  final bool longPressHaptic;
  final bool hapticTicks;
  final double animationSpeed;

  OverlayBehavior copyWith({
    String? stream,
    double? sensitivity,
    bool? edgeSnap,
    bool? freePlacement,
    bool? peekMode,
    bool? longPressHaptic,
    bool? hapticTicks,
    double? animationSpeed,
  }) =>
      OverlayBehavior(
        stream: stream ?? this.stream,
        sensitivity: sensitivity ?? this.sensitivity,
        edgeSnap: edgeSnap ?? this.edgeSnap,
        freePlacement: freePlacement ?? this.freePlacement,
        peekMode: peekMode ?? this.peekMode,
        longPressHaptic: longPressHaptic ?? this.longPressHaptic,
        hapticTicks: hapticTicks ?? this.hapticTicks,
        animationSpeed: animationSpeed ?? this.animationSpeed,
      );

  Map<String, dynamic> toJson() => {
        'stream': stream,
        'sensitivity': sensitivity,
        'edgeSnap': edgeSnap,
        'freePlacement': freePlacement,
        'peekMode': peekMode,
        'longPressHaptic': longPressHaptic,
        'hapticTicks': hapticTicks,
        'animationSpeed': animationSpeed,
      };

  factory OverlayBehavior.fromJson(Map<String, dynamic> json) =>
      OverlayBehavior(
        stream: json['stream'] as String? ?? 'media',
        sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 1.0,
        edgeSnap: json['edgeSnap'] as bool? ?? true,
        freePlacement: json['freePlacement'] as bool? ?? false,
        peekMode: json['peekMode'] as bool? ?? false,
        longPressHaptic: json['longPressHaptic'] as bool? ?? true,
        hapticTicks: json['hapticTicks'] as bool? ?? true,
        animationSpeed: (json['animationSpeed'] as num?)?.toDouble() ?? 1.0,
      );
}
