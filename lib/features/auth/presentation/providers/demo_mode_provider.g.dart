// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$isDemoModeHash() => r'241459c8827b3e8e13cce4a6c3ade6b9f0c9bd7d';

/// Convenience provider — true when in any demo preset.
///
/// Copied from [isDemoMode].
@ProviderFor(isDemoMode)
final isDemoModeProvider = AutoDisposeProvider<bool>.internal(
  isDemoMode,
  name: r'isDemoModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isDemoModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsDemoModeRef = AutoDisposeProviderRef<bool>;
String _$demoModeNotifierHash() => r'f7912be5a9c0557dc32866c9dd52766331a8c7ea';

/// See also [DemoModeNotifier].
@ProviderFor(DemoModeNotifier)
final demoModeNotifierProvider =
    AutoDisposeNotifierProvider<DemoModeNotifier, DemoPreset>.internal(
      DemoModeNotifier.new,
      name: r'demoModeNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$demoModeNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DemoModeNotifier = AutoDisposeNotifier<DemoPreset>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
