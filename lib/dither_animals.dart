/// Animated dithered (stipple and halftone) animal widgets for Flutter.
///
/// Features 50 cute chibi animal presets, ordered dithering (Bayer 8x8 matrix),
/// ripple poke physics with haptic feedback, custom image dithering,
/// facial expressions, signature moves, theming and an interactive studio.
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
export 'src/dither_animal.dart' show DitherAnimal, DitherDot, DitherMotion;
export 'src/theme.dart'
    show DitherTheme, DitherColorMode, DitherPart, DitherHooks;
export 'src/expression.dart'
    show
        DitherExpression,
        ExprParams,
        ExprFace,
        kExprParams,
        kMoodCycle,
        kDefaultMoodCycle;
export 'src/expression_faces.dart' show kExprFaces;
export 'src/animal_studio.dart' show AnimalStudioPage;
export 'src/dither_pet.dart' show DitherPet, PetDot, PetTheme, PetMood;
export 'src/dither_pet.dart'
    show DitherPet, DitherPetState, PetDot, PetMood, PetTheme;
