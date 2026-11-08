# dither_animals: building Flutter apps with animated stipple animals

You are helping a developer build a Flutter (Android-first) app that uses the `dither_animals` package: one widget, `DitherAnimal`, that draws 50 cute ordered-dither (stipple/halftone) animals which build in, idle, and dissolve in a loop. Follow this skill so the app is correct, fast, and feels designed rather than decorated.

## 0. Honest status (tell the developer)
- The package source was written without a Dart compiler. First action in any project: run `flutter pub get`, `flutter analyze`, and `flutter run`. Fix compile errors in the package before building on it, and say so plainly.
- `pubspec.yaml` has `publish_to: none`. Use a path or git dependency (see Setup), not pub.dev, until the developer changes it.
- Preview images made earlier were Python re-creations, not Flutter output. Judge visuals only from a real run.

## 1. Setup
```yaml
# app pubspec.yaml
dependencies:
  dither_animals:
    path: ../dither_animals      # or: git: {url: ..., ref: main}
```
```dart
import 'package:dither_animals/dither_animal.dart';
// Also exports: DitherAnimalType, DitherTheme, DitherColorMode, DitherPart,
// DitherExpression, ExprFace, kMoodCycle, signatureMood.
// NOT exported from that file (import directly if needed):
//   package:dither_animals/animal_studio.dart  -> AnimalStudioPage (tuning UI)
//   DitherHooks lives in theme.dart, which IS re-exported.
```
Minimum Flutter 3.10, Dart 3. Only dependency: `path_drawing`.

## 2. The API (single widget)
```dart
DitherAnimal(
  animal: DitherAnimalType.owl,     // 50 values, see section 3
  color: Color(0xFF1F3BFF),         // base dot color (theme.primary overrides)
  cells: 96,                        // dots across; lower = faster + chunkier
  dot: DitherDot.square,            // square | round | hex | diamond
  dotScale: 0.9,                    // dot size within its cell
  dotDensity: 1.0,                  // ink amount: <1 sparse/light, >1 dense/bold
  duration: null,                   // loop length; default = animal's own tempo
  motion: DitherMotion.loop,        // loop | once
  phase: 0,                         // 0..1 offset to desync multiple animals
  shimmer: 0.03,                    // edge flicker while formed
  showFace: true,                   // eyes, cheeks, detail overlays
  sparkles: true,                   // burst when formed
  pokeable: true,                   // tap = shockwave through dots
  signature: true,                  // unique occasional special move; false = idle only
  theme: DitherTheme.solid,         // solid | twoTone | gradient | parts, + dark mode
  hooks: null,                      // DitherHooks callbacks / DitherHooks.haptics()
  expression: DitherExpression.neutral, // neutral happy angry sleepy surprised sad wink
  autoMood: false,                  // animal cycles its own moods; overrides expression
  image: null, invertImage: false,  // dither any ImageProvider instead (generic motion)
)
```
- **Sizing:** the widget is square art in a 100x100 space. Give it a bounded parent: `SizedBox(width: 160, height: 160, child: DitherAnimal(...))`. Never put it in an unbounded Column/ListView child without a size.
- **Expression** changes morph smoothly (about 0.45 s). Drive it from app state; do not rebuild a new widget to change mood.
- **Theme:** `DitherTheme(mode: DitherColorMode.gradient, primary: ..., secondary: ..., gradientAngle: 90)`; `twoTone` uses `twoToneMix` (0..1); `parts` takes `Map<DitherPart, Color>` with `body, head, ears, sides, feet`; `brightness: Brightness.dark` or `followSystem: true` lifts colors for dark backgrounds.
- **Hooks:** `DitherHooks(onBuildStart, onFormed, onDissolve, onSignatureStart, onSignaturePeak, onSignatureEnd, onPoke)`, each `(DitherAnimalType) => void`. `DitherHooks.haptics(also: yourHooks)` adds ready-made haptics and chains yours.

