import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/models/game.dart';
import 'package:chicken_foot/models/game_rules.dart';
import 'package:chicken_foot/models/player.dart';
import 'package:chicken_foot/models/round.dart';
import 'package:chicken_foot/models/round_entry.dart';
import 'package:chicken_foot/theme/app_theme.dart';
import 'package:chicken_foot/widgets/domino_tile.dart';
import 'package:chicken_foot/widgets/score_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const players = [
    Player(id: 'a', name: 'Ann', seatOrder: 0),
    Player(id: 'b', name: 'Bo', seatOrder: 1),
  ];

  /// A game whose rounds came out in [openings] order, with the first player
  /// scoring the double they opened on so each column is identifiable.
  Game gameWith(List<int> openings) {
    var game = Game(
      id: 'g',
      createdAt: DateTime(2026),
      rules: const GameRules(set: DominoSet.double6),
      players: players,
      rounds: const [],
    );
    for (final (index, opening) in openings.indexed) {
      game = game.withRound(
        Round(
          index: index,
          startingDouble: opening,
          completedAt: DateTime(2026, 1, index + 1),
          entries: [
            RoundEntry(playerId: 'a', pips: opening),
            const RoundEntry(playerId: 'b', wentOut: true),
          ],
        ),
      );
    }
    return game;
  }

  Future<List<int>> pumpColumns(WidgetTester tester, Game game) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ScoreGrid(game: game)),
      ),
    );
    await tester.pumpAndSettle();

    return [
      for (final tile in tester.widgetList<DominoTile>(
        find.byType(DominoTile),
      ))
        tile.value,
    ];
  }

  testWidgets('columns run from the highest double down, not in play order',
      (tester) async {
    // The 6 was skipped in round one and picked up in round two.
    final columns = await pumpColumns(tester, gameWith([5, 6, 3]));
    expect(columns, [6, 5, 3]);
  });

  testWidgets('a game played straight down the ladder is unchanged',
      (tester) async {
    final columns = await pumpColumns(tester, gameWith([6, 5, 4]));
    expect(columns, [6, 5, 4]);
  });

  testWidgets('scores stay attached to their own round', (tester) async {
    final game = gameWith([5, 6, 3]);
    await pumpColumns(tester, game);

    // Ann's pips equal the double each round opened on, so the row must read
    // 6, 5, 3 once the columns are sorted rather than 5, 6, 3.
    final cells = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    final firstSix = cells.indexOf('6');
    final firstFive = cells.indexOf('5');
    final firstThree = cells.indexOf('3');
    expect(firstSix, lessThan(firstFive));
    expect(firstFive, lessThan(firstThree));
  });

  testWidgets('tapping a column opens that round, whatever its position',
      (tester) async {
    final game = gameWith([5, 6, 3]);
    var tapped = -1;

    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ScoreGrid(game: game, onTapRound: (index) => tapped = index),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The leftmost column shows the 6, which was played second.
    await tester.tap(find.byType(DominoTile).first);
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
