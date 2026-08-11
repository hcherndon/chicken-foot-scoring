import 'player.dart';

/// One row of the scoreboard: where a player stands right now.
class Standing {
  const Standing({
    required this.player,
    required this.total,
    required this.lastRoundScore,
    required this.rank,
    required this.previousRank,
  });

  final Player player;

  /// Cumulative score across every completed round. Lower is better.
  final int total;

  /// Score in the most recently completed round, or null if none yet.
  final int? lastRoundScore;

  /// 1-based position. Tied players share a rank.
  final int rank;

  /// Rank before the most recent round, or null if there was no prior round.
  final int? previousRank;

  /// Positions gained since the previous round (positive means moved up).
  int? get rankDelta =>
      previousRank == null ? null : previousRank! - rank;

  @override
  bool operator ==(Object other) =>
      other is Standing &&
      other.player == player &&
      other.total == total &&
      other.lastRoundScore == lastRoundScore &&
      other.rank == rank &&
      other.previousRank == previousRank;

  @override
  int get hashCode =>
      Object.hash(player, total, lastRoundScore, rank, previousRank);
}
