@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:chicken_foot/theme/app_palette.dart';
import 'package:chicken_foot/theme/app_theme.dart';
import 'package:chicken_foot/widgets/domino_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Draws `web/og-image.png` — the picture a link to the app unfurls to in
/// Discord, Slack or iMessage.
///
/// It is checked in rather than generated during the build, because the crawler
/// that fetches it is reading a static file and never runs Flutter. Rebuild it
/// after changing the card, the palette or the domino:
///   flutter test test/og_image_test.dart --run-skipped --update-goldens
///
/// Tagged `screenshots`, so it stays out of the default run and out of the
/// image build.
void main() {
  const palette = AppPalette.feltGreen;

  // Facebook's recommendation, and what every unfurler since has settled on:
  // 1200x630 is 1.91:1, the aspect the large-image card is cropped to.
  const size = Size(1200, 630);

  setUpAll(() async {
    // `flutter test` ships no real fonts — text lays out as Ahem boxes, which
    // is why the goldens under test/goldens/ are full of black bars. Harmless
    // when the point is layout; fatal when the point is a title. Roboto comes
    // with the SDK, and is the face Flutter's web engine falls back to anyway,
    // so the card is typeset in what the app itself renders in.
    final root = Platform.environment['FLUTTER_ROOT'];
    expect(
      root,
      isNotNull,
      reason: 'FLUTTER_ROOT is unset — run this through `flutter test`, '
          'not `dart test`.',
    );

    final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
    final loader = FontLoader('Roboto');
    for (final weight in const ['Regular', 'Medium', 'Bold', 'Black']) {
      final file = File('${fonts.path}/Roboto-$weight.ttf');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      loader.addFont(
        file.readAsBytes().then((bytes) => bytes.buffer.asByteData()),
      );
    }
    await loader.load();
  });

  testWidgets('og image', (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(palette),
        home: const _OgCard(palette: palette),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../web/og-image.png'),
    );
  });
}

/// The card itself: the app's name on felt, and the shape it is named after.
class _OgCard extends StatelessWidget {
  const _OgCard({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(palette.seed, Colors.white, 0.06)!,
            Color.lerp(palette.seed, Colors.black, 0.42)!,
          ],
        ),
      ),
      // Two things this wrapper is load-bearing for. Material supplies a real
      // default text style — without one the card inherits WidgetsApp's
      // fallback and every string picks up a yellow double underline. And
      // naming the family is what actually gets Roboto used: left to the
      // default, the test environment resolves unknown families to Ahem and
      // the card comes out as black bars.
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(84, 84, 64, 84),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _Wordmark(palette: palette)),
                const SizedBox(width: 40),
                const _ChickenFoot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chicken Foot',
          style: TextStyle(
            fontSize: 92,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            color: Colors.white,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Container(
          width: 108,
          height: 6,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'A score keeper for the domino game',
          style: TextStyle(
            fontSize: 32,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Double-6  ·  9  ·  12  ·  15',
          style: AppTheme.tabular.copyWith(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: palette.accent,
          ),
        ),
      ],
    );
  }
}

/// A double with three tiles branching off it — the shape the game is named
/// for, and the moment the app exists to record.
///
/// Every tile is a [DominoTile], the same widget the round entry screen draws,
/// so the card cannot drift away from the app's own look.
class _ChickenFoot extends StatelessWidget {
  const _ChickenFoot();

  /// Left to right: how far a toe sits off centre, how far it leans, its
  /// length, and the double it is.
  ///
  /// A fourth tile laid across the bottom — the double the toes branch off —
  /// was tried and cut: the toes stand exactly where its numerals are, so it
  /// only ever read as a blank slab behind the shape.
  static const _toes = [
    (-54.0, -0.78, 186.0, 6),
    (0.0, 0.0, 206.0, 3),
    (54.0, 0.78, 186.0, 0),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 430,
      height: 420,
      child: Stack(
        alignment: Alignment.bottomCenter,
        // Rotating about the bottom swings a tile's lower corners outside the
        // box; Stack would otherwise trim them square.
        clipBehavior: Clip.none,
        children: [
          for (final (dx, angle, length, value) in _toes)
            Positioned(
              bottom: 70,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment.bottomCenter,
                  child: _Tile(value: value, height: length),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// [DominoTile] with a drop shadow, so the tiles read as lying on the felt
/// rather than printed on it.
class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.height});

  final int value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height * 0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DominoTile(value: value, height: height),
    );
  }
}
