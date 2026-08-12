/// The domino sets a game can be played with.
///
/// The set determines how many rounds a game has (one per double, counting
/// down from the highest to the double-blank) and the largest pip total a
/// single hand could theoretically hold.
enum DominoSet {
  double6(maxDouble: 6, tileCount: 28),
  double9(maxDouble: 9, tileCount: 55),
  double12(maxDouble: 12, tileCount: 91),
  double15(maxDouble: 15, tileCount: 136);

  const DominoSet({required this.maxDouble, required this.tileCount});

  /// The highest double in the set, e.g. 9 for a double-9 set.
  final int maxDouble;

  /// How many dominoes the set contains.
  final int tileCount;

  String get label => 'Double-$maxDouble';

  /// The most rounds a game can run to: one per double, [maxDouble] down
  /// through double-blank. A game can be shorter when the house rule that
  /// burns doubles nobody holds is in play.
  int get maxRoundCount => maxDouble + 1;

  /// The double that opens round [roundIndex] when no doubles are burned.
  int startingDoubleFor(int roundIndex) => maxDouble - roundIndex;

  /// Total pips across every domino in the set — the ceiling for any hand.
  ///
  /// Sum of (i + j) for all 0 <= i <= j <= n, which reduces to n(n+1)(n+2)/2.
  int get totalPips => maxDouble * (maxDouble + 1) * (maxDouble + 2) ~/ 2;

  /// The customary hand size for [playerCount] players, or null if the set is
  /// too small to deal that many hands. Advisory only — nothing enforces it.
  int? recommendedHandSize(int playerCount) {
    if (playerCount < 2) return null;
    final table = switch (this) {
      DominoSet.double6 => const [7, 7, 5, 4],
      DominoSet.double9 => const [21, 14, 11, 8, 7, 6, 5],
      DominoSet.double12 => const [15, 15, 15, 12, 12, 11, 10, 9, 8, 7, 7],
      DominoSet.double15 => const [18, 18, 18, 15, 15, 13, 13, 11, 11, 10, 10, 9],
    };
    final index = playerCount - 2;
    if (index >= table.length) return null;
    final size = table[index];
    // Leave at least a few tiles in the boneyard.
    return size * playerCount < tileCount ? size : null;
  }

  static DominoSet fromMaxDouble(int maxDouble) =>
      DominoSet.values.firstWhere((s) => s.maxDouble == maxDouble);
}
