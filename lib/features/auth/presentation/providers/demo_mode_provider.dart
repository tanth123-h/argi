import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_mode_provider.g.dart';

enum DemoPreset {
  none,
  droughtLowN,     // Preset A: moisture=18%, N=15 — drought + Urea rec
  optimal,         // Preset B: all values in healthy range
  highHumidityDisease, // Preset C: moisture=85% + leaf blast
}

@riverpod
class DemoModeNotifier extends _$DemoModeNotifier {
  @override
  DemoPreset build() => DemoPreset.none;

  void enterDemo(DemoPreset preset) => state = preset;
  void exitDemo() => state = DemoPreset.none;
  void switchPreset(DemoPreset preset) => state = preset;

  bool get isActive => state != DemoPreset.none;
}

/// Convenience provider — true when in any demo preset.
@riverpod
bool isDemoMode(IsDemoModeRef ref) {
  return ref.watch(demoModeNotifierProvider) != DemoPreset.none;
}
