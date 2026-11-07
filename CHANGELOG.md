# Changelog

All notable changes to this project will be documented in this file.
See [Standard Version](https://semver.org/) for commit guidelines.

## 2.0.2

- Formatted all source files with `dart format`.
- Resolved all lints and static analysis warnings for full 140/140 pub.dev score.

## 2.0.1

- Cleaned up redundant imports, unused local variables, and deprecated API warnings across all codebase files.
- Refined `screenshots` specification in `pubspec.yaml` to ensure pub.dev search and sidebar thumbnail generation.
- Zero analysis issues on `dart analyze`.

## 2.0.0

- Added `screenshots` metadata in `pubspec.yaml` to display preview thumbnails in pub.dev search results and the package right-hand sidebar.
- Added high-resolution gallery grid (`doc/preview.png`) and close-up detail (`doc/animals_detail.png`) screenshots.
- Enhanced `doc/preview.gif` animation loop starting with animals fully rendered.
- Expanded to 50 handcrafted chibi animal presets with signature moves and expressions.
- Added `AnimalStudioPage`, `DitherTheme`, and interactive signature engine.
- Added `DitherPet` — a simple, beginner-friendly wrapper widget with plain-English parameters (`PetMood`, `PetDot`, `PetTheme`), `DitherPetState` for runtime control (`setColor`, `setSecondColor`, `setCells`, `replay`), and haptics enabled by default.
- Added facial expressions system: `DitherExpression` with 7 moods (neutral, happy, angry, sleepy, surprised, sad, wink), smooth morphing between expressions, and `autoMood` for self-changing moods.
- Added `DitherTheme` with solid, two-tone, gradient, and per-part color modes plus dark mode support.
- Added `DitherHooks` for event callbacks: `onBuildStart`, `onFormed`, `onDissolve`, `onSignatureStart`, `onSignaturePeak`, `onSignatureEnd`, `onPoke`.

## 1.0.2

- Fixed pub.dev README image rendering using absolute public raw media URLs.

## 1.0.1

- Added animated video preview demo and asset showcases in documentation.
- Visual previews for pub.dev package and GitHub repository.

## 1.0.0

- Initial release of `dither_animals`!
- 30 handcrafted chibi animal and element presets:
  - `owl`, `elephant`, `rabbit`, `fish`, `turtle`, `cat`, `penguin`, `frog`, `octopus`, `bear`
  - `lion`, `tiger`, `dog`, `panda`, `pig`, `fox`, `monkey`, `duck`, `sheep`, `hedgehog`
  - `sun`, `cloud`, `moon`, `star`, `ghost`, `mushroom`, `cactus`, `robot`, `rocket`, `cupcake`
- Ordered Bayer 8x8 matrix dithering engine rendered directly to Flutter canvas.
- Distinct personality animations for every animal (sway, bounce, hop, paddle, jet, waddle, etc.).
- Interactive poke ripple physics: tap to trigger an expanding shockwave ripple with haptic feedback.
- Support for custom image dithering using `ImageProvider`.
- Configurable dot styles (`DitherDot.square` and `DitherDot.round`).
- Configurable motion modes (`DitherMotion.loop` and `DitherMotion.once`).
- Fine-grained controls for grid cell density, shimmer, face overlay, and sparkles.
