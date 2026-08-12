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

  /// A game ends when the double-blank has been played, never on a count.
  /// Under strict rules that lands on round [GameRules.maxRoundCount]; when
  /// doubles are burned it lands sooner.
  bool get isComplete =>
      completedRounds.any((r) => r.startingDouble == _blank);

  /// Zero-based index of the round waiting to be scored, or null when done.
  int? get currentRoundIndex =>
      isComplete ? null : completedRounds.length;

  /// The double the next round should open on if everybody holds their share:
  /// the set's highest to begin with, then one below whatever the last round
  /// opened on. Null once the game is over.
  ///
  /// Under [GameRules.skipUnheldDoubles] the round may open lower than this if
  /// nobody holds it — see [openableDoubles].
  int? get nextStartingDouble {
    if (isComplete) return null;
    final played = completedRounds;
    return played.isEmpty
        ? rules.set.maxDouble
        : played.last.startingDouble - 1;
  }

  /// Every double the upcoming round could legally open on, highest first.
  /// One entry under strict rules; the whole remaining ladder when doubles can
  /// be burned.
  List<int> get openableDoubles {
    final next = nextStartingDouble;
    if (next == null) return const [];
    if (!rules.skipUnheldDoubles) return [next];
    return [for (var d = next; d >= _blank; d--) d];
  }

  /// Doubles that nobody held, so they were never played. Highest first.
  List<int> get burnedDoubles {
    final played = {for (final r in completedRounds) r.startingDouble};
    if (played.isEmpty) return const [];
    final lowest = played.reduce((a, b) => a < b ? a : b);
    return [
      for (var d = rules.set.maxDouble; d >= lowest; d--)
        if (!played.contains(d)) d,
    ];
  }

  /// How many rounds could still be played, at most. Exact only once the
  /// remaining doubles are all held.
  int get maxRemainingRounds {
    final next = nextStartingDouble;
    return next == null ? 0 : next + 1;
  }

  /// The highest double round [roundIndex] may open on: one below whatever the
  /// round before it opened on.
  int highestOpenableFor(int roundIndex) {
    final earlier = [
      for (final r in completedRounds) if (r.index < roundIndex) r,
    ];
    return earlier.isEmpty
        ? rules.set.maxDouble
        : earlier.last.startingDouble - 1;
  }

  /// Whether round [roundIndex] may open on [startingDouble].
  ///
  /// Guards three things the UI already respects but the model must not take
  /// on trust: no gaps in the round sequence, no opening on a double the
  /// ladder has already passed, and no burning at all under strict rules.
  bool canOpenRoundOn(int roundIndex, int startingDouble) {
    if (roundIndex < 0 || roundIndex > completedRounds.length) return false;
    final highest = highestOpenableFor(roundIndex);
    if (startingDouble < _blank || startingDouble > highest) return false;
    return rules.skipUnheldDoubles || startingDouble == highest;
  }

  bool get hasStarted => completedRounds.isNotEmpty;

  static const _blank = 0;

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

    final finished =
        updated.any((r) => r.isComplete && r.startingDouble == _blank);
    return copyWith(
      rounds: updated,
      completedAt: finished ? (completedAt ?? now ?? DateTime.now()) : null,
      clearCompletedAt: !finished,
    );
  }
}
