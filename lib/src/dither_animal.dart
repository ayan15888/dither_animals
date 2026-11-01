import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import 'animal_motion.dart';
import 'animal_shapes.dart';

export 'animal_shapes.dart' show DitherAnimalType;

enum DitherDot { square, round }

/// loop = build -> alive/idle -> dissolve -> repeat
/// once = build, then stay alive forever
enum DitherMotion { loop, once }

/// A cute animal rendered as animated ordered-dither stipple dots.
///
/// Tap it to poke it. Every built-in animal has its own personality (see animal_motion.dart):
/// owl blooms + sways + blinks, rabbit hops, fish swims, turtle paddles,
/// elephant swings its trunk and flaps its ears.
///
/// Pass [image] to dither your own artwork instead (dark art on a light or
/// transparent background works best).
class DitherAnimal extends StatefulWidget {
  const DitherAnimal({
    super.key,
    this.animal = DitherAnimalType.owl,
    this.image,
    this.invertImage = false,
    this.color = const Color(0xFF1F3BFF),
    this.cells = 96,
    this.dot = DitherDot.square,
    this.dotScale = 0.9,
    this.duration,
    this.motion = DitherMotion.loop,
    this.phase = 0,
    this.shimmer = 0.07,
    this.showFace = true,
    this.sparkles = true,
    this.pokeable = true,
  });

  final DitherAnimalType animal;
  final ImageProvider? image;
  final bool invertImage;
  final Color color;

  /// Dots across. Higher = finer stipple, more dots to draw.
  final int cells;
  final DitherDot dot;
  final double dotScale;

  /// Loop length. Defaults to the animal's own tempo.
  final Duration? duration;
  final DitherMotion motion;

  /// 0..1 offset so several widgets can animate out of sync.
  final double phase;

  /// Edge flicker while formed.
  final double shimmer;

  /// Draw eyes, blush cheeks and fine detail overlays (built-in animals only).
  final bool showFace;

  /// Sparkle burst when the animal finishes forming.
  final bool sparkles;

  /// Tap the animal to send a shockwave through the dots (+ haptic tick).
  final bool pokeable;

  @override
  State<DitherAnimal> createState() => _DitherAnimalState();
}

