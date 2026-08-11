import 'domino_set.dart';

/// The house rules a game is played under. Fixed once a game starts so that
/// historical games always re-score exactly the way they were played.
class GameRules {
  const GameRules({
    this.set = DominoSet.double9,
    this.doubleBlankPenaltyEnabled = true,
    this.doubleBlankPenalty = 50,
    this.endOnDoublePenaltyEnabled = false,
    this.endOnDoublePenalty = 50,
  });

  /// Which domino set is in play. Sets the number of rounds.
  final DominoSet set;

  /// Holding the 0–0 when a round ends costs [doubleBlankPenalty].
  final bool doubleBlankPenaltyEnabled;
  final int doubleBlankPenalty;

  /// A player whose last tile was a double takes [endOnDoublePenalty].
  final bool endOnDoublePenaltyEnabled;
  final int endOnDoublePenalty;

  int get roundCount => set.roundCount;

  /// Whether any per-player penalty toggles need to be shown during entry.
  bool get hasPenalties => doubleBlankPenaltyEnabled || endOnDoublePenaltyEnabled;

  GameRules copyWith({
    DominoSet? set,
    bool? doubleBlankPenaltyEnabled,
    int? doubleBlankPenalty,
    bool? endOnDoublePenaltyEnabled,
    int? endOnDoublePenalty,
  }) {
    return GameRules(
      set: set ?? this.set,
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
      other.doubleBlankPenaltyEnabled == doubleBlankPenaltyEnabled &&
      other.doubleBlankPenalty == doubleBlankPenalty &&
      other.endOnDoublePenaltyEnabled == endOnDoublePenaltyEnabled &&
      other.endOnDoublePenalty == endOnDoublePenalty;

  @override
  int get hashCode => Object.hash(
        set,
        doubleBlankPenaltyEnabled,
        doubleBlankPenalty,
        endOnDoublePenaltyEnabled,
        endOnDoublePenalty,
      );
}
