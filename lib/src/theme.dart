import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animal_shapes.dart' show DitherAnimalType;

/// How dot colors are chosen.
enum DitherColorMode {
  /// One color (the default; identical to the old `color` parameter).
  solid,

  /// Two colors speckled through the dots ([DitherTheme.twoToneMix] sets how
  /// much of the second color).
  twoTone,

  /// Smooth blend from [DitherTheme.primary] to [DitherTheme.secondary]
  /// along [DitherTheme.gradientAngle].
  gradient,

  /// A separate color for each body part ([DitherTheme.parts]).
  parts,
}

/// Body zones used by [DitherColorMode.parts]. Zones are found from where a
/// dot sits on the 100x100 art canvas, so they work for every animal:
/// ears = top corners, head = upper middle, sides = wings/arms/tails at the
/// edges, feet = the bottom strip, body = everything else.
enum DitherPart { body, head, ears, sides, feet }

@immutable
class DitherTheme {
  const DitherTheme({
    this.mode = DitherColorMode.solid,
    this.primary,
    this.secondary = const Color(0xFFFFB020),
    this.gradientAngle = 90,
    this.gradientSteps = 10,
    this.twoToneMix = 0.3,
    this.parts = const {},
    this.brightness,
    this.followSystem = false,
  });

  /// Base color. Null uses `DitherAnimal.color`.
  final Color? primary;
  final Color secondary;
  final DitherColorMode mode;

  /// Degrees. 90 = top to bottom, 0 = left to right.
  final double gradientAngle;
  final int gradientSteps;

  /// 0..1 share of dots that use [secondary] in two-tone mode.
  final double twoToneMix;

  /// Per-part colors for [DitherColorMode.parts]; missing parts use primary.
  final Map<DitherPart, Color> parts;

  /// [Brightness.dark] lifts every dot color so it reads on dark backgrounds.
  final Brightness? brightness;

  /// Follow the app's current light/dark theme instead of [brightness].
  final bool followSystem;

  static const solid = DitherTheme();

  /// Lightens a color for dark backgrounds, keeping its hue.
  static Color lift(Color c) {
    final h = HSLColor.fromColor(c);
    final l = (h.lightness * 0.45 + 0.42).clamp(0.55, 0.78);
    return h
        .withLightness(l)
        .withSaturation((h.saturation * 1.05).clamp(0.0, 1.0))
        .toColor();
  }

  /// The colors dots can take. [primary] is the base color; when
  /// [primaryLifted] is true it has already been lightened for dark mode.
  List<Color> palette(Color primary, bool dark, {bool primaryLifted = false}) {
    Color f(Color c) => dark ? lift(c) : c;
    final p = primaryLifted ? primary : f(primary);
    switch (mode) {
      case DitherColorMode.solid:
        return [p];
      case DitherColorMode.twoTone:
        return [p, f(secondary)];
      case DitherColorMode.gradient:
        final n = gradientSteps.clamp(2, 24);
        final s = f(secondary);
        return [for (var i = 0; i < n; i++) Color.lerp(p, s, i / (n - 1))!];
      case DitherColorMode.parts:
        return [
          for (final part in DitherPart.values)
            parts[part] == null ? p : f(parts[part]!)
        ];
    }
  }

  DitherTheme copyWith({
    DitherColorMode? mode,
    Color? primary,
    Color? secondary,
    double? gradientAngle,
    int? gradientSteps,
    double? twoToneMix,
    Map<DitherPart, Color>? parts,
    Brightness? brightness,
    bool? followSystem,
  }) =>
      DitherTheme(
        mode: mode ?? this.mode,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        gradientAngle: gradientAngle ?? this.gradientAngle,
        gradientSteps: gradientSteps ?? this.gradientSteps,
        twoToneMix: twoToneMix ?? this.twoToneMix,
        parts: parts ?? this.parts,
        brightness: brightness ?? this.brightness,
        followSystem: followSystem ?? this.followSystem,
      );

  @override
  bool operator ==(Object other) =>
      other is DitherTheme &&
      other.mode == mode &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.gradientAngle == gradientAngle &&
      other.gradientSteps == gradientSteps &&
      other.twoToneMix == twoToneMix &&
      mapEquals(other.parts, parts) &&
      other.brightness == brightness &&
      other.followSystem == followSystem;

  @override
  int get hashCode => Object.hash(
      mode,
      primary,
      secondary,
      gradientAngle,
      gradientSteps,
      twoToneMix,
      Object.hashAll(parts.entries.map((e) => Object.hash(e.key, e.value))),
      brightness,
      followSystem);
}

/// Event hooks, e.g. for haptics, sound or analytics. Every callback is
/// optional and gets the animal that fired it.
class DitherHooks {
  const DitherHooks({
    this.onBuildStart,
    this.onFormed,
    this.onDissolve,
    this.onSignatureStart,
    this.onSignaturePeak,
    this.onSignatureEnd,
    this.onPoke,
  });

  /// The dots begin to assemble.
  final void Function(DitherAnimalType animal)? onBuildStart;

  /// The animal finished forming (sparkle moment).
  final void Function(DitherAnimalType animal)? onFormed;

  /// The animal starts to dissolve.
  final void Function(DitherAnimalType animal)? onDissolve;

  /// A signature move begins / hits its main moment / finishes. These only
  /// fire while `DitherAnimal.signature` is true.
  final void Function(DitherAnimalType animal)? onSignatureStart;
  final void Function(DitherAnimalType animal)? onSignaturePeak;
  final void Function(DitherAnimalType animal)? onSignatureEnd;

  /// The user tapped the animal.
  final void Function(DitherAnimalType animal)? onPoke;

  /// Ready-made haptics: a soft tick when formed, a click when a signature
  /// starts, a strong thump on its peak. Pass [also] to add your own on top
  /// (sounds, analytics...).
  factory DitherHooks.haptics({DitherHooks? also}) => DitherHooks(
        onBuildStart: also?.onBuildStart,
        onFormed: (a) {
          HapticFeedback.lightImpact();
          also?.onFormed?.call(a);
        },
        onDissolve: also?.onDissolve,
        onSignatureStart: (a) {
          HapticFeedback.selectionClick();
          also?.onSignatureStart?.call(a);
        },
        onSignaturePeak: (a) {
          // the lion's roar deserves the heaviest buzz
          a == DitherAnimalType.lion
              ? HapticFeedback.heavyImpact()
              : HapticFeedback.mediumImpact();
          also?.onSignaturePeak?.call(a);
        },
        onSignatureEnd: also?.onSignatureEnd,
        onPoke: also?.onPoke,
      );
}
