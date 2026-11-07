import 'package:flutter/material.dart';

import 'dither_animal.dart';

/// Live dot-style, theme and haptics playground for any animal: change the dot shape, density, size
/// and resolution and watch the owl update instantly.
class AnimalStudioPage extends StatefulWidget {
  const AnimalStudioPage(
      {super.key,
      this.animal = DitherAnimalType.owl,
      this.color = const Color(0xFFFF5A1F)});
  final DitherAnimalType animal;
  final Color color;

  @override
  State<AnimalStudioPage> createState() => _AnimalStudioPageState();
}

class _AnimalStudioPageState extends State<AnimalStudioPage> {
  late DitherAnimalType _animal = widget.animal;
  DitherDot _dot = DitherDot.square;
  double _density = 1.0; // ink amount
  double _size = 0.9; // dot size
  double _shimmer = 0.03;
  int _cells = 96; // applied value
  double _cellsDraft = 96; // slider value while dragging
  bool _signature = true;
  late Color _color = widget.color;

  // theming
  DitherColorMode _mode = DitherColorMode.solid;
  Color _secondary = const Color(0xFFFFB020);
  double _angle = 90;
  double _mix = 0.3;
  final Map<DitherPart, Color> _parts = {
    DitherPart.head: const Color(0xFFFF5A1F),
    DitherPart.ears: const Color(0xFF111827),
    DitherPart.sides: const Color(0xFF16A37F),
    DitherPart.feet: const Color(0xFFFFB020),
    DitherPart.body: const Color(0xFFE6197A),
  };
  bool _dark = false;

  // expressions (cat and tiger)
  DitherExpression _expr = DitherExpression.neutral;
  bool _autoMood = false;

  // hooks / haptics
  bool _haptics = true;
  String _lastEvent = '-';

  DitherTheme get _theme => DitherTheme(
        mode: _mode,
        primary: _color,
        secondary: _secondary,
        gradientAngle: _angle,
        twoToneMix: _mix,
        parts: Map.of(_parts),
        brightness: _dark ? Brightness.dark : Brightness.light,
      );

  DitherHooks get _hooks {
    void log(String e) => setState(() => _lastEvent = e);
    final mine = DitherHooks(
      onFormed: (_) => log('formed'),
      onDissolve: (_) => log('dissolve'),
      onSignatureStart: (_) => log('signature start'),
      onSignaturePeak: (_) => log('signature PEAK'),
      onSignatureEnd: (_) => log('signature end'),
      onPoke: (_) => log('poke'),
    );
    return _haptics ? DitherHooks.haptics(also: mine) : mine;
  }

  static const _colors = [
    Color(0xFFFF5A1F),
    Color(0xFF1F3BFF),
    Color(0xFF16A37F),
    Color(0xFF7B2FF7),
    Color(0xFFE6197A),
    Color(0xFF111827),
  ];

  static const _shapes = {
    DitherDot.square: ('Square', Icons.crop_square),
    DitherDot.round: ('Round', Icons.circle_outlined),
    DitherDot.hex: ('Hex', Icons.hexagon_outlined),
    DitherDot.diamond: ('Diamond', Icons.diamond_outlined),
  };

