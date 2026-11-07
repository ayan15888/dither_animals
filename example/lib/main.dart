import 'package:flutter/material.dart';
import 'package:dither_animals/dither_animals.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class _Spec {
  const _Spec(this.type, this.color, this.label);
  final DitherAnimalType type;
  final Color color;
  final String label;
}

const _specs = [
  _Spec(DitherAnimalType.owl, Color(0xFFFF5A1F), '01 Owl · head swivel'),
  _Spec(DitherAnimalType.elephant, Color(0xFF0A2BE0), '02 Elephant · water spray'),
  _Spec(DitherAnimalType.rabbit, Color(0xFF7B2FF7), '03 Rabbit · binky hop'),
  _Spec(DitherAnimalType.fish, Color(0xFFE6197A), '04 Fish · speed dart'),
  _Spec(DitherAnimalType.turtle, Color(0xFF16A37F), '05 Turtle · shell hide'),
  _Spec(DitherAnimalType.cat, Color(0xFFF59E0B), '06 Cat · pounce + purr'),
  _Spec(DitherAnimalType.penguin, Color(0xFF0D9488), '07 Penguin · waddles'),
  _Spec(DitherAnimalType.frog, Color(0xFF65A30D), '08 Frog · big hops'),
  _Spec(DitherAnimalType.octopus, Color(0xFFE11D48), '09 Octopus · jets'),
  _Spec(DitherAnimalType.bear, Color(0xFF8B5A2B), '10 Bear · happy dance'),
  _Spec(DitherAnimalType.lion, Color(0xFFB45309), '11 Lion · roars'),
  _Spec(DitherAnimalType.tiger, Color(0xFFE8590C), '12 Tiger · prowls'),
  _Spec(DitherAnimalType.dog, Color(0xFF6D4C41), '13 Dog · wags'),
  _Spec(DitherAnimalType.panda, Color(0xFF1F2937), '14 Panda · munches'),
  _Spec(DitherAnimalType.mouse, Color(0xFF64748B), '15 Mouse · nibbles'),
  _Spec(DitherAnimalType.fox, Color(0xFFC2410C), '16 Fox · sly sweep'),
  _Spec(DitherAnimalType.monkey, Color(0xFFA16207), '17 Monkey · swings'),
  _Spec(DitherAnimalType.duck, Color(0xFFEAB308), '18 Duck · quacks'),
  _Spec(DitherAnimalType.sheep, Color(0xFF6366F1), '19 Sheep · boings'),
  _Spec(DitherAnimalType.hedgehog, Color(0xFF57534E), '20 Hedgehog · bristles'),
  _Spec(DitherAnimalType.koala, Color(0xFF6B7280), '21 Koala · sleepy'),
  _Spec(DitherAnimalType.raccoon, Color(0xFF475569), '22 Raccoon · sneaky'),
  _Spec(DitherAnimalType.whale, Color(0xFF0EA5E9), '23 Whale · spouts'),
  _Spec(DitherAnimalType.bee, Color(0xFFCA8A04), '24 Bee · buzzes'),
  _Spec(DitherAnimalType.cow, Color(0xFF334155), '25 Cow · chews & nods'),
  _Spec(DitherAnimalType.giraffe, Color(0xFFD97706), '26 Giraffe · graceful sway'),
  _Spec(DitherAnimalType.zebra, Color(0xFF111827), '27 Zebra · gallops'),
  _Spec(DitherAnimalType.crab, Color(0xFFDC2626), '28 Crab · scuttles'),
  _Spec(DitherAnimalType.flamingo, Color(0xFFF43F5E), '29 Flamingo · neck ribbon'),
  _Spec(DitherAnimalType.butterfly, Color(0xFF2563EB), '30 Butterfly · flutters'),
  _Spec(DitherAnimalType.snail, Color(0xFFA0623A), '31 Snail · glides'),
  _Spec(DitherAnimalType.squirrel, Color(0xFFB5541C), '32 Squirrel · tail sweep'),
  _Spec(DitherAnimalType.hippo, Color(0xFF6F85A6), '33 Hippo · yawns'),
  _Spec(DitherAnimalType.deer, Color(0xFF9C6B3C), '34 Deer · bounds'),
  _Spec(DitherAnimalType.parrot, Color(0xFF1F6FEB), '35 Parrot · flutters'),
  _Spec(DitherAnimalType.kangaroo, Color(0xFFC98A4B), '36 Kangaroo · hops'),
  _Spec(DitherAnimalType.shark, Color(0xFF5C7A99), '37 Shark · glides'),
  _Spec(DitherAnimalType.chicken, Color(0xFFC9A27A), '38 Chicken · pecks'),
  _Spec(DitherAnimalType.ladybug, Color(0xFFD62828), '39 Ladybug · crawls'),
  _Spec(DitherAnimalType.wolf, Color(0xFF6B7785), '40 Wolf · howls'),
  _Spec(DitherAnimalType.horse, Color(0xFF8B5E3C), '41 Horse · tosses mane'),
  _Spec(DitherAnimalType.camel, Color(0xFFD0A050), '42 Camel · chews'),
  _Spec(DitherAnimalType.rhino, Color(0xFF7B8794), '43 Rhino · scrapes'),
  _Spec(DitherAnimalType.goat, Color(0xFF9A8F7D), '44 Goat · kick-hops'),
  _Spec(DitherAnimalType.seal, Color(0xFF3F6E8C), '45 Seal · claps'),
  _Spec(DitherAnimalType.bat, Color(0xFF5B3A7A), '46 Bat · hovers'),
  _Spec(DitherAnimalType.crocodile, Color(0xFF3C8D40), '47 Crocodile · snaps'),
  _Spec(DitherAnimalType.jellyfish, Color(0xFFD36BC4), '48 Jellyfish · pulses'),
  _Spec(DitherAnimalType.peacock, Color(0xFF0E8A8A), '49 Peacock · fans tail'),
  _Spec(DitherAnimalType.redpanda, Color(0xFFC2410C), '50 Red panda · tail ripple'),
];

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  int _replay = 0;
  bool _signature = true;
  DitherDot _dot = DitherDot.square;
  DitherColorMode _mode = DitherColorMode.solid;
  bool _dark = false;
  bool _haptics = true;
  bool _autoMood = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
          useMaterial3: true,
          brightness: _dark ? Brightness.dark : Brightness.light),
      child: Scaffold(
      backgroundColor: _dark ? const Color(0xFF0B0F1A) : const Color(0xFFE4E4E6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Anatomy of\nAdaptation',
                style: TextStyle(
                    fontSize: 30, height: 1.1, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text('A visual study of how life evolves,\nadapts, and thrives.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Signature moves'),
                subtitle: const Text('Roar, spray, pounce... one special trick per animal'),
                value: _signature,
                onChanged: (v) => setState(() => _signature = v),
              ),
              SegmentedButton<DitherDot>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DitherDot.square, label: Text('Square')),
                  ButtonSegment(value: DitherDot.round, label: Text('Round')),
                  ButtonSegment(value: DitherDot.hex, label: Text('Hex')),
                  ButtonSegment(value: DitherDot.diamond, label: Text('Diamond')),
                ],
                selected: {_dot},
                onSelectionChanged: (v) => setState(() => _dot = v.first),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DitherColorMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DitherColorMode.solid, label: Text('Solid')),
                  ButtonSegment(value: DitherColorMode.twoTone, label: Text('Two-tone')),
                  ButtonSegment(value: DitherColorMode.gradient, label: Text('Gradient')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                value: _dark,
                onChanged: (v) => setState(() => _dark = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto mood (all animals)'),
                subtitle: const Text('Facial expressions that change on their own'),
                value: _autoMood,
                onChanged: (v) => setState(() => _autoMood = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Haptics'),
                subtitle: const Text('Buzz on form, signature moves and taps'),
                value: _haptics,
                onChanged: (v) => setState(() => _haptics = v),
              ),
              const Text('Tap the tune icon on any card to open its full studio',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < _specs.length; i++)
                    GestureDetector(
                      onLongPress: () => setState(() => _replay++),
                      child: _AnimalCard(
                        key: ValueKey('$i-$_replay'),
                        spec: _specs[i],
                        signature: _signature,
                        dot: _dot,
                        mode: _mode,
                        dark: _dark,
                        haptics: _haptics,
                        autoMood: _autoMood,
                        phase: i * 0.11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Tap an animal to poke it · long-press a card to replay',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        ),
      ),
    ));
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard(
      {super.key,
      required this.spec,
      required this.phase,
      required this.signature,
      required this.dot,
      required this.mode,
      required this.dark,
      required this.haptics,
      required this.autoMood});
  final _Spec spec;
  final bool signature;
  final DitherDot dot;
  final DitherColorMode mode;
  final bool dark;
  final bool haptics;
  final bool autoMood;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF151B2B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DitherAnimal(
            animal: spec.type,
            color: spec.color,
            phase: phase,
            cells: 96,
            signature: signature,
            dot: dot,
            theme: DitherTheme(
              mode: mode,
              secondary: const Color(0xFFFFB020),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            hooks: haptics ? DitherHooks.haptics() : null,
            autoMood: autoMood,
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(spec.label,
                  style: TextStyle(
                      fontSize: 10, color: dark ? Colors.white60 : Colors.black45)),
            ),
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      AnimalStudioPage(animal: spec.type, color: spec.color))),
              child: Icon(Icons.tune,
                  size: 18, color: dark ? Colors.white70 : Colors.black45),
            ),
          ]),
        ],
      ),
    );
  }
}
