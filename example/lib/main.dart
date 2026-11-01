import 'package:dither_animals/dither_animals.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DitherAnimalsDemoApp());

class DitherAnimalsDemoApp extends StatelessWidget {
  const DitherAnimalsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dither Animals Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F3BFF),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      home: const AnimalsGalleryPage(),
    );
  }
}

class AnimalSpec {
  const AnimalSpec(this.type, this.color, this.label, this.personality);
  final DitherAnimalType type;
  final Color color;
  final String label;
  final String personality;
}

const animalSpecs = [
  AnimalSpec(DitherAnimalType.owl, Color(0xFFFF5A1F), 'Owl', 'sways & blinks'),
  AnimalSpec(DitherAnimalType.elephant, Color(0xFF0A2BE0), 'Elephant', 'trunk swing'),
  AnimalSpec(DitherAnimalType.rabbit, Color(0xFF7B2FF7), 'Rabbit', 'hops gently'),
  AnimalSpec(DitherAnimalType.fish, Color(0xFFE6197A), 'Fish', 'swims & blows bubbles'),
  AnimalSpec(DitherAnimalType.turtle, Color(0xFF16A37F), 'Turtle', 'paddles smoothly'),
  AnimalSpec(DitherAnimalType.cat, Color(0xFFF59E0B), 'Cat', 'tail swish & perked ears'),
  AnimalSpec(DitherAnimalType.penguin, Color(0xFF0D9488), 'Penguin', 'waddles side-to-side'),
  AnimalSpec(DitherAnimalType.frog, Color(0xFF65A30D), 'Frog', 'big springy hops'),
  AnimalSpec(DitherAnimalType.octopus, Color(0xFFE11D48), 'Octopus', 'jets & undulating tentacles'),
  AnimalSpec(DitherAnimalType.bear, Color(0xFF8B5A2B), 'Bear', 'happy rhythmic dance'),
  AnimalSpec(DitherAnimalType.lion, Color(0xFFB45309), 'Lion', 'roars with majestic mane'),
  AnimalSpec(DitherAnimalType.tiger, Color(0xFFE8590C), 'Tiger', 'prowls stealthily'),
  AnimalSpec(DitherAnimalType.dog, Color(0xFF6D4C41), 'Dog', 'wags tail excitedly'),
  AnimalSpec(DitherAnimalType.panda, Color(0xFF1F2937), 'Panda', 'munches bamboo leisurely'),
  AnimalSpec(DitherAnimalType.pig, Color(0xFFF472B6), 'Pig', 'snuffles & bounces'),
  AnimalSpec(DitherAnimalType.fox, Color(0xFFC2410C), 'Fox', 'sly bushy sweep'),
  AnimalSpec(DitherAnimalType.monkey, Color(0xFFA16207), 'Monkey', 'swings playfully'),
  AnimalSpec(DitherAnimalType.duck, Color(0xFFEAB308), 'Duck', 'quacks & bobs head'),
  AnimalSpec(DitherAnimalType.sheep, Color(0xFF6366F1), 'Sheep', 'fluffy boings'),
  AnimalSpec(DitherAnimalType.hedgehog, Color(0xFF57534E), 'Hedgehog', 'bristles & scurries'),
  AnimalSpec(DitherAnimalType.sun, Color(0xFFF59E0B), 'Sun', 'radiant rays wiggle'),
  AnimalSpec(DitherAnimalType.cloud, Color(0xFF3B82F6), 'Cloud', 'floats & sprinkles rain'),
  AnimalSpec(DitherAnimalType.moon, Color(0xFF6D28D9), 'Moon', 'sleepy serene rock'),
  AnimalSpec(DitherAnimalType.star, Color(0xFFEAB308), 'Star', 'twinkles brightly'),
  AnimalSpec(DitherAnimalType.ghost, Color(0xFF64748B), 'Ghost', 'spooky floating boo!'),
  AnimalSpec(DitherAnimalType.mushroom, Color(0xFFDC2626), 'Mushroom', 'jelly cap hop'),
  AnimalSpec(DitherAnimalType.cactus, Color(0xFF15803D), 'Cactus', 'desert desert sway'),
  AnimalSpec(DitherAnimalType.robot, Color(0xFF0369A1), 'Robot', 'boots up & beeps'),
  AnimalSpec(DitherAnimalType.rocket, Color(0xFFEA580C), 'Rocket', 'blasts off to orbit'),
  AnimalSpec(DitherAnimalType.cupcake, Color(0xFFDB2777), 'Cupcake', 'wobbles deliciously'),
];

