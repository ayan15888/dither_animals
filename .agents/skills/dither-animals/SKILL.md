---
name: dither-animals
description: Comprehensive guide and code recipes for creating cute animated ordered-dither (stipple/halftone) animal widgets, retro pixel mascots, gamified companions, and interactive poke physics in Flutter using the dither_animals package.
---

# `dither_animals` Skill for Flutter

Use this skill whenever a user or task involves:
- Adding cute animated animal widgets or retro chibi mascots in Flutter.
- Ordered Bayer matrix dithering, stipple shading, or halftone retro visuals.
- Designing engaging empty states, loading indicators, 404 screens, onboarding illustrations, or success celebrations.
- Implementing interactive pets or companions with poke physics and haptic feedback.
- Custom image dithering (rendering logos/avatars as animated dithered dots).

---

## 1. Package Installation & Import

Add the package:
```bash
flutter pub add dither_animals
```

Import in Dart:
```dart
import 'package:dither_animals/dither_animals.dart';
```

---

## 2. Widget Selection Guide

Choose the right widget based on the use case:

| Widget | When to Use | Example |
|---|---|---|
| **`DitherPet`** | High-level drop-in for standard cards, buttons, avatars, and quick mascots. Simple named constructors. | `DitherPet.cat(mood: PetMood.happy)` |
| **`DitherAnimal`** | Full control over matrix resolution (`cells`), dot shapes (`DitherDot`), gradient themes, custom images, and callbacks. | `DitherAnimal(animal: DitherAnimalType.owl, cells: 96)` |
| **`AnimalStudioPage`** | Interactive debugging and playground screen to test and tune density, colors, and signatures live. | `Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalStudioPage()))` |

---

## 3. All 50 Available Animal Presets (`DitherAnimalType`)

| Category | Available Enums |
|---|---|
| **Forest & Woodland** | `owl`, `rabbit`, `bear`, `fox`, `hedgehog`, `deer`, `squirrel`, `wolf`, `raccoon` |
| **Pets & Farm** | `cat`, `dog`, `mouse`, `duck`, `sheep`, `cow`, `horse`, `goat`, `chicken`, `pig` |
| **Savanna & Jungle** | `lion`, `tiger`, `elephant`, `monkey`, `giraffe`, `zebra`, `hippo`, `rhino`, `camel`, `kangaroo`, `redpanda`, `panda`, `koala` |
| **Ocean & Water** | `fish`, `turtle`, `penguin`, `frog`, `octopus`, `whale`, `crab`, `flamingo`, `shark`, `seal`, `crocodile`, `jellyfish` |
| **Insects & Birds** | `bee`, `butterfly`, `snail`, `parrot`, `ladybug`, `bat`, `peacock` |

---

## 4. Visual Styles & Configuration

### A. Dot Shapes (`DitherDot` / `PetDot`)
- `DitherDot.square` (or `PetDot.square`): Crisp 80s/90s Mac retro pixel style. Highest performance.
- `DitherDot.round` (or `PetDot.round`): Organic halftone printing look.
- `DitherDot.hex` (or `PetDot.hex`): Modern hexagonal honeycomb matrix.
- `DitherDot.diamond` (or `PetDot.diamond`): Stylized rotated diamond points.

### B. Color Modes & Themes (`DitherTheme`)
```dart
// Solid color
DitherAnimal(
  animal: DitherAnimalType.frog,
  color: const Color(0xFF65A30D),
)

// Gradient blend
DitherAnimal(
  animal: DitherAnimalType.whale,
  theme: const DitherTheme(
    mode: DitherColorMode.gradient,
    primary: Color(0xFF0EA5E9),
    secondary: Color(0xFF6366F1),
    gradientAngle: 45,
  ),
)

// Two-tone stipple speckle
DitherAnimal(
  animal: DitherAnimalType.tiger,
  theme: const DitherTheme(
    mode: DitherColorMode.twoTone,
    primary: Color(0xFFE8590C),
    secondary: Color(0xFF111827),
    twoToneMix: 0.35,
  ),
)
```

### C. Moods & Expressions (`DitherExpression` / `PetMood`)
Four expressive facial moods:
- `DitherExpression.neutral` (or `PetMood.neutral`)
- `DitherExpression.happy` (or `PetMood.happy`)
- `DitherExpression.angry` (or `PetMood.angry`)
- `DitherExpression.sleepy` (or `PetMood.sleepy`)

To make moods dynamic automatically:
```dart
DitherAnimal(
  animal: DitherAnimalType.cat,
  autoMood: true, // Changes expressions naturally and reacts to moves
)
```

### D. Motion & Interaction
- `motion: DitherMotion.loop` — Continuously loops through entrance build, idle breathing/swaying, and signature move.
- `motion: DitherMotion.once` — Assembles smoothly on initial render, then stays idle indefinitely.
- `pokeable: true` — Tap anywhere on the animal to send an expanding radial shockwave with haptic feedback.
- `phase: 0.2` — Stagger multiple animals so their animations don't pulse synchronously.

---

## 5. Production Code Recipes

### Recipe 1: Empty State / 404 Illustration
```dart
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 150,
              height: 150,
              child: DitherPet.koala(
                mood: PetMood.sleepy,
                dot: PetDot.round,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Recipe 2: Gamification / Reward Mascot
```dart
Widget buildRewardBanner(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.amber.shade200),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: DitherAnimal(
            animal: DitherAnimalType.peacock,
            color: Color(0xFF0E8A8A),
            motion: DitherMotion.loop,
            signature: true,
            sparkles: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Level 10 Achieved!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('You unlocked the Majestic Feather badge.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Recipe 3: Staggered Animal Grid
When rendering multiple animals together, stagger the `phase` property:
```dart
Wrap(
  spacing: 12,
  runSpacing: 12,
  children: [
    for (int i = 0; i < animals.length; i++)
      SizedBox(
        width: 100,
        height: 100,
        child: DitherAnimal(
          animal: animals[i],
          phase: i * 0.15, // Prevents synchronized pulsing
        ),
      ),
  ],
)
```

---

## 6. Best Practices & Rules for AI Agents

1. **Always wrap in a bounded container**: `DitherAnimal` expands to fit its parent constraints. Always place it inside a `SizedBox`, `Container`, or bounded `AspectRatio` (typical sizes: 60x60 to 200x200).
2. **Use `DitherPet` for rapid prototyping**: When generating UI code for users who just asked for an animal icon or avatar, default to `DitherPet.<animal>()`.
3. **Use `cells: 72..96` for standard screens**: Grid cell counts between 64 and 96 offer the best balance of authentic retro stippling and crisp readability on mobile screens.
4. **Prefer `DitherMotion.loop` for hero mascots and `DitherMotion.once` for static avatars**.

