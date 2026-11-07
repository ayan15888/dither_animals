part of 'animal_motion.dart';

// ---------------------------------------------------------------------------
// Signature features: one unique, occasional "special move" per animal.
//
// A signature is layered ON TOP of the animal's normal motion (it never
// replaces or edits it). Turn all of them off with
// `DitherAnimal(signature: false)`; the animal then behaves exactly as it did
// before signatures existed.
// ---------------------------------------------------------------------------

/// Context handed to a signature's overlay painter.
class SigCtx {
  const SigCtx(this.u, this.t, this.alive, this.color, this.at);

  /// Progress 0..1 of the current signature action.
  final double u;

  /// Absolute clock seconds.
  final double t;

  /// 0..1 how "alive" (fully formed) the animal is.
  final double alive;
  final Color color;

  /// Maps a point in art space (100x100) to where that point currently is on
  /// screen (includes body pose + per-dot warp), so effects stay attached.
  final Offset Function(double x, double y) at;
}

class Signature {
  const Signature({
    required this.period,
    required this.dur,
    this.seed = 0,
    this.pose,
    this.warp,
    this.fx,
  });

  /// The move happens once per [period] seconds at a random moment, lasting
  /// [dur] seconds.
  final double period, dur, seed;
  final BodyPose Function(double u, double t)? pose;
  final Offset Function(double x, double y, double u, double t)? warp;
  final void Function(Canvas c, SigCtx s)? fx;

  double u(double t) => _u(t, period, dur, seed);
}

Paint _sp(Color c, double a, {double w = 1.2, bool fill = true}) => Paint()
  ..color = c.withOpacity(_clamp01(a))
  ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

