import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../providers/active_game_provider.dart';
import '../widgets/domino_tile.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';
import 'scoreboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = ref.watch(activeGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chicken Foot'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final value in [9, 6, 0])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: DominoTile(value: value, height: 72),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Keep score, not paper.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One round per double, highest to blank. Lowest total wins.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                active.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Text('Could not load saved games: $error'),
                  data: (game) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (game != null) ...[
                        _ResumeCard(game: game),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: () => _newGame(context, ref, game),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New game'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newGame(
    BuildContext context, WidgetRef ref, Game? active) async {
    if (active != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abandon the game in progress?'),
          content: Text(
            'The game with ${active.players.map((p) => p.name).join(', ')} '
            'has not finished. Starting a new one deletes it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep playing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abandon it'),
            ),
          ],
        ),
      );
      if (discard != true) return;
      await ref.read(activeGameProvider.notifier).abandon();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewGameScreen()),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roundIndex = game.currentRoundIndex;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (game.nextStartingDouble != null)
                DominoTile(value: game.nextStartingDouble!, height: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue game',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roundIndex == null
                          ? 'Ready to finish'
                          : 'Round ${roundIndex + 1} of '
                              '${game.rules.roundCount} · on the '
                              '${game.nextStartingDouble}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
