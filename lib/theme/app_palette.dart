import 'package:flutter/material.dart';

/// The colour a game is played in.
///
/// [seed] drives the whole Material 3 scheme; [accent] is a companion hue used
/// where a second colour reads better than a tint of the first — the hover
/// highlight in the theme picker, for one.
enum AppPalette {
  feltGreen('Felt green', Color(0xFF2E7D5B), Color(0xFFC9A227)),
  pine('Pine', Color(0xFF2E7D32), Color(0xFF8BC34A)),
  teal('Teal', Color(0xFF00796B), Color(0xFF26C6DA)),
  lagoon('Lagoon', Color(0xFF0097A7), Color(0xFF80DEEA)),
  ocean('Ocean', Color(0xFF1565C0), Color(0xFF64B5F6)),
  indigo('Indigo', Color(0xFF3949AB), Color(0xFF9FA8DA)),
  violet('Violet', Color(0xFF6A4FBF), Color(0xFFB39DDB)),
  plum('Plum', Color(0xFF8E24AA), Color(0xFFCE93D8)),
  rose('Rose', Color(0xFFC2185B), Color(0xFFF48FB1)),
  crimson('Crimson', Color(0xFFC62828), Color(0xFFEF9A9A)),
  ember('Ember', Color(0xFFE64A19), Color(0xFFFFAB91)),
  amber('Amber', Color(0xFFF9A825), Color(0xFFFFE082)),
  olive('Olive', Color(0xFF827717), Color(0xFFDCE775)),
  espresso('Espresso', Color(0xFF5D4037), Color(0xFFBCAAA4)),
  slate('Slate', Color(0xFF455A64), Color(0xFF90A4AE));

  const AppPalette(this.label, this.seed, this.accent);

  final String label;
  final Color seed;
  final Color accent;

  static const fallback = AppPalette.feltGreen;

  static AppPalette byName(String? name) => values.firstWhere(
        (palette) => palette.name == name,
        orElse: () => fallback,
      );
}

/// The colour chip shown beside a palette's name.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({super.key, required this.palette, this.size = 22});

  final AppPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.seed,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
