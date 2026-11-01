# Changelog

All notable changes to this project will be documented in this file.
See [Standard Version](https://semver.org/) for commit guidelines.

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