class _DitherAnimalState extends State<DitherAnimal>
    with TickerProviderStateMixin {
  late final AnimationController _loop; // 0..1 build/hold/dissolve cycle
  late final AnimationController _clock; // free-running seconds for idle motion
  _DitherGrid? _grid;
  int _loadId = 0;
  final List<_Ripple> _ripples = [];

  AnimalMotion get _motion => widget.image != null
      ? AnimalMotion.generic
      : AnimalMotion.of(widget.animal);

  Duration get _duration =>
      widget.duration ??
      Duration(milliseconds: (_motion.seconds * 1000).round());

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: _duration);
    _clock = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..repeat();
    _start();
    _load();
  }

  void _start() {
    _loop.duration = _duration;
    if (widget.motion == DitherMotion.loop) {
      _loop.repeat();
    } else {
      _loop.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(DitherAnimal old) {
    super.didUpdateWidget(old);
    if (old.animal != widget.animal ||
        old.image != widget.image ||
        old.cells != widget.cells ||
        old.invertImage != widget.invertImage) {
      _load();
    }
    if (old.motion != widget.motion ||
        old.duration != widget.duration ||
        old.animal != widget.animal) {
      _start();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    final grid = await _DitherGrid.build(
      cells: widget.cells,
      animal: widget.animal,
      image: widget.image,
      invert: widget.invertImage,
      motion: _motion,
    );
    if (!mounted || id != _loadId) return;
    setState(() => _grid = grid);
  }

  void _poke(TapDownDetails d) {
    final box = context.size;
    if (box == null || box.isEmpty) return;
    final side = math.min(box.width, box.height);
    final pos = Offset(
      (d.localPosition.dx - (box.width - side) / 2) / side * 100,
      (d.localPosition.dy - (box.height - side) / 2) / side * 100,
    );
    _ripples.add(_Ripple(pos, _clock.value * 3600.0));
    if (_ripples.length > 4) _ripples.removeAt(0);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    return AspectRatio(
      aspectRatio: 1,
      child: grid == null
          ? const SizedBox.shrink()
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.pokeable ? _poke : null,
              child: RepaintBoundary(
              child: CustomPaint(
                painter: _DitherPainter(
                  grid: grid,
                  loop: _loop,
                  clock: _clock,
                  motion: _motion,
                  art: widget.image == null ? kAnimalArt[widget.animal] : null,
                  color: widget.color,
                  dot: widget.dot,
                  dotScale: widget.dotScale,
                  phase: widget.phase,
                  mode: widget.motion,
                  shimmer: widget.shimmer,
                  showFace: widget.showFace,
                  sparkles: widget.sparkles,
                  ripples: _ripples,
                  loopSeconds: _duration.inMilliseconds / 1000.0,
                ),
              ),
            ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pre-computed per-cell data
// ---------------------------------------------------------------------------

class _DitherGrid {
  _DitherGrid(this.n, this.density, this.threshold, this.order, this.hashA,
      this.hashB, this.details);

  /// Pre-sampled vector detail overlays (mouths, whiskers, toes, ...).
  final List<_Poly> details;

  final int n;
  final Float32List density;
  final Float32List threshold; // Bayer 8x8
  final Float32List order; // when the cell appears during the build (0..1)
  final Float32List hashA;
  final Float32List hashB;

  static final List<List<int>> _bayer8 = _makeBayer(8);

  static List<List<int>> _makeBayer(int size) {
    var m = <List<int>>[
      [0]
    ];
    var s = 1;
    while (s < size) {
      final next = List.generate(s * 2, (_) => List.filled(s * 2, 0));
      for (var y = 0; y < s; y++) {
        for (var x = 0; x < s; x++) {
          final v = m[y][x] * 4;
          next[y][x] = v;
          next[y][x + s] = v + 2;
          next[y + s][x] = v + 3;
          next[y + s][x + s] = v + 1;
        }
      }
      m = next;
      s *= 2;
    }
    return m;
  }

  static Future<_DitherGrid> build({
    required int cells,
    required DitherAnimalType animal,
    required ImageProvider? image,
    required bool invert,
    required AnimalMotion motion,
  }) async {
    final n = cells;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()));
    final dens = Float32List(n * n);

    if (image != null) {
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final img = await _resolve(image);
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()),
        image: img,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else {
      canvas.drawColor(const Color(0xFF000000), BlendMode.src);
      canvas.scale(n / 100.0);
      for (final layer in kAnimalArt[animal]!.layers) {
        final g = (layer.density * 255).round().clamp(0, 255);
        canvas.drawPath(
          parseSvgPathData(layer.path),
          Paint()
            ..style = PaintingStyle.fill
            ..isAntiAlias = true
            ..color = Color.fromARGB(255, g, g, g),
        );
      }
    }

    final picture = rec.endRecording();
    final out = await picture.toImage(n, n);
    final bytes = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) throw StateError('Could not read pixels');
    for (var i = 0; i < n * n; i++) {
      final r = bytes.getUint8(i * 4) / 255.0;
      if (image != null) {
        final ink = invert ? r : 1.0 - r;
        dens[i] = ((ink - 0.05) * 1.1).clamp(0.0, 1.0);
      } else {
        dens[i] = r;
      }
    }

    final thr = Float32List(n * n);
    final ord = Float32List(n * n);
    final ha = Float32List(n * n);
    final hb = Float32List(n * n);
    final rnd = math.Random(7);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        thr[i] = (_bayer8[y % 8][x % 8] + 0.5) / 64.0;
        ha[i] = rnd.nextDouble();
        hb[i] = rnd.nextDouble();
        ord[i] = motion.order((x + 0.5) / n * 100, (y + 0.5) / n * 100, ha[i]);
      }
    }
    return _DitherGrid(n, dens, thr, ord, ha, hb, _sampleDetails(image == null ? kAnimalArt[animal] : null));
  }

  static List<_Poly> _sampleDetails(AnimalArt? art) {
    if (art == null) return const [];
    final out = <_Poly>[];
    for (final d in art.details) {
      final path = parseSvgPathData(d.path);
      for (final m in path.computeMetrics()) {
        final len = m.length;
        if (len <= 0) continue;
        final steps = math.max(2, (len / 1.1).ceil());
        final pts = <Offset>[];
        for (var i = 0; i <= steps; i++) {
          final tg = m.getTangentForOffset(len * i / steps);
          if (tg != null) pts.add(tg.position);
        }
        out.add(_Poly(d.kind, d.width, pts, m.isClosed));
      }
    }
    return out;
  }

  static Future<ui.Image> _resolve(ImageProvider provider) {
    final c = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (!c.isCompleted) c.complete(info.image);
      stream.removeListener(l);
    }, onError: (e, s) {
      if (!c.isCompleted) c.completeError(e, s);
      stream.removeListener(l);
    });
    stream.addListener(l);
    return c.future;
  }
}

