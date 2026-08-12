import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../providers/active_game_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/score_grid.dart';
import '../widgets/standings_list.dart';
import 'round_entry_screen.dart';
import 'scoreboard_screen.dart';

/// The end of a game — or a read-only look at one from history.
class GameSummaryScreen extends ConsumerWidget {
  const GameSummaryScreen({
    super.key,
    required this.game,
    this.readOnly = false,
  });

  final Game game;

  /// Opened from history: no rematch, no clearing the active slot.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // For a game that is still the active one, follow the provider so a round
    // corrected from here redraws instead of showing a stale snapshot.
    final live = readOnly ? null : ref.watch(activeGameProvider).valueOrNull;
    final game = live?.id == this.game.id ? live! : this.game;
    final winners = game.winners;
    final burned = game.burnedDoubles;

    return Scaffold(
      appBar: AppBar(
        title: Text(readOnly ? 'Game' : 'Results'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 40,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      switch (winners.length) {
                        0 => 'Unfinished',
                        1 => '${winners.single.name} wins',
                        _ =>
                          '${winners.map((p) => p.name).join(' & ')} tie for the win',
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (winners.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'with ${game.standings.first.total} points',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${game.rules.set.label} · '
                      '${game.completedRounds.length} rounds'
                      '${burned.isEmpty ? '' : ' · burned ${burned.join(', ')}'}'
                      ' · ${DateFormat.yMMMd().format(game.createdAt)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              StandingsList(
                standings: game.standings,
                showLastRound: false,
                highlightLeader: false,
              ),
              const SizedBox(height: 24),
              ScoreGrid(
                game: game,
                onTapRound: readOnly
                    ? null
                    : (index) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoundEntryScreen(roundIndex: index),
                          ),
                        ),
              ),
              const SizedBox(height: 24),
              if (!readOnly) ...[
                FilledButton.icon(
                  onPressed: () => _rematch(context, ref),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Rematch'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    ref.read(activeGameProvider.notifier).dismiss();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Starts a fresh game with the same table and the same rules.
  Future<void> _rematch(BuildContext context, WidgetRef ref) async {
    final names = [for (final p in game.players) p.name];
    await ref
        .read(activeGameProvider.notifier)
        .start(rules: game.rules, playerNames: names);
    await ref.read(settingsProvider.notifier).rememberSetup(game.rules, names);
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
    );
  }
}
