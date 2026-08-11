import 'game_rules.dart';

/// One player's result for one round: the pips left in their hand plus any
/// penalties that applied.
class RoundEntry {
  const RoundEntry({
    required this.playerId,
    this.pips = 0,
    this.wentOut = false,
    this.hadDoubleBlank = false,
    this.endedOnDouble = false,
  });

  final String playerId;

  /// Pips remaining in hand. Ignored when [wentOut] is true.
  final int pips;

  /// This player emptied their hand, so they score zero for the round.
  final bool wentOut;

  /// This player was still holding the 0–0.
  final bool hadDoubleBlank;

  /// This player's last played tile was a double, ending the round on a double.
  final bool endedOnDouble;

  /// Pips counted toward the score, before penalties.
  int get basePips => wentOut ? 0 : pips;

  /// Penalty points added under [rules].
  int penaltyUnder(GameRules rules) {
    var penalty = 0;
    if (rules.doubleBlankPenaltyEnabled && hadDoubleBlank) {
      penalty += rules.doubleBlankPenalty;
    }
    if (rules.endOnDoublePenaltyEnabled && endedOnDouble) {
      penalty += rules.endOnDoublePenalty;
    }
    return penalty;
  }

  /// The player's score for this round under [rules].
  int totalUnder(GameRules rules) => basePips + penaltyUnder(rules);

  RoundEntry copyWith({
    int? pips,
    bool? wentOut,
    bool? hadDoubleBlank,
    bool? endedOnDouble,
  }) {
    return RoundEntry(
      playerId: playerId,
      pips: pips ?? this.pips,
      wentOut: wentOut ?? this.wentOut,
      hadDoubleBlank: hadDoubleBlank ?? this.hadDoubleBlank,
      endedOnDouble: endedOnDouble ?? this.endedOnDouble,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoundEntry &&
      other.playerId == playerId &&
      other.pips == pips &&
      other.wentOut == wentOut &&
      other.hadDoubleBlank == hadDoubleBlank &&
      other.endedOnDouble == endedOnDouble;

  @override
  int get hashCode =>
      Object.hash(playerId, pips, wentOut, hadDoubleBlank, endedOnDouble);
}