// ---------------------------------------------------------------------------
// Painter  (everything is drawn in a 100x100 space)
// ---------------------------------------------------------------------------

class _Poly {
  const _Poly(this.kind, this.width, this.pts, this.closed);
  final int kind;
  final double width;
  final List<Offset> pts;
  final bool closed;
}

class _Ripple {
  _Ripple(this.pos, this.t0);
  final Offset pos; // 100-space
  final double t0; // clock seconds
}

class _Phase {
  const _Phase(this.prog, this.f, this.tau, this.dissolving);
  final double prog; // 0 gone .. 1 formed
  final double f; // raw build fraction 0..1
  final double tau; // seconds since fully built (99 = not applicable)
  final bool dissolving;
}

class _DitherPainter extends CustomPainter {
  _DitherPainter({
    required this.grid,
    required this.loop,
    required this.clock,
    required this.motion,
    required this.art,
    required this.color,
    required this.dot,
    required this.dotScale,
    required this.phase,
    required this.mode,
    required this.shimmer,
    required this.showFace,
    required this.sparkles,
    required this.ripples,
    required this.loopSeconds,
  }) : super(repaint: clock);

  final _DitherGrid grid;
  final AnimationController loop;
  final AnimationController clock;
  final AnimalMotion motion;
  final AnimalArt? art;
  final Color color;
  final DitherDot dot;
  final double dotScale;
  final double phase;
  final DitherMotion mode;
  final double shimmer;
  final bool showFace;
  final bool sparkles;
  final List<_Ripple> ripples;
  final double loopSeconds;

  static const double _band = 0.22;
  static const Color _blush = Color(0xFFFF7FA6);
  static const int _levels = 6; // dot-size steps per 1.0 scale
  static const int _buckets = 10;

  static Color _a(Color c, double o) =>
      c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