void _star(Canvas c, Offset p, double r, Paint paint) {
  final path = Path()
    ..moveTo(p.dx, p.dy - r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
  c.drawPath(path, paint);
}

// ---- Owl: head swivel + feather puff ---------------------------------------
final Signature _owlSig = Signature(
  period: 7.0, dur: 3.2, seed: 11,
  pose: (u, t) {
    final e = _env(u, 0.2, 0.25);
    return BodyPose(sx: 1 + 0.07 * e, sy: 1 + 0.05 * e, dy: -1.2 * e);
  },
  warp: (x, y, u, t) {
    if (y > 66) return Offset.zero;
    // head turns far one way, snaps past, then back
    final a = (u < 0.45 ? _sm(u / 0.45) : (u < 0.62 ? 1.0 : 1 - _sm((u - 0.62) / 0.38))) *
        1.25 * (u < 0.62 ? 1 : 1);
    final w = _headW(y, 66) * 0.6 + 0.4;
    final dx = x - 50;
    return Offset(dx * (math.cos(a) - 1) * w + 11 * math.sin(a) * w, 0);
  },
  fx: (c, s) {
    final e = _env(s.u, 0.2, 0.25);
    if (e < 0.05) return;
    for (var i = 0; i < 7; i++) {
      final ang = -math.pi + i * math.pi / 6;
      final r = 40 + 10 * s.u + (i % 2) * 3;
      final p = s.at(50, 55) + Offset(math.cos(ang) * r, math.sin(ang) * r * 0.9);
      c.drawLine(p, p + Offset(math.cos(ang), math.sin(ang)) * 3.2,
          _sp(s.color, 0.8 * e * (1 - s.u * 0.5), w: 1.1, fill: false));
    }
  },
);

// ---- Elephant: trunk water spray -------------------------------------------
final Signature _elephantSig = Signature(
  period: 8.0, dur: 3.4, seed: 23,
  pose: (u, t) {
    final e = _env(u, 0.22, 0.25);
    return BodyPose(rot: -0.04 * e, dy: 0.8 * e);
  },
  warp: (x, y, u, t) {
    // trunk (the lower middle column) curls up and out
    if (y < 56 || x < 38 || x > 74) return Offset.zero;
    final e = _env(u, 0.22, 0.25);
    final h = _clamp01((y - 56) / 30);
    final side = _sm((x - 38) / 8) * _sm((74 - x) / 8); // feathered edges
    return Offset(10 * e * h * h * side, -20 * e * h * h * h * side);
  },
  fx: (c, s) {
    if (s.u < 0.22 || s.u > 0.9) return;
    final f = _clamp01((s.u - 0.22) / 0.12) * (s.u > 0.8 ? 1 - (s.u - 0.8) / 0.1 : 1.0);
    final tip = s.at(62, 66);
    for (var i = 0; i < 22; i++) {
      final age = ((s.t * 1.7 + i * 0.045) % 1.0);
      final spread = (hash01(i.toDouble(), 3) - 0.5) * 0.7;
      final vx = 26 + 10 * hash01(i.toDouble(), 5), vy = -62 + 6 * spread * 10;
      final p = tip + Offset(vx * age + spread * 8 * age, vy * age + 78 * age * age);
      if (p.dy > 99) continue;
      c.drawCircle(p, 1.1 + 0.9 * (1 - age) * hash01(i.toDouble(), 7),
          _sp(s.color, 0.85 * f * (1 - age * 0.5)));
    }
  },
);

// ---- Rabbit: joyful binky (two twisting hops) -------------------------------
final Signature _rabbitSig = Signature(
  period: 6.0, dur: 2.2, seed: 31,
  pose: (u, t) {
    final k = math.sin(u * math.pi * 2).abs(); // two arcs
    final air = math.pow(k, 0.8).toDouble();
    final spin = math.sin(u * math.pi * 4) * 0.5;
    return BodyPose(
      dy: -17 * air,
      rot: spin * air,
      sx: 1 - 0.14 * math.sin(u * math.pi * 4).abs() * air + 0.04 * (1 - air),
      sy: 1 + 0.08 * air - 0.1 * (1 - air) * _env(u, 0.1, 0.1),
    );
  },
  warp: (x, y, u, t) {
    // ears streak behind the leap
    if (y > 38) return Offset.zero;
    final k = math.sin(u * math.pi * 2).abs();
    return Offset(0, 5 * k * _headW(y, 38) * math.sin(t * 20).abs());
  },
  fx: (c, s) {
    final k = math.sin(s.u * math.pi * 2).abs();
    if (k < 0.5) return;
    for (var i = 0; i < 4; i++) {
      final ph = (s.u * 2 + i * 0.25) % 1.0;
      final p = s.at(50, 50) + Offset((i - 1.5) * 20, -34 + math.sin(i * 2.1) * 6 - ph * 6);
      _star(c, p, 2.6 * (0.6 + 0.4 * math.sin(ph * math.pi)), _sp(s.color, 0.9 * k));
    }
  },
);

// ---- Fish: speed dart + bubble burst ----------------------------------------
final Signature _fishSig = Signature(
  period: 6.5, dur: 2.4, seed: 41,
  pose: (u, t) {
    // wind back, shoot forward (right), glide, return
    final back = u < 0.2 ? _sm(u / 0.2) : 0.0;
    final shoot = u < 0.2 ? 0.0 : (u < 0.42 ? _sm((u - 0.2) / 0.22) : 1 - _sm((u - 0.42) / 0.5));
    return BodyPose(dx: -6 * back * (1 - shoot) + 16 * shoot, rot: 0.1 * back - 0.08 * shoot, sx: 1 + 0.08 * shoot, sy: 1 - 0.07 * shoot);
  },
  warp: (x, y, u, t) {
    // tail whips hard during the dart
    final e = _env(u, 0.2, 0.4);
    if (x > 30) return Offset.zero;
    return Offset(0, math.sin(t * 30) * 4 * e * (1 - x / 30));
  },
  fx: (c, s) {
    if (s.u < 0.2 || s.u > 0.95) return;
    final src = s.at(94, 52);
    final fade = _clamp01((0.95 - s.u) / 0.3);
    for (var i = 0; i < 12; i++) {
      final age = _clamp01((s.u - 0.2 - i * 0.035) / 0.5);
      if (age <= 0) continue;
      final h = hash01(i.toDouble(), 9);
      final p = src + Offset(-26 * age + 6 * math.sin(i * 1.7), -30 * age * (0.5 + h) + 8);
      c.drawCircle(p, 1.4 + 2.4 * h * age,
          _sp(s.color, 0.9 * (1 - age) * fade, w: 1.1, fill: false));
    }
  },
);

// ---- Turtle: duck into the shell, then peek out -----------------------------
final Signature _turtleSig = Signature(
  period: 8.0, dur: 4.2, seed: 53,
  pose: (u, t) {
    final hide = _hide(u);
    return BodyPose(sy: 1 - 0.05 * hide, dy: 1.2 * hide);
  },
  warp: (x, y, u, t) {
    final hide = _hide(u);
    final peek = (u > 0.62 && u < 0.78) ? math.sin((u - 0.62) / 0.16 * math.pi) * 0.25 : 0.0;
    final k = hide - peek * hide;
    if (x < 72) return Offset.zero; // head + front legs retract into the shell
    final w = _clamp01((x - 72) / 10) * 0.85 + 0.15;
    return Offset(-(x - 66) * 0.85 * k * w, y > 60 ? -4 * k : 0.0);
  },
  fx: (c, s) {
    final h = _hide(s.u);
    if (h < 0.7) return;
    // little "…" over the shell while it hides
    for (var i = 0; i < 3; i++) {
      final bob = math.sin(s.t * 5 - i * 0.8) * 0.8;
      c.drawCircle(s.at(44 + i * 7, 22) + Offset(0, bob), 1.6, _sp(s.color, 0.85 * h));
    }
  },
);

double _hide(double u) =>
    u < 0 ? 0 : (u < 0.2 ? _sm(u / 0.2) : (u < 0.72 ? 1.0 : 1 - _sm((u - 0.72) / 0.28)));

// ---- Cat: crouch, butt-wiggle, pounce, purr ---------------------------------
final Signature _catSig = Signature(
  period: 7.5, dur: 3.4, seed: 61,
  pose: (u, t) {
    if (u < 0.45) {
      final c = _sm(u / 0.2);
      return BodyPose(dy: 3.5 * c, sy: 1 - 0.1 * c, sx: 1 + 0.05 * c,
          rot: math.sin(t * 26) * 0.045 * c * (u < 0.4 ? 1.0 : 0.0));
    }
    final p = _clamp01((u - 0.45) / 0.3); // pounce arc
    final air = math.sin(p * math.pi);
    final land = u > 0.75 ? _sm((u - 0.75) / 0.25) : 0.0;
    return BodyPose(dx: 9 * (p < 1 ? _sm(p) : 1 - land), dy: -15 * air + 3.5 * (1 - p) * (u < 0.75 ? 1 : 0),
        rot: 0.18 * air, sy: 1 + 0.1 * air);
  },
  warp: (x, y, u, t) {
    // tail swishes wildly while crouched
    if (x < 66 || y < 52) return Offset.zero;
    final e = u < 0.45 ? _sm(u / 0.2) : 0.3;
    return Offset(0, math.sin(t * 14 + x * 0.1) * 4 * e);
  },
  fx: (c, s) {
    if (s.u < 0.78) return;
    final e = _env((s.u - 0.78) / 0.22, 0.3, 0.4);
    // purr waves by the chin
    for (var i = 0; i < 3; i++) {
      final ph = (s.t * 1.6 + i / 3) % 1.0;
      final r = 6 + ph * 14;
      final cc = s.at(50, 62);
      final rect = Rect.fromCircle(center: cc, radius: r);
      c.drawArc(rect, 0.35, 0.9, false, _sp(s.color, (1 - ph) * 0.8 * e, w: 1.0, fill: false));
      c.drawArc(rect, math.pi + 0.35, 0.9, false, _sp(s.color, (1 - ph) * 0.8 * e, w: 1.0, fill: false));
    }
  },
);

/// Signature per animal: the hand-written ones below plus the data-driven
/// table in signature_table.dart (the lion's roar lives in animal_motion.dart).
final Map<DitherAnimalType, Signature> kSignatures = {
  for (final e in kSignatureSpecs.entries) e.key: e.value.build(),
  DitherAnimalType.owl: _owlSig,
  DitherAnimalType.elephant: _elephantSig,
  DitherAnimalType.rabbit: _rabbitSig,
  DitherAnimalType.fish: _fishSig,
  DitherAnimalType.turtle: _turtleSig,
  DitherAnimalType.cat: _catSig,
};

/// Progress 0..1 of [type]'s signature move at clock time [t] (-1 = idle).
/// Used by event hooks (haptics etc.).
double signatureProgress(DitherAnimalType type, AnimalMotion m, double t) {
  final s = kSignatures[type];
  if (s != null) return s.u(t);
  if (m.roarFx != null) return _lionU(t);
  return -1.0;
}
