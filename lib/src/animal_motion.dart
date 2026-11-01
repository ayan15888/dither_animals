import 'dart:math' as math;
import 'dart:ui';

import 'animal_shapes.dart';

/// How the dots appear (and disappear) for an animal.
enum RevealStyle {
  radial,
  bottomUp,
  topDown,
  rightToLeft,
  leftToRight,
  diagonal,
  antiDiagonal,
  spiral,
  splitX,
  splitY,
  blinds,
  scatter
}

/// Whole-body transform, in 100-space. Rotation in radians.
class BodyPose {
  const BodyPose({this.dx = 0, this.dy = 0, this.rot = 0, this.sx = 1, this.sy = 1});
  final double dx, dy, rot, sx, sy;

  static const identity = BodyPose();

  /// Combine two poses (offsets add, scales multiply).
  BodyPose plus(BodyPose o) => BodyPose(
        dx: dx + o.dx,
        dy: dy + o.dy,
        rot: rot + o.rot,
        sx: sx * o.sx,
        sy: sy * o.sy,
      );

  BodyPose scaled(double a) => BodyPose(
        dx: dx * a,
        dy: dy * a,
        rot: rot * a,
        sx: 1 + (sx - 1) * a,
        sy: 1 + (sy - 1) * a,
      );
}

/// Ease with a little overshoot (0..1 -> ~0..1.1 -> 1).
double backOut(double f, [double c1 = 1.70158]) {
  final x = f - 1;
  return 1 + (c1 + 1) * x * x * x + c1 * x * x;
}

/// A personality: how one animal builds in, idles, blinks and dissolves.
class AnimalMotion {
  const AnimalMotion({
    required this.reveal,
    required this.seconds,
    required this.buildEnd,
    required this.holdEnd,
    required this.dissolveEnd,
    required this.pivot,
    required this.pose,
    required this.warp,
    this.blinkEvery = 3.0,
    this.blinkLength = 0.2,
    this.bubbles = false,
    this.entrance = _noEntrance,
    this.landShake = 0,
    this.shadow = 26,
    this.revealCenter = const Offset(50, 52),
  });

  final RevealStyle reveal;
  final Offset revealCenter;

  /// Loop length in seconds.
  final double seconds;

  /// Loop fractions (0..1): fully built / start dissolving / fully gone.
  final double buildEnd, holdEnd, dissolveEnd;

  /// Pivot for [pose] (100-space).
  final Offset pivot;

  /// Whole-body motion at absolute time [t] seconds.
  final BodyPose Function(double t) pose;

  /// Per-dot displacement (100-space) at point x,y and time t. Lets limbs,
  /// ears, trunks and tails move independently of the body.
  final Offset Function(double x, double y, double t) warp;

  final double blinkEvery, blinkLength;
  final bool bubbles;

  /// Entrance motion while building. [f] goes 0..1 over the build.
  final BodyPose Function(double f) entrance;

  /// Horizontal shake on landing (100-space units). 0 = none.
  final double landShake;

  /// Half-width of the dotted ground shadow. 0 = no shadow.
  final double shadow;

  /// Spring squash (and optional shake) right after the animal finishes forming.
  /// [tau] = seconds since fully built.
  BodyPose settle(double tau) {
    if (tau > 1.4) return BodyPose.identity;
    final w = math.sin(tau * 22) * math.exp(-5.5 * tau);
    final shake = landShake * math.sin(tau * 70) * math.exp(-9 * tau);
    return BodyPose(sx: 1 + 0.07 * w, sy: 1 - 0.11 * w, dx: shake);
  }

  /// 0 = eyes open, 1 = closed.
  double blink(double t) {
    if (blinkEvery <= 0) return 0;
    final ph = t % blinkEvery;
    return ph < blinkLength ? math.sin(math.pi * ph / blinkLength) : 0.0;
  }

  /// Order in which a dot at 100-space (x,y) appears. [noise] in 0..1.
  double order(double x, double y, double noise) {
    double base;
    switch (reveal) {
      case RevealStyle.radial:
        final dx = x - revealCenter.dx, dy = y - revealCenter.dy;
        base = math.min(1.0, math.sqrt(dx * dx + dy * dy) / 62.0);
      case RevealStyle.bottomUp:
        base = 1 - y / 100;
      case RevealStyle.topDown:
        base = y / 100;
      case RevealStyle.rightToLeft:
        base = 1 - x / 100;
      case RevealStyle.leftToRight:
        base = x / 100;
      case RevealStyle.diagonal:
        base = (x + y) / 200;
      case RevealStyle.antiDiagonal:
        base = (x + (100 - y)) / 200;
      case RevealStyle.spiral:
        final sx = x - revealCenter.dx, sy = y - revealCenter.dy;
        final sang = (math.atan2(sy, sx) + math.pi) / (2 * math.pi);
        base = 0.55 * sang + 0.45 * math.min(1.0, math.sqrt(sx * sx + sy * sy) / 60.0);
      case RevealStyle.splitX:
        base = (x - 50).abs() / 50;
      case RevealStyle.splitY:
        base = (y - 50).abs() / 50;
      case RevealStyle.blinds:
        base = (((y / 6).floor() % 2) * 0.5) + x / 200;
      case RevealStyle.scatter:
        return noise;
    }
    return base * 0.68 + noise * 0.32;
  }

  /// Generic motion used for custom images.
  static const generic = AnimalMotion(
    reveal: RevealStyle.scatter,
    seconds: 6,
    buildEnd: 0.30,
    holdEnd: 0.72,
    dissolveEnd: 0.92,
    pivot: Offset(50, 50),
    pose: _still,
    warp: _noWarp,
    blinkEvery: 0,
  );