  Widget _owl({
    DitherDot? dot,
    int? cells,
    double? density,
    double? size,
    bool events = false,
  }) =>
      DitherAnimal(
        animal: _animal,
        color: _color,
        dot: dot ?? _dot,
        cells: cells ?? _cells,
        dotDensity: density ?? _density,
        dotScale: size ?? _size,
        shimmer: _shimmer,
        signature: _signature,
        theme: _theme,
        expression: _expr,
        autoMood: _autoMood,
        hooks: events ? _hooks : null, // only the big preview fires events
        motion: DitherMotion.once,
      );

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {ValueChanged<double>? onEnd, String? shown, int? divisions}) {
    return Row(children: [
      SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 13))),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onEnd,
        ),
      ),
      SizedBox(
          width: 44,
          child: Text(shown ?? value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Colors.black54))),
    ]);
  }

  Widget _swatches(String label, Color value, ValueChanged<Color> onPick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 13))),
        for (final c in _colors)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: c == value ? Colors.grey : Colors.transparent, width: 2),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF0B0F1A) : const Color(0xFFE4E4E6);
    final card = _dark ? const Color(0xFF151B2B) : Colors.white;
    return Theme(
      data: ThemeData(
          useMaterial3: true,
          brightness: _dark ? Brightness.dark : Brightness.light),
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('${_animal.name} studio'),
        backgroundColor: bg,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in DitherAnimalType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(a.name),
                      selected: a == _animal,
                      onSelected: (_) => setState(() => _animal = a),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ---- big live preview ----
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))
                ],
              ),
              child: _owl(events: true),
            ),
          ),
          const SizedBox(height: 16),
          // ---- shape picker ----
          SegmentedButton<DitherDot>(
            showSelectedIcon: false,
            segments: [
              for (final e in _shapes.entries)
                ButtonSegment(
                    value: e.key, label: Text(e.value.$1), icon: Icon(e.value.$2, size: 18)),
            ],
            selected: {_dot},
            onSelectionChanged: (s) => setState(() => _dot = s.first),
          ),
          const SizedBox(height: 8),
          _slider('Density', _density, 0.4, 1.6, (v) => setState(() => _density = v)),
          _slider('Dot size', _size, 0.4, 1.3, (v) => setState(() => _size = v)),
          _slider('Detail', _cellsDraft, 40, 128, (v) => setState(() => _cellsDraft = v),
              onEnd: (v) => setState(() => _cells = v.round()),
              shown: '${_cellsDraft.round()}',
              divisions: 22),
          _slider('Shimmer', _shimmer, 0, 0.15, (v) => setState(() => _shimmer = v)),
          Row(children: [
            const SizedBox(width: 74, child: Text('Color', style: TextStyle(fontSize: 13))),
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: c == _color ? Colors.black : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          if (kExprFaces.containsKey(_animal)) ...[
            const Text('Expression', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in DitherExpression.values)
                ChoiceChip(
                  label: Text(e.name),
                  selected: !_autoMood && e == _expr,
                  onSelected: (_) => setState(() {
                    _expr = e;
                    _autoMood = false;
                  }),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto mood'),
              subtitle: const Text('Changes by itself and reacts to its signature move'),
              value: _autoMood,
              onChanged: (v) => setState(() => _autoMood = v),
            ),
            const SizedBox(height: 6),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Expressions: not available for this animal',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          SegmentedButton<DitherColorMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: DitherColorMode.solid, label: Text('Solid')),
              ButtonSegment(value: DitherColorMode.twoTone, label: Text('Two-tone')),
              ButtonSegment(value: DitherColorMode.gradient, label: Text('Gradient')),
              ButtonSegment(value: DitherColorMode.parts, label: Text('Parts')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          if (_mode == DitherColorMode.twoTone || _mode == DitherColorMode.gradient)
            _swatches('2nd color', _secondary, (c) => setState(() => _secondary = c)),
          if (_mode == DitherColorMode.twoTone)
            _slider('Mix', _mix, 0.05, 0.6, (v) => setState(() => _mix = v)),
          if (_mode == DitherColorMode.gradient)
            _slider('Angle', _angle, 0, 360, (v) => setState(() => _angle = v),
                shown: '${_angle.round()}°'),
          if (_mode == DitherColorMode.parts)
            for (final part in DitherPart.values)
              _swatches(part.name, _parts[part]!, (c) => setState(() => _parts[part] = c)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark mode'),
            subtitle: const Text('Dark background, dot colors auto-lightened'),
            value: _dark,
            onChanged: (v) => setState(() => _dark = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptics'),
            subtitle: Text('Last event: $_lastEvent'),
            value: _haptics,
            onChanged: (v) => setState(() => _haptics = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Signature move'),
            value: _signature,
            onChanged: (v) => setState(() => _signature = v),
          ),
          const SizedBox(height: 4),
          const Text('Compare all shapes (same settings)',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in _shapes.entries)
              Container(
                width: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: card, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  _owl(dot: e.key, cells: 72),
                  Text(e.value.$1,
                      style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ]),
              ),
          ]),
          const SizedBox(height: 8),
          const Text('Density compare (sparse · normal · bold)',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          Row(children: [
            for (final d in const [0.6, 1.0, 1.4])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: card, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    _owl(density: d, cells: 64),
                    Text('${d}x',
                        style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                ),
              ),
          ]),
        ],
      ),
    ));
  }
}