## 3. The 50 animals
owl, rabbit, fish, turtle, elephant, cat, penguin, frog, octopus, bear, lion, tiger, dog, panda, mouse, fox, monkey, duck, sheep, hedgehog, koala, raccoon, whale, bee, cow, giraffe, zebra, crab, flamingo, butterfly, snail, squirrel, hippo, deer, parrot, kangaroo, shark, chicken, ladybug, wolf, horse, camel, rhino, goat, seal, bat, crocodile, jellyfish, peacock, redpanda.

Personality guide for picking: calm/focus = owl, panda, koala, turtle, seal; playful/kids = rabbit, duck, frog, penguin, monkey; strong/competitive = lion, tiger, rhino, wolf; water/health = fish, whale, dolphin-like shark, jellyfish; celebration = peacock, parrot, flamingo, butterfly; cute companion = cat, dog, mouse, hedgehog, redpanda, fox. Each has a unique signature move (lion roar, elephant water spray, cat pounce, duck quack rings...).

## 4. Hard rules and known limits (do not fight these)
1. **No controller.** There is no `play()`/`trigger()`. Signatures fire on the animal's own schedule (every few seconds) while `signature: true`. If an app needs "react now", change `expression`, toggle `key`, or use `onPoke`; do not promise an on-demand signature. If it is truly needed, extend the package (add a controller) as a separate, explicit task.
2. **Replay an entrance:** give the widget a changing `key` (`ValueKey(counter)`) to restart the build-in. With `motion: DitherMotion.once` it builds in and holds.
3. **Wink does nothing on side-view animals** (e.g. fish, some profile animals). Use `happy`/`surprised` for those.
4. **`autoMood: true` overrides `expression`.** Use one or the other.
5. **Per-part colors use fixed zones**, so on odd shapes (peacock, fish, snail, jellyfish) they look blocky. Prefer `gradient` or `twoTone` for those.
6. **Dark backgrounds:** set `theme.brightness: Brightness.dark` or `followSystem: true`, otherwise dots and eyes can vanish.
7. **Special-mouth animals** keep their drawn mouth under some expressions. Verify visually before promising an expression on a specific animal.
8. `image:` mode uses generic motion and no face; it is for logos/photos, not for animals.
9. Do not edit generated files (`lib/animal_shapes.dart`, `lib/expression_faces.dart`, `lib/signature_table.dart`). Change `tool/gen_shapes.py`, `tool/signature_spec.py` and rerun `python3 tool/gen_shapes.py` and `python3 tool/gen_signatures.py`.

## 5. Performance rules
- Each animal paints thousands of dots per frame. Defaults suit 1-3 animals on screen.
- Lists/grids: `cells: 48..64`, `sparkles: false`, `shimmer: 0`, `signature: false`, `pokeable: false` for thumbnails; wrap each in `RepaintBoundary`; stagger with `phase`.
- Only the focused animal gets full quality. Pause offscreen ones: the widget uses `TickerProviderStateMixin`, so `TickerMode(enabled: isVisible, child: ...)` stops its animation (use this for tabs, `IndexedStack`, covered routes).
- Prefer one hero animal per screen. Avoid animating more than ~6 at once.
- Test on a mid-range Android device, in profile mode (`flutter run --profile`), not only debug or an emulator.

## 6. Mood mapping (use consistently across the app)
| App state | expression |
|---|---|
| idle / default | neutral |
| success, streak, win | happy |
| error, failure, warning | sad (soft) or surprised (unexpected) |
| frustration, rival, combat | angry (use sparingly) |
| inactive, night, rest | sleepy |
| playful tease, secret | wink (front-view animals only) |
| surprise, new unlock | surprised |
Keep the mapping in one function (`DitherExpression moodFor(AppState s)`), not scattered in widgets.

## 7. Workflow for the agent
1. Ask (or infer) the app goal, target users, and the 1-3 moments where a character adds value. Do not put an animal on every screen.
2. Pick animal(s) by personality (section 3) and one brand palette; define it once in a `DitherTheme`.
3. Create a small wrapper `AppMascot` widget that fixes size, theme, dark mode, and takes only `mood` and `animal`. All screens use the wrapper.
4. Drive mood from state (Riverpod/Provider/Bloc, whatever the app already uses; do not add a new state library unprompted).
5. Add hooks only where they do something (haptics on poke, analytics on signature, sound on formed).
6. Run analyze, run on device, check light AND dark mode, check reduced motion (section 9), check small and large screens.
7. Add widget tests (section 10).