  static AnimalMotion of(DitherAnimalType a) => _byType[a]!;
}

BodyPose _noEntrance(double f) => BodyPose.identity;

// Owl pops in from small with a wobble.
BodyPose _owlEntrance(double f) {
  final k = 0.5 + 0.5 * backOut(f);
  return BodyPose(
      sx: k, sy: k, rot: math.sin(f * 11) * 0.28 * (1 - f), dy: (1 - f) * 10);
}

// Rabbit drops from above, accelerating.
BodyPose _rabbitEntrance(double f) => BodyPose(dy: -38 * (1 - f * f));

// Fish glides in from the right, wiggling.
BodyPose _fishEntrance(double f) =>
    BodyPose(dx: 36 * (1 - f) * (1 - f), rot: math.sin(f * 14) * 0.06 * (1 - f));

// Turtle rises slowly from below.
BodyPose _turtleEntrance(double f) => BodyPose(dy: 18 * (1 - f) * (1 - f));

// Elephant drops in heavy; landing shakes.
BodyPose _elephantEntrance(double f) => BodyPose(dy: -32 * (1 - f * f));

BodyPose _still(double t) => BodyPose.identity;
Offset _noWarp(double x, double y, double t) => Offset.zero;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

// ---------------------------------------------------------------------------
// Owl: blooms outward from its face, sways like a sleepy metronome, blinks.
// ---------------------------------------------------------------------------
BodyPose _owlPose(double t) => BodyPose(
      rot: math.sin(t * 1.7) * 0.075,
      dy: math.sin(t * 3.4) * 0.9,
    );

