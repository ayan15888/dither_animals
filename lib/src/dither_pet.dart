import 'package:flutter/material.dart';

import 'dither_animal.dart';

/// Dot style presets — simple names instead of [DitherDot] enum values.
enum PetDot {
  /// Classic pixelated square dots (default, fastest).
  square,

  /// Smooth round bubbles.
  round,

  /// Hexagonal honeycomb grid.
  hex,

  /// Rotated diamond points.
  diamond,
}

/// Color/theme presets for [DitherPet].
enum PetTheme {
  /// Solid single color (default).
  solid,

  /// Two colors speckled together.
  twoTone,

  /// Smooth gradient blend between two colors.
  gradient,

  /// Different color for each body part.
  parts,
}

/// Mood presets for [DitherPet.mood].
enum PetMood {
  /// Default face, as drawn.
  neutral,

  /// Big smile, lifted brows, blush.
  happy,

  /// Furrowed brows, slight frown.
  angry,

  /// Half-closed eyes, zzz floating.
  sleepy,

  /// Wide eyes, open mouth, sweat drop.
  surprised,

  /// Downturned eyes, tear drop.
  sad,

  /// One eye winks, big smile.
  wink,
}

/// A simple, easy-to-use wrapper around [DitherAnimal].
///
/// Drop any of the 50 built-in animals into your app with a single widget.
/// No need to understand [DitherTheme], [DitherHooks], or [DitherMotion] —
/// just pick an animal, a color, and a mood.
///
/// ## Minimal usage
/// ```dart
/// DitherPet(animal: DitherAnimalType.owl)
/// ```
///
/// ## Full usage
/// ```dart
/// DitherPet(
///   animal: DitherAnimalType.cat,
///   color: Colors.orange,
///   size: 160,
///   mood: PetMood.happy,
///   autoMood: true,
///   dot: PetDot.round,
///   darkMode: true,
///   haptics: true,
///   signatureMove: true,
///   loop: true,
///   onTap: () => print('Cat tapped!'),
///   onFormed: () => print('Cat appeared!'),
/// )
/// ```
class DitherPet extends StatefulWidget {
  const DitherPet({
    super.key,

    /// Which animal to show. All 50 animals are available via [DitherAnimalType].
    this.animal = DitherAnimalType.owl,

    /// Primary dot color.
    this.color = const Color(0xFF1F3BFF),

    /// Widget size in logical pixels (square). Defaults to filling parent.
    this.size,

    /// Facial expression. Ignored when [autoMood] is true.
    this.mood = PetMood.neutral,

    /// Let the animal change mood on its own as it animates.
    this.autoMood = false,

    /// Shape of the dither dots.
    this.dot = PetDot.square,

    /// Resolution — dots across. 64 is fast & sharp, 96 is the default fine-detail.
    this.resolution = 96,

    /// Dot ink density. 1.0 = default. 0.6 = light & airy. 1.4 = bold & heavy.
    this.density = 1.0,

    /// Enable dark-background mode (auto-lifts dot colors so they read on dark surfaces).
    this.darkMode = false,

    /// Enable the animal's unique signature / special move.
    this.signatureMove = true,

    /// Enable built-in haptic feedback (buzz on form, tick on tap, thump on signature peak).
    this.haptics = true,

    /// Loop the build → idle → dissolve animation continuously.
    /// Set to false to build once and stay formed.
    this.loop = true,

    /// Called when the user taps the animal.
    this.onTap,

    /// Called when the animal finishes assembling its dots.
    this.onFormed,

    /// Called when the animal's signature move starts.
    this.onSignature,

    /// Color/blending style — pick this first, then set the matching color params below.
    this.themeStyle = PetTheme.solid,

    /// Second color — used when [themeStyle] is [PetTheme.twoTone] or [PetTheme.gradient].
    ///
    /// ```dart
    /// // Two-tone: dots are speckled between [color] and [secondColor].
    /// DitherPet(
    ///   animal: DitherAnimalType.owl,
    ///   color: Colors.orange,
    ///   themeStyle: PetTheme.twoTone,
    ///   secondColor: Colors.deepPurple,
    /// )
    ///
    /// // Gradient: smooth blend from [color] → [secondColor].
    /// DitherPet(
    ///   animal: DitherAnimalType.owl,
    ///   color: Colors.blue,
    ///   themeStyle: PetTheme.gradient,
    ///   secondColor: Colors.pink,
    /// )
    /// ```
    this.secondColor = const Color(0xFFFFB020),
  });