  _Phase _phase() {
    final be = motion.buildEnd, he = motion.holdEnd, de = motion.dissolveEnd;
    if (mode == DitherMotion.once) {
      final t = loop.value;
      final f = (t / be).clamp(0.0, 1.0);
      return _Phase(Curves.easeOutCubic.transform(f), f,
          math.max(0.0, (t - be) * loopSeconds), false);
    }
    final u = (loop.value + phase) % 1.0;
    if (u < be) {
      final f = u / be;
      return _Phase(Curves.easeOutCubic.transform(f), f, 0, false);
    }
    if (u < he) return _Phase(1.0, 1.0, (u - be) * loopSeconds, false);
    if (u < de) {
      final k = (u - he) / (de - he);
      return _Phase(1.0 - Curves.easeInCubic.transform(k), 1.0, 99, true);
    }
    return const _Phase(0.0, 1.0, 99, true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = grid.n;
    final side = math.min(size.width, size.height);
    final k = side / 100.0;
    final cell = 100.0 / n;

    final seconds = clock.value * 3600.0;
    final ph = _phase();
    final prog = ph.prog;
    final p = prog * (1.0 + _band);
    final alive = ((prog - 0.55) / 0.45).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(k);

    // ---- whole-body pose: idle + entrance + landing squash ----
    var pose = motion.pose(seconds).scaled(alive);
    if (ph.f < 1) pose = pose.plus(motion.entrance(ph.f));
    pose = pose.plus(motion.settle(ph.tau));

    // ---- dotted ground shadow (stays on the ground while the body hops) ----
    if (motion.shadow > 0 && prog > 0) {
      final lift = math.max(0.0, -pose.dy);
      final sc = (1 - lift / 40).clamp(0.35, 1.0);
      final sp = Paint()
        ..color = _a(color, 0.28 * prog * sc)
        ..strokeCap = StrokeCap.square;
      for (var r = 0; r < 2; r++) {
        final rw = motion.shadow * sc * (1 - r * 0.3);
        final step = cell * 1.7;
        final pts = <Offset>[];
        for (var x = 50 - rw; x <= 50 + rw; x += step) {
          pts.add(Offset(x, 98.2 + r * 1.5));
        }
        canvas.drawPoints(ui.PointMode.points, pts,
            sp..strokeWidth = cell * 0.75 * (1 - r * 0.3));
      }
    }

    canvas.translate(motion.pivot.dx + pose.dx, motion.pivot.dy + pose.dy);
    canvas.rotate(pose.rot);
    canvas.scale(pose.sx, pose.sy);
    canvas.translate(-motion.pivot.dx, -motion.pivot.dy);

    // live ripples
    final live = <_Ripple>[
      for (final r in ripples)
        if (seconds - r.t0 < 1.8) r
    ];

    final main = List.generate(_buckets, (_) => <Offset>[]);
    final hi = List.generate(_buckets, (_) => <Offset>[]);

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        final d0 = grid.density[i];
        if (d0 < 0.03) continue;

        final s = ((p - grid.order[i]) / _band).clamp(0.0, 1.0);
        if (s <= 0) continue;

        final flick = math.sin(seconds * 2.2 + grid.hashA[i] * 6.2831853);
        final d = d0 + shimmer * flick * (s >= 1 ? 1.0 : 0.0);
        if (d * Curves.easeOut.transform(s) <= grid.threshold[i]) continue;

        var px = (x + 0.5) * cell;
        var py = (y + 0.5) * cell;
        var sc = 1.0;
        var bright = false;

        if (alive > 0) {
          final w = motion.warp(px, py, seconds);
          px += w.dx * alive;
          py += w.dy * alive;
        }

        if (s < 1) {
          final e = 1 - s;
          if (ph.dissolving) {
            // blow away: drift outward + float upward, shrinking
            px += (grid.hashA[i] - 0.5) * e * cell * 12 + e * e * cell * 8;
            py -= e * e * cell * (10 + 18 * grid.hashB[i]);
            sc = s;
          } else {
            // fly in from random spots, pop with overshoot on arrival
            px += (grid.hashA[i] - 0.5) * e * e * cell * 18;
            py += (grid.hashB[i] * 0.8 - 0.1) * e * e * cell * 18;
            sc = backOut(s);
          }
        } else if (alive > 0) {
          // breathing wave rolling through the dots
          sc += 0.2 * alive * math.sin(seconds * 3.0 - (px + py) * 0.09);
        }

        // tap shockwaves
        for (final r in live) {
          final age = seconds - r.t0;
          final dx = px - r.pos.dx, dy = py - r.pos.dy;
          final dist = math.sqrt(dx * dx + dy * dy) + 0.001;
          final front = age * 75;
          final ring = math.exp(-math.pow((dist - front) / 8, 2));
          final fade = math.exp(-age * 1.7);
          final push = ring * 6 * fade;
          px += dx / dist * push;
          py += dy / dist * push;
          sc += 0.8 * ring * fade;
          if (ring * fade > 0.35) bright = true;
        }

        final idx = (sc * _levels).round().clamp(0, _buckets - 1);
        if (idx == 0) continue;
        (bright ? hi : main)[idx].add(Offset(px, py));
      }
    }

    final round = dot == DitherDot.round;
    final base = Paint()
      ..color = color
      ..isAntiAlias = round
      ..strokeCap = round ? StrokeCap.round : StrokeCap.square;
    final light = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!
      ..isAntiAlias = round
      ..strokeCap = round ? StrokeCap.round : StrokeCap.square;
    for (var b = 1; b < _buckets; b++) {
      final w = cell * dotScale * b / _levels;
      if (main[b].isNotEmpty) {
        canvas.drawPoints(ui.PointMode.points, main[b], base..strokeWidth = w);
      }
      if (hi[b].isNotEmpty) {
        canvas.drawPoints(ui.PointMode.points, hi[b], light..strokeWidth = w);
      }
    }

