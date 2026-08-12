import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import '../models/round_entry.dart';
import '../providers/active_game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/domino_tile.dart';
import '../widgets/pip_field.dart';
import 'game_summary_screen.dart';

/// Scores one round: pips left in every hand, plus who went out.
///
/// Also used to correct an already-scored round — pass its index and the
/// existing values load in.
class RoundEntryScreen extends ConsumerStatefulWidget {
  const RoundEntryScreen({super.key, required this.roundIndex});

  final int roundIndex;

  @override
  ConsumerState<RoundEntryScreen> createState() => _RoundEntryScreenState();
}

class _RoundEntryScreenState extends ConsumerState<RoundEntryScreen> {
  final _controllers = <String, TextEditingController>{};
  final _focusNodes = <String, FocusNode>{};
  var _entries = <RoundEntry>[];
  var _initialised = false;
  var _saving = false;

  /// The double this round opened on. Seeded from the natural next double and
  /// stepped down when nobody held it.
  late int _startingDouble;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _initialise(Game game) {
    if (_initialised) return;
    _initialised = true;

    final existing = game.rounds
        .where((r) => r.index == widget.roundIndex)
        .firstOrNull;

    _startingDouble = existing?.startingDouble ??
        game.nextStartingDouble ??
        game.rules.set.maxDouble;

    _entries = [
      for (final player in game.players)
        existing?.entryFor(player.id) ?? RoundEntry(playerId: player.id),
    ];
    for (final entry in _entries) {
      _controllers[entry.playerId] = TextEditingController(
        text: entry.pips == 0 ? '' : '${entry.pips}',
      );
      _focusNodes[entry.playerId] = FocusNode();
    }
  }

  /// Applies a change, keeping "went out" exclusive: only one player can empty
  /// their hand, and doing so zeroes their pip field.
  void _update(RoundEntry updated) {
    setState(() {
      final claimedWentOut = updated.wentOut &&
          !_entries
              .firstWhere((e) => e.playerId == updated.playerId)
              .wentOut;

      _entries = [
        for (final entry in _entries)
          if (entry.playerId == updated.playerId)
            updated.wentOut ? updated.copyWith(pips: 0) : updated
          else if (claimedWentOut && entry.wentOut)
            entry.copyWith(wentOut: false)
          else
            entry,
      ];

      if (updated.wentOut) {
        _controllers[updated.playerId]!.clear();
      }
    });
  }

  Future<void> _save(Game game) async {
    if (_saving) return;
    final maxPips = game.rules.set.totalPips;
    final overflowing = _entries.where((e) => e.pips > maxPips).toList();
    if (overflowing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A ${game.rules.set.label} set only has $maxPips pips in total — '
            'check ${game.playerById(overflowing.first.playerId).name}.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(activeGameProvider.notifier)
          .submitRound(
            widget.roundIndex,
            _entries,
            startingDouble: _startingDouble,
          );
      if (!mounted) return;
      if (updated.isComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GameSummaryScreen(game: updated)),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the round: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final game = ref.watch(activeGameProvider).valueOrNull;

    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initialise(game);

    final isRescore = game.rounds.any(
      (r) => r.index == widget.roundIndex && r.isComplete,
    );
    // The opening double can only be changed for the round at the end of the
    // sheet: rewriting an earlier one would strand every round after it.
    final latestIndex = game.completedRounds.isEmpty
        ? -1
        : game.completedRounds.last.index;
    final canChooseDouble = game.rules.skipUnheldDoubles &&
        (widget.roundIndex >= latestIndex);
    final highestOpenable = game.highestOpenableFor(widget.roundIndex);
    final nobodyWentOut = !_entries.any((e) => e.wentOut);

    return Scaffold(
      appBar: AppBar(title: Text('Round ${widget.roundIndex + 1}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _OpeningDouble(
                value: _startingDouble,
                highestOpenable: highestOpenable,
                editable: canChooseDouble,
                burned: [
                  for (var d = highestOpenable; d > _startingDouble; d--) d,
                ],
                onBurn: () => setState(() => _startingDouble--),
                onRestore: () => setState(() => _startingDouble++),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter the pips left in each hand. The player who went out '
                'scores nothing.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final (index, entry) in _entries.indexed)
                PipField(
                  player: game.playerById(entry.playerId),
                  entry: entry,
                  rules: game.rules,
                  controller: _controllers[entry.playerId]!,
                  focusNode: _focusNodes[entry.playerId]!,
                  onChanged: _update,
                  textInputAction: index == _entries.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: () {
                    if (index < _entries.length - 1) {
                      _focusNodes[_entries[index + 1].playerId]!.requestFocus();
                    } else {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              if (nobodyWentOut)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nobody marked as going out — fine if the round '
                          'ended blocked.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          // heightFactor keeps this sized to its child; a bare Center would
          // expand to fill the scaffold and squeeze the body to nothing.
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Round total: '
                    '${_entries.fold(0, (sum, e) => sum + e.totalUnder(game.rules))}',
                    style: AppTheme.tabular.merge(
                      theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(game),
                      icon: Icon(
                        isRescore ? Icons.save_rounded : Icons.check_rounded,
                      ),
                      label: Text(
                        isRescore ? 'Update round' : 'Save round',
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

/// The double this round opened on, with a way to burn it when it turns out
/// nobody holds it.
class _OpeningDouble extends StatelessWidget {
  const _OpeningDouble({
    required this.value,
    required this.highestOpenable,
    required this.editable,
    required this.burned,
    required this.onBurn,
    required this.onRestore,
  });

  final int value;

  /// The highest double this round could have opened on.
  final int highestOpenable;

  final bool editable;

  /// Doubles stepped past on the way down to [value], highest first.
  final List<int> burned;

  final VoidCallback onBurn;
  final VoidCallback onRestore;

  bool get _isFinalRound => value == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DominoTile(value: value, height: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opened on the double-$value',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isFinalRound
                          ? 'Final round — the double-blank is always played, '
                              'drawn for if need be.'
                          : burned.isEmpty
                              ? 'Somebody held it.'
                              : 'Burned ${burned.join(', ')} — nobody held '
                                  '${burned.length == 1 ? 'it' : 'them'}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (editable && !(_isFinalRound && burned.isEmpty)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_isFinalRound)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBurn,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      label: Text(
                        'Nobody had the $value — open on ${value - 1}',
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                if (value < highestOpenable) ...[
                  if (!_isFinalRound) const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Put the ${value + 1} back',
                    onPressed: onRestore,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
