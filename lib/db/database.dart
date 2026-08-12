import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'game_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Games, Players, Rounds, RoundEntries], daos: [GameDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: an isolated in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(games, games.skipUnheldDoubles);
            // Games recorded before this rule existed were played straight
            // down the ladder, so they are strict regardless of the column
            // default that ALTER TABLE just handed them.
            await customStatement('UPDATE games SET skip_unheld_doubles = 0');
          }
        },
        beforeOpen: (details) async {
          // Cascading deletes are off by default in SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() => driftDatabase(
      name: 'chicken_foot',
      native: const DriftNativeOptions(),
      // On the web, drift runs SQLite compiled to WASM in a worker and
      // persists to OPFS or IndexedDB. Both assets ship from web/ — see
      // README for how to refresh them.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
