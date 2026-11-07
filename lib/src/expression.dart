import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'animal_shapes.dart' show DitherAnimalType;

/// Facial expressions, available on every animal (see [kExprFaces]).
/// [neutral] is the original, untouched face.
enum DitherExpression { neutral, happy, angry, sleepy, surprised, sad, wink }

/// Numbers that describe one face. Expressions are blended by lerping these,
/// so changing expression is a smooth morph, not a pop.
@immutable
class ExprParams {
  const ExprParams({
    this.amount = 1, // 0 = original baked face, 1 = fully drawn expression
    this.eyeOpen = 1, // vertical eye scale (0 = shut)
    this.eyeScale = 1,
    this.eyeTilt = 0, // radians; + = inner ends down (angry), - = up (sad)
    this.arc = 0, // happy ^ ^ eyes
    this.winkL = 0, // left eye turns into ^
    this.browShow = 1,
    this.browAngle = 0, // + = inner ends down
    this.browLift = 0, // + = lower on the face, - = raised
    this.smile = 1, // -1 frown .. 1 smile .. 1.6 big grin
    this.mouthOpen = 0,
    this.openW = 0.7, // open-mouth width factor
    this.blush = 1,
    this.tear = 0,
    this.sweat = 0,
    this.fangs = 0,
    this.zzz = 0,
  });

  final double amount,
      eyeOpen,
      eyeScale,
      eyeTilt,
      arc,
      winkL,
      browShow,
      browAngle,
      browLift,
      smile,
      mouthOpen,
      openW,
      blush,
      tear,
      sweat,
      fangs,
      zzz;

  static const neutral = ExprParams(amount: 0);

  static ExprParams lerp(ExprParams a, ExprParams b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return ExprParams(
      amount: l(a.amount, b.amount),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      eyeScale: l(a.eyeScale, b.eyeScale),
      eyeTilt: l(a.eyeTilt, b.eyeTilt),
      arc: l(a.arc, b.arc),
      winkL: l(a.winkL, b.winkL),
      browShow: l(a.browShow, b.browShow),
      browAngle: l(a.browAngle, b.browAngle),
      browLift: l(a.browLift, b.browLift),
      smile: l(a.smile, b.smile),
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      openW: l(a.openW, b.openW),
      blush: l(a.blush, b.blush),
      tear: l(a.tear, b.tear),
      sweat: l(a.sweat, b.sweat),
      fangs: l(a.fangs, b.fangs),
      zzz: l(a.zzz, b.zzz),
    );
  }
}

const Map<DitherExpression, ExprParams> kExprParams = {
  DitherExpression.neutral: ExprParams.neutral,
  DitherExpression.happy: ExprParams(
      arc: 1,
      browShow: 0.5,
      browLift: -1.5,
      smile: 1.5,
      mouthOpen: 0.7,
      openW: 0.85,
      blush: 1.3),
  DitherExpression.angry: ExprParams(
      eyeOpen: 0.7,
      eyeTilt: 0.3,
      browAngle: 0.5,
      browLift: 1.0,
      smile: -0.8,
      mouthOpen: 0.0,
      blush: 0.6,
      fangs: 1),
  DitherExpression.sleepy: ExprParams(
      eyeOpen: 0.16,
      browShow: 0.45,
      browLift: 0.5,
      smile: 0.4,
      blush: 1.1,
      zzz: 1),
  DitherExpression.surprised: ExprParams(
      eyeScale: 1.22,
      eyeOpen: 1.05,
      browLift: -3.0,
      smile: 0,
      mouthOpen: 1,
      openW: 0.3,
      blush: 0.9,
      sweat: 1),
  DitherExpression.sad: ExprParams(
      eyeOpen: 0.92,
      eyeTilt: -0.22,
      browAngle: -0.4,
      browLift: -0.5,
      smile: -1.0,
      blush: 0.8,
      tear: 1),
  DitherExpression.wink: ExprParams(
      winkL: 1,
      browShow: 0.6,
      browLift: -0.8,
      smile: 1.4,
      mouthOpen: 0.35,
      openW: 0.7,
      blush: 1.25),
};

/// Where the face parts sit on the 100x100 art canvas. The table `kExprFaces`
/// is generated for every animal (expression_faces.dart); animals whose mouth
/// is a special shape (beaks, snouts...) keep their drawn mouth.
class ExprFace {
  const ExprFace({
    this.mouth, // center of the nose/mouth junction (null = keep the drawn mouth)
    this.mouthHalf = 6,
    this.mouthDrop = 2.6,
    required this.brows, // (cx, cy, width)
    this.top = const Offset(50, 20), // where zzz rises from
  });
  final Offset? mouth;
  final double mouthHalf, mouthDrop;
  final List<(double, double, double)> brows;
  final Offset top;
}

