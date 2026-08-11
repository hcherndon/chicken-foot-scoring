import 'game_rules.dart';
import 'round_entry.dart';

/// A single completed (or in-progress) round of a game.
class Round {
  const Round({
    required this.index,
    required this.startingDouble,
    required this.entries,
    this.completedAt,
  });

  /// Zero-based round number. Round 0 opens on the set's highest double.
  final int index;

  /// The double this round opened on, e.g. 9 then 8 then 7...
  final int startingDouble;

  /// One entry per player, in seat order.
  final List<RoundEntry> entries;

  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  /// Human-facing round number.
  int get displayNumber => index + 1;

  RoundEntry? entryFor(String playerId) {
    for (final entry in entries) {
      if (entry.playerId == playerId) return entry;
    }
    return null;
  }

  int scoreFor(String playerId, GameRules rules) =>
      entryFor(playerId)?.totalUnder(rules) ?? 0;

  /// The player who emptied their hand, if anyone did.
  String? get wentOutPlayerId {
    for (final entry in entries) {
      if (entry.wentOut) return entry.playerId;
    }
    return null;
  }

  Round copyWith({
    List<RoundEntry>? entries,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Round(
      index: index,
      startingDouble: startingDouble,
      entries: entries ?? this.entries,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  /// A blank round for [playerIds], ready to be filled in.
  static Round empty({
    required int index,
    required int startingDouble,
    required List<String> playerIds,
  }) {
    return Round(
      index: index,
      startingDouble: startingDouble,
      entries: [for (final id in playerIds) RoundEntry(playerId: id)],
    );
  }
}
