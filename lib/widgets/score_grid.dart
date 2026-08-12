import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';
import 'domino_tile.dart';

const _rowHeight = 38.0;
const _headerHeight = 46.0;
const _nameWidth = 96.0;
// Wide enough for a four-digit total plus its label without wrapping.
const _totalWidth = 66.0;
const _roundWidth = 44.0;

/// The full score sheet: players down the side, rounds across the top, each
/// round headed by the domino it opened on.
///
/// Rows stay in seat order (not standings order) so the grid reads like the
/// paper sheet it replaces. The name and total columns are pinned while the
/// rounds scroll horizontally. Tapping anywhere in a round's column opens that
/// round for correction.
class ScoreGrid extends StatelessWidget {
  const ScoreGrid({super.key, required this.game, this.onTapRound});

  final Game game;

  /// Called with a round index when its column is tapped.
  final void Function(int roundIndex)? onTapRound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Read like the paper sheet: highest double on the left, down to the
    // blank — not the order the rounds happened to come out in.
    final rounds = [...game.completedRounds]
      ..sort((a, b) => b.startingDouble.compareTo(a.startingDouble));

    if (rounds.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Scores appear here once the first round is in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = AppTheme.tabular.merge(theme.textTheme.bodyMedium);
    final remaining = game.remainingDoubles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinned: player names.
              Column(
                children: [
                  _cell(
                    width: _nameWidth,
                    height: _headerHeight,
                    align: Alignment.centerLeft,
                    child: Text('Player', style: headerStyle),
                  ),
                  for (final player in game.players)
                    _cell(
                      width: _nameWidth,
                      align: Alignment.centerLeft,
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final round in rounds)
                        // The whole column is one target — a 44px header alone
                        // is a fussy thing to hit.
                        InkWell(
                          onTap: onTapRound == null
                              ? null
                              : () => onTapRound!(round.index),
                          child: Column(
                            children: [
                              _cell(
                                width: _roundWidth,
                                height: _headerHeight,
                                child: DominoTile(
                                  value: round.startingDouble,
                                  height: 32,
                                ),
                              ),
                              for (final player in game.players)
                                _cell(
                                  width: _roundWidth,
                                  child: Text(
                                    '${round.scoreFor(player.id, game.rules)}',
                                    style: round.wentOutPlayerId == player.id
                                        ? cellStyle.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          )
                                        : cellStyle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Pinned: running totals.
              Column(
                children: [
                  _cell(
                    width: _totalWidth,
                    height: _headerHeight,
                    align: Alignment.centerRight,
                    child: Text('Total', style: headerStyle),
                  ),
                  for (final player in game.players)
                    _cell(
                      width: _totalWidth,
                      align: Alignment.centerRight,
                      child: Text(
                        '${game.totalFor(player.id)}',
                        style: AppTheme.tabular.merge(
                          theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (remaining.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    remaining.length == 1
                        ? 'Still to play: the ${remaining.single}'
                        : 'Still to play: ${remaining.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell({
    required double width,
    required Widget child,
    double height = _rowHeight,
    Alignment align = Alignment.center,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}