  final DitherAnimalType animal;
  final Color color;
  final double? size;
  final PetMood mood;
  final bool autoMood;
  final PetDot dot;
  final int resolution;
  final double density;
  final bool darkMode;
  final bool signatureMove;
  final bool haptics;
  final bool loop;
  final VoidCallback? onTap;
  final VoidCallback? onFormed;
  final VoidCallback? onSignature;
  final Color secondColor;
  final PetTheme themeStyle;

  @override
  State<DitherPet> createState() => DitherPetState();
}

/// Public state for [DitherPet] — access via [GlobalKey<DitherPetState>].
///
/// ```dart
/// final key = GlobalKey<DitherPetState>();
///
/// // In build:
/// DitherPet(key: key, animal: DitherAnimalType.owl)
///
/// // Anywhere:
/// key.currentState?.replay();
/// key.currentState?.setColor(Colors.purple);
/// key.currentState?.setCells(64);
/// ```
class DitherPetState extends State<DitherPet> {
  int _replayKey = 0;

  /// Restart the build animation from the beginning.
  void replay() => setState(() => _replayKey++);

  /// Change the primary dot color at runtime without rebuilding the parent.
  void setColor(Color color) => setState(() => _color = color);
  Color? _color; // null = use widget.color

  /// Change the dot resolution (cells) at runtime.
  void setCells(int cells) => setState(() => _cells = cells);
  int? _cells; // null = use widget.resolution

  /// Change the second (blend/gradient) color at runtime.
  void setSecondColor(Color color) => setState(() => _secondColor = color);
  Color? _secondColor; // null = use widget.secondColor

  DitherDot get _dot => switch (widget.dot) {
        PetDot.square  => DitherDot.square,
        PetDot.round   => DitherDot.round,
        PetDot.hex     => DitherDot.hex,
        PetDot.diamond => DitherDot.diamond,
      };

  DitherExpression get _expr => switch (widget.mood) {
        PetMood.neutral   => DitherExpression.neutral,
        PetMood.happy     => DitherExpression.happy,
        PetMood.angry     => DitherExpression.angry,
        PetMood.sleepy    => DitherExpression.sleepy,
        PetMood.surprised => DitherExpression.surprised,
        PetMood.sad       => DitherExpression.sad,
        PetMood.wink      => DitherExpression.wink,
      };

  DitherColorMode get _colorMode => switch (widget.themeStyle) {
        PetTheme.solid    => DitherColorMode.solid,
        PetTheme.twoTone  => DitherColorMode.twoTone,
        PetTheme.gradient => DitherColorMode.gradient,
        PetTheme.parts    => DitherColorMode.parts,
      };

  DitherHooks get _hooks {
    final hasCb = widget.onTap != null ||
        widget.onFormed != null ||
        widget.onSignature != null;
    if (!widget.haptics && !hasCb) return const DitherHooks();
    final mine = DitherHooks(
      onFormed: widget.onFormed != null ? (_) => widget.onFormed!() : null,
      onSignatureStart:
          widget.onSignature != null ? (_) => widget.onSignature!() : null,
      onPoke: widget.onTap != null ? (_) => widget.onTap!() : null,
    );
    return widget.haptics ? DitherHooks.haptics(also: mine) : mine;
  }

  @override
  Widget build(BuildContext context) {
    // Runtime-overridable values take priority over widget params.
    final effectiveColor      = _color       ?? widget.color;
    final effectiveCells      = _cells       ?? widget.resolution;
    final effectiveSecondColor = _secondColor ?? widget.secondColor;

    final animal = DitherAnimal(
      key: ValueKey('${widget.animal.name}-$_replayKey'),
      animal: widget.animal,
      color: effectiveColor,
      dot: _dot,
      cells: effectiveCells,
      dotDensity: widget.density,
      motion: widget.loop ? DitherMotion.loop : DitherMotion.once,
      signature: widget.signatureMove,
      autoMood: widget.autoMood,
      expression: _expr,
      theme: DitherTheme(
        mode: _colorMode,
        secondary: effectiveSecondColor,
        brightness: widget.darkMode ? Brightness.dark : Brightness.light,
      ),
      hooks: _hooks,
    );

    if (widget.size != null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: animal,
      );
    }
    return animal;
  }
}

