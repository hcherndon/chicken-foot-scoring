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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Cascading deletes are off by default in SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() =>
    driftDatabase(name: 'chicken_foot', native: const DriftNativeOptions());
