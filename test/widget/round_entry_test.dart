import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/models/game_rules.dart';
import 'package:chicken_foot/providers/active_game_provider.dart';
import 'package:chicken_foot/providers/database_provider.dart';
import 'package:chicken_foot/screens/round_entry_screen.dart';
import 'package:chicken_foot/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  /// Starts a three-player game and pumps the entry screen for round 0.
  Future<void> pumpEntry(
    WidgetTester tester, {
    GameRules rules = const GameRules(set: DominoSet.double6),
  }) async {
    // Let the initial load settle first, the same way the home screen does
    // before it offers a "New game" button.
    await container.read(activeGameProvider.future);
    await container.read(activeGameProvider.notifier).start(
          rules: rules,
          playerNames: const ['Ann', 'Bo', 'Cy'],
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RoundEntryScreen(roundIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('typed pips are scored and saved to the game', (tester) async {
    await pumpEntry(tester);

    await tester.enterText(find.byType(TextField).at(0), '12');
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.enterText(find.byType(TextField).at(2), '0');
    await tester.pump();

    expect(find.text('Round total: 15'), findsOneWidget);

    await tester.tap(find.text('Save round'));
    await tester.pumpAndSettle();

    final game = container.read(activeGameProvider).requireValue!;
    expect(game.completedRounds, hasLength(1));
    expect(game.totalFor(game.players[0].id), 12);
    expect(game.totalFor(game.players[1].id), 3);
    expect(game.currentRoundIndex, 1);
  });

  testWidgets('going out zeroes that player and disables their field',
      (tester) async {
    await pumpEntry(tester);

    await tester.enterText(find.byType(TextField).at(0), '20');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Went out').first);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(field.enabled, isFalse);
    expect(field.controller!.text, isEmpty);
    expect(find.text('Round total: 0'), findsOneWidget);
  });

  testWidgets('only one player can be marked as going out', (tester) async {
    await pumpEntry(tester);

    Future<void> tapWentOut(int index) async {
      final chip = find.widgetWithText(FilterChip, 'Went out').at(index);
      // The last player sits below the fold on the default test surface.
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await tapWentOut(0);
    await tapWentOut(2);

    final chips = tester
        .widgetList<FilterChip>(find.widgetWithText(FilterChip, 'Went out'))
        .toList();
    expect([for (final c in chips) c.selected], [false, false, true]);
  });

  testWidgets('the keyboard next action walks down the roster',
      (tester) async {
    await pumpEntry(tester);

    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final second = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(second.focusNode!.hasFocus, isTrue);
  });

  testWidgets('penalty toggles only appear for enabled rules', (tester) async {
    await pumpEntry(
      tester,
      rules: const GameRules(
        set: DominoSet.double6,
        doubleBlankPenaltyEnabled: true,
        endOnDoublePenaltyEnabled: false,
      ),
    );

    expect(find.textContaining('Held 0–0'), findsNWidgets(3));
    expect(find.textContaining('Ended on a double'), findsNothing);
  });

  testWidgets('penalties are added on top of the pips left in hand',
      (tester) async {
    await pumpEntry(
      tester,
      rules: const GameRules(
        set: DominoSet.double6,
        doubleBlankPenaltyEnabled: true,
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.pump();
    await tester.tap(find.textContaining('Held 0–0').at(1));
    await tester.pump();

    expect(find.text('Scores 54 this round'), findsOneWidget);

    await tester.tap(find.text('Save round'));
    await tester.pumpAndSettle();

    final game = container.read(activeGameProvider).requireValue!;
    expect(game.totalFor(game.players[1].id), 54);
  });

  testWidgets('rejects a pip count larger than the whole set', (tester) async {
    await pumpEntry(tester);

    // A double-6 set only holds 168 pips in total.
    await tester.enterText(find.byType(TextField).at(0), '999');
    await tester.pump();
    await tester.tap(find.text('Save round'));
    await tester.pump();

    expect(find.textContaining('only has 168 pips'), findsOneWidget);
    expect(
      container.read(activeGameProvider).requireValue!.completedRounds,
      isEmpty,
    );
  });
}