class AnimalsGalleryPage extends StatefulWidget {
  const AnimalsGalleryPage({super.key});

  @override
  State<AnimalsGalleryPage> createState() => _AnimalsGalleryPageState();
}

class _AnimalsGalleryPageState extends State<AnimalsGalleryPage> {
  int _replayKey = 0;
  DitherDot _dotShape = DitherDot.square;
  DitherMotion _motionMode = DitherMotion.loop;
  int _cells = 96;
  String _searchQuery = '';
  bool _showFace = true;
  bool _sparkles = true;

  @override
  Widget build(BuildContext context) {
    final filtered = animalSpecs.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.label.toLowerCase().contains(q) ||
          s.personality.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dither_animals',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Animated ordered-dither animal widgets',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Replay all animations',
            icon: const Icon(Icons.replay),
            onPressed: () => setState(() => _replayKey++),
          ),
          IconButton(
            tooltip: 'Toggle Dot Shape (Round/Square)',
            icon: Icon(
              _dotShape == DitherDot.round
                  ? Icons.circle
                  : Icons.crop_square_rounded,
            ),
            onPressed: () => setState(() {
              _dotShape = _dotShape == DitherDot.square
                  ? DitherDot.round
                  : DitherDot.square;
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildControlsBar(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching animals found.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < filtered.length; i++)
                                _AnimalCard(
                                  key: ValueKey(
                                    '${filtered[i].type.name}-$_replayKey-$_dotShape-$_cells-$_motionMode-$_showFace-$_sparkles',
                                  ),
                                  spec: filtered[i],
                                  phase: i * 0.11,
                                  dotShape: _dotShape,
                                  motionMode: _motionMode,
                                  cells: _cells,
                                  showFace: _showFace,
                                  sparkles: _sparkles,
                                  onReplay: () => setState(() => _replayKey++),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'Showing ${filtered.length} of ${animalSpecs.length} animals • Tap any animal to poke it!',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search 30 animals (owl, lion, rocket, cupcake...)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<DitherDot>(
                  segments: const [
                    ButtonSegment(
                      value: DitherDot.square,
                      label: Text('Square Dots', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: DitherDot.round,
                      label: Text('Round Dots', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_dotShape},
                  onSelectionChanged: (s) => setState(() => _dotShape = s.first),
                ),
                const SizedBox(width: 8),
                SegmentedButton<DitherMotion>(
                  segments: const [
                    ButtonSegment(
                      value: DitherMotion.loop,
                      label: Text('Loop', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: DitherMotion.once,
                      label: Text('Once', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_motionMode},
                  onSelectionChanged: (s) =>
                      setState(() => _motionMode = s.first),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Face', style: TextStyle(fontSize: 11)),
                  selected: _showFace,
                  onSelected: (v) => setState(() => _showFace = v),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Sparkles', style: TextStyle(fontSize: 11)),
                  selected: _sparkles,
                  onSelected: (v) => setState(() => _sparkles = v),
                ),
                const SizedBox(width: 8),
                Text('Grid: ${_cells}x$_cells',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _cells.toDouble(),
                    min: 48,
                    max: 128,
                    divisions: 5,
                    onChanged: (v) => setState(() => _cells = v.round()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({
    super.key,
    required this.spec,
    required this.phase,
    required this.dotShape,
    required this.motionMode,
    required this.cells,
    required this.showFace,
    required this.sparkles,
    required this.onReplay,
  });

  final AnimalSpec spec;
  final double phase;
  final DitherDot dotShape;
  final DitherMotion motionMode;
  final int cells;
  final bool showFace;
  final bool sparkles;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DitherAnimal(
            animal: spec.type,
            color: spec.color,
            phase: phase,
            cells: cells,
            dot: dotShape,
            motion: motionMode,
            showFace: showFace,
            sparkles: sparkles,
            pokeable: true,
          ),
          const SizedBox(height: 6),
          Text(
            spec.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            spec.personality,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
