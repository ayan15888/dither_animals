/// Animated dithered (stipple and halftone) animal widgets for Flutter.
///
/// Features 30 cute chibi animal presets, ordered dithering (Bayer 8x8 matrix),
/// ripple poke physics with haptic feedback, and custom image dithering.
library dither_animals;

export 'src/animal_motion.dart'
    show AnimalMotion, BodyPose, RevealStyle, backOut;
export 'src/animal_shapes.dart'
    show
        AnimalArt,
        DetailSpec,
        DitherAnimalType,
        EyeSpec,
        ShapeLayer,
        kAnimalArt;
export 'src/dither_animal.dart'
    show DitherAnimal, DitherDot, DitherMotion;