Offset _owlWarp(double x, double y, double t) {
  // Wings flutter a little.
  if (y > 40 && (x < 20 || x > 80)) {
    final side = x < 50 ? -1.0 : 1.0;
    return Offset(side * (math.sin(t * 5.5) * 0.5 + 0.5) * 2.2, 0);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Rabbit: builds from the ground up, hops with squash & stretch, ears wiggle.
// ---------------------------------------------------------------------------
BodyPose _rabbitPose(double t) {
  const period = 1.35;
  final ph = (t % period) / period;
  var dy = 0.0, sx = 1.0, sy = 1.0;
  if (ph < 0.12) {
    // anticipation: crouch
    final k = math.sin(math.pi * ph / 0.12);
    sy = 1 - 0.07 * k;
    sx = 1 + 0.05 * k;
  } else if (ph < 0.58) {
    final k = (ph - 0.12) / 0.46;
    final h = math.sin(math.pi * k);
    dy = -h * 7;
    sy = 1 + 0.07 * h;
    sx = 1 - 0.045 * h;
  } else if (ph < 0.78) {
    // landing squash
    final k = math.sin(math.pi * (ph - 0.58) / 0.20);
    sy = 1 - 0.10 * k;
    sx = 1 + 0.07 * k;
  }
  return BodyPose(dy: dy, sx: sx, sy: sy);
}

Offset _rabbitWarp(double x, double y, double t) {
  if (y < 44) {
    final w = (44 - y) / 44;
    final left = x < 50;
    final dx = math.sin(t * 6.0 + (left ? 0 : 1.7)) * 3.0 * w * w;
    return Offset(dx, 0);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Fish: swims in head-first from the right, tail whips, body bobs, bubbles.
// ---------------------------------------------------------------------------
BodyPose _fishPose(double t) => BodyPose(
      dy: math.sin(t * 1.6) * 3.0,
      dx: math.sin(t * 0.8) * 2.0,
      rot: math.sin(t * 3.2) * 0.035,
    );

Offset _fishWarp(double x, double y, double t) {
  final tail = _clamp01((70 - x) / 62);
  final amp = 0.8 + 5.5 * tail * tail;
  return Offset(0, math.sin(t * 7.5 - x * 0.10) * amp);
}

// ---------------------------------------------------------------------------
// Turtle: drifts in as scattered dots, slow float, paddles its flippers.
// ---------------------------------------------------------------------------
BodyPose _turtlePose(double t) => BodyPose(
      dy: math.sin(t * 1.1) * 2.0,
      rot: math.sin(t * 0.85) * 0.035,
    );

Offset _turtleWarp(double x, double y, double t) {
  var dx = 0.0, dy = 0.0;
  if (y > 74) {
    final s = math.sin(t * 3.6 + (x < 42 ? 0.0 : math.pi));
    dx = s * 3.0;
    dy = -math.max(0.0, s) * 2.4;
  }
  if (x > 68) dy += math.sin(t * 2.0) * 1.4; // head nods
  return Offset(dx, dy);
}

// ---------------------------------------------------------------------------
// Elephant: unrolls top-down, ears flap, trunk swings, heavy breathing.
// ---------------------------------------------------------------------------
BodyPose _elephantPose(double t) {
  final b = math.sin(t * 2.2);
  return BodyPose(sy: 1 + b * 0.022, sx: 1 - b * 0.012, dy: -b.abs() * 0.8);
}

Offset _elephantWarp(double x, double y, double t) {
  // trunk swing
  if (y > 54 && x > 38 && x < 72) {
    final w = _clamp01((y - 54) / 36);
    return Offset(math.sin(t * 3.4) * 7.0 * w * w, 0);
  }
  // ears flap outward
  if (y > 22 && y < 72) {
    if (x < 33) {
      final w = _clamp01((33 - x) / 17);
      return Offset(-(math.sin(t * 4.6) * 0.5 + 0.5) * 3.2 * w, 0);
    }
    if (x > 67) {
      final w = _clamp01((x - 67) / 17);
      return Offset((math.sin(t * 4.6) * 0.5 + 0.5) * 3.2 * w, 0);
    }
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Cat: pounces in from the left, tail swishes, ears twitch, head tilts.
// ---------------------------------------------------------------------------
BodyPose _catEntrance(double f) => BodyPose(
    dx: -42 * (1 - f) * (1 - f),
    dy: -math.sin(math.pi * f) * 16,
    rot: -0.35 * (1 - f));

BodyPose _catPose(double t) => BodyPose(
      rot: math.sin(t * 1.1) * 0.05,
      sy: 1 + math.sin(t * 2.0) * 0.015,
    );

Offset _catWarp(double x, double y, double t) {
  if (x > 62 && y > 50) {
    final w = _clamp01((x - 62) / 30);
    return Offset(math.sin(t * 3.2) * 6 * w * w, math.sin(t * 3.2 + 1) * 2 * w);
  }
  if (y < 30 && (x < 46 || x > 54)) {
    final tw = math.pow(math.max(0.0, math.sin(t * 1.3)), 10).toDouble();
    final dir = x < 50 ? 1.0 : -1.0;
    return Offset(dir * tw * 2.4 * _clamp01((30 - y) / 22), 0);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Penguin: slides in tipped over, waddles side to side, flaps its flippers.
// ---------------------------------------------------------------------------
BodyPose _penguinEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dx: -46 * e, rot: -0.9 * e);
}

BodyPose _penguinPose(double t) => BodyPose(
      rot: math.sin(t * 4.6) * 0.085,
      dx: math.sin(t * 4.6) * 0.8,
      dy: -math.sin(t * 9.2).abs() * 0.8,
    );

Offset _penguinWarp(double x, double y, double t) {
  if (y > 50 && (x < 24 || x > 76)) {
    final side = x < 50 ? -1.0 : 1.0;
    final w = _clamp01((y - 52) / 34);
    return Offset(side * (0.5 + 0.5 * math.sin(t * 6)) * 5 * w, 0);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Frog: leaps in on an arc, big hops, throat puffs between jumps.
// ---------------------------------------------------------------------------
BodyPose _frogEntrance(double f) =>
    BodyPose(dx: -44 * (1 - f), dy: -math.sin(math.pi * f) * 24);

BodyPose _frogPose(double t) {
  const period = 2.3;
  final ph = (t % period) / period;
  var dy = 0.0, sx = 1.0, sy = 1.0;
  if (ph < 0.15) {
    final k = math.sin(math.pi * ph / 0.15);
    sy = 1 - 0.09 * k;
    sx = 1 + 0.07 * k;
  } else if (ph < 0.55) {
    final k = (ph - 0.15) / 0.40;
    final h = math.sin(math.pi * k);
    dy = -h * 11;
    sy = 1 + 0.08 * h;
    sx = 1 - 0.05 * h;
  } else if (ph < 0.75) {
    final k = math.sin(math.pi * (ph - 0.55) / 0.20);
    sy = 1 - 0.12 * k;
    sx = 1 + 0.09 * k;
  }
  return BodyPose(dy: dy, sx: sx, sy: sy);
}

Offset _frogWarp(double x, double y, double t) {
  if ((x - 50).abs() < 24 && y > 58) {
    final puff = math.pow(0.5 + 0.5 * math.sin(t * 4.4), 2).toDouble();
    final w = _clamp01((y - 58) / 22);
    return Offset((x - 50) / 24 * puff * 1.6 * w, puff * 3.0 * w);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Octopus: spins up from below, jets in pulses, tentacles ripple.
// ---------------------------------------------------------------------------
BodyPose _octoEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dy: 40 * e, rot: math.sin(f * 9) * 0.35 * (1 - f), sx: 1 - 0.12 * e);
}

BodyPose _octoPose(double t) {
  final pulse = math.pow(math.max(0.0, math.sin(t * 2.4)), 3).toDouble();
  return BodyPose(
    dy: -pulse * 5 + math.sin(t * 1.3) * 1.5,
    sx: 1 - 0.05 * pulse,
    sy: 1 + 0.07 * pulse,
    rot: math.sin(t * 1.1) * 0.03,
  );
}

Offset _octoWarp(double x, double y, double t) {
  if (y > 52) {
    final w = _clamp01((y - 52) / 40);
    return Offset(math.sin(t * 5 + y * 0.16 + x * 0.08) * 3.4 * w, 0);
  }
  return Offset.zero;
}

// ---------------------------------------------------------------------------
// Bear: rolls in, then a happy dance: bounce, sway, floppy ears.
// ---------------------------------------------------------------------------
BodyPose _bearEntrance(double f) {
  final e = (1 - f);
  return BodyPose(
      dx: -48 * e * e, rot: -7 * math.pow(e, 1.6).toDouble());
}

BodyPose _bearPose(double t) {
  final b = math.sin(t * 5.2).abs();
  return BodyPose(
    rot: math.sin(t * 2.6) * 0.06,
    dy: -b * 3.5,
    sy: 1 + 0.03 * b,
    sx: 1 - 0.02 * b,
  );
}

Offset _bearWarp(double x, double y, double t) {
  if (y < 32 && (x < 34 || x > 66)) {
    final w = _clamp01((32 - y) / 14);
    return Offset(0, math.sin(t * 5.2 + (x < 50 ? 0.0 : 0.8)) * 2.2 * w);
  }
  return Offset.zero;
}

// ===========================================================================
// Batch 3
// ===========================================================================

// Lion: spirals in, mane ripples, periodic ROAR pulse.
double _roar(double t) =>
    math.pow(math.max(0.0, math.sin(t * 1.85)), 6).toDouble();

BodyPose _lionEntrance(double f) {
  final k = 0.4 + 0.6 * backOut(f);
  return BodyPose(sx: k, sy: k, dy: (1 - f) * 12);
}

BodyPose _lionPose(double t) {
  final r = _roar(t);
  return BodyPose(
      rot: math.sin(t * 0.9) * 0.03, sx: 1 + 0.05 * r, sy: 1 + 0.05 * r, dy: -r * 1.5);
}

Offset _lionWarp(double x, double y, double t) {
  final dx = x - 50, dy = y - 46;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 26) {
    final w = _clamp01((r - 26) / 14);
    final ang = math.atan2(dy, dx);
    final off = math.sin(t * 3.5 + ang * 4) * (1.6 + 3.0 * _roar(t)) * w;
    return Offset(dx / r * off, dy / r * off);
  }
  return Offset.zero;
}

// Tiger: stripes (blinds) reveal, leaps in from the right, prowls, tail + ears.
BodyPose _tigerEntrance(double f) => BodyPose(
    dx: 44 * (1 - f) * (1 - f),
    dy: -math.sin(math.pi * f) * 20,
    rot: 0.3 * (1 - f));

BodyPose _tigerPose(double t) => BodyPose(
      rot: math.sin(t * 1.6) * 0.04,
      dx: math.sin(t * 1.6) * 1.6,
      sy: 1 + math.sin(t * 3.2) * 0.012,
    );

Offset _tigerWarp(double x, double y, double t) {
  if (x > 66 && y > 58) {
    final w = _clamp01((x - 66) / 28);
    return Offset(math.sin(t * 2.8) * 6 * w * w, math.sin(t * 2.8 + 1) * 2.5 * w);
  }
  if (y < 32 && (x < 34 || x > 66)) {
    final tw = math.pow(math.max(0.0, math.sin(t * 1.1 + 1)), 10).toDouble();
    return Offset((x < 50 ? 1.0 : -1.0) * tw * 2.6 * _clamp01((32 - y) / 18), 0);
  }
  return Offset.zero;
}

// Dog: bounds in with decaying bounces, wags tail like mad, floppy ears,
// panting tongue, curious head cock.
BodyPose _dogEntrance(double f) => BodyPose(
    dx: -46 * (1 - f),
    dy: -math.sin(f * math.pi * 3).abs() * 14 * (1 - f));

BodyPose _dogPose(double t) {
  final c = math.pow(math.max(0.0, math.sin(t * 0.8)), 4).toDouble();
  return BodyPose(
      rot: math.sin(t * 2.2) * 0.03 + c * 0.14, dy: -math.sin(t * 6).abs() * 0.8);
}

Offset _dogWarp(double x, double y, double t) {
  if (x > 66 && y > 68) {
    final w = _clamp01((x - 66) / 26);
    return Offset(math.sin(t * 11) * 7 * w, 0);
  }
  if (y > 66 && y < 82 && (x - 50).abs() < 8) {
    return Offset(0, (0.5 + 0.5 * math.sin(t * 9)) * 2.2);
  }
  if (y > 26 && y < 68 && (x < 26 || x > 74)) {
    final w = _clamp01((y - 28) / 30);
    return Offset(0, math.sin(t * 3.1 + (x < 50 ? 0.0 : 1.2)) * 2.0 * w);
  }
  return Offset.zero;
}

// Panda (no rotation): rises + pops in, lazy side-to-side sway, chews, arms bob, sleepy blinks.
BodyPose _pandaEntrance(double f) {
  final k = 0.65 + 0.35 * backOut(f);
  return BodyPose(sx: k, sy: k, dy: 26 * (1 - f) * (1 - f));
}

BodyPose _pandaPose(double t) =>
    BodyPose(dx: math.sin(t * 1.3) * 2.0, dy: math.sin(t * 2.2) * 1.0);

Offset _pandaWarp(double x, double y, double t) {
  if (y > 54 && y < 74 && (x - 50).abs() < 16) {
    return Offset(0, math.sin(t * 9) * 1.1);
  }
  if (y > 66 && (x < 34 || x > 66)) {
    final w = _clamp01((y - 66) / 20);
    return Offset(math.sin(t * 4 + (x < 50 ? 0.0 : math.pi)) * 2.0 * w, 0);
  }
  return Offset.zero;
}

// Pig: trots in with little bounces, snuffles, ears flop, tail wiggles.
BodyPose _pigEntrance(double f) => BodyPose(
    dx: 44 * (1 - f), dy: -math.sin(f * math.pi * 4).abs() * 8 * (1 - f));

BodyPose _pigPose(double t) => BodyPose(
    dy: -math.sin(t * 3.2).abs() * 2.5, rot: math.sin(t * 3.2) * 0.025);

Offset _pigWarp(double x, double y, double t) {
  if (y > 56 && y < 70 && (x - 50).abs() < 16) {
    return Offset(math.sin(t * 10) * 0.5, math.sin(t * 10) * 0.9);
  }
  if (y < 40 && (x < 38 || x > 62)) {
    final w = _clamp01((40 - y) / 22);
    return Offset(0, math.sin(t * 4 + (x < 50 ? 0.0 : 1.0)) * 2.4 * w);
  }
  if (x > 76 && y > 74) return Offset(0, math.sin(t * 7) * 2.5);
  return Offset.zero;
}

// Fox: slinks in low, then pops up; big bushy tail sweep, ears swivel, sniffs.
BodyPose _foxEntrance(double f) => BodyPose(
    dx: 40 * (1 - f) * (1 - f), sy: 0.75 + 0.25 * f, sx: 1.12 - 0.12 * f);

BodyPose _foxPose(double t) => BodyPose(
    rot: math.sin(t * 1.4) * 0.05,
    dy: -math.pow(math.max(0.0, math.sin(t * 2.6)), 4).toDouble() * 1.8);

Offset _foxWarp(double x, double y, double t) {
  if (x > 66 && y > 44) {
    final w = _clamp01((x - 66) / 28);
    return Offset(math.sin(t * 2.6) * 8 * w * w, -math.cos(t * 2.6) * 3 * w);
  }
  if (y < 36) {
    final w = _clamp01((36 - y) / 26);
    return Offset(math.sin(t * 1.9 + (x < 50 ? 0.0 : math.pi)) * 2.0 * w, 0);
  }
  return Offset.zero;
}

// Monkey: swings in on a vine arc, bouncy dance, waves arms, curly tail.
BodyPose _monkeyEntrance(double f) =>
    BodyPose(dx: -40 * (1 - f), dy: -24 * (1 - f), rot: -0.5 * (1 - f));

BodyPose _monkeyPose(double t) {
  final b = math.sin(t * 3.3).abs();
  return BodyPose(rot: math.sin(t * 3.3) * 0.05, dy: -b * 3.2);
}

Offset _monkeyWarp(double x, double y, double t) {
  if (y > 66 && (x < 34 || x > 66)) {
    final w = _clamp01((y - 68) / 28);
    return Offset(math.sin(t * 6 + (x < 50 ? 0.0 : math.pi)) * 5 * w, 0);
  }
  if (x > 72 && y > 56) {
    return Offset(0, math.sin(t * 4) * 3 * _clamp01((x - 72) / 24));
  }
  return Offset.zero;
}

// Duck: paddles in, waddles fast, wing flaps, tail wiggle, QUACK (beak opens).
BodyPose _duckEntrance(double f) => BodyPose(
    dx: -46 * math.pow(1 - f, 1.5).toDouble(), dy: math.sin(f * 20) * 1.5 * (1 - f));

BodyPose _duckPose(double t) => BodyPose(
    rot: math.sin(t * 6) * 0.065, dy: -math.sin(t * 12).abs() * 0.7);

Offset _duckWarp(double x, double y, double t) {
  final q = math.pow(math.max(0.0, math.sin(t * 2.6)), 8).toDouble();
  if (x > 80 && y > 34 && y < 52) {
    return Offset(q * 1.8, (y < 42 ? -1.0 : 1.0) * q * 2.2);
  }
  if (x < 20 && y > 54) {
    return Offset(0, math.sin(t * 10) * 2.2 * _clamp01((20 - x) / 16));
  }
  if (x > 24 && x < 56 && y > 64 && y < 84) {
    return Offset(0, -math.max(0.0, math.sin(t * 5)) * 2.6);
  }
  return Offset.zero;
}

// Sheep: big high arc in (counting sheep!), boing boing, fluffy wool jiggle.
BodyPose _sheepEntrance(double f) =>
    BodyPose(dx: -48 * (1 - f), dy: -math.sin(math.pi * f) * 30);

BodyPose _sheepPose(double t) {
  final b = math.sin(t * 4.4).abs();
  return BodyPose(dy: -b * 5, sy: 1 + 0.04 * b, sx: 1 - 0.03 * b);
}

Offset _sheepWarp(double x, double y, double t) {
  final dx = x - 50, dy = y - 56;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 22) {
    final w = _clamp01((r - 22) / 14);
    final a = math.atan2(dy, dx);
    return Offset(math.sin(t * 7 + a * 3) * 1.3 * w, math.cos(t * 7 + a * 3) * 1.3 * w);
  }
  return Offset.zero;
}

// Hedgehog: unrolls from a curled ball, trots, spikes bristle & puff, sniffs.
BodyPose _hedgeEntrance(double f) {
  final k = 0.5 + 0.5 * backOut(f);
  return BodyPose(
      sx: k, sy: k, rot: -1.2 * (1 - f) * (1 - f), dx: -30 * (1 - f) * (1 - f));
}

BodyPose _hedgePose(double t) =>
    BodyPose(dx: math.sin(t * 1.2) * 3, dy: -math.sin(t * 6).abs() * 1.2);

Offset _hedgeWarp(double x, double y, double t) {
  if (x > 86) return Offset(0, math.sin(t * 8) * 1.2);
  final dx = x - 44, dy = y - 69;
  final r = math.sqrt(dx * dx + dy * dy);
  if (dy < 4 && r > 24) {
    final ang = math.atan2(dy, dx);
    final puff = math.pow(0.5 + 0.5 * math.sin(t * 2.2), 6).toDouble();
    final off = math.sin(t * 14 + ang * 5) * 0.9 + puff * 2.2;
    return Offset(dx / r * off, dy / r * off);
  }
  return Offset.zero;
}

// ===========================================================================
// Batch 4: things (not animals)
// ===========================================================================

// Sun: spins in, rays wiggle, smiles and pulses like a heartbeat.
BodyPose _sunEntrance(double f) {
  final k = 0.3 + 0.7 * backOut(f);
  return BodyPose(sx: k, sy: k, rot: -2.5 * (1 - f));
}

BodyPose _sunPose(double t) {
  final p = 1 + 0.04 * math.sin(t * 3);
  return BodyPose(sx: p, sy: p);
}

Offset _sunWarp(double x, double y, double t) {
  final dx = x - 50, dy = y - 50;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 26) {
    final w = _clamp01((r - 26) / 6);
    final a = math.sin(t * 1.2) * 0.3 * w;
    final c = math.cos(a), s = math.sin(a);
    return Offset(dx * c - dy * s - dx, dx * s + dy * c - dy);
  }
  return Offset.zero;
}

// Cloud: drifts in from the left, floats, puffs breathe, it RAINS.
BodyPose _cloudEntrance(double f) =>
    BodyPose(dx: -54 * math.pow(1 - f, 1.6).toDouble());

BodyPose _cloudPose(double t) =>
    BodyPose(dx: math.sin(t * 1.1) * 3, dy: math.sin(t * 2.0) * 1.6);

Offset _cloudWarp(double x, double y, double t) {
  if (y > 79.5) {
    final ph = x < 42 ? 0.0 : (x < 58 ? 0.35 : 0.7);
    return Offset(0, ((t * 1.2 + ph) % 1.0) * 10);
  }
  if (y < 56) {
    return Offset(0, -math.sin(t * 3 + x * 0.12) * 1.2 * _clamp01((56 - y) / 20));
  }
  return Offset.zero;
}

// Moon: swings down like a pendulum, rocks to sleep, stars twinkle.
const List<Offset> _moonStars = [Offset(76, 28), Offset(89, 56), Offset(70, 76)];

BodyPose _moonEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dy: -30 * e, rot: 0.8 * e);
}

BodyPose _moonPose(double t) => BodyPose(rot: math.sin(t * 1.3) * 0.08);

Offset _moonWarp(double x, double y, double t) {
  for (var i = 0; i < _moonStars.length; i++) {
    final c = _moonStars[i];
    final dx = x - c.dx, dy = y - c.dy;
    if (dx * dx + dy * dy < 100) {
      final k = 0.32 * math.sin(t * 4 + i * 2.1);
      return Offset(dx * k, dy * k);
    }
  }
  return Offset.zero;
}

// Star: shoots in spinning from the top-right, wobbles, tips shimmer.
BodyPose _starEntrance(double f) {
  final e = (1 - f) * (1 - f);
  final k = 0.4 + 0.6 * backOut(f);
  return BodyPose(dx: 40 * e, dy: -40 * e, rot: -6 * (1 - f), sx: k, sy: k);
}

BodyPose _starPose(double t) {
  final p = 1 + 0.06 * math.sin(t * 5);
  return BodyPose(rot: math.sin(t * 2) * 0.18, sx: p, sy: p);
}

Offset _starWarp(double x, double y, double t) {
  final dx = x - 50, dy = y - 52;
  final r = math.sqrt(dx * dx + dy * dy);
  if (r > 28) {
    final ang = math.atan2(dy, dx);
    final off = math.sin(t * 6 + ang * 5) * 1.4 * _clamp01((r - 28) / 12);
    return Offset(dx / r * off, dy / r * off);
  }
  return Offset.zero;
}

// Ghost: floats up wobbling, bobs, tail ripples, raises arms: BOO!
BodyPose _ghostEntrance(double f) => BodyPose(
    dy: 44 * (1 - f) * (1 - f), dx: math.sin(f * 12) * 4 * (1 - f));

BodyPose _ghostPose(double t) =>
    BodyPose(dy: math.sin(t * 2.2) * 4, rot: math.sin(t * 1.1) * 0.04);

Offset _ghostWarp(double x, double y, double t) {
  if (y > 78) {
    return Offset(
        math.sin(t * 5 + x * 0.2) * 2.2 * _clamp01((y - 78) / 14), 0);
  }
  if ((x < 22 || x > 78) && y > 50 && y < 72) {
    final boo = math.pow(math.max(0.0, math.sin(t * 1.4)), 4).toDouble();
    return Offset(0, -boo * 7);
  }
  return Offset.zero;
}

// Mushroom: sprouts from the ground, jelly hops, cap wobbles.
BodyPose _shroomEntrance(double f) =>
    BodyPose(sy: 0.2 + 0.8 * backOut(f), sx: 1 + 0.15 * (1 - f));

BodyPose _shroomPose(double t) {
  final a = math.sin(t * 2.5).abs();
  final land = math.pow(1 - a, 6).toDouble();
  return BodyPose(
      dy: -a * 5, sy: 1 - 0.10 * land + 0.05 * a, sx: 1 + 0.07 * land - 0.03 * a);
}

Offset _shroomWarp(double x, double y, double t) {
  if (y < 62) {
    return Offset(math.sin(t * 5 - y * 0.08) * 1.6 * _clamp01((62 - y) / 50), 0);
  }
  return Offset.zero;
}

// Cactus: pops up out of its pot, sways, arms wave, flower bobs.
BodyPose _cactusEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dy: 40 * e, sy: 1 + 0.15 * e);
}

BodyPose _cactusPose(double t) =>
    BodyPose(rot: math.sin(t * 1.5) * 0.035, sy: 1 + math.sin(t * 2.0) * 0.01);

Offset _cactusWarp(double x, double y, double t) {
  if (y < 26) return Offset(math.sin(t * 3) * 1.6 * _clamp01((26 - y) / 12), 0);
  final left = x < 30 && y < 66;
  final right = x > 70 && y < 60;
  if (left || right) {
    final w = _clamp01(((left ? 66 : 60) - y) / 28);
    return Offset(0, math.sin(t * 4.5 + (left ? 0.0 : 1.6)) * 2.2 * w);
  }
  return Offset.zero;
}

// Robot: boots up (scanlines), drops in with servo jitter, snappy head turns.
BodyPose _robotEntrance(double f) => BodyPose(
    dy: -40 * (1 - f * f), dx: math.sin(f * 40) * 1.0 * (1 - f));

BodyPose _robotPose(double t) => BodyPose(
    rot: math.pow(math.sin(t * 1.3), 3).toDouble() * 0.07,
    dy: -math.sin(t * 4).abs() * 0.8);

Offset _robotWarp(double x, double y, double t) {
  if (y < 19) {
    return Offset(math.sin(t * 8) * 1.5 * _clamp01((19 - y) / 12), 0);
  }
  if ((x < 24 || x > 76) && y > 70) {
    return Offset(0, math.sin(t * 6 + (x < 50 ? 0.0 : math.pi)) * 3);
  }
  return Offset.zero;
}

// Rocket: blasts up from below, vibrates, hovers, flame flickers.
BodyPose _rocketEntrance(double f) => BodyPose(
    dy: 70 * (1 - f) * (1 - f), rot: 0.3 * (1 - f));

BodyPose _rocketPose(double t) => BodyPose(
    dx: math.sin(t * 38) * 0.5,
    dy: math.sin(t * 2.2) * 2.5 + math.sin(t * 29) * 0.4);

Offset _rocketWarp(double x, double y, double t) {
  if (y > 74) {
    final w = _clamp01((y - 74) / 24);
    return Offset(math.sin(t * 17 + y * 0.3) * 1.8 * w,
        (math.sin(t * 21) + 1) * 0.5 * 3 * w);
  }
  return Offset.zero;
}

// Cupcake: plops from above, jelly bounce, frosting sways, cherry wiggles.
BodyPose _cupcakeEntrance(double f) => BodyPose(dy: -40 * (1 - f * f));

BodyPose _cupcakePose(double t) {
  final a = math.sin(t * 3).abs();
  final land = math.pow(1 - a, 6).toDouble();
  return BodyPose(
      dy: -a * 3, sy: 1 - 0.07 * land + 0.03 * a, sx: 1 + 0.05 * land - 0.02 * a);
}

Offset _cupcakeWarp(double x, double y, double t) {
  if (y < 22) return Offset(0, math.sin(t * 6) * 1.4);
  if (y < 66) {
    return Offset(math.sin(t * 4 - y * 0.1) * 2.0 * _clamp01((66 - y) / 50), 0);
  }
  return Offset.zero;
}

const Map<DitherAnimalType, AnimalMotion> _byType = {
  DitherAnimalType.owl: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(50, 45),
    seconds: 6.5,
    buildEnd: 0.30,
    holdEnd: 0.74,
    dissolveEnd: 0.94,
    pivot: Offset(50, 95),
    pose: _owlPose,
    warp: _owlWarp,
    blinkEvery: 3.1,
    entrance: _owlEntrance,
    shadow: 22,
  ),
  DitherAnimalType.rabbit: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 5.4,
    buildEnd: 0.22,
    holdEnd: 0.76,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _rabbitPose,
    warp: _rabbitWarp,
    blinkEvery: 2.7,
    entrance: _rabbitEntrance,
    shadow: 20,
  ),
  DitherAnimalType.fish: AnimalMotion(
    reveal: RevealStyle.rightToLeft,
    seconds: 5.8,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.94,
    pivot: Offset(50, 50),
    pose: _fishPose,
    warp: _fishWarp,
    blinkEvery: 4.2,
    bubbles: true,
    entrance: _fishEntrance,
    shadow: 0,
  ),
  DitherAnimalType.turtle: AnimalMotion(
    reveal: RevealStyle.scatter,
    seconds: 7.5,
    buildEnd: 0.38,
    holdEnd: 0.76,
    dissolveEnd: 0.97,
    pivot: Offset(45, 72),
    pose: _turtlePose,
    warp: _turtleWarp,
    blinkEvery: 3.6,
    blinkLength: 0.32,
    entrance: _turtleEntrance,
    shadow: 36,
  ),
  DitherAnimalType.elephant: AnimalMotion(
    reveal: RevealStyle.topDown,
    seconds: 6.8,
    buildEnd: 0.32,
    holdEnd: 0.72,
    dissolveEnd: 0.92,
    pivot: Offset(50, 97),
    pose: _elephantPose,
    warp: _elephantWarp,
    blinkEvery: 2.9,
    entrance: _elephantEntrance,
    landShake: 1.6,
    shadow: 32,
  ),
  DitherAnimalType.cat: AnimalMotion(
    reveal: RevealStyle.leftToRight,
    seconds: 6.2,
    buildEnd: 0.28,
    holdEnd: 0.74,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _catPose,
    warp: _catWarp,
    blinkEvery: 3.4,
    entrance: _catEntrance,
    shadow: 24,
  ),
  DitherAnimalType.penguin: AnimalMotion(
    reveal: RevealStyle.diagonal,
    seconds: 6.6,
    buildEnd: 0.30,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _penguinPose,
    warp: _penguinWarp,
    blinkEvery: 3.0,
    entrance: _penguinEntrance,
    shadow: 24,
  ),
  DitherAnimalType.frog: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(50, 70),
    seconds: 5.6,
    buildEnd: 0.24,
    holdEnd: 0.75,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _frogPose,
    warp: _frogWarp,
    blinkEvery: 2.4,
    entrance: _frogEntrance,
    shadow: 30,
  ),
  DitherAnimalType.octopus: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(50, 32),
    seconds: 6.9,
    buildEnd: 0.32,
    holdEnd: 0.74,
    dissolveEnd: 0.94,
    pivot: Offset(50, 50),
    pose: _octoPose,
    warp: _octoWarp,
    blinkEvery: 3.3,
    entrance: _octoEntrance,
    shadow: 0,
  ),
  DitherAnimalType.bear: AnimalMotion(
    reveal: RevealStyle.antiDiagonal,
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.74,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _bearPose,
    warp: _bearWarp,
    blinkEvery: 3.1,
    entrance: _bearEntrance,
    shadow: 26,
  ),
  DitherAnimalType.lion: AnimalMotion(
    reveal: RevealStyle.spiral,
    revealCenter: Offset(50, 46),
    seconds: 6.8,
    buildEnd: 0.32,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _lionPose,
    warp: _lionWarp,
    blinkEvery: 3.5,
    entrance: _lionEntrance,
    shadow: 24,
  ),
  DitherAnimalType.tiger: AnimalMotion(
    reveal: RevealStyle.blinds,
    seconds: 6.2,
    buildEnd: 0.28,
    holdEnd: 0.74,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _tigerPose,
    warp: _tigerWarp,
    blinkEvery: 3.8,
    entrance: _tigerEntrance,
    shadow: 26,
  ),
  DitherAnimalType.dog: AnimalMotion(
    reveal: RevealStyle.splitX,
    seconds: 5.8,
    buildEnd: 0.26,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _dogPose,
    warp: _dogWarp,
    blinkEvery: 3.0,
    entrance: _dogEntrance,
    shadow: 26,
  ),
  DitherAnimalType.panda: AnimalMotion(
    reveal: RevealStyle.splitY,
    seconds: 7.0,
    buildEnd: 0.34,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 70),
    pose: _pandaPose,
    warp: _pandaWarp,
    blinkEvery: 4.0,
    blinkLength: 0.35,
    entrance: _pandaEntrance,
    shadow: 28,
  ),
  DitherAnimalType.pig: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _pigPose,
    warp: _pigWarp,
    blinkEvery: 2.8,
    entrance: _pigEntrance,
    shadow: 28,
  ),
  DitherAnimalType.fox: AnimalMotion(
    reveal: RevealStyle.rightToLeft,
    seconds: 6.0,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _foxPose,
    warp: _foxWarp,
    blinkEvery: 2.9,
    entrance: _foxEntrance,
    shadow: 24,
  ),
  DitherAnimalType.monkey: AnimalMotion(
    reveal: RevealStyle.topDown,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _monkeyPose,
    warp: _monkeyWarp,
    blinkEvery: 2.6,
    entrance: _monkeyEntrance,
    shadow: 24,
  ),
  DitherAnimalType.duck: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(66, 40),
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _duckPose,
    warp: _duckWarp,
    blinkEvery: 3.3,
    entrance: _duckEntrance,
    shadow: 34,
  ),
  DitherAnimalType.sheep: AnimalMotion(
    reveal: RevealStyle.scatter,
    seconds: 6.6,
    buildEnd: 0.34,
    holdEnd: 0.75,
    dissolveEnd: 0.95,
    pivot: Offset(50, 96),
    pose: _sheepPose,
    warp: _sheepWarp,
    blinkEvery: 3.2,
    entrance: _sheepEntrance,
    shadow: 22,
  ),
  DitherAnimalType.hedgehog: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 6.4,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _hedgePose,
    warp: _hedgeWarp,
    blinkEvery: 3.6,
    entrance: _hedgeEntrance,
    shadow: 34,
  ),
  DitherAnimalType.sun: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(50, 50),
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 50),
    pose: _sunPose,
    warp: _sunWarp,
    blinkEvery: 3.2,
    entrance: _sunEntrance,
    shadow: 0,
  ),
  DitherAnimalType.cloud: AnimalMotion(
    reveal: RevealStyle.leftToRight,
    seconds: 6.6,
    buildEnd: 0.32,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 60),
    pose: _cloudPose,
    warp: _cloudWarp,
    blinkEvery: 3.4,
    entrance: _cloudEntrance,
    shadow: 0,
  ),
  DitherAnimalType.moon: AnimalMotion(
    reveal: RevealStyle.spiral,
    revealCenter: Offset(50, 50),
    seconds: 7.0,
    buildEnd: 0.32,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 50),
    pose: _moonPose,
    warp: _moonWarp,
    blinkEvery: 3.5,
    blinkLength: 0.7,
    entrance: _moonEntrance,
    shadow: 0,
  ),
  DitherAnimalType.star: AnimalMotion(
    reveal: RevealStyle.diagonal,
    seconds: 5.6,
    buildEnd: 0.28,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 52),
    pose: _starPose,
    warp: _starWarp,
    blinkEvery: 2.8,
    entrance: _starEntrance,
    shadow: 0,
  ),
  DitherAnimalType.ghost: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(50, 40),
    seconds: 6.4,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 60),
    pose: _ghostPose,
    warp: _ghostWarp,
    blinkEvery: 3.3,
    entrance: _ghostEntrance,
    shadow: 22,
  ),
  DitherAnimalType.mushroom: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.75,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _shroomPose,
    warp: _shroomWarp,
    blinkEvery: 3.0,
    entrance: _shroomEntrance,
    shadow: 30,
  ),
  DitherAnimalType.cactus: AnimalMotion(
    reveal: RevealStyle.splitX,
    seconds: 6.2,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 98),
    pose: _cactusPose,
    warp: _cactusWarp,
    blinkEvery: 3.6,
    entrance: _cactusEntrance,
    shadow: 28,
  ),
  DitherAnimalType.robot: AnimalMotion(
    reveal: RevealStyle.blinds,
    seconds: 6.0,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _robotPose,
    warp: _robotWarp,
    blinkEvery: 2.6,
    entrance: _robotEntrance,
    shadow: 28,
  ),
  DitherAnimalType.rocket: AnimalMotion(
    reveal: RevealStyle.topDown,
    seconds: 5.8,
    buildEnd: 0.3,
    holdEnd: 0.76,
    dissolveEnd: 0.94,
    pivot: Offset(50, 70),
    pose: _rocketPose,
    warp: _rocketWarp,
    blinkEvery: 3.0,
    entrance: _rocketEntrance,
    shadow: 0,
  ),
  DitherAnimalType.cupcake: AnimalMotion(
    reveal: RevealStyle.antiDiagonal,
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _cupcakePose,
    warp: _cupcakeWarp,
    blinkEvery: 3.1,
    entrance: _cupcakeEntrance,
    shadow: 32,
  ),
};
