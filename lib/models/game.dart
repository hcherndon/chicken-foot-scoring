import 'game_rules.dart';
import 'player.dart';
import 'round.dart';
import 'standing.dart';

/// A whole game: the rules it is played under, who is playing, and every round
/// scored so far. Immutable — mutations return a new [Game].
class Game {
  const Game({
    required this.id,
    required this.createdAt,
    required this.rules,
    required this.players,
    required this.rounds,
    this.completedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? completedAt;
  final GameRules rules;

  /// Players in seat order.
  final List<Player> players;

  /// Completed rounds, in order. A game in progress has fewer rounds than
  /// [GameRules.roundCount].
  final List<Round> rounds;

  List<String> get playerIds => [for (final p in players) p.id];

  List<Round> get completedRounds =>
      [for (final r in rounds) if (r.isComplete) r];

  /// Zero-based index of the round waiting to be scored, or null when done.
  int? get currentRoundIndex {
    final played = completedRounds.length;
    return played >= rules.roundCount ? null : played;
  }

  /// The double that opens the round waiting to be scored.
  int? get currentStartingDouble {
    final index = currentRoundIndex;
    return index == null ? null : rules.set.startingDoubleFor(index);
  }

  bool get isComplete => completedRounds.length >= rules.roundCount;

  bool get hasStarted => completedRounds.isNotEmpty;

  Player playerById(String id) => players.firstWhere((p) => p.id == id);

  /// Cumulative score for [playerId] across the first [roundLimit] completed
  /// rounds (all of them when [roundLimit] is null).
  int totalFor(String playerId, {int? roundLimit}) {
    final rounds = completedRounds;
    final end = roundLimit == null
        ? rounds.length
        : roundLimit.clamp(0, rounds.length);
    var total = 0;
    for (var i = 0; i < end; i++) {
      total += rounds[i].scoreFor(playerId, rules);
    }
    return total;
  }

  /// The scoreboard, best (lowest total) first. Ties share a rank and are
  /// ordered by seat so the list stays stable.
  List<Standing> get standings => _standings(completedRounds.length);

  /// Standings as they stood after [roundCount] completed rounds.
  List<Standing> standingsAfterRound(int roundCount) => _standings(roundCount);

  List<Standing> _standings(int roundCount) {
    final limit = roundCount.clamp(0, completedRounds.length);
    final totals = {
      for (final player in players) player.id: totalFor(player.id, roundLimit: limit),
    };
    final previousTotals = limit == 0
        ? null
        : {
            for (final player in players)
              player.id: totalFor(player.id, roundLimit: limit - 1),
          };
    final previousRanks =
        previousTotals == null ? null : _ranksFrom(previousTotals);
    final ranks = _ranksFrom(totals);

    final ordered = [...players]..sort((a, b) {
        final byTotal = totals[a.id]!.compareTo(totals[b.id]!);
        return byTotal != 0 ? byTotal : a.seatOrder.compareTo(b.seatOrder);
      });

    return [
      for (final player in ordered)
        Standing(
          player: player,
          total: totals[player.id]!,
          lastRoundScore: limit == 0
              ? null
              : completedRounds[limit - 1].scoreFor(player.id, rules),
          rank: ranks[player.id]!,
          previousRank: previousRanks?[player.id],
        ),
    ];
  }

  /// Competition ranking (1, 2, 2, 4) over a map of player totals.
  Map<String, int> _ranksFrom(Map<String, int> totals) {
    final sorted = totals.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final ranks = <String, int>{};
    var rank = 0;
    int? previousTotal;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].value != previousTotal) {
        rank = i + 1;
        previousTotal = sorted[i].value;
      }
      ranks[sorted[i].key] = rank;
    }
    return ranks;
  }

  /// The winner(s) once the game is complete — everyone tied for the lowest
  /// total. Empty while the game is still in progress.
  List<Player> get winners {
    if (!isComplete) return const [];
    final board = standings;
    if (board.isEmpty) return const [];
    final best = board.first.total;
    return [for (final s in board) if (s.total == best) s.player];
  }

  /// The leader right now, or null before any round is scored. Null as well
  /// when the lead is shared.
  Player? get leader {
    final board = standings;
    if (board.isEmpty || !hasStarted) return null;
    if (board.length > 1 && board[1].total == board.first.total) return null;
    return board.first.player;
  }

  Game copyWith({
    GameRules? rules,
    List<Player>? players,
    List<Round>? rounds,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Game(
      id: id,
      createdAt: createdAt,
      rules: rules ?? this.rules,
      players: players ?? this.players,
      rounds: rounds ?? this.rounds,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  /// Adds or replaces the round at [round.index] and stamps the game complete
  /// once the final round lands.
  Game withRound(Round round, {DateTime? now}) {
    final updated = [...rounds];
    final existing = updated.indexWhere((r) => r.index == round.index);
    if (existing >= 0) {
      updated[existing] = round;
    } else {
      updated.add(round);
    }
    updated.sort((a, b) => a.index.compareTo(b.index));

    final completed = updated.where((r) => r.isComplete).length;
    final finished = completed >= rules.roundCount;
    return copyWith(
      rounds: updated,
      completedAt: finished ? (completedAt ?? now ?? DateTime.now()) : null,
      clearCompletedAt: !finished,
    );
  }
}
