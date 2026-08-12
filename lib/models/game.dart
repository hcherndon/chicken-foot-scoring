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

  /// Rounds in play order. A game in progress has fewer rounds than
  /// [GameRules.maxRoundCount] — and so does a finished one if any doubles
  /// were burned along the way.
  final List<Round> rounds;

  List<String> get playerIds => [for (final p in players) p.id];

  List<Round> get completedRounds =>
      [for (final r in rounds) if (r.isComplete) r];

  /// Doubles that have not been played yet, highest first.
  ///
  /// This is the pool a round draws its opening double from. Skipping a
  /// double does not take it out — it is still here for the next round.
  List<int> get remainingDoubles => _remainingExcluding(null);

  /// A game ends when every double has had its round, however out of order
  /// they came. That is the same [GameRules.roundCount] rounds either way.
  bool get isComplete => remainingDoubles.isEmpty;

  /// Zero-based index of the round waiting to be scored, or null when done.
  int? get currentRoundIndex => isComplete ? null : completedRounds.length;

  /// The double the next round tries first: the highest one still unplayed.
  /// Null once the game is over.
  int? get nextStartingDouble =>
      remainingDoubles.isEmpty ? null : remainingDoubles.first;

  /// Every double round [roundIndex] could legally open on, highest first.
  ///
  /// Under strict rules that is only the highest unplayed one. Otherwise it
  /// is the whole remaining pool, since the round steps down through it until
  /// somebody holds one. The round's own double is not counted as taken, so
  /// re-scoring a round can move it anywhere still free.
  List<int> openableDoublesFor(int roundIndex) {
    final remaining = _remainingExcluding(roundIndex);
    if (remaining.isEmpty) return const [];
    return rules.skipUnheldDoubles ? remaining : [remaining.first];
  }

  /// [openableDoublesFor] the round waiting to be scored.
  List<int> get openableDoubles {
    final index = currentRoundIndex;
    return index == null ? const [] : openableDoublesFor(index);
  }

  /// Whether round [roundIndex] may open on [startingDouble]: it has to be a
  /// double no other round has taken, and under strict rules the highest one.
  bool canOpenRoundOn(int roundIndex, int startingDouble) {
    if (roundIndex < 0 || roundIndex > completedRounds.length) return false;
    return openableDoublesFor(roundIndex).contains(startingDouble);
  }

  /// The doubles tried and passed over before round [roundIndex] settled on
  /// [startingDouble] — the ones nobody held that day. Highest first.
  List<int> skippedBefore(int roundIndex, int startingDouble) {
    final takenEarlier = {
      for (final r in completedRounds)
        if (r.index < roundIndex) r.startingDouble,
    };
    return [
      for (var d = rules.set.maxDouble; d > startingDouble; d--)
        if (!takenEarlier.contains(d)) d,
    ];
  }

  /// The doubles [round] passed over on its way to the one it opened on.
  List<int> skippedIn(Round round) =>
      skippedBefore(round.index, round.startingDouble);

  /// Rounds still to play. Exact — one per double left in the pool.
  int get remainingRounds => remainingDoubles.length;

  /// Doubles nobody has taken yet, optionally pretending [ignoreRoundIndex]
  /// has not been played.
  List<int> _remainingExcluding(int? ignoreRoundIndex) {
    final taken = {
      for (final r in completedRounds)
        if (r.index != ignoreRoundIndex) r.startingDouble,
    };
    return [
      for (var d = rules.set.maxDouble; d >= 0; d--)
        if (!taken.contains(d)) d,
    ];
  }

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

    final played = {
      for (final r in updated) if (r.isComplete) r.startingDouble,
    };
    final finished = played.length >= rules.roundCount;
    return copyWith(
      rounds: updated,
      completedAt: finished ? (completedAt ?? now ?? DateTime.now()) : null,
      clearCompletedAt: !finished,
    );
  }
}
