import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/slider_config.dart';

/// Slider config with live write-through: changes re-render the real
/// notification immediately when the service is active (doc §8.9).
class SliderConfigController extends Notifier<SliderConfig> {
  @override
  SliderConfig build() {
    final raw = ref.watch(settingsRepositoryProvider).sliderConfigJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        return SliderConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return const SliderConfig();
  }

  Future<void> update(SliderConfig Function(SliderConfig) mutate) async {
    state = mutate(state);
    await ref
        .read(settingsRepositoryProvider)
        .setSliderConfigJson(jsonEncode(state.toJson()));
    try {
      await ref.read(sliderChannelProvider).refresh();
    } catch (_) {}
  }
}

final sliderConfigProvider =
    NotifierProvider<SliderConfigController, SliderConfig>(
        SliderConfigController.new);
