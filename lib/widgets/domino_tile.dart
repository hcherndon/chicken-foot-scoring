import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small domino showing a double — the tile a round opens on.
///
/// The halves carry numerals rather than pips: it stays legible at 24px, and
/// it works for a double-15 set where pip arrangements would not.
class DominoTile extends StatelessWidget {
  const DominoTile({super.key, required this.value, this.height = 44});

  final int value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = height * 0.5;
    final fontSize = height * 0.24;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(height * 0.12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _half(scheme, fontSize),
          Container(
            height: 1,
            color: scheme.outlineVariant,
            margin: EdgeInsets.symmetric(horizontal: width * 0.15),
          ),
          _half(scheme, fontSize),
        ],
      ),
    );
  }

  Widget _half(ColorScheme scheme, double fontSize) {
    return Expanded(
      child: Center(
        child: Text(
          '$value',
          style: AppTheme.tabular.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            height: 1,
          ),
        ),
      ),
    );
  }
}
