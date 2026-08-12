import 'package:chicken_foot/app.dart';
import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays a whole game through the real widget tree, from the home screen to
/// the results, and checks it survives a restart along the way.
void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  /// Bounded settling. `pumpAndSettle` cannot be used here: the loading
  /// spinners the app shows while SQLite and preferences load never stop
  /// animating, so it would wait forever.
  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ChickenFootApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await settle(tester, frames: 4);
    await tester.tap(finder.first);
    await settle(tester);
  }

  /// Fills in every pip field on the round entry screen and saves.
  Future<void> scoreRound(WidgetTester tester, List<int> pips) async {
    for (final (index, value) in pips.indexed) {
      final field = find.byType(TextField).at(index);
      await tester.ensureVisible(field);
      await settle(tester, frames: 4);
      await tester.enterText(field, '$value');
      await settle(tester, frames: 4);
    }
    await tap(tester, find.text('Save round'));
  }

  testWidgets('play a full double-6 game from home screen to results',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await launch(tester);
    expect(find.text('Keep score, not paper.'), findsOneWidget);

    // Set up: three players on a double-6 set, which is 7 rounds.
    await tap(tester, find.text('New game'));

    await tester.enterText(find.byType(TextField).at(0), 'Ann');
    await tester.enterText(find.byType(TextField).at(1), 'Bo');
    await tap(tester, find.text('Add player'));
    await tester.enterText(find.byType(TextField).at(2), 'Cy');
    await settle(tester);

    await tap(
      tester,
      find.descendant(
        of: find.byType(SegmentedButton<DominoSet>),
        matching: find.text('6'),
      ),
    );
    expect(find.textContaining('Double-6'), findsWidgets);

    await tap(tester, find.textContaining('Start · 7 rounds'));

    // Round 1 of 7, opening on the double-6.
    expect(find.text('Standings'), findsOneWidget);
    expect(find.textContaining('Score round 1 of 7'), findsOneWidget);

    await tap(tester, find.textContaining('Score round 1 of 7'));
    expect(find.text('Round 1'), findsOneWidget);
    await scoreRound(tester, [10, 4, 0]);

    // Back on the scoreboard, ready for round 2.
    expect(find.textContaining('Score round 2 of 7'), findsOneWidget);

    // Restart the app mid-game: the round just scored must still be there.
    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 4);
    await launch(tester);
    expect(find.text('Continue game'), findsOneWidget);
    expect(find.textContaining('Round 2 of 7 · on the 5'), findsOneWidget);
    await tap(tester, find.text('Continue game'));

    // Play the remaining six rounds. Ann scores nothing after her bad start,
    // so she comes back to win on the lowest total: 10 against Bo's 40 and
    // Cy's 36.
    for (var round = 2; round <= 7; round++) {
      await tap(tester, find.textContaining('Score round $round of 7'));
      await scoreRound(tester, [0, 6, 6]);
    }

    // The final round pushes straight through to the results.
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Ann wins'), findsOneWidget);
    expect(find.text('with 10 points'), findsOneWidget);

    // Finish up, then confirm the game landed in history.
    await tap(tester, find.text('Done'));
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Continue game'), findsNothing);

    await tap(tester, find.byTooltip('History'));
    expect(find.text('Ann'), findsOneWidget);
    expect(find.textContaining('3 players · Double-6'), findsOneWidget);

    // Tear the tree down inside the test so drift's stream watchers get a
    // chance to fire their timers before the binding checks for stragglers.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('a skipped double comes back and the game still runs its course',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await launch(tester);
    await tap(tester, find.text('New game'));
    await tester.enterText(find.byType(TextField).at(0), 'Ann');
    await tester.enterText(find.byType(TextField).at(1), 'Bo');
    await settle(tester);
    await tap(
      tester,
      find.descendant(
        of: find.byType(SegmentedButton<DominoSet>),
        matching: find.text('6'),
      ),
    );
    await tap(tester, find.textContaining('Start · 7 rounds'));

    // Round 1: nobody holds the 6, so the round opens on the 5 instead.
    await tap(tester, find.textContaining('Score round 1 of 7'));
    await tap(tester, find.textContaining('Nobody had the 6'));
    expect(find.text('Opened on the double-5'), findsOneWidget);
    expect(find.textContaining('Skipped 6'), findsOneWidget);
    await scoreRound(tester, [0, 9]);

    // The 6 was not spent — it is back at the top of the pool.
    expect(find.textContaining('Still to play: 6, 4, 3, 2, 1, 0'),
        findsOneWidget);
    expect(find.textContaining('Score round 2 of 7'), findsOneWidget);

    // Round 2 goes looking for the 6 again, and this time somebody has it.
    await tap(tester, find.textContaining('Score round 2 of 7'));
    expect(find.text('Opened on the double-6'), findsOneWidget);
    await scoreRound(tester, [4, 0]);

    // With the 6 and 5 both spent, round 3 moves on to the 4.
    expect(find.textContaining('Still to play: 4, 3, 2, 1, 0'), findsOneWidget);
    await tap(tester, find.textContaining('Score round 3 of 7'));
    expect(find.text('Opened on the double-4'), findsOneWidget);
    await scoreRound(tester, [0, 5]);

    // Play it out. Every double gets its round, so the game is still 7 long.
    for (var round = 4; round <= 7; round++) {
      await tap(tester, find.textContaining('Score round $round of 7'));
      await scoreRound(tester, [0, 2]);
    }

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Ann wins'), findsOneWidget);
    expect(find.textContaining('7 rounds'), findsOneWidget);
    // Nothing left over once every double has had its turn.
    expect(find.textContaining('Still to play'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
