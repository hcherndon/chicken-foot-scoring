import 'package:flutter/material.dart';

import '../models/game.dart';
import '../theme/app_theme.dart';

const _rowHeight = 40.0;
const _nameWidth = 104.0;
// Wide enough for a four-digit total plus its label without wrapping.
const _totalWidth = 72.0;
const _roundWidth = 46.0;

/// The full score sheet: players down the side, rounds across the top.
///
/// Rows stay in seat order (not standings order) so the grid reads like the
/// paper sheet it replaces. The name and total columns are pinned while the
/// rounds scroll horizontally.
class ScoreGrid extends StatelessWidget {
  const ScoreGrid({super.key, required this.game, this.onTapRound});

  final Game game;

  /// Called with a round index when its column header is tapped.
  final void Function(int roundIndex)? onTapRound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rounds = game.completedRounds;

    if (rounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Scores appear here once the first round is in.',
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned: player names and running totals.
          Column(
            children: [
              _cell(
                width: _nameWidth,
                child: Text('Player', style: headerStyle),
                align: Alignment.centerLeft,
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
              reverse: true, // keep the most recent round in view
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final round in rounds)
                        InkWell(
                          onTap: onTapRound == null
                              ? null
                              : () => onTapRound!(round.index),
                          child: _cell(
                            width: _roundWidth,
                            child: Text(
                              '${round.startingDouble}',
                              style: headerStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final player in game.players)
                    Row(
                      children: [
                        for (final round in rounds)
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
                ],
              ),
            ),
          ),
          // Pinned: running totals.
          Column(
            children: [
              _cell(
                width: _totalWidth,
                child: Text('Total', style: headerStyle),
                align: Alignment.centerRight,
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
    );
  }

  Widget _cell({
    required double width,
    required Widget child,
    Alignment align = Alignment.center,
  }) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }
}
