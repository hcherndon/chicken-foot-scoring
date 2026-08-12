@Tags(['screenshots'])
library;

import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/models/game.dart';
import 'package:chicken_foot/models/game_rules.dart';
import 'package:chicken_foot/models/player.dart';
import 'package:chicken_foot/models/round.dart';
import 'package:chicken_foot/models/round_entry.dart';
import 'package:chicken_foot/providers/active_game_provider.dart';
import 'package:chicken_foot/providers/database_provider.dart';
import 'package:chicken_foot/screens/game_summary_screen.dart';
import 'package:chicken_foot/screens/round_entry_screen.dart';
import 'package:chicken_foot/screens/scoreboard_screen.dart';
import 'package:chicken_foot/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders key screens to PNGs under `test/goldens/` for eyeballing layout.
///
/// Not part of the normal suite — it is tagged `screenshots` and excluded in
/// `dart_test.yaml`. Run it with:
///   flutter test test/screenshots_test.dart --run-skipped --update-goldens
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  final players = [
    const Player(id: 'a', name: 'Ann', seatOrder: 0),
    const Player(id: 'b', name: 'Bo', seatOrder: 1),
    const Player(id: 'c', name: 'Cy', seatOrder: 2),
    const Player(id: 'd', name: 'Dee', seatOrder: 3),
  ];

  /// [openings] gives the double each round opened on; when omitted the game
  /// walks the ladder without burning anything.
  Game gameWithRounds(
    int count, {
    GameRules rules = const GameRules(),
    List<int>? openings,
  }) {
    var game = Game(
      id: 'g',
      createdAt: DateTime(2026, 8, 11),
      rules: rules,
      players: players,
      rounds: const [],
    );
    const pips = [
      [0, 14, 7, 22],
      [11, 0, 19, 5],
      [3, 8, 0, 31],
      [17, 4, 12, 0],
      [0, 26, 9, 6],
      [8, 0, 14, 3],
      [5, 12, 0, 18],
      [0, 7, 21, 4],
      [13, 0, 6, 9],
      [2, 15, 0, 11],
    ];
    for (var i = 0; i < count; i++) {
      final row = pips[i % pips.length];
      game = game.withRound(
        Round(
          index: i,
          startingDouble:
              openings == null ? rules.set.startingDoubleFor(i) : openings[i],
          completedAt: DateTime(2026, 8, 11, 13 + i),
          entries: [
            for (final (seat, player) in players.indexed)
              RoundEntry(
                playerId: player.id,
                pips: row[seat],
                wentOut: row[seat] == 0,
              ),
          ],
        ),
        now: DateTime(2026, 8, 11, 23),
      );
    }
    return game;
  }

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    Size size = const Size(420, 860),
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: screen,
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 40));
  }

  testWidgets('scoreboard mid-game', (tester) async {
    await container.read(activeGameProvider.future);
    // Nobody held the 9 or the 6, so both were burned.
    await db.gameDao.save(
      gameWithRounds(
        4,
        openings: const [8, 7, 5, 4],
      ),
    );
    await container.read(activeGameProvider.notifier).resume('g');
    await shoot(tester, 'scoreboard', const ScoreboardScreen());
  });

  testWidgets('scoreboard mid-game, dark', (tester) async {
    await container.read(activeGameProvider.future);
    await db.gameDao.save(gameWithRounds(4));
    await container.read(activeGameProvider.notifier).resume('g');
    await shoot(
      tester,
      'scoreboard_dark',
      const ScoreboardScreen(),
      brightness: Brightness.dark,
    );
  });

  testWidgets('scoreboard on a wide window', (tester) async {
    await container.read(activeGameProvider.future);
    await db.gameDao.save(gameWithRounds(6));
    await container.read(activeGameProvider.notifier).resume('g');
    await shoot(
      tester,
      'scoreboard_wide',
      const ScoreboardScreen(),
      size: const Size(1100, 700),
    );
  });

  testWidgets('round entry', (tester) async {
    await container.read(activeGameProvider.future);
    await db.gameDao.save(gameWithRounds(
      2,
      rules: const GameRules(endOnDoublePenaltyEnabled: true),
    ));
    await container.read(activeGameProvider.notifier).resume('g');
    await shoot(tester, 'round_entry', const RoundEntryScreen(roundIndex: 2));
  });

  testWidgets('results', (tester) async {
    final game = gameWithRounds(
      10,
      rules: const GameRules(set: DominoSet.double9),
    );
    await shoot(tester, 'results', GameSummaryScreen(game: game));
  });
}