/// Mood script used by `autoMood`: the animal drifts through these on its own.
const Map<DitherAnimalType, List<DitherExpression>> kMoodCycle = {
  DitherAnimalType.cat: [
    DitherExpression.neutral,
    DitherExpression.happy,
    DitherExpression.neutral,
    DitherExpression.sleepy,
    DitherExpression.neutral,
    DitherExpression.wink,
    DitherExpression.surprised,
  ],
  DitherAnimalType.tiger: [
    DitherExpression.neutral,
    DitherExpression.angry,
    DitherExpression.neutral,
    DitherExpression.happy,
    DitherExpression.neutral,
    DitherExpression.sleepy,
    DitherExpression.surprised,
    DitherExpression.neutral,
  ],
};

const List<DitherExpression> kDefaultMoodCycle = [
  DitherExpression.neutral,
  DitherExpression.happy,
  DitherExpression.neutral,
  DitherExpression.sleepy,
  DitherExpression.neutral,
  DitherExpression.wink,
  DitherExpression.surprised,
  DitherExpression.neutral,
  DitherExpression.sad,
];

/// Expression forced while a signature move runs (when `autoMood` is on).
DitherExpression? signatureMood(DitherAnimalType a, double u) {
  if (u < 0) return null;
  switch (a) {
    case DitherAnimalType.tiger:
      return DitherExpression.angry; // growly the whole charge
    case DitherAnimalType.cat:
      return u < 0.45
          ? DitherExpression.angry // narrowed hunting eyes while crouched
          : (u < 0.78 ? DitherExpression.surprised : DitherExpression.happy);
    default:
      return null;
  }
}

Color _alpha(Color c, double a) =>
    c.withValues(alpha: a.clamp(0.0, 1.0).toDouble());

/// One expressive eye (replaces the round eye while an expression is active).
void drawExprEye(Canvas c, Offset ctr, double r, ExprParams p, bool left,
    double blink, Color ink, Color shine, double alpha) {
  final wink = left ? p.winkL : 0.0;
  final arc = math.max(p.arc, wink);
  final round = 1 - arc;
  c.save();
  c.translate(ctr.dx, ctr.dy);
  if (round > 0.01) {
    c.save();
    c.rotate((left ? 1 : -1) * p.eyeTilt);
    c.scale(p.eyeScale, p.eyeScale * p.eyeOpen * (1 - 0.88 * blink));
    c.drawCircle(Offset.zero, r, Paint()..color = _alpha(ink, alpha * round));
    final sp = Paint()..color = _alpha(shine, alpha * round);
    c.drawCircle(Offset(-r * 0.32, -r * 0.34), r * 0.36, sp);
    c.drawCircle(Offset(r * 0.34, r * 0.30), r * 0.16, sp);
    c.restore();
  }
  final a2 = arc;
  if (a2 > 0.01) {
    final path = Path()
      ..moveTo(-r * 1.0, r * 0.45)
      ..quadraticBezierTo(0, -r * 1.35, r * 1.0, r * 0.45);
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6
          ..color = _alpha(ink, alpha * a2));
  }
  c.restore();
}