    // ---- face (pops in, eyes look around + blink) ----
    final faceA = ((prog - 0.75) / 0.25).clamp(0.0, 1.0);
    final a = art;
    if (showFace && a != null && faceA > 0) {
      final pop = backOut(faceA);
      Offset at(EyeSpec e) {
        final w = motion.warp(e.x, e.y, seconds);
        return Offset(e.x + w.dx * alive, e.y + w.dy * alive);
      }

      final blushPaint = Paint()..color = _a(_blush, 0.85 * faceA);
      for (final c in a.cheeks) {
        canvas.drawOval(
            Rect.fromCenter(
                center: at(c),
                width: c.r * 2.2 * pop,
                height: c.r * 1.6 * pop),
            blushPaint);
      }

      final hsl = HSLColor.fromColor(color);
      final eyeColor =
          hsl.withLightness((hsl.lightness * 0.35).clamp(0.05, 0.25)).toColor();
      final eyePaint = Paint()..color = _a(eyeColor, faceA);
      final shine = Paint()..color = _a(Colors.white, faceA);
      // ---- crisp vector details (mouth, whiskers, brows, toes, scales...) ----
      final lineP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fillP = Paint()..style = PaintingStyle.fill;
      for (final poly in grid.details) {
        final path = Path();
        for (var i = 0; i < poly.pts.length; i++) {
          final q = poly.pts[i];
          final w = motion.warp(q.dx, q.dy, seconds);
          final ox = q.dx + w.dx * alive, oy = q.dy + w.dy * alive;
          if (i == 0) {
            path.moveTo(ox, oy);
          } else {
            path.lineTo(ox, oy);
          }
        }
        if (poly.closed) path.close();
        switch (poly.kind) {
          case 0:
            canvas.drawPath(
                path,
                lineP
                  ..color = _a(eyeColor, 0.9 * faceA)
                  ..strokeWidth = poly.width);
          case 1:
            canvas.drawPath(path, fillP..color = _a(eyeColor, faceA));
          case 2:
            canvas.drawPath(
                path,
                lineP
                  ..color = _a(Colors.white, 0.85 * faceA)
                  ..strokeWidth = poly.width);
          case 3:
            canvas.drawPath(path, fillP..color = _a(Colors.white, 0.95 * faceA));
          default:
            canvas.drawPath(path, fillP..color = _a(_blush, faceA));
        }
      }

      final b = motion.blink(seconds);
      final look = Offset(math.sin(seconds * 0.7) * 0.9 * alive,
          math.cos(seconds * 0.5) * 0.5 * alive);
      for (final e in a.eyes) {
        final c = at(e) + look;
        final r = e.r * pop;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1.0, 1.0 - 0.88 * b);
        canvas.drawCircle(Offset.zero, r, eyePaint);
        canvas.drawCircle(Offset(-r * 0.32, -r * 0.34), r * 0.36, shine);
        canvas.drawCircle(Offset(r * 0.34, r * 0.30), r * 0.16, shine);
        canvas.restore();
      }
    }

    // ---- fish bubbles ----
    if (motion.bubbles && alive > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      for (var b = 0; b < 3; b++) {
        final life = ((seconds * 0.45 + b / 3.0) % 1.0);
        final bx = 93 + math.sin(life * 9 + b * 2) * 2.5;
        final by = 40 - life * 34;
        final r = 1.6 + life * 2.6 + b * 0.4;
        ring.color = _a(color, (1 - life) * 0.9 * alive);
        canvas.drawCircle(Offset(bx, by), r, ring);
      }
    }

    // ---- sparkle burst right after forming ----
    if (sparkles && ph.tau < 1.0 && ph.f >= 1) {
      final life = ph.tau / 1.0;
      final c = motion.revealCenter;
      final fade = 1 - life;
      final lineP = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2;
      for (var i = 0; i < 10; i++) {
        final ang = i * 0.6283 + 0.3;
        final rr = (24 + Curves.easeOutCubic.transform(life) * 38) *
            (0.8 + 0.4 * ((i * 37) % 10) / 10.0);
        final pos = c + Offset(math.cos(ang), math.sin(ang)) * rr;
        final len = 4.2 * fade * (0.7 + (i % 3) * 0.25);
        lineP.color = _a(i.isEven ? color : Color.lerp(color, Colors.white, 0.4)!,
            fade);
        canvas.drawLine(pos - Offset(len, 0), pos + Offset(len, 0), lineP);
        canvas.drawLine(pos - Offset(0, len), pos + Offset(0, len), lineP);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_DitherPainter old) =>
      old.grid != grid ||
      old.color != color ||
      old.dot != dot ||
      old.dotScale != dotScale ||
      old.phase != phase ||
      old.mode != mode ||
      old.shimmer != shimmer ||
      old.showFace != showFace ||
      old.sparkles != sparkles ||
      old.loopSeconds != loopSeconds ||
      old.motion != motion ||
      old.art != art;
}
