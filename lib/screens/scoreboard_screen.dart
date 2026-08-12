import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../providers/active_game_provider.dart';
import '../widgets/domino_tile.dart';
import '../widgets/score_grid.dart';
import '../widgets/standings_list.dart';
import 'game_summary_screen.dart';
import 'round_entry_screen.dart';

/// The home of a game in progress: where everyone stands, and the way into the
/// next round.
class ScoreboardScreen extends ConsumerWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
        actions: [
          if (active.valueOrNull != null)
            PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'abandon' => _abandon(context, ref),
                _ => null,
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'abandon',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Abandon game'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: active.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (game) {
          if (game == null) {
            return const Center(child: Text('No game in progress.'));
          }
          return _ScoreboardBody(game: game);
        },
      ),
    );
  }

  Future<void> _abandon(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon this game?'),
        content: const Text('Every round scored so far is deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(activeGameProvider.notifier).abandon();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ScoreboardBody extends StatelessWidget {
  const _ScoreboardBody({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final standings = _Standings(game: game);
        final grid = _Grid(game: game);

        if (wide) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 10, 20),
                        child: standings,
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(10, 12, 20, 20),
                        child: grid,
                      ),
                    ),
                  ],
                ),
              ),
              _NextRoundBar(game: game),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  standings,
                  const SizedBox(height: 24),
                  grid,
                ],
              ),
            ),
            _NextRoundBar(game: game),
          ],
        );
      },
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Standings',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                'Lowest wins',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StandingsList(standings: game.standings),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Score sheet',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (game.hasStarted)
              Flexible(
                child: Text(
                  'Tap a column to fix it',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ScoreGrid(
          game: game,
          onTapRound: (index) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoundEntryScreen(roundIndex: index),
            ),
          ),
        ),
      ],
    );
  }
}

/// The single call to action, pinned to the bottom.
class _NextRoundBar extends StatelessWidget {
  const _NextRoundBar({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roundIndex = game.currentRoundIndex;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          // heightFactor keeps this sized to its child; a bare Center would
          // expand to fill the scaffold and squeeze the body to nothing.
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: roundIndex == null
                  ? FilledButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => GameSummaryScreen(game: game),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_rounded),
                      label: const Text('See results'),
                    )
                  : Row(
                      children: [
                        DominoTile(
                          value: game.nextStartingDouble ?? 0,
                          height: 44,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RoundEntryScreen(roundIndex: roundIndex),
                              ),
                            ),
                            child: Text(
                              'Score round ${roundIndex + 1} '
                              'of ${game.rules.roundCount}',
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
