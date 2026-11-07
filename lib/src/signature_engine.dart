part of 'animal_motion.dart';

// Interpreter for the data-driven signature table (signature_table.dart).
// Mirrors tool/signature_spec.py; see that file for the op reference.

class SigOp {
  const SigOp(this.k, this.p);
  final String k;
  final List<double> p;
}

class SigSpec {
  const SigSpec(this.period, this.dur, this.seed,
      {this.pose = const [], this.warp = const [], this.fx = const []});
  final double period, dur, seed;
  final List<SigOp> pose, warp, fx;

  Signature build() => Signature(
        period: period,
        dur: dur,
        seed: seed,
        pose: pose.isEmpty ? null : (u, t) => _specPose(pose, u, t),
        warp: warp.isEmpty ? null : (x, y, u, t) => _specWarp(warp, x, y, u, t),
        fx: fx.isEmpty ? null : (c, s) => _specFx(c, s, fx),
      );
}

/// Smootherstep (zero velocity AND acceleration at both ends).
double _s5(double x) {
  final c = _clamp01(x);
  return c * c * c * (c * (c * 6 - 15) + 10);
}

/// Signature envelope: eases in over [a], holds, eases out over [r].
double _senv(double u, double a, double r) =>
    u < a ? _s5(u / a) : (u > 1 - r ? _s5((1 - u) / r) : 1.0);

BodyPose _specPose(List<SigOp> ops, double u, double t) {
  var b = BodyPose.identity;
  final e = _senv(u, 0.25, 0.3);
  for (final o in ops) {
    final p = o.p;
    switch (o.k) {
      case 'hop':
        final k = math.sin(math.pi * p[0] * u).abs();
        final land = math.pow(1 - k, 6).toDouble(); // squash right at touch-down
        b = b.plus(BodyPose(
            dy: -p[1] * k,
            rot: p[2] * math.sin(2 * math.pi * p[0] * u) * k,
            sy: 1 + 0.05 * k - 0.06 * land,
            sx: 1 - 0.03 * k + 0.05 * land));
        break;
      case 'shake':
        b = b.plus(BodyPose(rot: p[1] * math.sin(t * p[0]) * _senv(u, 0.15, 0.3)));
        break;
      case 'tilt':
        final e2 = _senv(u, 0.3, 0.35);
        b = b.plus(BodyPose(rot: p[0] * e2, dy: p[1] * e2));
        break;
      case 'puff':
        b = b.plus(BodyPose(sx: 1 + (p[0] - 1) * e, sy: 1 + (p[1] - 1) * e));
        break;
      case 'dash':
        final back = u < 0.2 ? _s5(u / 0.2) : 0.0;
        final sh = u < 0.2
            ? 0.0
            : (u < 0.42 ? _s5((u - 0.2) / 0.22) : 1 - _s5((u - 0.42) / 0.5));
        b = b.plus(BodyPose(
            dx: -0.4 * p[0] * back * (1 - sh) + p[0] * sh,
            rot: p[1] * (0.6 * back - 0.5 * sh),
            sx: 1 + 0.08 * sh,
            sy: 1 - 0.07 * sh));
        break;
      case 'bounce':
        final s = p[1] * math.sin(u * math.pi * 2 * p[0]) * e;
        b = b.plus(BodyPose(sx: 1 + s, sy: 1 - s));
        break;
      case 'spin':
        // a twirl: the body turns around (mirrors) once, staying in frame
        final c = math.cos(2 * math.pi * p[0] * _s5(u));
        b = b.plus(BodyPose(
            sx: c.abs() < 0.08 ? 0.08 * (c < 0 ? -1 : 1) : c,
            dy: -4 * math.sin(math.pi * u)));
        break;
      case 'rise':
        b = b.plus(BodyPose(dy: -p[0] * e));
        break;
      case 'crouch':
        final c = _senv(u, 0.25, 0.25);
        b = b.plus(BodyPose(dy: p[0] * c, sy: 1 - p[1] * c, sx: 1 + p[1] * 0.5 * c));
        break;
      case 'sway':
        b = b.plus(BodyPose(dx: p[0] * math.sin(t * p[1]) * e));
        break;
      case 'rear':
        final e2 = _senv(u, 0.3, 0.35);
        b = b.plus(BodyPose(rot: -p[0] * e2, sy: 1 + p[1] * e2, dy: -p[1] * 10 * e2));
        break;
    }
  }
  return b;
}

double _rampOf(int gd, double x, double y, double x0, double y0, double x1, double y1) {
  switch (gd) {
    case 1:
      return _clamp01((x - x0) / (x1 - x0));
    case 2:
      return _clamp01((x1 - x) / (x1 - x0));
    case 3:
      return _clamp01((y - y0) / (y1 - y0));
    case 4:
      return _clamp01((y1 - y) / (y1 - y0));
    default:
      return 1.0;
  }
}

double _rectWeight(double x, double y, List<double> p) =>
    _sm((x - p[0]) / 9) * _sm((p[2] - x) / 9) * _sm((y - p[1]) / 9) * _sm((p[3] - y) / 9);

