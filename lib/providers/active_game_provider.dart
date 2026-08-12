import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../models/round_entry.dart';
import '../util/ids.dart';
import 'database_provider.dart';

/// The game currently being scored, or null when there isn't one.
///
/// Every mutation writes through to SQLite immediately, so a crash or a
/// force-quit never costs more than the round being typed.
final activeGameProvider =
    AsyncNotifierProvider<ActiveGameNotifier, Game?>(ActiveGameNotifier.new);

class ActiveGameNotifier extends AsyncNotifier<Game?> {
  @override
  Future<Game?> build() => ref.watch(gameDaoProvider).loadActive();

  Game get _game {
    final game = state.valueOrNull;
    if (game == null) throw StateError('No active game');
    return game;
  }

  /// Starts a fresh game. Any unfinished game is left in history untouched —
  /// only one game is "active" at a time, the most recently created one.
  Future<Game> start({
    required GameRules rules,
    required List<String> playerNames,
  }) async {
    final game = Game(
      id: newId(),
      createdAt: DateTime.now(),
      rules: rules,
      players: [
        for (final (index, name) in playerNames.indexed)
          Player(id: newId(), name: name.trim(), seatOrder: index),
      ],
      rounds: const [],
    );
    await ref.read(gameDaoProvider).save(game);
    state = AsyncData(game);
    return game;
  }

  /// Records [entries] for round [roundIndex] and advances the game. Passing
  /// an index that already has a round re-scores it in place.
  ///
  /// [startingDouble] is the double the round actually opened on, which is not
  /// derivable from the index: under the house rule, doubles nobody holds get
  /// burned and the round opens lower.
  Future<Game> submitRound(
    int roundIndex,
    List<RoundEntry> entries, {
    required int startingDouble,
  }) async {
    final game = _game;
    if (!game.canOpenRoundOn(roundIndex, startingDouble)) {
      throw ArgumentError.value(
        startingDouble,
        'startingDouble',
        'Round ${roundIndex + 1} cannot open on it',
      );
    }
    final round = Round(
      index: roundIndex,
      startingDouble: startingDouble,
      entries: entries,
      completedAt: DateTime.now(),
    );
    final updated = game.withRound(round);
    await ref.read(gameDaoProvider).save(updated);
    state = AsyncData(updated);
    return updated;
  }

  /// Clears the game from the active slot without deleting it. A finished game
  /// stays in history; this just stops the app offering to resume it.
  void dismiss() => state = const AsyncData(null);

  /// Deletes the active game outright.
  Future<void> abandon() async {
    final game = state.valueOrNull;
    if (game == null) return;
    await ref.read(gameDaoProvider).deleteGame(game.id);
    state = const AsyncData(null);
  }

  /// Loads an existing game back into the active slot (used by "rematch" and
  /// by resuming from history).
  Future<void> resume(String gameId) async {
    state = AsyncData(await ref.read(gameDaoProvider).load(gameId));
  }
}
