import 'dart:math' as math;
import 'dart:ui';

import 'animal_shapes.dart';

part 'signatures.dart';
part 'signature_engine.dart';
part 'signature_table.dart';

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

// ---------------------------------------------------------------------------
// Organic-motion helpers: irregular timing instead of metronome sine waves.
// ---------------------------------------------------------------------------

/// Deterministic pseudo-random 0..1 from an index and a seed.
double hash01(double k, double s) {
  final v = math.sin(k * 12.9898 + s * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

double _sm(double x) {
  final c = _clamp01(x);
  return c * c * (3 - 2 * c);
}

/// Smooth wandering noise in -1..1 (sum of incommensurate sines).
double _nz(double t, double s) =>
    (math.sin(t * 0.71 + s * 1.7) +
        math.sin(t * 1.13 + s * 4.1) * 0.6 +
        math.sin(t * 1.93 + s * 2.3) * 0.35) /
    1.95;

/// Progress 0..1 of a one-off action that happens once per [period] seconds
/// at a random moment and lasts [dur] seconds; -1 when idle.
double _u(double t, double period, double dur, double s) {
  final k = (t / period).floorToDouble();
  final st = hash01(k, s) * (period - dur);
  final u = (t - k * period - st) / dur;
  return (u >= 0 && u <= 1) ? u : -1.0;
}

/// Ease-in / hold / ease-out envelope for an action progress [u].
double _env(double u, [double a = 0.3, double r = 0.3]) {
  if (u < 0) return 0;
  if (u < a) return _sm(u / a);
  if (u > 1 - r) return _sm((1 - u) / r);
  return 1;
}

double _headW(double y, double span) => _clamp01((span - y) / span);


// ---------------------------------------------------------------------------
// Shared natural-behaviour layer used by characters without scripted actions.
// ---------------------------------------------------------------------------

/// Whole-body part: weight shifts and an occasional startle hop.
BodyPose organicPose(double t, double seed) {
  final hop = _u(t, 9.0, 0.7, 50 + seed);
  var dy = 0.0, sy = 1.0;
  if (hop >= 0) {
    if (hop < 0.25) {
      sy = 1 - 0.05 * _sm(hop / 0.25);
    } else if (hop < 0.8) {
      final a = math.sin(math.pi * (hop - 0.25) / 0.55);
      dy = -a * 4;
    } else {
      sy = 1 - 0.05 * math.sin(math.pi * (hop - 0.8) / 0.2);
    }
  }
  return BodyPose(dx: _nz(t, 60 + seed) * 0.9, dy: dy, sy: sy, sx: 1 / sy);
}

/// Per-dot part: the head scans and tilts on its own schedule, trailing
/// the body slightly, with a quick settle after each turn.
Offset organicWarp(double x, double y, double t, double seed) {
  final h = _headW(y, 78);
  if (h <= 0) return Offset.zero;
  final tiltU = _u(t, 5.0, 1.8, 70 + seed);
  final tilt = _env(tiltU, 0.3, 0.35);
  final dir = hash01((t / 5).floorToDouble(), 71 + seed) > 0.5 ? 1.0 : -1.0;
  final scan = _nz(t, 80 + seed) * 1.8;
  final nod = _nz(t * 0.8, 90 + seed) * 0.7;
  return Offset((scan + dir * tilt * 2.6) * h, (nod + tilt * 0.8) * h * h);
}


/// Ease with a little overshoot (0..1 -> ~0..1.1 -> 1).
double backOut(double f, [double c1 = 1.70158]) {
  final x = f - 1;
  return 1 + (c1 + 1) * x * x * x + c1 * x * x;
}

/// Describes an animated, angry roar: how wide the mouth is open (0..1), how
/// angry the brows/squint are (0..1), and where the mouth sits in art space.
class RoarFx {
  const RoarFx({
    required this.open,
    required this.anger,
    required this.mouth,
    this.mouthW = 11,
    this.mouthH = 12,
    this.burst = const Offset(50, 46),
  });
  final double Function(double t) open;
  final double Function(double t) anger;
  final Offset mouth;
  final double mouthW, mouthH;

  /// Centre of the emphasis lines / shock rings drawn while roaring.
  final Offset burst;
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
    this.organic = true,
    this.roarFx,
    this.calmPose,
    this.calmWarp,
  });

  final RevealStyle reveal;

  /// Adds the shared natural-behaviour layer (head scans, tilts, weight
  /// shifts, random startle hops). The newest characters script their own.
  final bool organic;

  /// Optional angry-roar effect (open mouth, brows, shock lines).
  final RoarFx? roarFx;

  /// Used instead of [pose]/[warp] (and without [roarFx]) when signature
  /// features are switched off, for animals whose signature is baked into
  /// their base motion (the lion's roar).
  final BodyPose Function(double t)? calmPose;
  final Offset Function(double x, double y, double t)? calmWarp;
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

  /// 0 = eyes open, 1 = closed. Irregular timing, with the odd double blink.
  double blink(double t) {
    if (blinkEvery <= 0) return 0;
    final k = (t / blinkEvery).floorToDouble();
    final st = k * blinkEvery + hash01(k, 3) * blinkEvery * 0.6;
    var b = 0.0;
    final offs = [0.0, if (hash01(k, 4) > 0.78) blinkLength * 1.4];
    for (final off in offs) {
      final l = (t - st - off) / blinkLength;
      if (l >= 0 && l <= 1) b = math.max(b, math.sin(math.pi * l));
    }
    return b;
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

// Lion: a proper angry roar. Every few seconds it inhales and crouches
// (mane pulls in), then throws its head up and ROARS: jaw drops wide with
// fangs and tongue, brows slam down, the whole body shakes and the mane
// flares and flutters, with shock lines radiating out. Then it relaxes.
double _lionU(double t) => _u(t, 4.6, 2.6, 90.0);

/// Anticipation (inhale) 0..1..0 over the first third of the action.
double _lionAnt(double u) =>
    u < 0 ? 0.0 : (u < 0.22 ? _sm(u / 0.22) : (u < 0.34 ? 1 - _sm((u - 0.22) / 0.12) : 0.0));

/// Roar intensity: snaps up fast, holds, then releases.
double _lionRoarAmt(double u) => u < 0.22
    ? 0.0
    : (u < 0.34 ? _sm((u - 0.22) / 0.12) : (u < 0.8 ? 1.0 : 1 - _sm((u - 0.8) / 0.2)));

double _lionOpen(double t) {
  final u = _lionU(t);
  if (u < 0) return 0;
  final s = 0.88 + 0.12 * math.sin(t * 18); // growl pulsing
  if (u < 0.22) return 0.06 * _sm(u / 0.22);
  if (u < 0.34) return _sm((u - 0.22) / 0.12) * s;
  return s * _lionRoarAmt(u);
}

double _lionAnger(double t) {
  final u = _lionU(t);
  if (u < 0) return 0;
  if (u < 0.12) return _sm(u / 0.12);
  if (u > 0.9) return 1 - _sm((u - 0.9) / 0.1);
  return 1;
}

BodyPose _lionEntrance(double f) {
  final k = 0.4 + 0.6 * backOut(f);
  return BodyPose(sx: k, sy: k, dy: (1 - f) * 12);
}

BodyPose _lionPose(double t) => _lionPoseAt(t, _lionU(t));
BodyPose _lionCalmPose(double t) => _lionPoseAt(t, -1.0);

BodyPose _lionPoseAt(double t, double u) {
  final a = _lionAnt(u), r = _lionRoarAmt(u);
  return BodyPose(
    dx: math.sin(t * 52) * 0.45 * r,
    dy: 1.6 * a - 1.4 * r,
    rot: math.sin(t * 0.9) * 0.03 - 0.02 * a + math.sin(t * 43) * 0.012 * r,
    sx: 1 + 0.03 * a + 0.03 * r,
    sy: 1 - 0.045 * a + 0.03 * r,
  );
}

Offset _lionWarp(double x, double y, double t) => _lionWarpAt(x, y, t, _lionU(t));
Offset _lionCalmWarp(double x, double y, double t) => _lionWarpAt(x, y, t, -1.0);

Offset _lionWarpAt(double x, double y, double t, double u) {
  final a = _lionAnt(u), r = _lionRoarAmt(u), open = u < 0 ? 0.0 : _lionOpen(t);
  final dx = x - 50, dy = y - 46;
  final rad = math.sqrt(dx * dx + dy * dy);
  var ox = 0.0, oy = 0.0;
  if (rad > 26) {
    final w = _clamp01((rad - 26) / 14);
    final ang = math.atan2(dy, dx);
    final off = (math.sin(t * 3.5 + ang * 4) * 1.4 +
            1.6 * r -
            1.3 * a +
            math.sin(t * 14 + ang * 5) * (0.5 + 2.2 * r)) *
        w;
    ox += dx / rad * off;
    oy += dy / rad * off;
  }
  if (y < 80) {
    final h = _headW(y, 80);
    oy += (-2.2 * r + 2.0 * a) * h; // head thrusts up, dips back to inhale
  }
  if (y > 58 && y < 82 && dx.abs() < 15) oy += open * 3.6; // lower jaw drops
  if (y > 48 && y < 58 && dx.abs() < 14) oy -= open * 0.8;
  return Offset(ox, oy);
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

// Mouse: scurries in, twitchy nose, big ears flick, tail curls and swishes.
BodyPose _mouseEntrance(double f) => BodyPose(
    dx: 44 * (1 - f), dy: -math.sin(f * math.pi * 4).abs() * 6 * (1 - f));

BodyPose _mousePose(double t) {
  final nib = _env(_u(t, 3.4, 1.1, 101), 0.2, 0.2); // nibble: quick head-bobs
  return BodyPose(
      dy: -math.sin(t * 3.0).abs() * 1.2 + math.sin(t * 22) * 0.5 * nib,
      rot: math.sin(t * 2.4) * 0.03,
      sy: 1 - 0.02 * nib);
}

Offset _mouseWarp(double x, double y, double t) {
  if (y > 52 && y < 70 && (x - 50).abs() < 12) {
    return Offset(math.sin(t * 15) * 0.6, math.sin(t * 15) * 0.5); // nose twitch
  }
  if (y < 44 && (x < 34 || x > 66)) {
    final w = _clamp01((44 - y) / 26);
    final flick = _env(_u(t, 2.6, 0.4, x < 50 ? 102.0 : 103.0), 0.3, 0.4);
    return Offset((x < 50 ? 1.0 : -1.0) * 2.2 * flick * w, math.sin(t * 2.2 + (x < 50 ? 0.0 : 1.0)) * 1.2 * w);
  }
  if (x > 66 && y > 54) {
    final w = _clamp01((x - 66) / 30);
    return Offset(math.sin(t * 3.4) * 3 * w * w, math.sin(t * 3.4 + 1) * 3 * w);
  }
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

// Duck (front view): waddles in, rocks side to side, wing flutter, QUACK (bill opens).
BodyPose _duckEntrance(double f) => BodyPose(
    dx: -46 * math.pow(1 - f, 1.5).toDouble(),
    rot: math.sin(f * 24) * 0.09 * (1 - f),
    dy: -math.sin(f * 24).abs() * 1.6 * (1 - f));

BodyPose _duckPose(double t) => BodyPose(
    rot: math.sin(t * 3.2) * 0.05,
    dx: math.sin(t * 1.6) * 1.1,
    dy: -math.sin(t * 3.2).abs() * 0.8);

Offset _duckWarp(double x, double y, double t) {
  final q = math.pow(math.max(0.0, math.sin(t * 2.4)), 8).toDouble();
  // bill: lower half drops open on each quack
  if ((x - 50).abs() < 18 && y > 52 && y < 68) {
    return Offset(0, q * 1.9 * _clamp01((y - 52) / 10));
  }
  // wings flutter
  if ((x < 30 || x > 70) && y > 60 && y < 96) {
    final s = x < 50 ? -1.0 : 1.0;
    final w = _clamp01((math.min(x, 100 - x) < 30 ? (30 - math.min(x, 100 - x)) : 0) / 14);
    return Offset(s * math.sin(t * 6) * 1.2 * w, math.sin(t * 6 + 1) * 1.8 * w);
  }
  // head bob
  if (y < 60) {
    return Offset(math.sin(t * 1.6 + 0.4) * 0.7 * _clamp01((60 - y) / 30), 0);
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
// Batch 5: more animals + mascots
// ===========================================================================

// Koala: climbs up slowly, sleepy sway, long slow blinks, ears flop, nose twitch.
BodyPose _koalaEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dy: 30 * e, sy: 1 + 0.06 * e);
}

BodyPose _koalaPose(double t) =>
    BodyPose(rot: math.sin(t * 1.1) * 0.05, dy: math.sin(t * 1.8) * 0.8);

Offset _koalaWarp(double x, double y, double t) {
  if (y < 48 && (x < 30 || x > 70)) {
    return Offset(0, math.sin(t * 3 + (x < 50 ? 0.0 : 1.3)) * 1.4);
  }
  if (y > 48 && y < 66 && (x - 50).abs() < 9) {
    return Offset(0, math.sin(t * 6) * 0.6);
  }
  return Offset.zero;
}

// Raccoon: peeks up from below, sneaky tilt, bushy striped tail, rubs its paws.
BodyPose _raccoonEntrance(double f) => BodyPose(dy: 40 * (1 - f) * (1 - f));

BodyPose _raccoonPose(double t) {
  final c = math.pow(math.max(0.0, math.sin(t * 0.7)), 4).toDouble();
  return BodyPose(
      rot: math.sin(t * 1.6) * 0.04 + c * 0.12, dx: math.sin(t * 0.9) * 1.5);
}

Offset _raccoonWarp(double x, double y, double t) {
  if (x > 66 && y > 56) {
    final w = _clamp01((x - 66) / 28);
    return Offset(math.sin(t * 3) * 5 * w * w, 0);
  }
  if (y > 93 && y < 100) {
    return Offset(math.sin(t * 9) * 1.2 * (x < 50 ? 1.0 : -1.0), 0);
  }
  return Offset.zero;
}

// Whale: surfaces with a splash, glides in waves, spout fountain.
BodyPose _whaleEntrance(double f) =>
    BodyPose(dy: 40 * (1 - f) * (1 - f), rot: -0.3 * (1 - f) * (1 - f));

BodyPose _whalePose(double t) =>
    BodyPose(dy: math.sin(t * 1.5) * 3, rot: math.sin(t * 1.5) * 0.03);

Offset _whaleWarp(double x, double y, double t) {
  if (y < 26) {
    final ph = x < 52 ? 0.0 : (x < 60 ? 0.33 : 0.66);
    return Offset(0, ((t * 1.1 + ph) % 1.0) * 9);
  }
  return Offset(0, math.sin(t * 3 - x * 0.07) * (0.8 + 3 * _clamp01((45 - x) / 40)));
}

// Bee: zig-zags in from the top-right, hovers in a figure-eight, wings buzz.
BodyPose _beeEntrance(double f) {
  final e = (1 - f) * (1 - f);
  return BodyPose(dx: 40 * e + math.sin(f * 14) * 5 * (1 - f), dy: -30 * e);
}

BodyPose _beePose(double t) =>
    BodyPose(dx: math.sin(t * 1.3) * 6, dy: math.sin(t * 2.6) * 3);

Offset _beeWarp(double x, double y, double t) {
  if (y < 52 && (x < 36 || x > 64)) return Offset(0, math.sin(t * 26) * 3);
  return Offset.zero;
}

// Cow: lumbers in, slow head nod, chews, ears flap, tail-less sway.
BodyPose _cowEntrance(double f) =>
    BodyPose(dx: -44 * (1 - f) * (1 - f), dy: -math.sin(f * math.pi * 3).abs() * 3 * (1 - f));

BodyPose _cowPose(double t) =>
    BodyPose(rot: math.sin(t * 1.1) * 0.03, dy: math.sin(t * 2.2).abs() * -0.8);

Offset _cowWarp(double x, double y, double t) {
  if (y > 58 && y < 74 && (x - 50).abs() < 20) {
    return Offset(math.sin(t * 5) * 0.8, math.sin(t * 10) * 0.4);
  }
  if (y > 32 && y < 52 && (x < 24 || x > 76)) {
    final w = _clamp01(((x - 50).abs() - 26) / 14);
    return Offset(0, math.sin(t * 3.4 + (x < 50 ? 0.0 : 1.2)) * 3 * w);
  }
  return Offset.zero;
}

// Giraffe: unfolds from the top, long graceful sway, head leads the neck.
BodyPose _giraffeEntrance(double f) =>
    BodyPose(dy: -36 * (1 - f) * (1 - f), sy: 0.8 + 0.2 * backOut(f));

BodyPose _giraffePose(double t) => BodyPose(rot: math.sin(t * 1.0) * 0.02);

Offset _giraffeWarp(double x, double y, double t) {
  if (y < 62) {
    final w = _clamp01((62 - y) / 62);
    return Offset(math.sin(t * 1.0 - 0.9) * 4.5 * w * w, math.sin(t * 2.0) * 1.2 * w);
  }
  return Offset.zero;
}

// Zebra: gallops in, mane streams, ears flick, nibbles.
BodyPose _zebraEntrance(double f) => BodyPose(
    dx: -46 * (1 - f), dy: -math.sin(f * math.pi * 5).abs() * 7 * (1 - f));

BodyPose _zebraPose(double t) => BodyPose(
    rot: math.sin(t * 2.0) * 0.03,
    dy: -math.pow(math.max(0.0, math.sin(t * 2.2)), 3).toDouble() * 2);

Offset _zebraWarp(double x, double y, double t) {
  if (y < 34 && (x - 50).abs() < 9) {
    final w = _clamp01((34 - y) / 28);
    return Offset(math.sin(t * 5 - y * 0.15) * 2 * w, 0);
  }
  if (y < 28 && (x < 36 || x > 64)) {
    final f = math.pow(math.max(0.0, math.sin(t * 2.7 + (x < 50 ? 0.0 : 2.0))), 6).toDouble();
    return Offset((x < 50 ? -1 : 1) * 2.5 * f, 0);
  }
  if (y > 64 && y < 80 && (x - 50).abs() < 17) {
    return Offset(0, math.sin(t * 7) * 0.8);
  }
  return Offset.zero;
}

// Crab: scuttles sideways in, claws snap, eyes bob, legs skitter.
BodyPose _crabEntrance(double f) => BodyPose(dx: 54 * (1 - f) * (1 - f));

BodyPose _crabPose(double t) =>
    BodyPose(dx: math.sin(t * 1.3) * 4.5, dy: -math.sin(t * 5.2).abs() * 0.8);

Offset _crabWarp(double x, double y, double t) {
  if (y < 50 && x < 28) {
    final s = math.pow(math.max(0.0, math.sin(t * 3.0)), 3).toDouble();
    return Offset(0, -s * 4 * _clamp01((28 - x) / 20));
  }
  if (y < 50 && x > 72) {
    final s = math.pow(math.max(0.0, math.sin(t * 3.0 + 1.6)), 3).toDouble();
    return Offset(0, -s * 4 * _clamp01((x - 72) / 20));
  }
  if (y < 44 && (x - 50).abs() < 16 && (x - 50).abs() > 8) {
    return Offset(0, math.sin(t * 3 + x * 0.2) * 1.4 * _clamp01((44 - y) / 20));
  }
  if (y > 72) return Offset(0, math.sin(t * 10 + x * 0.3) * 1.3);
  return Offset.zero;
}

// Flamingo: tiptoes in, neck sways like a ribbon, head dips, wing ruffles.
BodyPose _flamingoEntrance(double f) =>
    BodyPose(dy: 30 * (1 - f) * (1 - f), rot: 0.2 * (1 - f));

BodyPose _flamingoPose(double t) => BodyPose(rot: math.sin(t * 1.2) * 0.025);

Offset _flamingoWarp(double x, double y, double t) {
  if (x > 46 && y < 64) {
    final w = _clamp01((64 - y) / 44);
    return Offset(math.sin(t * 1.5 - y * 0.05) * 4 * w, math.sin(t * 1.5) * 2 * w * w);
  }
  if (x < 50 && y > 56 && y < 82) {
    return Offset(math.sin(t * 3 - x * 0.1) * 0.9, 0);
  }
  return Offset.zero;
}

// Butterfly: flutters in a lazy loop, wings fold open and shut.
BodyPose _butterflyEntrance(double f) => BodyPose(
    dx: math.sin(f * 9) * 8 * (1 - f), dy: -30 * (1 - f) * (1 - f), rot: math.sin(f * 7) * 0.2 * (1 - f));

BodyPose _butterflyPose(double t) => BodyPose(
    dx: math.sin(t * 0.9) * 5, dy: math.sin(t * 1.8) * 4, rot: math.sin(t * 0.9) * 0.05);

Offset _butterflyWarp(double x, double y, double t) {
  final d = x - 50;
  if (d.abs() > 6) {
    final fold = (1 - math.cos(t * 8)) / 2; // 0 open .. 1 folded
    final w = _clamp01((d.abs() - 6) / 20);
    return Offset(-d * 0.26 * fold * w, -fold * 2.5 * w);
  }
  return Offset.zero;
}

// ===========================================================================
// Batch 6: the last ten animals - behaviour-driven (idle + random actions)
// ===========================================================================

// Snail: slow crawl, foot ripples, eyestalks wander independently, and now
// and then it gets spooked and pulls both stalks in.
BodyPose _snailEntrance(double f) => BodyPose(dx: -40 * (1 - f) * (1 - f));

BodyPose _snailPose(double t) => BodyPose(
    dx: 2.2 * math.sin(t * 0.33) + 0.8 * _nz(t, 1), sy: 1 + 0.008 * math.sin(t * 1.1));

Offset _snailWarp(double x, double y, double t) {
  final r = _env(_u(t, 6.0, 2.6, 3.0), 0.18, 0.45);
  if (x > 66 && y < 46) {
    final w = _clamp01((46 - y) / 26);
    final id = x > 82 ? 1.0 : 0.0;
    return Offset(_nz(t, 2 + id * 3) * 3.2 * w * (1 - r) - r * 2.0 * w, r * 15 * w);
  }
  if (y > 78) {
    final ph = t * 2.4 - x * 0.12;
    return Offset(math.sin(ph) * 0.5, math.sin(ph) * 0.7);
  }
  if (x > 66 && y > 44 && y < 80) return Offset(_nz(t, 7) * 0.8 * (1 - r * 0.6), 0);
  if (x < 66) return Offset(_nz(t, 5) * 0.5 * _clamp01((82 - y) / 60), 0);
  return Offset.zero;
}

// Squirrel: alert and twitchy. Quick hops with a crouch and landing, tail
// flicks that whip and settle, ears and nose twitch in short bursts.
BodyPose _squirrelEntrance(double f) => BodyPose(
    dx: 40 * (1 - f) * (1 - f), dy: -math.sin(f * math.pi * 3).abs() * 9 * (1 - f));

BodyPose _squirrelPose(double t) {
  final u = _u(t, 6.5, 1.0, 4.0);
  var dy = 0.0, sy = 1 + 0.008 * math.sin(t * 2.2);
  if (u >= 0) {
    if (u < 0.18) {
      sy *= 1 - 0.07 * _sm(u / 0.18);
    } else if (u < 0.78) {
      dy = -math.sin(math.pi * (u - 0.18) / 0.6) * 7;
      sy *= 1 + 0.02 * math.sin(math.pi * (u - 0.18) / 0.6);
    } else {
      sy *= 1 - 0.08 * math.sin(math.pi * (u - 0.78) / 0.22);
    }
  }
  return BodyPose(dy: dy, sy: sy, sx: 1 / sy, rot: _nz(t, 6) * 0.012);
}

Offset _squirrelWarp(double x, double y, double t) {
  if (x < 36 && y > 20) {
    final w = _clamp01((36 - x) / 34);
    final fu = _u(t, 4.0, 0.9, 9.0);
    final flick = fu < 0 ? 0.0 : math.sin(fu * math.pi * 3) * math.exp(-3 * fu) * 7;
    return Offset(-w * w * (_nz(t, 8) * 3.0 + flick), w * (_nz(t, 9) * 1.5 - flick.abs() * 0.3));
  }
  if (y < 30 && (x < 44 || x > 56)) {
    final e = _env(_u(t, 3.5, 0.35, x < 50 ? 10.0 : 11.0), 0.2, 0.4);
    return Offset(0, -2.0 * e + math.sin(t * 38) * 0.4 * e);
  }
  if (y > 56 && y < 68 && (x - 50).abs() < 14) {
    final sn = _env(_u(t, 2.2, 0.9, 12.0), 0.2, 0.3);
    return Offset(0, math.sin(t * 16) * 0.7 * sn);
  }
  return Offset.zero;
}

// Hippo: heavy and slow. Deep breathing, weight shifts, lazy independent ear
// flicks, and a rare enormous yawn.
BodyPose _hippoEntrance(double f) =>
    BodyPose(dy: -36 * (1 - f) * (1 - f), sy: 1 + 0.1 * (1 - f));

BodyPose _hippoPose(double t) =>
    BodyPose(dx: _nz(t, 13) * 1.0, sy: 1 + 0.012 * math.sin(t * 1.05));

Offset _hippoWarp(double x, double y, double t) {
  final yw = _env(_u(t, 7.0, 3.2, 14.0), 0.28, 0.3);
  if (y < 34 && (x < 30 || x > 70)) {
    final e = _env(_u(t, 4.2, 0.5, x < 50 ? 15.0 : 16.0), 0.35, 0.45);
    return Offset(0, -2.2 * e + math.sin(t * 30) * 0.5 * e);
  }
  if (y > 70 && y < 88 && (x - 50).abs() < 24) return Offset(0, yw * 3.6);
  if (y > 58 && y < 70 && (x - 50).abs() < 22) return Offset(0, -yw * 1.2);
  return Offset(_nz(t, 17) * 0.8 * _clamp01((98 - y) / 70), 0);
}

// Deer: wary. Head lowers to graze and chews, then snaps up; ears flick
// independently; head scans slowly.
BodyPose _deerEntrance(double f) =>
    BodyPose(dx: -44 * (1 - f), dy: -math.sin(f * math.pi) * 12 * (1 - f));

BodyPose _deerPose(double t) => BodyPose(sy: 1 + 0.01 * math.sin(t * 1.5));

Offset _deerWarp(double x, double y, double t) {
  final g = _env(_u(t, 7.5, 3.6, 18.0), 0.25, 0.22);
  var dx = _nz(t, 21) * 1.6 * _clamp01((98 - y) / 70) * (1 - g);
  var dy = 0.0;
  if (y < 78) {
    final w = _headW(y, 78);
    dy += g * 9 * w;
    dx += g * 2.0 * w;
    if (y > 58 && (x - 50).abs() < 16) dx += math.sin(t * 7) * 0.5 * g;
  }
  if (y > 28 && y < 46 && (x < 30 || x > 70)) {
    final e = _env(_u(t, 3.1, 0.3, x < 50 ? 19.0 : 20.0), 0.2, 0.4);
    dy -= 3.0 * e;
  }
  if (y > 60 && y < 72 && (x - 50).abs() < 10) {
    dy += math.sin(t * 12) * 0.4 * _env(_u(t, 2.6, 0.8, 22.0), 0.2, 0.3);
  }
  return Offset(dx, dy);
}

// Parrot: curious. Quick head-bob bursts, crest raises, one wing stretches
// and flaps, then everything settles into a small preen-shuffle.
BodyPose _parrotEntrance(double f) => BodyPose(
    dy: -40 * (1 - f) * (1 - f), rot: math.sin(f * 10) * 0.3 * (1 - f));

BodyPose _parrotPose(double t) =>
    BodyPose(dx: _nz(t, 26) * 0.8, sy: 1 + 0.01 * math.sin(t * 2.4));

Offset _parrotWarp(double x, double y, double t) {
  final bu = _u(t, 5.0, 1.6, 22.0);
  var dx = 0.0, dy = 0.0;
  if (y < 66) {
    final w = _clamp01((66 - y) / 50);
    if (bu >= 0) dx += math.sin(bu * math.pi * 6) * _env(bu, 0.15, 0.25) * 2.5 * w;
  }
  if (y < 22) {
    final c = _env(_u(t, 8.0, 1.6, 23.0), 0.2, 0.4);
    dy -= c * 2.5;
    dx += (x - 50) * 0.06 * c;
  }
  if (y > 56 && y < 94 && (x - 50).abs() > 16) {
    final left = hash01((t / 6).floorToDouble(), 5) > 0.5;
    if ((x < 50) == left) {
      final wu = _u(t, 6.0, 1.8, 24.0);
      final e = _env(wu, 0.25, 0.35);
      final s = x < 50 ? -1.0 : 1.0;
      dx += s * 3.5 * e;
      dy += -e * 3 + (wu >= 0 ? math.sin(wu * math.pi * 7) * 1.8 * e : 0.0);
    }
  }
  if (y > 88 && (x - 50).abs() < 14) dx += _nz(t, 25) * 1.2;
  return Offset(dx, dy);
}

// Kangaroo: stands alert, ears swivel one at a time; now and then does two
// proper hops (crouch, launch, land) with the tail counterbalancing.
BodyPose _kangarooEntrance(double f) => BodyPose(
    dx: 46 * (1 - f), dy: -math.sin(f * math.pi * 2).abs() * 14 * (1 - f));

double _kangAir(double t) {
  final u = _u(t, 5.0, 2.2, 27.0);
  if (u < 0) return 0;
  final f = (u * 2) % 1.0;
  return (f > 0.2 && f < 0.75) ? math.sin(math.pi * (f - 0.2) / 0.55) : 0.0;
}

BodyPose _kangarooPose(double t) {
  var sy = 1 + 0.01 * math.sin(t * 1.4), dy = 0.0, lean = 0.0;
  final u = _u(t, 5.0, 2.2, 27.0);
  if (u >= 0) {
    final f = (u * 2) % 1.0;
    if (f < 0.2) {
      sy *= 1 - 0.1 * _sm(f / 0.2);
    } else if (f < 0.75) {
      final a = math.sin(math.pi * (f - 0.2) / 0.55);
      dy = -a * 8;
      lean = -0.04 * a;
    } else {
      sy *= 1 - 0.08 * math.sin(math.pi * (f - 0.75) / 0.25);
    }
  }
  return BodyPose(dy: dy, sy: sy, sx: 1 / sy, rot: lean);
}

Offset _kangarooWarp(double x, double y, double t) {
  if (x > 62 && y > 56) {
    final w = _clamp01((x - 62) / 34);
    final a = _kangAir(t);
    return Offset(_nz(t, 28) * 1.5 * w, (-a * 4 + _nz(t, 29) * 1.2) * w);
  }
  if (y < 30 && (x < 44 || x > 56)) {
    final e = _env(_u(t, 3.0, 0.6, x < 50 ? 30.0 : 31.0), 0.3, 0.4);
    return Offset((x < 50 ? -1.0 : 1.0) * 2.2 * e * _clamp01((30 - y) / 20), 0);
  }
  return Offset.zero;
}

// Shark: continuous swimming. Body wave travels to the tail, amplitude
// surges in bursts, and the whole body drifts and rolls slowly.
BodyPose _sharkEntrance(double f) => BodyPose(dx: 50 * (1 - f) * (1 - f));

BodyPose _sharkPose(double t) =>
    BodyPose(dy: _nz(t, 32) * 2.2, rot: _nz(t, 33) * 0.02);

Offset _sharkWarp(double x, double y, double t) {
  final w = _clamp01(x / 100);
  final burst = 1 + 0.6 * _env(_u(t, 8.0, 3.0, 31.0), 0.3, 0.4);
  final dy = math.sin(t * 3.1 - x * 0.075) * (0.35 + 3.4 * w * w) * burst;
  final dx = y < 36 ? math.sin(t * 3.1 - x * 0.075 - 0.6) * 1.2 * _clamp01((36 - y) / 28) : 0.0;
  return Offset(dx, dy);
}

// Chicken: pecks in quick triple bursts (fast down, fast up), the head jerks
// to a new spot between bursts, comb lags behind, tail flicks, wing ruffles.
double _peck(double t) {
  final u = _u(t, 5.5, 2.2, 34.0);
  if (u < 0) return 0;
  final f = (u * 3) % 1.0;
  if (f < 0.25) return _sm(f / 0.25);
  if (f < 0.5) return 1 - _sm((f - 0.25) / 0.25);
  return 0;
}

BodyPose _chickenEntrance(double f) => BodyPose(
    dx: -42 * (1 - f), dy: -math.sin(f * math.pi * 6).abs() * 2.5 * (1 - f));

BodyPose _chickenPose(double t) {
  final p = _peck(t);
  return BodyPose(rot: -p * 0.12, dy: p * 2.0);
}

Offset _chickenWarp(double x, double y, double t) {
  final p = _peck(t);
  if (y < 24) {
    final lag = (_peck(t - 0.08) - p) * 3.0;
    return Offset(_nz(t * 2, 35) * 0.6, p * 6 * _headW(y, 66) + lag);
  }
  if (y < 66) {
    final j = _env(_u(t, 2.7, 0.35, 35.0), 0.1, 0.3);
    return Offset(2.0 * j * _headW(y, 66), p * 6 * _headW(y, 66));
  }
  if (x > 66 && y > 28 && y < 76) {
    final w = _clamp01((x - 66) / 30);
    final fu = _u(t, 4.3, 0.8, 36.0);
    final fl = fu < 0 ? 0.0 : math.sin(fu * math.pi * 2);
    return Offset(fl * 2.4 * w, -fl.abs() * 3 * w);
  }
  if (x < 48 && y > 60 && y < 88) {
    return Offset(0, math.sin(t * 30) * 0.8 * _env(_u(t, 9.0, 1.2, 37.0), 0.2, 0.3));
  }
  return Offset.zero;
}

// Ladybug: walks in short steps (smooth start/stop, alternating direction),
// legs scuttle only while moving, antennae probe, shell sometimes lifts.
BodyPose _ladybugEntrance(double f) =>
    BodyPose(dy: -40 * (1 - f) * (1 - f), rot: math.sin(f * 12) * 0.2 * (1 - f));

double _ladyWalk(double t) => _sm((t % 3.4) / 1.5);

BodyPose _ladybugPose(double t) {
  final k = (t / 3.4).floorToDouble();
  final pp = _ladyWalk(t);
  final dir = (k % 2 == 0) ? 1.0 : -1.0;
  return BodyPose(
      dx: 5 * math.cos(math.pi * (k + pp)),
      rot: -dir * math.sin(math.pi * pp) * 0.05);
}

Offset _ladybugWarp(double x, double y, double t) {
  final ph = (t % 3.4) / 1.5;
  final walking = ph < 1 ? math.sin(math.pi * ph) : 0.0;
  if (y < 22) {
    final id = x > 50 ? 3.0 : 0.0;
    return Offset(_nz(t * 1.7, 41 + id) * 2.4 * _clamp01((22 - y) / 14), 0);
  }
  final l = _env(_u(t, 6.5, 2.2, 42.0), 0.25, 0.35);
  if (y > 40 && y < 94 && (x - 50).abs() > 4 && (x - 50).abs() < 38) {
    final side = (x - 50).abs() / 38;
    return Offset((x - 50) * 0.1 * l, -l * 2.2 * side + math.sin(t * 35) * 0.4 * l);
  }
  if ((x < 24 || x > 76) && y > 44 && y < 80) {
    return Offset(0, math.sin(t * 18 + y * 0.4) * 1.1 * walking);
  }
  return Offset.zero;
}

// Wolf: watchful. Head slowly scans, ears swivel independently, ruff
// ripples; occasionally lifts its snout for a long, slow howl.
BodyPose _wolfEntrance(double f) => BodyPose(
    dx: 44 * (1 - f), dy: -math.sin(f * math.pi) * 18 * (1 - f), rot: 0.3 * (1 - f));

BodyPose _wolfPose(double t) {
  final h = _env(_u(t, 8.5, 4.2, 44.0), 0.3, 0.3);
  return BodyPose(sy: 1 + 0.01 * math.sin(t * 1.7) + 0.045 * h, dy: -h * 2);
}

Offset _wolfWarp(double x, double y, double t) {
  final h = _env(_u(t, 8.5, 4.2, 44.0), 0.3, 0.3);
  var dx = 0.0, dy = 0.0;
  if (y < 80) dx += _nz(t, 43) * 2.2 * _headW(y, 80) * (1 - h);
  if (y > 55 && y < 76 && (x - 50).abs() < 20) dy -= h * 3.2;
  if (y < 70) dy -= h * 2.5 * _headW(y, 70);
  if (y < 30 && (x < 40 || x > 60)) {
    final e = _env(_u(t, 3.3, 0.4, x < 50 ? 45.0 : 46.0), 0.25, 0.4);
    dy -= 2.6 * e;
    dx += (x < 50 ? -1.0 : 1.0) * 1.2 * e;
  }
  if ((x < 28 || x > 72) && y > 64 && y < 86) dx += _nz(t, 47) * 0.8;
  return Offset(dx, dy);
}

// ===========================================================================
// Batch 8: ten more animals
// ===========================================================================

// Horse: gallops in, tosses its head with a whipping mane, snorts.
BodyPose _horseEntrance(double f) => BodyPose(
    dx: -50 * (1 - f), dy: -math.sin(f * math.pi * 5).abs() * 7 * (1 - f));

BodyPose _horsePose(double t) {
  final p = _env(_u(t, 6.5, 1.3, 51.0), 0.3, 0.4);
  return BodyPose(rot: -p * 0.04, dy: -p * 1.5, sy: 1 + 0.008 * math.sin(t * 1.6));
}

Offset _horseWarp(double x, double y, double t) {
  final toss = _env(_u(t, 6.5, 1.3, 51.0), 0.3, 0.4);
  var dx = 0.0, dy = 0.0;
  if (x > 54 && y < 56) {
    final w = _clamp01((56 - y) / 48);
    dx += (_nz(t * 1.6, 52) * 1.6 + toss * math.sin(t * 9) * 2.4) * w;
    dy += toss * 2 * w;
  }
  if (y < 76) dy -= toss * 3.0 * _headW(y, 76);
  if (y < 28 && (x < 42 || x > 58)) {
    final e = _env(_u(t, 3.0, 0.35, x < 50 ? 53.0 : 54.0), 0.2, 0.4);
    dy -= 2.4 * e;
  }
  final sn = _env(_u(t, 5.0, 0.7, 55.0), 0.2, 0.4);
  if (y > 66 && y < 80 && (x - 50).abs() < 14) dy += math.sin(t * 22) * 0.7 * sn;
  return Offset(dx, dy);
}

// Camel: unbothered. Constant slow side-to-side chewing, haughty head sway,
// humps wobble a beat late, long slow blinks.
BodyPose _camelEntrance(double f) => BodyPose(dx: 44 * (1 - f) * (1 - f));

BodyPose _camelPose(double t) => BodyPose(rot: _nz(t, 56) * 0.015, sy: 1 + 0.01 * math.sin(t * 1.2));

Offset _camelWarp(double x, double y, double t) {
  if (y < 38 && (x - 50).abs() > 12 && (x - 50).abs() < 30) {
    return Offset(_nz(t - 0.25, 57) * 1.4, math.sin(t * 1.4 - 0.7) * 0.9);
  }
  if (y > 60 && y < 80 && (x - 50).abs() < 20) {
    final c = 0.5 + 0.5 * _nz(t, 58);
    return Offset(math.sin(t * 3.2) * (0.5 + 0.5 * c), math.sin(t * 6.4) * 0.4);
  }
  return Offset.zero;
}

// Rhino: heavy. Lowers the head and scrapes, rocks back, then settles.
BodyPose _rhinoEntrance(double f) =>
    BodyPose(dx: 40 * (1 - f) * (1 - f), sy: 1 + 0.06 * (1 - f));

BodyPose _rhinoPose(double t) {
  final c = _env(_u(t, 8.0, 2.8, 59.0), 0.3, 0.3);
  return BodyPose(rot: 0.04 * c, dy: c * 1.2, sy: 1 - 0.015 * c);
}

Offset _rhinoWarp(double x, double y, double t) {
  final c = _env(_u(t, 8.0, 2.8, 59.0), 0.3, 0.3);
  if (y < 78) {
    final w = _headW(y, 78);
    final scrape = c * math.sin(t * 6) * 0.8;
    return Offset(c * 1.5 * w + scrape * w, c * 5 * w + _nz(t, 60) * 0.3);
  }
  return Offset.zero;
}

// Goat: spry. Sudden sideways kick-hops, head butts, beard wags, chews.
BodyPose _goatEntrance(double f) => BodyPose(
    dx: -42 * (1 - f), dy: -math.sin(f * math.pi * 4).abs() * 9 * (1 - f));

BodyPose _goatPose(double t) {
  final u = _u(t, 5.5, 0.9, 61.0);
  var dy = 0.0, rot = 0.0, sy = 1.0;
  if (u >= 0) {
    if (u < 0.2) {
      sy = 1 - 0.06 * _sm(u / 0.2);
    } else if (u < 0.75) {
      final a = math.sin(math.pi * (u - 0.2) / 0.55);
      dy = -a * 7;
      rot = math.sin(math.pi * (u - 0.2) / 0.55 * 2) * 0.07;
    } else {
      sy = 1 - 0.06 * math.sin(math.pi * (u - 0.75) / 0.25);
    }
  }
  return BodyPose(dy: dy, rot: rot, sy: sy, sx: 1 / sy);
}

Offset _goatWarp(double x, double y, double t) {
  if (y > 74 && (x - 50).abs() < 10) {
    final w = _clamp01((y - 74) / 24);
    return Offset(math.sin(t * 5 + y * 0.1) * 2.2 * w * (0.4 + 0.6 * (0.5 + 0.5 * _nz(t, 62))), 0);
  }
  if (y > 28 && y < 46 && (x < 20 || x > 80)) {
    final e = _env(_u(t, 3.2, 0.4, x < 50 ? 63.0 : 64.0), 0.2, 0.4);
    return Offset(0, -2.8 * e);
  }
  if (y > 60 && y < 72 && (x - 50).abs() < 14) return Offset(math.sin(t * 6) * 0.5, 0);
  return Offset.zero;
}

// Seal: bursts of flipper claps, nose-up pose, whiskers twitch, body bobs.
BodyPose _sealEntrance(double f) => BodyPose(
    dy: -30 * (1 - f) * (1 - f), sy: 1 + 0.12 * (1 - f));

BodyPose _sealPose(double t) {
  final n = _env(_u(t, 7.0, 2.4, 65.0), 0.3, 0.3);
  return BodyPose(dy: math.sin(t * 1.3) * 1.2 - n * 1.0, rot: -n * 0.04);
}

Offset _sealWarp(double x, double y, double t) {
  if (y > 66 && y < 92 && (x - 50).abs() > 30) {
    final cu = _u(t, 5.0, 1.6, 66.0);
    final c = cu < 0 ? 0.0 : math.sin(cu * math.pi * 6).abs() * _env(cu, 0.1, 0.2);
    final s = x < 50 ? -1.0 : 1.0;
    return Offset(-s * c * 3.5, -c * 6);
  }
  if (y < 62) {
    final n = _env(_u(t, 7.0, 2.4, 65.0), 0.3, 0.3);
    return Offset(0, -n * 3.2 * _headW(y, 62));
  }
  return Offset.zero;
}

// Bat: hovers; wings fold and open with an uneven flutter, ears swivel.
BodyPose _batEntrance(double f) => BodyPose(
    dy: -36 * (1 - f) * (1 - f), dx: math.sin(f * 8) * 6 * (1 - f));

BodyPose _batPose(double t) => BodyPose(
    dx: _nz(t, 67) * 3.0, dy: _nz(t * 1.3, 68) * 3.5 + math.sin(t * 8) * 0.8,
    rot: _nz(t, 69) * 0.05);

Offset _batWarp(double x, double y, double t) {
  final d = x - 50;
  if (d.abs() > 14) {
    final amp = 0.7 + 0.3 * (0.5 + 0.5 * _nz(t, 70));
    final fold = (1 - math.cos(t * 8 + _nz(t, 71) * 0.8)) / 2;
    final w = _clamp01((d.abs() - 14) / 28);
    return Offset(-d * 0.2 * fold * w * amp, -fold * 5 * w * amp + 2 * w);
  }
  if (y < 30) {
    final e = _env(_u(t, 3.6, 0.4, x < 50 ? 72.0 : 73.0), 0.2, 0.4);
    return Offset(0, -2 * e);
  }
  return Offset.zero;
}

// Crocodile: floats low, then a sudden jaw snap with a recoil.
BodyPose _crocodileEntrance(double f) =>
    BodyPose(dy: 20 * (1 - f) * (1 - f), sy: 0.9 + 0.1 * f);

BodyPose _crocodilePose(double t) {
  final s = _env(_u(t, 6.0, 1.0, 77.0), 0.35, 0.15);
  return BodyPose(dy: math.sin(t * 0.9) * 0.9 + s * 1.5, rot: -s * 0.03);
}

Offset _crocodileWarp(double x, double y, double t) {
  final s = _env(_u(t, 6.0, 1.0, 77.0), 0.35, 0.15);
  if (y > 68 && y < 90 && (x - 50).abs() < 28) return Offset(0, s * 6);
  if (y > 56 && y < 68 && (x - 50).abs() < 26) return Offset(0, -s * 2);
  if (y < 40 && (x < 42 || x > 58)) return Offset(0, math.sin(t * 1.5) * 0.5);
  return Offset.zero;
}

// Jellyfish: real pulse - quick contraction, slow expansion - drifting up on
// each pulse and sinking in between; tentacles trail behind with a delay.
double _jellyPulse(double t) {
  final p = (t * 0.7) % 1.0;
  return p < 0.25 ? _sm(p / 0.25) : 1 - _sm((p - 0.25) / 0.75);
}

BodyPose _jellyfishEntrance(double f) => BodyPose(dy: 40 * (1 - f) * (1 - f));

BodyPose _jellyfishPose(double t) {
  final c = _jellyPulse(t);
  return BodyPose(dy: -c * 4 + math.sin(t * 0.7) * 1.2, sy: 1 - 0.09 * c, sx: 1 + 0.07 * c, dx: _nz(t, 78) * 1.5);
}

Offset _jellyfishWarp(double x, double y, double t) {
  if (y > 60) {
    final w = _clamp01((y - 60) / 40);
    final lag = _jellyPulse(t - 0.3 * w);
    return Offset(math.sin(t * 2.0 - y * 0.09 + x * 0.05) * 3.2 * w * (0.6 + 0.4 * lag),
        lag * 5 * w * w);
  }
  if (y < 62) return Offset((x - 50) * 0.04 * _jellyPulse(t), 0);
  return Offset.zero;
}

// Peacock: struts, bobbing its head; now and then fans its tail wide and
// shivers it, then lowers it again.
BodyPose _peacockEntrance(double f) => BodyPose(
    dx: 40 * (1 - f) * (1 - f), dy: -math.sin(f * math.pi * 3).abs() * 3 * (1 - f));

BodyPose _peacockPose(double t) => BodyPose(sy: 1 + 0.008 * math.sin(t * 2.0));

Offset _peacockWarp(double x, double y, double t) {
  final fan = _env(_u(t, 8.0, 3.6, 79.0), 0.3, 0.3);
  if (y < 66 && (x - 50).abs() > 12) {
    final w = _clamp01(((x - 50).abs() - 12) / 36);
    final shiver = math.sin(t * 24) * 0.7 * fan * w;
    return Offset((x - 50) * 0.07 * fan * w + shiver, -fan * 4 * w + shiver * 0.5);
  }
  if (y > 28 && y < 66 && (x - 50).abs() < 12) {
    final w = _clamp01((66 - y) / 38);
    return Offset(math.sin(t * 2.2 - y * 0.05) * 1.6 * w + _nz(t, 80) * 0.8 * w,
        math.sin(t * 4.4) * 0.7 * w);
  }
  return Offset.zero;
}

// Red panda: curious. Stands tall now and then, big ringed tail ripples in a
// travelling wave, ears flick, nose sniffs in short bursts.
BodyPose _redpandaEntrance(double f) => BodyPose(
    dx: 40 * (1 - f) * (1 - f), dy: -math.sin(f * math.pi * 3).abs() * 8 * (1 - f));

BodyPose _redpandaPose(double t) {
  final r = _env(_u(t, 7.0, 2.2, 81.0), 0.3, 0.3);
  return BodyPose(sy: 1 + 0.05 * r + 0.008 * math.sin(t * 2.0), dy: -r * 1.5);
}

Offset _redpandaWarp(double x, double y, double t) {
  final r = _env(_u(t, 7.0, 2.2, 81.0), 0.3, 0.3);
  if (x > 60 && y > 38) {
    final w = _clamp01((x - 60) / 40);
    return Offset((_nz(t, 82) * 2.4 + math.sin(t * 1.8 - x * 0.1) * 1.2) * w,
        math.sin(t * 2.4 - x * 0.12) * 1.6 * w - r * 2 * w);
  }
  if (y < 34 && (x < 44 || x > 56)) {
    final e = _env(_u(t, 3.2, 0.35, x < 50 ? 84.0 : 85.0), 0.2, 0.4);
    return Offset(0, -2.4 * e);
  }
  if (y > 56 && y < 68 && (x - 50).abs() < 9) {
    return Offset(0, math.sin(t * 14) * 0.5 * _env(_u(t, 3.0, 1.0, 83.0), 0.2, 0.3));
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
    organic: false,
    reveal: RevealStyle.spiral,
    revealCenter: Offset(50, 46),
    seconds: 10.0,
    buildEnd: 0.2,
    holdEnd: 0.88,
    dissolveEnd: 0.96,
    roarFx: RoarFx(
      open: _lionOpen,
      anger: _lionAnger,
      mouth: Offset(50, 60.5),
      mouthW: 11,
      mouthH: 13,
      burst: Offset(50, 46),
    ),
    pivot: Offset(50, 96),
    pose: _lionPose,
    warp: _lionWarp,
    calmPose: _lionCalmPose,
    calmWarp: _lionCalmWarp,
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
  DitherAnimalType.mouse: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _mousePose,
    warp: _mouseWarp,
    blinkEvery: 2.6,
    entrance: _mouseEntrance,
    shadow: 26,
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
    revealCenter: Offset(50, 46),
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
  DitherAnimalType.koala: AnimalMotion(
    reveal: RevealStyle.splitY,
    seconds: 7.0,
    buildEnd: 0.34,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 96),
    pose: _koalaPose,
    warp: _koalaWarp,
    blinkEvery: 4.2,
    blinkLength: 0.5,
    entrance: _koalaEntrance,
    shadow: 26,
  ),
  DitherAnimalType.raccoon: AnimalMotion(
    reveal: RevealStyle.rightToLeft,
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _raccoonPose,
    warp: _raccoonWarp,
    blinkEvery: 3.0,
    entrance: _raccoonEntrance,
    shadow: 26,
  ),
  DitherAnimalType.whale: AnimalMotion(
    reveal: RevealStyle.radial,
    revealCenter: Offset(60, 60),
    seconds: 6.6,
    buildEnd: 0.32,
    holdEnd: 0.76,
    dissolveEnd: 0.94,
    pivot: Offset(50, 60),
    pose: _whalePose,
    warp: _whaleWarp,
    blinkEvery: 3.8,
    entrance: _whaleEntrance,
    shadow: 0,
  ),
  DitherAnimalType.bee: AnimalMotion(
    reveal: RevealStyle.diagonal,
    seconds: 5.6,
    buildEnd: 0.3,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 60),
    pose: _beePose,
    warp: _beeWarp,
    blinkEvery: 2.8,
    entrance: _beeEntrance,
    shadow: 0,
  ),
  DitherAnimalType.cow: AnimalMotion(
    reveal: RevealStyle.leftToRight,
    seconds: 6.4,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _cowPose,
    warp: _cowWarp,
    entrance: _cowEntrance,
    shadow: 30,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.giraffe: AnimalMotion(
    reveal: RevealStyle.topDown,
    seconds: 7.0,
    buildEnd: 0.34,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 96),
    pose: _giraffePose,
    warp: _giraffeWarp,
    entrance: _giraffeEntrance,
    shadow: 30,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.zebra: AnimalMotion(
    reveal: RevealStyle.rightToLeft,
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _zebraPose,
    warp: _zebraWarp,
    entrance: _zebraEntrance,
    shadow: 28,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.crab: AnimalMotion(
    reveal: RevealStyle.splitX,
    seconds: 5.8,
    buildEnd: 0.28,
    holdEnd: 0.74,
    dissolveEnd: 0.93,
    pivot: Offset(50, 80),
    pose: _crabPose,
    warp: _crabWarp,
    entrance: _crabEntrance,
    shadow: 34,
    revealCenter: Offset(50, 62),
  ),
  DitherAnimalType.flamingo: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 6.6,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(46, 96),
    pose: _flamingoPose,
    warp: _flamingoWarp,
    entrance: _flamingoEntrance,
    shadow: 26,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.butterfly: AnimalMotion(
    reveal: RevealStyle.spiral,
    seconds: 6.0,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 56),
    pose: _butterflyPose,
    warp: _butterflyWarp,
    entrance: _butterflyEntrance,
    shadow: 0,
    revealCenter: Offset(50, 50),
  ),
  DitherAnimalType.snail: AnimalMotion(
    organic: false,
    reveal: RevealStyle.leftToRight,
    seconds: 7.2,
    buildEnd: 0.34,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 96),
    pose: _snailPose,
    warp: _snailWarp,
    entrance: _snailEntrance,
    shadow: 38,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.squirrel: AnimalMotion(
    organic: false,
    reveal: RevealStyle.diagonal,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _squirrelPose,
    warp: _squirrelWarp,
    entrance: _squirrelEntrance,
    shadow: 28,
    revealCenter: Offset(50, 52),
  ),
  DitherAnimalType.hippo: AnimalMotion(
    organic: false,
    reveal: RevealStyle.bottomUp,
    seconds: 6.4,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _hippoPose,
    warp: _hippoWarp,
    entrance: _hippoEntrance,
    shadow: 32,
  ),
  DitherAnimalType.deer: AnimalMotion(
    organic: false,
    reveal: RevealStyle.leftToRight,
    seconds: 6.2,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _deerPose,
    warp: _deerWarp,
    entrance: _deerEntrance,
    shadow: 26,
  ),
  DitherAnimalType.parrot: AnimalMotion(
    organic: false,
    reveal: RevealStyle.topDown,
    seconds: 5.8,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _parrotPose,
    warp: _parrotWarp,
    entrance: _parrotEntrance,
    shadow: 24,
  ),
  DitherAnimalType.kangaroo: AnimalMotion(
    organic: false,
    reveal: RevealStyle.radial,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _kangarooPose,
    warp: _kangarooWarp,
    entrance: _kangarooEntrance,
    shadow: 28,
  ),
  DitherAnimalType.shark: AnimalMotion(
    organic: false,
    reveal: RevealStyle.rightToLeft,
    seconds: 6.6,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 56),
    pose: _sharkPose,
    warp: _sharkWarp,
    entrance: _sharkEntrance,
    shadow: 0,
  ),
  DitherAnimalType.chicken: AnimalMotion(
    organic: false,
    reveal: RevealStyle.blinds,
    seconds: 5.6,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _chickenPose,
    warp: _chickenWarp,
    entrance: _chickenEntrance,
    shadow: 28,
  ),
  DitherAnimalType.ladybug: AnimalMotion(
    organic: false,
    reveal: RevealStyle.spiral,
    seconds: 6.0,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 80),
    pose: _ladybugPose,
    warp: _ladybugWarp,
    entrance: _ladybugEntrance,
    shadow: 30,
  ),
  DitherAnimalType.wolf: AnimalMotion(
    organic: false,
    reveal: RevealStyle.antiDiagonal,
    seconds: 6.4,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _wolfPose,
    warp: _wolfWarp,
    entrance: _wolfEntrance,
    shadow: 28,
  ),
  DitherAnimalType.horse: AnimalMotion(
    reveal: RevealStyle.rightToLeft,
    seconds: 6.4,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _horsePose,
    warp: _horseWarp,
    entrance: _horseEntrance,
    shadow: 28,
  ),
  DitherAnimalType.camel: AnimalMotion(
    reveal: RevealStyle.leftToRight,
    seconds: 6.6,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _camelPose,
    warp: _camelWarp,
    entrance: _camelEntrance,
    shadow: 30,
  ),
  DitherAnimalType.rhino: AnimalMotion(
    reveal: RevealStyle.bottomUp,
    seconds: 6.4,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _rhinoPose,
    warp: _rhinoWarp,
    entrance: _rhinoEntrance,
    shadow: 32,
  ),
  DitherAnimalType.goat: AnimalMotion(
    reveal: RevealStyle.antiDiagonal,
    seconds: 5.8,
    buildEnd: 0.26,
    holdEnd: 0.74,
    dissolveEnd: 0.92,
    pivot: Offset(50, 96),
    pose: _goatPose,
    warp: _goatWarp,
    entrance: _goatEntrance,
    shadow: 26,
  ),
  DitherAnimalType.seal: AnimalMotion(
    reveal: RevealStyle.radial,
    seconds: 6.2,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 90),
    pose: _sealPose,
    warp: _sealWarp,
    entrance: _sealEntrance,
    shadow: 32,
  ),
  DitherAnimalType.bat: AnimalMotion(
    organic: false,
    reveal: RevealStyle.spiral,
    seconds: 6.0,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 60),
    pose: _batPose,
    warp: _batWarp,
    entrance: _batEntrance,
    shadow: 0,
  ),
  DitherAnimalType.crocodile: AnimalMotion(
    reveal: RevealStyle.splitX,
    seconds: 6.2,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _crocodilePose,
    warp: _crocodileWarp,
    entrance: _crocodileEntrance,
    shadow: 34,
  ),
  DitherAnimalType.jellyfish: AnimalMotion(
    organic: false,
    reveal: RevealStyle.topDown,
    seconds: 7.0,
    buildEnd: 0.34,
    holdEnd: 0.76,
    dissolveEnd: 0.95,
    pivot: Offset(50, 60),
    pose: _jellyfishPose,
    warp: _jellyfishWarp,
    entrance: _jellyfishEntrance,
    shadow: 0,
  ),
  DitherAnimalType.peacock: AnimalMotion(
    organic: false,
    reveal: RevealStyle.diagonal,
    seconds: 6.6,
    buildEnd: 0.3,
    holdEnd: 0.75,
    dissolveEnd: 0.94,
    pivot: Offset(50, 96),
    pose: _peacockPose,
    warp: _peacockWarp,
    entrance: _peacockEntrance,
    shadow: 26,
  ),
  DitherAnimalType.redpanda: AnimalMotion(
    reveal: RevealStyle.radial,
    seconds: 6.2,
    buildEnd: 0.28,
    holdEnd: 0.75,
    dissolveEnd: 0.93,
    pivot: Offset(50, 96),
    pose: _redpandaPose,
    warp: _redpandaWarp,
    entrance: _redpandaEntrance,
    shadow: 28,
  ),
};
