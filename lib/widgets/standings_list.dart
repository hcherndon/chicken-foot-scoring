import 'package:flutter/material.dart';

import '../models/standing.dart';
import '../theme/app_theme.dart';

/// The scoreboard. Rows animate into their new positions when a round lands,
/// so you can see who overtook whom.
class StandingsList extends StatelessWidget {
  const StandingsList({
    super.key,
    required this.standings,
    this.showLastRound = true,
    this.highlightLeader = true,
  });

  final List<Standing> standings;

  /// Show each player's score from the round just scored.
  final bool showLastRound;

  /// Tint the top row. Suppressed on a finished game, where the winner banner
  /// already says who won.
  final bool highlightLeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, standing) in standings.indexed)
          _StandingRow(
            key: ValueKey(standing.player.id),
            standing: standing,
            showLastRound: showLastRound,
            highlighted: highlightLeader && index == 0,
          ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    super.key,
    required this.standing,
    required this.showLastRound,
    required this.highlighted,
  });

  final Standing standing;
  final bool showLastRound;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${standing.rank}',
              style: AppTheme.tabular.merge(
                theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    standing.player.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (standing.rankDelta != null && standing.rankDelta != 0) ...[
                  const SizedBox(width: 6),
                  _RankDelta(delta: standing.rankDelta!),
                ],
              ],
            ),
          ),
          if (showLastRound && standing.lastRoundScore != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                standing.lastRoundScore == 0
                    ? '—'
                    : '+${standing.lastRoundScore}',
                style: AppTheme.tabular.merge(
                  theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Text(
            '${standing.total}',
            style: AppTheme.tabular.merge(
              theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankDelta extends StatelessWidget {
  const _RankDelta({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up = delta > 0;
    final color = up ? scheme.primary : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 18,
          color: color,
        ),
        Text(
          '${delta.abs()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