## 8. Recipes: 15 use cases
Each recipe: goal, animal pick, wiring, pitfalls.

### 1. Onboarding / welcome
A hero animal greets on each page, changing mood per step.
```dart
DitherAnimal(
  key: ValueKey(pageIndex),            // re-plays the build-in per page
  animal: pages[pageIndex].animal,
  expression: pages[pageIndex].mood,   // happy, surprised, wink...
  motion: DitherMotion.once,
  theme: brandTheme,
)
```
Pitfall: do not auto-advance faster than the build-in (about 1.5 s).

### 2. Loading indicator
Use a small animal looping while awaiting data; the dissolve/rebuild cycle reads as "working".
```dart
SizedBox(width: 96, height: 96,
  child: DitherAnimal(animal: DitherAnimalType.fish, cells: 56, signature: false, pokeable: false))
```
Pitfall: if the wait can be under 300 ms, show nothing; animals need about a second to read.

### 3. Empty states
"No items yet" with a sleepy or neutral animal and one clear action button. `expression: sleepy`, `signature: false` so it stays calm.

### 4. Error / offline states
`expression: sad` (or `surprised` for unexpected errors), a short human sentence, a Retry button. Never use `angry` for user errors. On retry success, switch to `happy` and let the animal's `onFormed` finish before navigating.

### 5. Habit tracker mascot
Mood reflects streak health: streak alive = happy, missed today = sleepy, broken = sad, milestone = surprised then happy.
```dart
DitherExpression moodFor(Habit h) => h.justHitMilestone ? DitherExpression.surprised
  : h.doneToday ? DitherExpression.happy
  : h.streakBroken ? DitherExpression.sad : DitherExpression.sleepy;
```
Pitfall: do not guilt-trip; sad should invite, not shame. Keep copy supportive.

### 6. Pomodoro / focus timer
Focus phase: owl or panda, `sleepy` off, `signature: false`, `pokeable: false` (no distractions). Break phase: switch animal to a playful one (rabbit, duck), `happy`, `signature: true`. Use `AnimatedSwitcher` with `ValueKey(phase)` between them. Hooks: `onFormed` plays a soft chime.