/// Brows, mouth, tears, sweat and zzz.
void drawExprFace(
    Canvas c,
    ExprFace f,
    ExprParams p,
    Offset Function(double, double) at,
    Color ink,
    double alpha,
    double seconds,
    List<Offset> eyePts,
    double eyeR) {
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  Offset a2(double x, double y) => at(x, y);

  // ---- brows ----
  if (p.browShow > 0.01) {
    for (final b in f.brows) {
      final s = b.$1 < 50 ? 1.0 : -1.0; // + = inner side is to the right
      final half = b.$3 / 2;
      final cy = b.$2 + 0.6 + p.browLift;
      final inner =
          a2(b.$1 + s * half, cy + math.sin(p.browAngle) * half * 1.0);
      final outer =
          a2(b.$1 - s * half, cy - math.sin(p.browAngle) * half * 1.0);
      final mid = a2(b.$1, cy - 2.2 + (p.browAngle > 0 ? 1.6 : 0));
      c.drawPath(
          Path()
            ..moveTo(outer.dx, outer.dy)
            ..quadraticBezierTo(mid.dx, mid.dy, inner.dx, inner.dy),
          line
            ..strokeWidth = 1.3 + 0.5 * p.browAngle.abs() * 2
            ..color = _alpha(ink, alpha * p.browShow * p.amount));
    }
  }

  // ---- mouth ----
  final fm = f.mouth;
  if (fm != null) {
    final mx = fm.dx, my = fm.dy;
    final s = p.smile;
    final half = f.mouthHalf * (1 + 0.28 * math.max(s - 1, 0));
    final y0 = my + 2.4;
    final ctrl = f.mouthDrop * 1.15 * s;
    final endY = y0 + 2.0 - 0.85 * s;
    final mp = line
      ..strokeWidth = 1.0
      ..color = _alpha(ink, alpha * 0.95 * p.amount);
    c.drawLine(a2(mx, my), a2(mx, y0), mp);
    for (final sg in [-1.0, 1.0]) {
      final cp = a2(mx + sg * half * 0.55, y0 + ctrl);
      final ep = a2(mx + sg * half, endY);
      final st = a2(mx, y0);
      c.drawPath(
          Path()
            ..moveTo(st.dx, st.dy)
            ..quadraticBezierTo(cp.dx, cp.dy, ep.dx, ep.dy),
          mp);
    }
    if (p.mouthOpen > 0.02) {
      final o = p.mouthOpen;
      final w = f.mouthHalf * p.openW * (0.55 + 0.45 * o);
      final h = 1.2 + 4.2 * o;
      final top = y0 + 0.2;
      final p0 = a2(mx - w, top),
          p1 = a2(mx, top + h * 1.15),
          p2 = a2(mx + w, top);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(a2(mx - w * 0.9, top + h * 1.1).dx,
            a2(mx - w * 0.9, top + h * 1.1).dy, p1.dx, p1.dy)
        ..quadraticBezierTo(a2(mx + w * 0.9, top + h * 1.1).dx,
            a2(mx + w * 0.9, top + h * 1.1).dy, p2.dx, p2.dy)
        ..quadraticBezierTo(
            a2(mx, top + 0.5).dx, a2(mx, top + 0.5).dy, p0.dx, p0.dy)
        ..close();
      c.drawPath(
          path,
          Paint()
            ..color =
                _alpha(Color.lerp(ink, Colors.black, 0.45)!, alpha * p.amount));
      c.save();
      c.clipPath(path);
      final tc = a2(mx, top + h * 1.0);
      c.drawOval(Rect.fromCenter(center: tc, width: w * 1.3, height: h * 0.7),
          Paint()..color = _alpha(const Color(0xFFFF7FA6), alpha * p.amount));
      c.restore();
    }
    if (p.fangs > 0.02) {
      final fg = Paint()..color = _alpha(Colors.white, alpha * p.fangs);
      for (final sg in [-1.0, 1.0]) {
        final x = mx + sg * f.mouthHalf * 0.5;
        final t0 = a2(x - 1.2, y0 + 1.4),
            t1 = a2(x + 1.2, y0 + 1.4),
            t2 = a2(x, y0 + 4.4);
        c.drawPath(
            Path()
              ..moveTo(t0.dx, t0.dy)
              ..lineTo(t1.dx, t1.dy)
              ..lineTo(t2.dx, t2.dy)
              ..close(),
            fg);
      }
    }
  }

  // ---- tears ----
  if (p.tear > 0.02) {
    final ph = (seconds * 0.7) % 1.0;
    for (var i = 0; i < eyePts.length; i++) {
      final e = eyePts[i];
      final y = e.dy + eyeR * 1.3 + ph * 5.5;
      final a = math.sin(math.pi * ph) * p.tear;
      final path = Path()
        ..moveTo(e.dx, y - 1.4)
        ..quadraticBezierTo(e.dx + 1.3, y + 0.6, e.dx, y + 1.3)
        ..quadraticBezierTo(e.dx - 1.3, y + 0.6, e.dx, y - 1.4);
      c.drawPath(
          path, Paint()..color = _alpha(const Color(0xFF7DD3FC), alpha * a));
    }
  }
  // ---- sweat drop ----
  if (p.sweat > 0.02 && eyePts.length > 1) {
    final e = eyePts.last;
    final ph = (seconds * 0.9) % 1.0;
    final y = e.dy - eyeR * 2.6 + ph * 3;
    final path = Path()
      ..moveTo(e.dx + 5, y - 2.2)
      ..quadraticBezierTo(e.dx + 7, y + 1, e.dx + 5, y + 2.2)
      ..quadraticBezierTo(e.dx + 3, y + 1, e.dx + 5, y - 2.2);
    c.drawPath(
        path,
        Paint()
          ..color = _alpha(
              const Color(0xFF7DD3FC), alpha * p.sweat * (1 - ph * 0.5)));
  }
  // ---- zzz ----
  if (p.zzz > 0.02) {
    final t0 = at(f.top.dx, f.top.dy);
    for (var i = 0; i < 3; i++) {
      final ph = ((seconds * 0.5 - i * 0.28) % 1.0 + 1.0) % 1.0;
      final r = 1.6 + 0.9 * i;
      final pos = t0 + Offset(ph * 6 + i * 3.0, -ph * 12);
      final a = math.sin(math.pi * ph) * p.zzz;
      c.drawPath(
          Path()
            ..moveTo(pos.dx - r, pos.dy - r)
            ..lineTo(pos.dx + r, pos.dy - r)
            ..lineTo(pos.dx - r, pos.dy + r)
            ..lineTo(pos.dx + r, pos.dy + r),
          line
            ..strokeWidth = 1.0 + 0.2 * i
            ..color = _alpha(ink, alpha * a));
    }
  }
}
