import 'package:drift/drift.dart';

import '../models/domino_set.dart';
import '../models/game.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../models/round_entry.dart';
import '../util/ids.dart';
import 'database.dart';
import 'tables.dart';

part 'game_dao.g.dart';

/// Reads and writes whole [Game] aggregates.
///
/// A game is a handful of rows (at most 16 rounds x 12 players), so [save]
/// replaces the game's rounds and players wholesale inside a transaction
/// rather than diffing. That keeps writes trivially consistent, and callers
/// can save after every round without noticeable cost.
@DriftAccessor(tables: [Games, Players, Rounds, RoundEntries])
class GameDao extends DatabaseAccessor<AppDatabase> with _$GameDaoMixin {
  GameDao(super.db);

  Future<void> save(Game game) {
    return transaction(() async {
      await into(games).insertOnConflictUpdate(
        GamesCompanion.insert(
          id: game.id,
          createdAt: game.createdAt,
          completedAt: Value(game.completedAt),
          maxDouble: game.rules.set.maxDouble,
          skipUnheldDoubles: Value(game.rules.skipUnheldDoubles),
          doubleBlankPenaltyEnabled: game.rules.doubleBlankPenaltyEnabled,
          doubleBlankPenalty: game.rules.doubleBlankPenalty,
          endOnDoublePenaltyEnabled: game.rules.endOnDoublePenaltyEnabled,
          endOnDoublePenalty: game.rules.endOnDoublePenalty,
        ),
      );

      // Rounds first: deleting players would cascade into their entries.
      await (delete(rounds)..where((r) => r.gameId.equals(game.id))).go();
      await (delete(players)..where((p) => p.gameId.equals(game.id))).go();

      await batch((b) {
        b.insertAll(players, [
          for (final player in game.players)
            PlayersCompanion.insert(
              id: player.id,
              gameId: game.id,
              name: player.name,
              seatOrder: player.seatOrder,
            ),
        ]);
      });

      for (final round in game.rounds) {
        final roundId = newId();
        await into(rounds).insert(
          RoundsCompanion.insert(
            id: roundId,
            gameId: game.id,
            roundIndex: round.index,
            startingDouble: round.startingDouble,
            completedAt: Value(round.completedAt),
          ),
        );
        await batch((b) {
          b.insertAll(roundEntries, [
            for (final entry in round.entries)
              RoundEntriesCompanion.insert(
                id: newId(),
                roundId: roundId,
                playerId: entry.playerId,
                pips: Value(entry.pips),
                wentOut: Value(entry.wentOut),
                hadDoubleBlank: Value(entry.hadDoubleBlank),
                endedOnDouble: Value(entry.endedOnDouble),
              ),
          ]);
        });
      }
    });
  }

  Future<Game?> load(String gameId) async {
    final row = await (select(games)..where((g) => g.id.equals(gameId)))
        .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).first;
  }

  /// The most recently created game that has not been finished, if any.
  Future<Game?> loadActive() async {
    final row = await (select(games)
          ..where((g) => g.completedAt.isNull())
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).first;
  }

  /// Finished games, newest first.
  Stream<List<Game>> watchCompleted() {
    final query = select(games)
      ..where((g) => g.completedAt.isNotNull())
      ..orderBy([(g) => OrderingTerm.desc(g.completedAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  /// Every game, newest first — finished or not.
  Stream<List<Game>> watchAll() {
    final query = select(games)
      ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    return query.watch().asyncMap(_hydrate);
  }

  Future<void> deleteGame(String gameId) =>
      (delete(games)..where((g) => g.id.equals(gameId))).go();

  Future<void> deleteAll() => transaction(() async {
        await delete(roundEntries).go();
        await delete(rounds).go();
        await delete(players).go();
        await delete(games).go();
      });

  /// Loads the children for [rows] in three queries and stitches whole games.
  Future<List<Game>> _hydrate(List<GameRow> rows) async {
    if (rows.isEmpty) return const [];
    final gameIds = [for (final row in rows) row.id];

    final playerRows =
        await (select(players)..where((p) => p.gameId.isIn(gameIds))).get();
    final roundRows =
        await (select(rounds)..where((r) => r.gameId.isIn(gameIds))).get();
    final entryRows = roundRows.isEmpty
        ? <RoundEntryRow>[]
        : await (select(roundEntries)
              ..where((e) => e.roundId.isIn([for (final r in roundRows) r.id])))
            .get();

    final playersByGame = <String, List<Player>>{};
    for (final row in playerRows) {
      playersByGame
          .putIfAbsent(row.gameId, () => [])
          .add(Player(id: row.id, name: row.name, seatOrder: row.seatOrder));
    }
    for (final list in playersByGame.values) {
      list.sort((a, b) => a.seatOrder.compareTo(b.seatOrder));
    }

    final entriesByRound = <String, List<RoundEntry>>{};
    for (final row in entryRows) {
      entriesByRound.putIfAbsent(row.roundId, () => []).add(
            RoundEntry(
              playerId: row.playerId,
              pips: row.pips,
              wentOut: row.wentOut,
              hadDoubleBlank: row.hadDoubleBlank,
              endedOnDouble: row.endedOnDouble,
            ),
          );
    }

    final roundsByGame = <String, List<Round>>{};
    for (final row in roundRows) {
      final seats = {
        for (final p in playersByGame[row.gameId] ?? const <Player>[])
          p.id: p.seatOrder,
      };
      final entries = entriesByRound[row.id] ?? <RoundEntry>[];
      entries.sort((a, b) =>
          (seats[a.playerId] ?? 0).compareTo(seats[b.playerId] ?? 0));
      roundsByGame.putIfAbsent(row.gameId, () => []).add(
            Round(
              index: row.roundIndex,
              startingDouble: row.startingDouble,
              entries: entries,
              completedAt: row.completedAt,
            ),
          );
    }
    for (final list in roundsByGame.values) {
      list.sort((a, b) => a.index.compareTo(b.index));
    }

    return [
      for (final row in rows)
        Game(
          id: row.id,
          createdAt: row.createdAt,
          completedAt: row.completedAt,
          rules: GameRules(
            set: DominoSet.fromMaxDouble(row.maxDouble),
            skipUnheldDoubles: row.skipUnheldDoubles,
            doubleBlankPenaltyEnabled: row.doubleBlankPenaltyEnabled,
            doubleBlankPenalty: row.doubleBlankPenalty,
            endOnDoublePenaltyEnabled: row.endOnDoublePenaltyEnabled,
            endOnDoublePenalty: row.endOnDoublePenalty,
          ),
          players: playersByGame[row.id] ?? const [],
          rounds: roundsByGame[row.id] ?? const [],
        ),
    ];
  }
}