### 7. Virtual pet / companion
Persist `{animal, hunger, energy, lastSeen}` (shared_preferences or the app's DB). Compute mood from stats on app open; use `autoMood: false` and your own mapping. Feeding = `onPoke` handler that bumps stats and shows `happy` for 2 s, then returns to the computed mood via a timer that you cancel in `dispose`. Add `DitherHooks.haptics()`.
Pitfall: do not simulate time in the background; compute from timestamps on resume.

### 8. Chat / assistant avatar
Avatar next to messages, mood from message sentiment or typing state: typing = neutral, answer ready = happy, error = sad. Use `cells: 48`, `signature: false`, and `RepaintBoundary` so scrolling a long chat stays smooth. Only the latest avatar animates; older ones can be static by wrapping in `TickerMode(enabled: false, ...)`.

### 9. Quiz / education feedback
Correct = happy (plus confetti if the app has it), wrong = sad then neutral after 1.2 s, streak of 3+ = surprised then happy. Use hooks sparingly: `DitherHooks.haptics()` is enough. Pitfall: do not block input while the mood morphs (0.45 s is purely visual).

### 10. Kids' emotion learning
Show one animal, ask "how does it feel?", offer the 7 expressions as large buttons; compare the child's pick with the displayed `expression`. Use a bright theme, `dot: DitherDot.round` (friendlier), big touch targets (>=56 dp), and `signature: true` as reward. Note: wink is front-view only; use animals whose face is front-view (cat, owl, bear, panda).

### 11. Breathing / meditation
The animal sits (calm animal, `sleepy` or `neutral`, `signature: false`). Drive the breath yourself: an `AnimationController` (4 s in, 6 s out) scales a parent `Transform.scale(0.92..1.04)` and optionally lerps `dotDensity` through a rebuild. Do not expect the package to provide a breathing mode.

### 12. Fitness / water / step tracker
Progress ring around a mascot. Mood by percent of goal: <25% sleepy, 25-99% neutral, 100% happy plus signature visible, over-goal surprised. Pick an animal that matches the theme (fish/whale for water, kangaroo/horse for steps).

### 13. Collection / avatar picker with unlocks
Grid of all 50, locked ones shown as a gray `DitherTheme(mode: solid, primary: Colors.grey)` silhouette (set `showFace: false`). Thumbnails use the grid performance settings (section 5); the preview pane shows one full-quality animal with the studio controls (dot shape, density, theme). `AnimalStudioPage` (from `animal_studio.dart`) can serve as a ready preview/tuner screen.
Pitfall: store the selected `DitherAnimalType` by `.name`, never by `.index` (order may change).

### 14. Branded splash + theming + dark mode
Build one `DitherTheme` from brand colors (two-tone or gradient), with `followSystem: true`. Use a larger `cells` (110+) and `motion: DitherMotion.once` on the in-app splash route. Do not use it as the native splash; Android's native splash must be static (`flutter_native_splash`), then hand off to the animated one.
Check contrast of eyes in both light and dark.

### 15. Sharing images / home-screen widget
Capture the animal as an image: wrap in `RepaintBoundary(key: k)`, wait until `onFormed` fired (or a fixed delay), then `RenderRepaintBoundary.toImage(pixelRatio: 3)` -> PNG bytes -> `share_plus` / save with `gal`. For a Android home-screen widget use `home_widget` and render that PNG; home widgets cannot run Flutter animation, so they show a still. Pitfall: capturing mid-dissolve gives a half-formed animal; always capture after `onFormed` and before `onDissolve`.

## 9. Accessibility and quality bar
- Wrap decorative animals in `ExcludeSemantics`; give meaningful ones `Semantics(label: 'Owl mascot, happy')` that reflects the mood.
- Respect reduced motion: if `MediaQuery.of(context).disableAnimations` is true, use `motion: DitherMotion.once`, `signature: false`, `shimmer: 0`, `sparkles: false`, `pokeable: false`.
- Haptics must be optional: expose a settings toggle and only pass `DitherHooks.haptics()` when enabled.
- Never put essential information only in the animal's mood; always pair with text.
- Respect battery: no animal on screens users sit on for long, unless paused when not visible.

## 10. Testing and verification checklist
- `flutter analyze` clean; `flutter test` passes.
- Widget test: pump the wrapper with each mood, assert no exceptions: `await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(width:160,height:160, child: DitherAnimal(animal: a, expression: e)))))); await tester.pump(const Duration(seconds: 2));`
- Loop over all 50 `DitherAnimalType.values` x 7 `DitherExpression.values` in one smoke test (use `cells: 24` to keep it fast).
- Golden tests (`alchemist` or `golden_toolkit`) for the 3-5 animals the app actually uses, in light and dark.
- Manual: profile build on a mid-range device, scroll any list with animals, rotate, switch dark mode, toggle system reduced motion.
- Verify hook behavior with a fake `DitherHooks` that records calls.

## 11. Common mistakes to avoid
- Animal in an unbounded parent (layout exception or zero size).
- 50 animals animating in a grid with default quality (jank).
- Changing `animal` each frame (resets the loop); change it only on real transitions.
- Using `autoMood` and `expression` together and wondering why expression is ignored.
- Storing enum index in persistence.
- Editing generated Dart files by hand.
- Promising a feature the package lacks (on-demand signature, speech lip-sync, custom animals through the widget). If the app needs it, propose extending the package explicitly (`tool/gen_shapes.py` for art, `tool/signature_spec.py` for signatures, a new controller for triggers).

## 12. Extending the package (only when asked)
- New animal: add art to `tool/gen_shapes.py` (`A[...]`, `DET[...]`), motion to `lib/animal_motion.dart`, signature to `tool/signature_spec.py`, regenerate, add the enum value, update expression faces via the generator.
- New fill color: extend `_kFillPalette` in `lib/dither_animal.dart` and the detail-kind switch (kind 14 is orange).
- Always keep existing animals and flags unchanged when adding features, and keep `signature` independently toggleable.