Offset _specWarp(List<SigOp> ops, double x, double y, double u, double t) {
  var ox = 0.0, oy = 0.0;
  final e = _senv(u, 0.25, 0.3);
  for (final o in ops) {
    final p = o.p;
    if (o.k == 'wave') {
      final w = _rectWeight(x, y, p);
      if (w <= 0) continue;
      final r = _rampOf(p[8].round(), x, y, p[0], p[1], p[2], p[3]);
      final sg = p[9] > 0.5 ? (x < 50 ? -1.0 : 1.0) : 1.0;
      final s = math.sin(t * p[6] - p[7] * (x + y));
      ox += p[4] * sg * s * e * w * r;
      oy += p[5] * s * e * w * r;
    } else if (o.k == 'lift') {
      final w = _rectWeight(x, y, p);
      if (w <= 0) continue;
      final r = _rampOf(p[6].round(), x, y, p[0], p[1], p[2], p[3]);
      final sg = p[7] > 0.5 ? (x < 50 ? -1.0 : 1.0) : 1.0;
      ox += p[4] * sg * e * w * r;
      oy += p[5] * e * w * r;
    } else if (o.k == 'puff') {
      final dx = x - p[0], dy = y - p[1];
      final d = math.sqrt(dx * dx + dy * dy);
      if (d >= p[2]) continue;
      final w = _sm(1 - d / p[2]);
      ox += dx / (d + 0.001) * p[3] * e * w;
      oy += dy / (d + 0.001) * p[3] * e * w;
    } else if (o.k == 'pull') {
      final w = _rectWeight(x, y, p);
      if (w <= 0) continue;
      final r = _rampOf(p[7].round(), x, y, p[0], p[1], p[2], p[3]);
      ox += (p[4] - x) * p[6] * e * w * r;
      oy += (p[5] - y) * p[6] * e * w * r;
    }
  }
  return Offset(ox, oy);
}

void _heart(Canvas c, Offset o, double r, Paint paint) {
  final p = Path()
    ..moveTo(o.dx, o.dy + r)
    ..cubicTo(o.dx - 1.4 * r, o.dy - 0.1 * r, o.dx - 0.9 * r, o.dy - 1.2 * r,
        o.dx, o.dy - 0.4 * r)
    ..cubicTo(o.dx + 0.9 * r, o.dy - 1.2 * r, o.dx + 1.4 * r, o.dy - 0.1 * r,
        o.dx, o.dy + r);
  c.drawPath(p, paint);
}

