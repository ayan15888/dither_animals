import 'package:dither_animals/dither_animals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DitherAnimalType & Art Specs', () {
    test('contains 50 defined animals', () {
      expect(DitherAnimalType.values.length, 50);
    });

    test('every animal type has defined art with layers', () {
      for (final type in DitherAnimalType.values) {
        final art = kAnimalArt[type];
        expect(art, isNotNull, reason: 'Missing art for ${type.name}');
        expect(art!.layers, isNotEmpty,
            reason: '${type.name} should have layers');
        expect(art.eyes, isNotNull);
        expect(art.cheeks, isNotNull);
      }
    });

    test('every animal type has defined motion personality', () {
      for (final type in DitherAnimalType.values) {
        final motion = AnimalMotion.of(type);
        expect(motion.seconds, greaterThan(0));
        expect(motion.buildEnd, greaterThan(0));
        expect(motion.holdEnd, greaterThanOrEqualTo(motion.buildEnd));
        expect(motion.dissolveEnd, greaterThanOrEqualTo(motion.holdEnd));
      }
    });
  });

  group('DitherAnimal Widget', () {
    testWidgets('renders default owl without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: DitherAnimal(animal: DitherAnimalType.owl, cells: 32),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DitherAnimal), findsOneWidget);
      // Pump initial frames for asynchronous grid build
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DitherAnimal), findsOneWidget);
    });

    testWidgets('renders with round dots and once motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: DitherAnimal(
                  animal: DitherAnimalType.cat,
                  dot: DitherDot.round,
                  motion: DitherMotion.once,
                  cells: 32,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DitherAnimal), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DitherAnimal), findsOneWidget);
    });

    testWidgets('can be tapped when pokeable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: DitherAnimal(
                  animal: DitherAnimalType.frog,
                  pokeable: true,
                  cells: 32,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DitherAnimal), findsOneWidget);

      await tester.tap(find.byType(DitherAnimal), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(DitherAnimal), findsOneWidget);
    });
  });
}
