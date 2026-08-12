import 'package:chicken_foot/app.dart';
import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/providers/database_provider.dart';
import 'package:chicken_foot/providers/settings_provider.dart';
import 'package:chicken_foot/screens/settings_screen.dart';
import 'package:chicken_foot/theme/app_palette.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await container.read(settingsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await settle(tester);
  }

  test('every palette has a distinct name, seed and accent', () {
    final labels = {for (final p in AppPalette.values) p.label};
    final seeds = {for (final p in AppPalette.values) p.seed};
    expect(AppPalette.values, hasLength(15));
    expect(labels, hasLength(AppPalette.values.length));
    expect(seeds, hasLength(AppPalette.values.length));
    for (final palette in AppPalette.values) {
      expect(palette.accent, isNot(palette.seed), reason: palette.name);
    }
  });

  test('an unknown stored palette falls back rather than throwing', () {
    expect(AppPalette.byName('chartreuse'), AppPalette.fallback);
    expect(AppPalette.byName(null), AppPalette.fallback);
    expect(AppPalette.byName('plum'), AppPalette.plum);
  });

  testWidgets('the picker lists every palette with its own swatch',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(DropdownMenu<AppPalette>));
    await settle(tester);

    for (final palette in AppPalette.values) {
      final entry = find.text(palette.label).last;
      await tester.ensureVisible(entry);
      await settle(tester, frames: 2);
      expect(entry, findsOneWidget, reason: '${palette.name} not reachable');
      expect(
        find.descendant(
          of: find.ancestor(of: entry, matching: find.byType(MenuItemButton)),
          matching: find.byType(PaletteSwatch),
        ),
        findsOneWidget,
        reason: '${palette.name} has no swatch',
      );
    }
  });

  testWidgets('choosing a palette repaints the app and sticks', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(DropdownMenu<AppPalette>));
    await settle(tester);

    // The menu scrolls, so this one may start below the fold.
    final entry = find.text(AppPalette.crimson.label).last;
    await tester.ensureVisible(entry);
    await settle(tester);
    await tester.tap(entry);
    await settle(tester);

    expect(
      container.read(settingsProvider).requireValue.palette,
      AppPalette.crimson,
    );

    // A fresh app picks the choice back up from preferences.
    final reloaded = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(reloaded.dispose);
    expect(
      (await reloaded.read(settingsProvider.future)).palette,
      AppPalette.crimson,
    );
  });

  testWidgets('the whole app takes its colours from the chosen palette',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await container.read(settingsProvider.future);
    await container.read(settingsProvider.notifier).setPalette(AppPalette.ocean);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ChickenFootApp(),
      ),
    );
    await settle(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final expected = ColorScheme.fromSeed(seedColor: AppPalette.ocean.seed);
    expect(app.theme!.colorScheme.primary, expected.primary);
    expect(app.darkTheme!.colorScheme.brightness, Brightness.dark);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
