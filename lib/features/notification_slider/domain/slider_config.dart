/// Notification-slider configuration (doc §6.3, §8.9). Serialized into the
/// `slider.config` pref as JSON; the Kotlin `SliderNotificationBuilder`
/// reads the same keys.
class SliderConfig {
  const SliderConfig({
    this.layout = 'expanded',
    this.stepPercent = 10,
    this.presets = const [0, 25, 50, 75, 100],
    this.showMute = true,
    this.showStream = true,
    this.stream = 'media',
  });

  /// `compact` (collapsed row only) or `expanded` (adds preset chips).
  final String layout;

  /// 0 = one discrete AudioManager step; else 5 or 10 (percent).
  final int stepPercent;

  final List<int> presets;
  final bool showMute;
  final bool showStream;
  final String stream;

  SliderConfig copyWith({
    String? layout,
    int? stepPercent,
    List<int>? presets,
    bool? showMute,
    bool? showStream,
    String? stream,
  }) =>
      SliderConfig(
        layout: layout ?? this.layout,
        stepPercent: stepPercent ?? this.stepPercent,
        presets: presets ?? this.presets,
        showMute: showMute ?? this.showMute,
        showStream: showStream ?? this.showStream,
        stream: stream ?? this.stream,
      );

  Map<String, dynamic> toJson() => {
        'layout': layout,
        'stepPercent': stepPercent,
        'presets': presets,
        'showMute': showMute,
        'showStream': showStream,
        'stream': stream,
      };

  factory SliderConfig.fromJson(Map<String, dynamic> json) => SliderConfig(
        layout: json['layout'] as String? ?? 'expanded',
        stepPercent: (json['stepPercent'] as num?)?.toInt() ?? 10,
        presets: (json['presets'] as List?)?.cast<int>() ??
            const [0, 25, 50, 75, 100],
        showMute: json['showMute'] as bool? ?? true,
        showStream: json['showStream'] as bool? ?? true,
        stream: json['stream'] as String? ?? 'media',
      );
}
