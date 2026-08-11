import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../providers/database_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'game_summary_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (games) {
          if (games.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No finished games yet',
              message: 'Games show up here once the final round is scored.',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: games.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _HistoryCard(
                  game: games[index],
                  onDelete: () => ref
                      .read(gameDaoProvider)
                      .deleteGame(games[index].id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.game, required this.onDelete});

  final Game game;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final winners = game.winners;
    final board = game.standings;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameSummaryScreen(game: game, readOnly: true),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      winners.map((p) => p.name).join(' & '),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (board.isNotEmpty)
                    Text(
                      '${board.first.total}',
                      style: AppTheme.tabular.merge(
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${game.players.length} players · ${game.rules.set.label} · '
                '${DateFormat.yMMMd().add_jm().format(game.completedAt ?? game.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [for (final s in board) '${s.player.name} ${s.total}'].join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this game?'),
        content: const Text('It will be removed from history for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}
