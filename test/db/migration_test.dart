import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/models/domino_set.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The schema as it stood at version 1, before games recorded whether doubles
/// nobody holds get burned.
const _v1Schema = '''
CREATE TABLE games (
  id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  max_double INTEGER NOT NULL,
  double_blank_penalty_enabled INTEGER NOT NULL,
  double_blank_penalty INTEGER NOT NULL,
  end_on_double_penalty_enabled INTEGER NOT NULL,
  end_on_double_penalty INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE players (
  id TEXT NOT NULL,
  game_id TEXT NOT NULL REFERENCES games (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  seat_order INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE rounds (
  id TEXT NOT NULL,
  game_id TEXT NOT NULL REFERENCES games (id) ON DELETE CASCADE,
  round_index INTEGER NOT NULL,
  starting_double INTEGER NOT NULL,
  completed_at INTEGER,
  PRIMARY KEY (id),
  UNIQUE (game_id, round_index)
);
CREATE TABLE round_entries (
  id TEXT NOT NULL,
  round_id TEXT NOT NULL REFERENCES rounds (id) ON DELETE CASCADE,
  player_id TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
  pips INTEGER NOT NULL DEFAULT 0,
  went_out INTEGER NOT NULL DEFAULT 0,
  had_double_blank INTEGER NOT NULL DEFAULT 0,
  ended_on_double INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE (round_id, player_id)
);
''';

int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

void main() {
  /// A database holding one finished double-6 game, written by version 1.
  AppDatabase openV1Database() {
    return AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (db) {
          for (final statement in _v1Schema.split(';')) {
            if (statement.trim().isNotEmpty) db.execute(statement);
          }
          db.execute('''
            INSERT INTO games VALUES (
              'old', ${_seconds(DateTime(2026, 5, 1))},
              ${_seconds(DateTime(2026, 5, 1, 21))}, 6, 1, 50, 0, 50
            )
          ''');
          db.execute("INSERT INTO players VALUES ('p1', 'old', 'Ann', 0)");
          db.execute("INSERT INTO players VALUES ('p2', 'old', 'Bo', 1)");
          db.execute('''
            INSERT INTO rounds VALUES
              ('r0', 'old', 0, 6, ${_seconds(DateTime(2026, 5, 1, 20))})
          ''');
          db.execute(
            "INSERT INTO round_entries VALUES ('e1', 'r0', 'p1', 0, 1, 0, 0)",
          );
          db.execute(
            "INSERT INTO round_entries VALUES ('e2', 'r0', 'p2', 12, 0, 0, 0)",
          );
          db.execute('PRAGMA user_version = 1');
        },
      ),
    );
  }

  test('upgrading from v1 adds the column without disturbing the game',
      () async {
    final db = openV1Database();
    addTearDown(db.close);

    final game = await db.gameDao.load('old');

    expect(game, isNotNull);
    expect(game!.rules.set, DominoSet.double6);
    expect(game.players.map((p) => p.name), ['Ann', 'Bo']);
    expect(game.rounds.single.startingDouble, 6);
    expect(game.totalFor('p2'), 12);
    expect(game.rules.doubleBlankPenaltyEnabled, isTrue);
    expect(game.rules.endOnDoublePenaltyEnabled, isFalse);
  });

  test('games written before the rule existed are treated as strict', () async {
    final db = openV1Database();
    addTearDown(db.close);

    final game = await db.gameDao.load('old');

    // They were played straight down the ladder, so they must not come back
    // claiming doubles could have been burned — that would rewrite history.
    expect(game!.rules.skipUnheldDoubles, isFalse);
    expect(game.openableDoubles, [5]);
  });

  test('games created after the upgrade default to burning doubles', () async {
    final db = openV1Database();
    addTearDown(db.close);
    // Force the migration to run before inserting through the new schema.
    await db.gameDao.load('old');

    await db.customStatement('''
      INSERT INTO games (id, created_at, max_double,
        double_blank_penalty_enabled, double_blank_penalty,
        end_on_double_penalty_enabled, end_on_double_penalty)
      VALUES ('fresh', ${_seconds(DateTime(2026, 8, 11))}, 9, 1, 50, 0, 50)
    ''');

    final fresh = await db.gameDao.load('fresh');
    expect(fresh!.rules.skipUnheldDoubles, isTrue);
  });

  test('a fresh database is created at the current version', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final version = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(version, db.schemaVersion);
    expect(db.schemaVersion, 2);
  });
}
