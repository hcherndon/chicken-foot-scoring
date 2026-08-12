import 'domino_set.dart';

/// The house rules a game is played under. Fixed once a game starts so that
/// historical games always re-score exactly the way they were played.
class GameRules {
  const GameRules({
    this.set = DominoSet.double9,
    this.skipUnheldDoubles = true,
    this.doubleBlankPenaltyEnabled = true,
    this.doubleBlankPenalty = 50,
    this.endOnDoublePenaltyEnabled = false,
    this.endOnDoublePenalty = 50,
  });

  /// Which domino set is in play. Sets the longest a game can run.
  final DominoSet set;

  /// When a round's opening double turns out to be in nobody's hand, burn it
  /// and open on the next double down instead of drawing until it appears.
  ///
  /// Burning doubles makes a game shorter than [maxRoundCount]. The
  /// double-blank is never burned — the last round is always played.
  final bool skipUnheldDoubles;

  /// Holding the 0–0 when a round ends costs [doubleBlankPenalty].
  final bool doubleBlankPenaltyEnabled;
  final int doubleBlankPenalty;

  /// A player whose last tile was a double takes [endOnDoublePenalty].
  final bool endOnDoublePenaltyEnabled;
  final int endOnDoublePenalty;

  /// The most rounds this game can run to. The actual count is only known once
  /// the double-blank has been played.
  int get maxRoundCount => set.maxRoundCount;

  /// Whether any per-player penalty toggles need to be shown during entry.
  bool get hasPenalties => doubleBlankPenaltyEnabled || endOnDoublePenaltyEnabled;

  GameRules copyWith({
    DominoSet? set,
    bool? skipUnheldDoubles,
    bool? doubleBlankPenaltyEnabled,
    int? doubleBlankPenalty,
    bool? endOnDoublePenaltyEnabled,
    int? endOnDoublePenalty,
  }) {
    return GameRules(
      set: set ?? this.set,
      skipUnheldDoubles: skipUnheldDoubles ?? this.skipUnheldDoubles,
      doubleBlankPenaltyEnabled:
          doubleBlankPenaltyEnabled ?? this.doubleBlankPenaltyEnabled,
      doubleBlankPenalty: doubleBlankPenalty ?? this.doubleBlankPenalty,
      endOnDoublePenaltyEnabled:
          endOnDoublePenaltyEnabled ?? this.endOnDoublePenaltyEnabled,
      endOnDoublePenalty: endOnDoublePenalty ?? this.endOnDoublePenalty,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameRules &&
      other.set == set &&
      other.skipUnheldDoubles == skipUnheldDoubles &&
      other.doubleBlankPenaltyEnabled == doubleBlankPenaltyEnabled &&
      other.doubleBlankPenalty == doubleBlankPenalty &&
      other.endOnDoublePenaltyEnabled == endOnDoublePenaltyEnabled &&
      other.endOnDoublePenalty == endOnDoublePenalty;

  @override
  int get hashCode => Object.hash(
        set,
        skipUnheldDoubles,
        doubleBlankPenaltyEnabled,
        doubleBlankPenalty,
        endOnDoublePenaltyEnabled,
        endOnDoublePenalty,
      );
}
