import 'package:flutter/material.dart';

import 'presets.dart';

/// Icon-id → glyph mapping shared by app + overlay presentation layers.
const Map<String, IconData> kThemeIcons = {
  'volume_up': Icons.volume_up_rounded,
  'music_note': Icons.music_note_rounded,
  'graphic_eq': Icons.graphic_eq_rounded,
  'speaker': Icons.speaker_rounded,
  'headphones': Icons.headphones_rounded,
  'equalizer': Icons.equalizer_rounded,
  'tune': Icons.tune_rounded,
  'campaign': Icons.campaign_rounded,
  'surround_sound': Icons.surround_sound_rounded,
  'radio': Icons.radio_rounded,
  'album': Icons.album_rounded,
  'waves': Icons.waves_rounded,
};

IconData themeIcon(String id) => kThemeIcons[id] ?? Icons.volume_up_rounded;

/// Sanity: every advertised id resolves (checked in tests).
bool get themeIconsCoverIds =>
    kThemeIconIds.every(kThemeIcons.containsKey);
