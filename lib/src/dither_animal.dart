import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import 'animal_motion.dart';
import 'animal_shapes.dart';
import 'expression.dart';
import 'expression_faces.dart';
import 'theme.dart';

export 'animal_shapes.dart' show DitherAnimalType;
export 'theme.dart';
export 'expression.dart';
export 'expression_faces.dart';

/// Shape of every dot. [hex] and [diamond] are drawn as filled polygons.
enum DitherDot { square, round, hex, diamond }

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
    this.dotDensity = 1.0,
    this.duration,
    this.motion = DitherMotion.loop,
    this.phase = 0,
    this.shimmer = 0.03,
    this.showFace = true,
    this.sparkles = true,
    this.pokeable = true,
    this.signature = true,
    this.theme = DitherTheme.solid,
    this.hooks,
    this.expression = DitherExpression.neutral,
    this.autoMood = false,
  });

  final DitherAnimalType animal;
  final ImageProvider? image;
  final bool invertImage;
  final Color color;

  /// Dots across. Higher = finer stipple, more dots to draw.
  final int cells;
  final DitherDot dot;
  final double dotScale;

  /// Ink amount multiplier (1.0 = original). Below 1 the stipple gets sparser
  /// and lighter, above 1 it gets denser and bolder.
  final double dotDensity;

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

  /// Each animal has one unique occasional "special move" (the lion's angry
  /// roar, the elephant's water spray, the cat's pounce...). Set to false to
  /// hide them all; the animals then just do their regular idle behaviour.
  final bool signature;

  /// Dot colors: solid, two-tone, gradient, per-part, and dark mode.
  /// `theme.primary` (when set) overrides [color].
  final DitherTheme theme;

  /// Optional event callbacks (haptics, sound...). See [DitherHooks.haptics].
  final DitherHooks? hooks;

  /// Facial expression, available on every animal.
  /// [DitherExpression.neutral] is the original face. Changing it morphs
  /// smoothly.
  final DitherExpression expression;

  /// Let the animal change mood on its own (cat: happy, sleepy, wink...;
  /// tiger: grumpy, happy...; every animal has a default mood cycle) and react
  /// during its signature move.
  /// Overrides [expression] while true.
  final bool autoMood;

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
    _clock.addListener(_tick);
    _clock.addListener(_moodTick);
    _exprTo = _exprFrom = widget.expression;
    _start();
    _load();
  }

  // ---- expressions ----
  DitherExpression _exprFrom = DitherExpression.neutral;
  DitherExpression _exprTo = DitherExpression.neutral;
  double _exprStart = -10;

  void _setMood(DitherExpression m) {
    if (m == _exprTo) return;
    setState(() {
      _exprFrom = _exprTo;
      _exprTo = m;
      _exprStart = _clock.value * 3600.0;
    });
  }

  void _moodTick() {
    if (!widget.autoMood || widget.image != null || _grid == null) return;
    if (!kExprFaces.containsKey(widget.animal)) return;
    final cyc = kMoodCycle[widget.animal] ?? kDefaultMoodCycle;
    final sec = _clock.value * 3600.0;
    final su = widget.signature ? signatureProgress(widget.animal, _motion, sec) : -1.0;
    _setMood(signatureMood(widget.animal, su) ?? cyc[(sec / 5.0).floor() % cyc.length]);
  }

  // ---- event hooks ----
  int _stage = -1; // 0 building, 1 alive, 2 dissolving
  bool _sigOn = false, _sigPeaked = false;

  void _tick() {
    final h = widget.hooks;
    if (h == null || _grid == null || widget.image != null) return;
    final m = _motion;
    final a = widget.animal;
    final sec = _clock.value * 3600.0;
    final u = widget.motion == DitherMotion.loop
        ? (_loop.value + widget.phase) % 1.0
        : _loop.value;
    final st = u < m.buildEnd
        ? 0
        : (u < m.holdEnd || widget.motion == DitherMotion.once ? 1 : 2);
    if (st != _stage) {
      if (st == 0) h.onBuildStart?.call(a);
      if (st == 1) h.onFormed?.call(a);
      if (st == 2) h.onDissolve?.call(a);
      _stage = st;
    }
    final su = widget.signature && st == 1 ? signatureProgress(a, m, sec) : -1.0;
    if (su >= 0 && !_sigOn) {
      _sigOn = true;
      _sigPeaked = false;
      h.onSignatureStart?.call(a);
    }
    if (_sigOn && !_sigPeaked && su >= 0.5) {
      _sigPeaked = true;
      h.onSignaturePeak?.call(a);
    }
    if (_sigOn && su < 0) {
      _sigOn = false;
      h.onSignatureEnd?.call(a);
    }
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
    if (old.expression != widget.expression && !widget.autoMood) {
      _setMood(widget.expression);
    }
    if (old.autoMood && !widget.autoMood) _setMood(widget.expression);
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
    widget.hooks?.onPoke?.call(widget.animal);
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    final th = widget.theme;
    final dark = th.followSystem
        ? Theme.of(context).brightness == Brightness.dark
        : th.brightness == Brightness.dark;
    final base = th.primary ?? widget.color;
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
                  color: dark ? DitherTheme.lift(base) : base,
                  theme: th,
                  dark: dark,
                  dot: widget.dot,
                  dotScale: widget.dotScale,
                  dotDensity: widget.dotDensity,
                  phase: widget.phase,
                  mode: widget.motion,
                  shimmer: widget.shimmer,
                  showFace: widget.showFace,
                  sparkles: widget.sparkles,
                  signature: widget.signature,
                  exprFace: widget.image == null ? kExprFaces[widget.animal] : null,
                  exprFrom: _exprFrom,
                  exprTo: _exprTo,
                  exprStart: _exprStart,
                  sigDef: widget.image == null ? kSignatures[widget.animal] : null,
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
        out.add(_Poly(d.kind, d.width, pts, m.isClosed, d.tag));
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
  const _Poly(this.kind, this.width, this.pts, this.closed, [this.tag = '']);
  final String tag;
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

/// Accent fills for detail kinds 5..13 (red, gold, emerald, royal blue,
/// violet, light gold, sky, navy, pale blue).
const List<Color> _kFillPalette = [
  Color(0xFFD93A2B), Color(0xFFF5B82E), Color(0xFF14A06F), Color(0xFF1F5FD6),
  Color(0xFF6B3FD1), Color(0xFFFFD86B), Color(0xFF5BB8F0), Color(0xFF16306B),
  Color(0xFFBFE3F8), Color(0xFFFF8A1F), // 13 pale blue, 14 orange
];

/// Accent strokes for detail kinds 20..22 (gold, emerald, light blue).
const List<Color> _kStrokePalette = [
  Color(0xFFF5B82E), Color(0xFF14A06F), Color(0xFF8FD0F5),
];

class _DitherPainter extends CustomPainter {
  _DitherPainter({
    required this.grid,
    required this.loop,
    required this.clock,
    required this.motion,
    required this.art,
    required this.color,
    required this.theme,
    required this.dark,
    required this.dot,
    required this.dotScale,
    required this.dotDensity,
    required this.phase,
    required this.mode,
    required this.shimmer,
    required this.showFace,
    required this.sparkles,
    required this.signature,
    required this.exprFace,
    required this.exprFrom,
    required this.exprTo,
    required this.exprStart,
    required this.sigDef,
    required this.ripples,
    required this.loopSeconds,
  }) : super(repaint: clock);

  final _DitherGrid grid;
  final AnimationController loop;
  final AnimationController clock;
  final AnimalMotion motion;
  final AnimalArt? art;
  final Color color;
  final DitherTheme theme;
  final bool dark;
  final DitherDot dot;
  final double dotScale;
  final double dotDensity;
  final double phase;
  final DitherMotion mode;
  final double shimmer;
  final bool showFace;
  final bool sparkles;
  final bool signature;
  final ExprFace? exprFace;
  final DitherExpression exprFrom, exprTo;
  final double exprStart;
  final Signature? sigDef;
  final List<_Ripple> ripples;
  final double loopSeconds;

  static const double _band = 0.22;
  static const Color _blush = Color(0xFFFF7FA6);
  static const int _levels = 12; // dot-size steps per 1.0 scale
  static const int _buckets = 22;

  /// Which body zone an art-space point belongs to (for per-part colors).
  static DitherPart _partOf(double x, double y) {
    final dx = (x - 50).abs();
    if (y > 88) return DitherPart.feet;
    if (y < 38 && dx > 20) return DitherPart.ears;
    if (y < 64 && dx <= 34) return DitherPart.head;
    if (dx > 34) return DitherPart.sides;
    return DitherPart.body;
  }

  /// One path holding a polygon per point: hexagons (pointy-top) or diamonds.
  Path _polyDots(List<Offset> pts, double w) {
    final hex = dot == DitherDot.hex;
    final r = hex ? w * 0.56 : w * 0.62;
    final n = hex ? 6 : 4;
    final a0 = hex ? -math.pi / 2 : -math.pi / 2;
    final path = Path();
    for (final p in pts) {
      for (var i = 0; i < n; i++) {
        final a = a0 + i * 2 * math.pi / n;
        final x = p.dx + r * math.cos(a), y = p.dy + r * math.sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
    }
    return path;
  }

  static double _gazeEase(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

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
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(k);
    // fit scale so wandering never leaves the frame
    canvas.translate(50, 98);
    canvas.scale(0.93);
    canvas.translate(-50, -98);

    // ---- whole-body pose: idle + entrance + landing squash ----
    final sig = signature ? sigDef : null;
    final su = sig == null ? -1.0 : sig.u(seconds);
    final calm = !signature && motion.calmPose != null;
    var pose = (calm ? motion.calmPose!(seconds) : motion.pose(seconds)).scaled(alive);
    if (sig?.pose != null && su >= 0) pose = pose.plus(sig!.pose!(su, seconds).scaled(alive));
    // ---- continuous "life" layer: slow wandering drift, lean into the
    // motion, breathing, and follow-through (head/ears lag behind body) ----
    final lt = seconds + phase * 7.0;
    final ldx = 2.6 * math.sin(0.45 * lt) + 1.2 * math.sin(0.8 * lt + 1.3);
    final lvx = 2.6 * 0.45 * math.cos(0.45 * lt) + 1.2 * 0.8 * math.cos(0.8 * lt + 1.3);
    final ldy = 0.7 * math.sin(0.9 * lt + 0.4);
    final breath = 0.014 * math.sin(1.9 * lt);
    pose = pose.plus(BodyPose(
        dx: ldx * alive,
        dy: ldy * alive,
        rot: lvx * 0.014 * alive,
        sx: 1 - breath * 0.6 * alive,
        sy: 1 + breath * alive));
    final oseed = phase * 13.0;
    if (motion.organic) {
      pose = pose.plus(organicPose(seconds, oseed).scaled(alive));
    }
    Offset wp(double x, double y) {
      var w = calm ? motion.calmWarp!(x, y, seconds) : motion.warp(x, y, seconds);
      if (sig?.warp != null && su >= 0) w = w + sig!.warp!(x, y, su, seconds);
      if (motion.organic) w = w + organicWarp(x, y, seconds, oseed);
      final h = ((98 - y) / 100).clamp(0.0, 1.0);
      final lag = -lvx * 0.7 * h * h;
      final sway = 0.35 * h * math.sin(1.3 * lt - y * 0.05);
      return Offset(w.dx + lag + sway, w.dy);
    }
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
        final cx0 = 50 + pose.dx;
        for (var x = cx0 - rw; x <= cx0 + rw; x += step) {
          pts.add(Offset(x, 98.2 + r * 1.5));
        }
        canvas.drawPoints(ui.PointMode.points, pts,
            sp..strokeWidth = cell * 0.75 * (1 - r * 0.3));
      }
    }

    canvas.save(); // inner: pose transform
    canvas.translate(motion.pivot.dx + pose.dx, motion.pivot.dy + pose.dy);
    canvas.rotate(pose.rot);
    canvas.scale(pose.sx, pose.sy);
    canvas.translate(-motion.pivot.dx, -motion.pivot.dy);

    // live ripples
    final live = <_Ripple>[
      for (final r in ripples)
        if (seconds - r.t0 < 1.8) r
    ];

    final palette = theme.palette(color, dark, primaryLifted: true);
    final nc = palette.length;
    final main = List.generate(nc, (_) => List.generate(_buckets, (_) => <Offset>[]));
    final hi = List.generate(nc, (_) => List.generate(_buckets, (_) => <Offset>[]));
    final ga = theme.gradientAngle * math.pi / 180;
    final gcos = math.cos(ga), gsin = math.sin(ga);
    int pick(int i, double cx, double cy) {
      switch (theme.mode) {
        case DitherColorMode.solid:
          return 0;
        case DitherColorMode.twoTone:
          return grid.hashB[i] < theme.twoToneMix ? 1 : 0;
        case DitherColorMode.gradient:
          final t = (((cx - 50) * gcos + (cy - 50) * gsin) / 80 + 0.5).clamp(0.0, 1.0);
          return (t * (nc - 1)).round();
        case DitherColorMode.parts:
          return _partOf(cx, cy).index;
      }
    }

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        final d0 = grid.density[i];
        if (d0 < 0.03) continue;

        final s = ((p - grid.order[i]) / _band).clamp(0.0, 1.0);
        if (s <= 0) continue;

        final flick = math.sin(seconds * 2.2 + grid.hashA[i] * 6.2831853);
        final d = d0 * dotDensity + shimmer * flick * (s >= 1 ? 1.0 : 0.0);
        if (d * Curves.easeOut.transform(s) <= grid.threshold[i]) continue;

        var px = (x + 0.5) * cell;
        var py = (y + 0.5) * cell;
        final ci = nc == 1 ? 0 : pick(i, px, py);
        var sc = 1.0;
        var bright = false;

        if (alive > 0) {
          final w = wp(px, py);
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
        (bright ? hi : main)[ci][idx].add(Offset(px, py));
      }
    }

    final round = dot == DitherDot.round;
    final poly = dot == DitherDot.hex || dot == DitherDot.diamond;
    final base = Paint()
      ..isAntiAlias = round || poly
      ..strokeCap = round ? StrokeCap.round : StrokeCap.square;
    final light = Paint()
      ..isAntiAlias = round || poly
      ..strokeCap = round ? StrokeCap.round : StrokeCap.square;
    for (var c = 0; c < nc; c++) {
      base.color = palette[c];
      light.color = Color.lerp(palette[c], Colors.white, 0.45)!;
      for (var b = 1; b < _buckets; b++) {
        final w = cell * dotScale * b / _levels;
        final m = main[c][b], h = hi[c][b];
        if (poly) {
          if (m.isNotEmpty) canvas.drawPath(_polyDots(m, w), base);
          if (h.isNotEmpty) canvas.drawPath(_polyDots(h, w), light);
          continue;
        }
        if (m.isNotEmpty) {
          canvas.drawPoints(ui.PointMode.points, m, base..strokeWidth = w);
        }
        if (h.isNotEmpty) {
          canvas.drawPoints(ui.PointMode.points, h, light..strokeWidth = w);
        }
      }
    }

    // ---- expression blend (null = original face, untouched) ----
    ExprParams? ep;
    if (exprFace != null &&
        (exprFrom != DitherExpression.neutral || exprTo != DitherExpression.neutral)) {
      final tt = ((seconds - exprStart) / 0.45).clamp(0.0, 1.0).toDouble();
      ep = ExprParams.lerp(kExprParams[exprFrom]!, kExprParams[exprTo]!, tt * tt * (3 - 2 * tt));
    }

    // ---- face (pops in, eyes look around + blink) ----
    final faceA = ((prog - 0.75) / 0.25).clamp(0.0, 1.0);
    final a = art;
    if (showFace && a != null && faceA > 0) {
      final pop = backOut(faceA);
      Offset at(EyeSpec e) {
        final w = wp(e.x, e.y);
        return Offset(e.x + w.dx * alive, e.y + w.dy * alive);
      }

      final bl = ep == null ? 1.0 : 1 + (ep.blush - 1) * ep.amount;
      final blushPaint = Paint()..color = _a(_blush, 0.85 * faceA);
      for (final c in a.cheeks) {
        canvas.drawOval(
            Rect.fromCenter(
                center: at(c),
                width: c.r * 2.2 * pop * bl,
                height: c.r * 1.6 * pop * bl),
            blushPaint);
      }

      final hsl = HSLColor.fromColor(color);
      // on dark backgrounds the dark eye/brow ink would vanish, so flip it
      final eyeColor = dark
          ? const Color(0xFFF1F5F9)
          : hsl.withLightness((hsl.lightness * 0.35).clamp(0.05, 0.25)).toColor();
      final eyePaint = Paint()..color = _a(eyeColor, faceA);
      final shine = Paint()
        ..color = _a(dark ? const Color(0xFF0B0F1A) : Colors.white, faceA);
      // ---- crisp vector details (mouth, whiskers, brows, toes, scales...) ----
      final lineP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fillP = Paint()..style = PaintingStyle.fill;
      for (final poly in grid.details) {
        if (poly.tag.isNotEmpty && ep != null && ep.amount > 0.99) continue;
        final hideA = (poly.tag.isNotEmpty && ep != null) ? 1 - ep.amount : 1.0;
        final path = Path();
        for (var i = 0; i < poly.pts.length; i++) {
          final q = poly.pts[i];
          final w = wp(q.dx, q.dy);
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
                  ..color = _a(eyeColor, 0.9 * faceA * hideA)
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
          case 5 || 6 || 7 || 8 || 9 || 10 || 11 || 12 || 13 || 14:
            canvas.drawPath(
                path, fillP..color = _a(_kFillPalette[poly.kind - 5], faceA));
          case 20 || 21 || 22:
            canvas.drawPath(
                path,
                lineP
                  ..color = _a(_kStrokePalette[poly.kind - 20], 0.95 * faceA)
                  ..strokeWidth = poly.width);
          default:
            canvas.drawPath(path, fillP..color = _a(_blush, faceA));
        }
      }

      final fx = signature ? motion.roarFx : null;
      final roarOpen = fx == null ? 0.0 : fx.open(seconds) * alive;
      final roarAnger = fx == null ? 0.0 : fx.anger(seconds) * alive;
      final b = math.max(motion.blink(seconds), roarAnger * 0.32);
      // ---- roaring mouth: dark cavity, tongue, fangs ----
      if (fx != null && roarOpen > 0.02) {
        final mw = wp(fx.mouth.dx, fx.mouth.dy);
        final cx = fx.mouth.dx + mw.dx * alive, cy = fx.mouth.dy + mw.dy * alive;
        final w = fx.mouthW * (0.55 + 0.45 * roarOpen);
        final h = fx.mouthH * roarOpen;
        final cavity = Path()
          ..moveTo(cx - w, cy)
          ..quadraticBezierTo(cx - w * 0.9, cy + h * 1.05, cx, cy + h * 1.1)
          ..quadraticBezierTo(cx + w * 0.9, cy + h * 1.05, cx + w, cy)
          ..quadraticBezierTo(cx, cy - h * 0.12, cx - w, cy)
          ..close();
        canvas.drawPath(cavity,
            fillP..color = _a(Color.lerp(eyeColor, Colors.black, 0.45)!, faceA));
        canvas.save();
        canvas.clipPath(cavity);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, cy + h * 0.98), width: w * 1.3, height: h * 0.85),
            fillP..color = _a(const Color(0xFFFF7FA6), faceA));
        canvas.restore();
        final fang = fillP..color = _a(Colors.white, faceA);
        for (final s in [-1.0, 1.0]) {
          final fx0 = cx + s * w * 0.55;
          canvas.drawPath(
              Path()
                ..moveTo(fx0 - 1.5, cy + 0.1)
                ..lineTo(fx0 + 1.5, cy + 0.1)
                ..lineTo(fx0, cy + 1.2 + 3.4 * roarOpen)
                ..close(),
              fang);
          canvas.drawPath(
              Path()
                ..moveTo(fx0 * 0.6 + cx * 0.4 - 1.1, cy + h * 1.06)
                ..lineTo(fx0 * 0.6 + cx * 0.4 + 1.1, cy + h * 1.06)
                ..lineTo(fx0 * 0.6 + cx * 0.4, cy + h * 1.06 - 2.2 * roarOpen)
                ..close(),
              fang);
        }
      }

      // eyes hold, then flick to a new spot (saccades) instead of orbiting
      final gk = (seconds / 1.8).floorToDouble();
      final ga = _gazeEase((seconds - gk * 1.8) / 0.18);
      Offset gz(double k) =>
          Offset((hash01(k, 1) - 0.5) * 1.8, (hash01(k, 2) - 0.5) * 1.0);
      final look = Offset.lerp(gz(gk - 1), gz(gk), ga)! * alive;
      for (final e in a.eyes) {
        final c = at(e) + look;
        final r = e.r * pop;
        if (ep != null) {
          drawExprEye(canvas, c, r, ep, e.x < 50, b, eyeColor,
              dark ? const Color(0xFF0B0F1A) : Colors.white, faceA);
          continue;
        }
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1.0, 1.0 - 0.88 * b);
        canvas.drawCircle(Offset.zero, r, eyePaint);
        canvas.drawCircle(Offset(-r * 0.32, -r * 0.34), r * 0.36, shine);
        canvas.drawCircle(Offset(r * 0.34, r * 0.30), r * 0.16, shine);
        canvas.restore();
      }
      if (ep != null && exprFace != null) {
        Offset atXY(double x, double y) {
          final w = wp(x, y);
          return Offset(x + w.dx * alive, y + w.dy * alive);
        }
        drawExprFace(canvas, exprFace!, ep, atXY, eyeColor, faceA, seconds,
            [for (final e in a.eyes) at(e) + look],
            a.eyes.isEmpty ? 4.0 : a.eyes.first.r * pop);
      }
      // ---- angry brows slam down over the eyes ----
      if (roarAnger > 0.02) {
        for (final e in a.eyes) {
          final c = at(e) + look;
          final s = e.x < 50 ? -1.0 : 1.0;
          canvas.drawLine(
              Offset(c.dx + s * 7.5, c.dy - 6.2 - (1 - roarAnger) * 2),
              Offset(c.dx - s * 5.0, c.dy - 1.4),
              lineP
                ..color = _a(eyeColor, 0.95 * faceA)
                ..strokeWidth = 1.2 + 1.8 * roarAnger);
        }
      }
    }

    // ---- signature overlay effects (drawn in world space, attached via at) ----
    if (sig?.fx != null && su >= 0 && alive > 0.5) {
      // we are still inside the pose transform, so only the warp is needed
      Offset sigAt(double x, double y) {
        final w = wp(x, y);
        return Offset(x + w.dx * alive, y + w.dy * alive);
      }
      sig!.fx!(canvas, SigCtx(su, seconds, alive, color, sigAt));
    }

    // ---- roar shock lines + rings ----
    final rfx = signature ? motion.roarFx : null;
    if (rfx != null) {
      final ro = rfx.open(seconds) * alive;
      if (ro > 0.05) {
        final bc = rfx.burst;
        final dash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.3
          ..color = _a(color, 0.85 * ro);
        for (var i = 0; i < 16; i++) {
          final ang = i * math.pi * 2 / 16 + math.sin(seconds * 7 + i) * 0.04;
          final r0 = 46 + 2.5 * math.sin(seconds * 24 + i * 1.7);
          final r1 = r0 + 4 + 5 * ro;
          final p0 = Offset(bc.dx + math.cos(ang) * r0, bc.dy + math.sin(ang) * r0);
          final p1 = Offset(bc.dx + math.cos(ang) * r1, bc.dy + math.sin(ang) * r1);
          if (p1.dy < 2 || p0.dy < 2 || p1.dx < 1 || p1.dx > 99) continue;
          canvas.drawLine(p0, p1, dash);
        }
        for (var k = 0; k < 2; k++) {
          final ph = (seconds * 1.8 - k * 0.5) % 1.0;
          canvas.drawCircle(
              rfx.mouth + const Offset(0, 4),
              12 + ph * 34,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.1
                ..color = _a(color, (1 - ph) * 0.45 * ro));
        }
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

    canvas.restore(); // inner
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DitherPainter old) =>
      old.grid != grid ||
      old.color != color ||
      old.theme != theme ||
      old.dark != dark ||
      old.dot != dot ||
      old.dotScale != dotScale ||
      old.dotDensity != dotDensity ||
      old.phase != phase ||
      old.mode != mode ||
      old.shimmer != shimmer ||
      old.showFace != showFace ||
      old.sparkles != sparkles ||
      old.signature != signature ||
      old.exprFace != exprFace ||
      old.exprFrom != exprFrom ||
      old.exprTo != exprTo ||
      old.exprStart != exprStart ||
      old.sigDef != sigDef ||
      old.loopSeconds != loopSeconds ||
      old.motion != motion ||
      old.art != art;
}
