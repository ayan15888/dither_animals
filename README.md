# dither_animals

[![pub package](https://img.shields.io/badge/pub-v2.1.0-blue.svg)](https://pub.dev/packages/dither_animals)
[![Live Showcase](https://img.shields.io/badge/Live%20Showcase-ditheranimals.vercel.app-FF6B35.svg?style=flat&logo=vercel)](https://ditheranimals.vercel.app/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10.0-02569B?logo=flutter)](https://flutter.dev)
[![GitHub](https://img.shields.io/badge/GitHub-ayan15888%2Fdither__animals-181717?logo=github)](https://github.com/ayan15888/dither_animals)

> 🌐 **Live Interactive Web Showcase & Studio Playground:**  
> Play with all 50 animated dither pets, customize Bayer matrix dot geometries, test poke ripple physics, tweak colors, and copy ready-to-use Flutter snippets directly in your browser:  
> 👉 **[https://ditheranimals.vercel.app/](https://ditheranimals.vercel.app/)**

Cute animated dithered (stipple, halftone, and ordered-dither) animal widgets for Flutter with **50 handcrafted chibi animals**, retro Bayer matrix rendering, signature moves, facial expressions, and ripple poke physics.

<p align="center">
  <a href="https://github.com/ayan15888/dither_animals/raw/main/doc/animal_details.mp4">
    <img src="https://raw.githubusercontent.com/ayan15888/dither_animals/main/doc/preview.gif" alt="dither_animals animated demo" width="680" style="max-width: 100%; border-radius: 12px;"/>
  </a>
</p>

<p align="center">
  <sub>🎬 <i>Click the preview above or <a href="https://github.com/ayan15888/dither_animals/raw/main/doc/animal_details.mp4"><b>watch full HD video (animal_details.mp4)</b></a></i></sub>
</p>

Rendered entirely on the Flutter `Canvas` using an **ordered 8×8 Bayer dithering matrix**, each animal features its own handcrafted animation curves, unique entrance/reveal transitions, facial expressions, idle breathing/swaying, and interactive poke physics with haptic feedback.

---

## ✨ Features

- 🌐 **Live Web Showcase & Studio**: Test all 50 pets, ordered Bayer dithering, and export Flutter code live at [ditheranimals.vercel.app](https://ditheranimals.vercel.app/).
- 🐾 **50 Handcrafted Chibi Animals**: From owls, cats, and frogs to whales, pandas, and flamingos.
- 🐶 **`DitherPet` Wrapper**: Ultra-clean, high-level API with one-line convenience constructors (`DitherPet.cat()`, `DitherPet.dog()`, etc.).
- 🎨 **Ordered Bayer 8×8 Matrix Dithering**: Authentic retro stipple rendering with smooth multi-layer density shading.
- 🕹️ **Interactive Poke Shockwaves**: Tap any animal to send an interactive radial wave ripple through the stipple grid, accompanied by haptic click feedback.
- 🔲 **4 Dot Shapes**: Choose between `DitherDot.square`, `DitherDot.round`, `DitherDot.hex`, and `DitherDot.diamond`.
- 🌈 **Advanced Theming**: Solid colors, two-tone speckled blends, continuous gradients, and individual body part coloring via `DitherTheme`.
- 😊 **Facial Expressions & Auto Mood**: Dynamic emotions (`neutral`, `happy`, `angry`, `sleepy`) that can shift on their own.
- ⚡ **Signature Moves**: Special characteristic actions for each animal (lion roar, elephant water spray, frog tongue flick).
- 🎛️ **Built-in `AnimalStudioPage`**: A live, interactive playground to test dot shapes, density, colors, haptics, and motions in real time.
- 🖼️ **Custom Image Dithering**: Pass any Flutter `ImageProvider` to dither and animate custom logos, avatars, or artwork.

---

## 📦 Installation

Add `dither_animals` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  dither_animals: ^2.1.0
```

Or run:

```bash
flutter pub add dither_animals
```

Then import the package in your Dart code:

```dart
import 'package:dither_animals/dither_animals.dart';
```

---

## 🚀 Quick Start

### 1. Simple Drop-in with `DitherPet`

The easiest way to display an animated animal companion:

```dart
import 'package:dither_animals/dither_animals.dart';
import 'package:flutter/material.dart';

// One-liner pet with built-in personality
Widget myCat = const DitherPet.cat(
  mood: PetMood.happy,
  theme: PetTheme.gradient,
  dot: PetDot.round,
);

// Or using any animal by type
Widget myOwl = const DitherPet(
  animal: DitherAnimalType.owl,
  mood: PetMood.neutral,
);
```

### 2. Full Control with `DitherAnimal`

For fine-grained matrix control, custom grid cell density, dot scaling, and motion modes:

```dart
import 'package:dither_animals/dither_animals.dart';
import 'package:flutter/material.dart';

class OwlExample extends StatelessWidget {
  const OwlExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: DitherAnimal(
          animal: DitherAnimalType.owl,
          color: Color(0xFFFF5A1F),
          cells: 96,
          dot: DitherDot.square,
          motion: DitherMotion.loop,
          signature: true,
          pokeable: true,
        ),
      ),
    );
  }
}
```

### 3. Open the Interactive Studio Playground

Inspect and tune dot density, haptics, colors, and signatures on the fly:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const AnimalStudioPage(
      animal: DitherAnimalType.frog,
      color: Color(0xFF65A30D),
    ),
  ),
);
```

---

## 🦁 All 50 Built-in Chibi Characters

Every character features unique vector path layers, custom entrance transitions, and signature animations:

| # | Character | Enum | Signature Move & Personality |
|---|---|---|---|
| 01 | 🦉 Owl | `DitherAnimalType.owl` | Head swivel & big curious blinks |
| 02 | 🐘 Elephant | `DitherAnimalType.elephant` | Water spray from trunk & flapping ears |
| 03 | 🐰 Rabbit | `DitherAnimalType.rabbit` | Gentle binky hop & ear twitches |
| 04 | 🐟 Fish | `DitherAnimalType.fish` | Speed dart & bubble blowing |
| 05 | 🐢 Turtle | `DitherAnimalType.turtle` | Shell hide & calm paddle |
| 06 | 🐱 Cat | `DitherAnimalType.cat` | Playful pounce, purr & tail swish |
| 07 | 🐧 Penguin | `DitherAnimalType.penguin` | Waddles & cute side-to-side shuffle |
| 08 | 🐸 Frog | `DitherAnimalType.frog` | Big springy hops & tongue snap |
| 09 | 🐙 Octopus | `DitherAnimalType.octopus` | Jet burst & undulating tentacles |
| 10 | 🐻 Bear | `DitherAnimalType.bear` | Happy rhythmic celebratory dance |
| 11 | 🦁 Lion | `DitherAnimalType.lion` | Regal mane puff & fierce roar |
| 12 | 🐯 Tiger | `DitherAnimalType.tiger` | Stealth prowl & horizontal stalk |
| 13 | 🐶 Dog | `DitherAnimalType.dog` | Excited tail wag & joyful head tilts |
| 14 | 🐼 Panda | `DitherAnimalType.panda` | Leisurely bamboo munching & roll |
| 15 | 🐭 Mouse | `DitherAnimalType.mouse` | Speedy scurry & cheese nibble |
| 16 | 🦊 Fox | `DitherAnimalType.fox` | Sly sweep & bushy tail flick |
| 17 | 🐵 Monkey | `DitherAnimalType.monkey` | Playful branch swinging |
| 18 | 🦆 Duck | `DitherAnimalType.duck` | Water wobble, quacks & head bob |
| 19 | 🐑 Sheep | `DitherAnimalType.sheep` | Fluffy joyful spring boings |
| 20 | 🦔 Hedgehog | `DitherAnimalType.hedgehog` | Defensive bristle & scurry |
| 21 | 🐨 Koala | `DitherAnimalType.koala` | Sleepy eucalyptus hug & slow blinks |
| 22 | 🦝 Raccoon | `DitherAnimalType.raccoon` | Sneaky paws & trash bandit peek |
| 23 | 🐋 Whale | `DitherAnimalType.whale` | Majestic spout geyser & deep ocean glide |
| 24 | 🐝 Bee | `DitherAnimalType.bee` | Figure-8 buzz dance & flower hover |
| 25 | 🐮 Cow | `DitherAnimalType.cow` | Calm chewing & rhythmic head nods |
| 26 | 🦒 Giraffe | `DitherAnimalType.giraffe` | Graceful long-neck sway & canopy stretch |
| 27 | 🦓 Zebra | `DitherAnimalType.zebra` | Savanna gallop & striped dash |
| 28 | 🦀 Crab | `DitherAnimalType.crab` | Sideways beach scuttle & pincer snip |
| 29 | 🦩 Flamingo | `DitherAnimalType.flamingo` | One-leg balance & neck ribbon curl |
| 30 | 🦋 Butterfly | `DitherAnimalType.butterfly` | Gentle fluttering & spiral drift |
| 31 | 🐌 Snail | `DitherAnimalType.snail` | Slow glide & eye-stalk retract |
| 32 | 🐿️ Squirrel | `DitherAnimalType.squirrel` | Acorn stash & flicking tail whip |
| 33 | 🦛 Hippo | `DitherAnimalType.hippo` | Huge river yawn & water snort |
| 34 | 🦌 Deer | `DitherAnimalType.deer` | Elegant forest bounds & antler tilt |
| 35 | 🦜 Parrot | `DitherAnimalType.parrot` | Wing flutter & head bobbing whistle |
| 36 | 🦘 Kangaroo | `DitherAnimalType.kangaroo` | Powerful boing leaps & tail bounce |
| 37 | 🦈 Shark | `DitherAnimalType.shark` | Fin surface slice & sleek ocean glide |
| 38 | 🐔 Chicken | `DitherAnimalType.chicken` | Rhythmic scratch & grain pecks |
| 39 | 🐞 Ladybug | `DitherAnimalType.ladybug` | Leaf crawl & elytra wing spread |
| 40 | 🐺 Wolf | `DitherAnimalType.wolf` | Pack stance & full moon howl |
| 41 | 🐴 Horse | `DitherAnimalType.horse` | Mane toss & spirited hoof stamp |
| 42 | 🐪 Camel | `DitherAnimalType.camel` | Desert stride & unbothered chew |
| 43 | 🦏 Rhino | `DitherAnimalType.rhino` | Heavy ground scrape & armored charge |
| 44 | 🐐 Goat | `DitherAnimalType.goat` | Mountain kick-hops & playful headbutt |
| 45 | 🦭 Seal | `DitherAnimalType.seal` | Joyful flipper claps & belly bounce |
| 46 | 🦇 Bat | `DitherAnimalType.bat` | Wing wrap drape & sonar hover |
| 47 | 🐊 Crocodile | `DitherAnimalType.crocodile` | River float & sudden jaw snap |
| 48 | 🪼 Jellyfish | `DitherAnimalType.jellyfish` | Bioluminescent pulse & tentacle drift |
| 49 | 🦚 Peacock | `DitherAnimalType.peacock` | Majestic iridescent fan tail shimmer |
| 50 | 🐾 Red Panda | `DitherAnimalType.redpanda` | Fluffy tail ripple & two-paw stand |

---

## 🎨 Themes, Dot Shapes & Expressions

### Dot Shapes (`DitherDot`)
- `DitherDot.square`: Authentic retro pixel aesthetics (fastest).
- `DitherDot.round`: Organic halftone stipple dots.
- `DitherDot.hex`: Stylized honeycomb hexagonal pattern.
- `DitherDot.diamond`: Elegant rotated diamond matrix.

### Dynamic Color Themes (`DitherTheme`)
```dart
DitherAnimal(
  animal: DitherAnimalType.panda,
  theme: DitherTheme(
    mode: DitherColorMode.gradient,
    primary: const Color(0xFF1F3BFF),
    secondary: const Color(0xFFFFB020),
    gradientAngle: 45,
  ),
)
```

### Facial Moods & Auto Mood (`DitherExpression`)
Pass an explicit expression or let the animal shift naturally with `autoMood: true`:
- `DitherExpression.neutral`
- `DitherExpression.happy`
- `DitherExpression.angry`
- `DitherExpression.sleepy`

---

## 🎛️ Detailed API Reference

### `DitherAnimal`

| Property | Type | Default | Description |
|---|---|---|---|
| `animal` | `DitherAnimalType` | `DitherAnimalType.owl` | The animal preset to render. |
| `color` | `Color` | `Color(0xFF1F3BFF)` | Primary ink / dot color. |
| `cells` | `int` | `96` | Matrix grid resolution across width (40 to 128). |
| `dot` | `DitherDot` | `DitherDot.square` | `square`, `round`, `hex`, or `diamond`. |
| `dotScale` | `double` | `0.9` | Dot size scaling factor. |
| `dotDensity` | `double` | `1.0` | Ink density multiplier (0.4 to 1.6). |
| `motion` | `DitherMotion` | `DitherMotion.loop` | `loop` (infinite cycle) or `once` (assemble and stay). |
| `signature` | `bool` | `true` | Enables the animal's signature personality action. |
| `pokeable` | `bool` | `true` | Tap to trigger radial wave ripple & haptic feedback. |
| `theme` | `DitherTheme?` | `null` | Solid, twoTone, gradient, or per-part coloring. |
| `expression` | `DitherExpression` | `neutral` | Facial mood overlay. |
| `autoMood` | `bool` | `false` | Mood automatically shifts over time and reacts to moves. |
| `hooks` | `DitherHooks?` | `null` | Callbacks (`onFormed`, `onPoke`, `onSignatureStart`). |
| `image` | `ImageProvider?` | `null` | Custom image to dither instead of built-in animals. |

---

## 🖼️ Custom Image Dithering

You can dither any custom bitmap or avatar using the Bayer matrix:

```dart
DitherAnimal(
  image: const AssetImage('assets/logo.png'),
  color: Colors.deepPurple,
  cells: 112,
  dot: DitherDot.round,
  motion: DitherMotion.loop,
)
```

---

## 📱 Interactive Example App

The repository includes a complete gallery showcasing all 50 animals, interactive search filtering, dot style toggle, live tuning sliders, and full studio mode:

```bash
cd example
flutter pub get
flutter run
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