void _specFx(Canvas c, SigCtx s, List<SigOp> ops) {
  for (final o in ops) {
    final p = o.p; // ax, ay, n, size, u0, u1, extra
    final n = p[2].round();
    final size = p[3], u0 = p[4], u1 = p[5], extra = p[6];
    if (s.u < u0 || s.u > u1) continue;
    final ph = (s.u - u0) / (u1 - u0);
    final anchor = s.at(p[0], p[1]);
    final col = s.color;
    switch (o.k) {
      case 'hearts':
      case 'notes':
      case 'zzz':
        for (var i = 0; i < n; i++) {
          final age = (ph * 1.3 - i / n * 0.6).clamp(0.0, 1.0).toDouble();
          if (age <= 0 || age >= 1) continue;
          final pos = anchor +
              Offset((i - (n - 1) / 2) * size * 1.6 + math.sin(age * 5 + i) * size * 0.5,
                  -age * size * 7);
          final a = math.sin(math.pi * age);
          if (o.k == 'hearts') {
            _heart(c, pos, size, _sp(col, 0.9 * a));
          } else if (o.k == 'notes') {
            c.drawCircle(pos, size * 0.5, _sp(col, 0.9 * a));
            final st = _sp(col, 0.9 * a, w: 1.0, fill: false);
            c.drawLine(pos + Offset(size * 0.45, 0), pos + Offset(size * 0.45, -size * 1.9), st);
            c.drawLine(pos + Offset(size * 0.45, -size * 1.9), pos + Offset(size * 1.2, -size * 1.3), st);
          } else {
            final st = _sp(col, 0.9 * a, w: 1.0 + 0.2 * i, fill: false);
            final r = size * (0.6 + 0.25 * i);
            final path = Path()
              ..moveTo(pos.dx - r, pos.dy - r)
              ..lineTo(pos.dx + r, pos.dy - r)
              ..lineTo(pos.dx - r, pos.dy + r)
              ..lineTo(pos.dx + r, pos.dy + r);
            c.drawPath(path, st);
          }
        }
        break;
      case 'stars':
        for (var i = 0; i < n; i++) {
          final ang = 2 * math.pi * i / n + ph * 0.8;
          final tw = math.sin(math.pi * ((ph * 2 + i / n) % 1.0));
          final pos = anchor + Offset(math.cos(ang), math.sin(ang)) * extra * (0.85 + 0.15 * math.sin(i * 2.0));
          _star(c, pos, size * (0.5 + 0.7 * tw), _sp(col, 0.9 * tw));
        }
        break;
      case 'drops':
        final f = math.sin(math.pi * ph).clamp(0.0, 1.0).toDouble() * 1.4;
        for (var i = 0; i < n; i++) {
          final age = (ph * 1.6 + i * 0.045) % 1.0;
          final h1 = hash01(i.toDouble(), 3), h2 = hash01(i.toDouble(), 5);
          final pos = anchor +
              Offset(extra * (h1 - 0.35) * 2.2 * age, -56 * (0.6 + 0.5 * h2) * age + 70 * age * age);
          c.drawCircle(pos, size * (1.0 - 0.4 * age) * (0.7 + 0.5 * h2),
              _sp(col, 0.85 * f.clamp(0.0, 1.0).toDouble() * (1 - age * 0.5)));
        }
        break;
      case 'bubbles':
        for (var i = 0; i < n; i++) {
          final age = (ph * 1.3 - i / n * 0.5).clamp(0.0, 1.0).toDouble();
          if (age <= 0 || age >= 1) continue;
          final pos = anchor + Offset(math.sin(i * 2.0 + age * 6) * size * 2.2 + (i - n / 2) * size, -age * size * 9);
          c.drawCircle(pos, size * (0.6 + age), _sp(col, 0.9 * (1 - age), w: 1.0, fill: false));
        }
        break;
      case 'dust':
        final fd = 1 - ph;
        for (var i = 0; i < n; i++) {
          final side = i.isEven ? 1.0 : -1.0;
          final h = hash01(i.toDouble(), 11);
          final pos = anchor + Offset(side * (4 + ph * extra * (0.4 + h * 0.6)), -ph * 6 * h - 1);
          c.drawCircle(pos, size * (0.5 + ph * 0.9) * (0.6 + h * 0.6), _sp(col, 0.55 * fd));
        }
        break;
      case 'rings':
        for (var k = 0; k < 3; k++) {
          final age = (ph * 1.5 + k / 3) % 1.0;
          c.drawCircle(anchor, size * (0.3 + age * 2.2),
              _sp(col, 0.7 * (1 - age) * math.sin(math.pi * ph), w: 1.1, fill: false));
        }
        break;
      case 'lines':
        final fl = math.sin(math.pi * ph);
        for (var i = 0; i < n; i++) {
          final p0 = anchor + Offset(-(2 + (i % 2) * 4.0), (i - (n - 1) / 2) * size * 1.5);
          c.drawLine(p0, p0 + Offset(-extra * fl, 0), _sp(col, 0.8 * fl, w: 1.1, fill: false));
        }
        break;
      case 'sweat':
        final pos = anchor + Offset(0, ph * size * 3);
        c.drawCircle(pos, size * 0.6, _sp(col, 0.8 * (1 - ph)));
        break;
      case 'tongue':
        // quick snap out to catch a fly, then reel back in
        final k = ph < 0.4 ? _sm(ph / 0.4) : 1 - _sm((ph - 0.4) / 0.35).clamp(0.0, 1.0).toDouble();
        final tip = anchor + Offset(extra * 0.8, -extra * 0.55) * k;
        final pink = const Color(0xFFFF7FA6);
        c.drawLine(anchor, tip, _sp(pink, 1.0, w: 2.2, fill: false));
        c.drawCircle(tip, 2.0, _sp(pink, 1.0));
        if (ph < 0.45) {
          final fly = anchor + Offset(extra * 0.8, -extra * 0.55);
          c.drawCircle(fly + Offset(0, math.sin(s.t * 30) * 0.6), 1.2, _sp(col, 0.95));
        }
        break;
      case 'cloud':
        for (var i = 0; i < n; i++) {
          final h = hash01(i.toDouble(), 17);
          final r = size * (0.6 + 0.8 * h) * (0.4 + ph);
          final pos = anchor + Offset(extra * ph * (0.4 + h) + (h - 0.5) * 6, (hash01(i.toDouble(), 19) - 0.5) * 12 * (0.3 + ph));
          c.drawCircle(pos, r, _sp(const Color(0xFF111827), 0.55 * (1 - ph * 0.7)));
        }
        break;
      case 'orbit':
        for (var i = 0; i < n; i++) {
          final ang = s.t * 4 + i * 2 * math.pi / n;
          final pos = anchor + Offset(math.cos(ang) * extra, math.sin(ang) * extra * 0.35);
          final a = math.sin(math.pi * ph).clamp(0.0, 1.0).toDouble();
          c.drawCircle(pos, size, _sp(col, 0.9 * a));
          c.drawLine(pos, pos + Offset(0, -size * 1.4), _sp(col, 0.7 * a, w: 1.0, fill: false));
        }
        break;
      case 'moon':
        final a = math.sin(math.pi * ph).clamp(0.0, 1.0).toDouble();
        final m = Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: anchor, radius: size)),
            Path()..addOval(Rect.fromCircle(center: anchor + Offset(size * 0.5, -size * 0.2), radius: size * 0.85)));
        c.drawPath(m, _sp(col, 0.85 * a));
        break;
    }
  }
}
