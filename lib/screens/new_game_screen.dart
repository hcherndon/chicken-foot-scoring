import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/domino_set.dart';
import '../models/game_rules.dart';
import '../providers/active_game_provider.dart';
import '../providers/settings_provider.dart';
import 'scoreboard_screen.dart';

const _minPlayers = 2;
const _maxPlayers = 12;

class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  final _controllers = <TextEditingController>[];
  final _focusNodes = <FocusNode>[];
  GameRules _rules = const GameRules();
  bool _starting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Seeds the roster from the last game played, the first time settings land.
  void _prefillOnce(Settings settings) {
    if (_prefilled) return;
    _prefilled = true;
    _rules = settings.defaultRules;
    final names = settings.lastPlayerNames.isEmpty
        ? const ['', '']
        : settings.lastPlayerNames;
    for (final name in names) {
      _addSeat(name, focus: false);
    }
  }

  void _addSeat(String name, {bool focus = true}) {
    _controllers.add(TextEditingController(text: name));
    _focusNodes.add(FocusNode());
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.last.requestFocus();
      });
    }
  }

  void _removeSeat(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
      _focusNodes.removeAt(index).dispose();
    });
  }

  List<String> get _names {
    return [
      for (final (index, c) in _controllers.indexed)
        c.text.trim().isEmpty ? 'Player ${index + 1}' : c.text.trim(),
    ];
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final names = _names;
    try {
      await ref
          .read(activeGameProvider.notifier)
          .start(rules: _rules, playerNames: names);
      await ref.read(settingsProvider.notifier).rememberSetup(_rules, names);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start the game: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    settings.whenData(_prefillOnce);
    if (!_prefilled) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final playerCount = _controllers.length;
    final handSize = _rules.set.recommendedHandSize(playerCount);

    return Scaffold(
      appBar: AppBar(title: const Text('New game')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              _SectionLabel('Players'),
              for (var i = 0; i < playerCount; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textCapitalization: TextCapitalization.words,
                          textInputAction: i == playerCount - 1
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: (_) {
                            if (i < playerCount - 1) {
                              _focusNodes[i + 1].requestFocus();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Player ${i + 1}',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: playerCount > _minPlayers
                            ? () => _removeSeat(i)
                            : null,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: playerCount < _maxPlayers
                      ? () => setState(() => _addSeat(''))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add player'),
                ),
              ),

              const SizedBox(height: 20),
              _SectionLabel('Domino set'),
              SegmentedButton<DominoSet>(
                segments: [
                  for (final set in DominoSet.values)
                    ButtonSegment(
                      value: set,
                      label: Text('${set.maxDouble}'),
                      tooltip: '${set.label} · ${set.roundCount} rounds',
                    ),
                ],
                selected: {_rules.set},
                onSelectionChanged: (selection) =>
                    setState(() => _rules = _rules.copyWith(set: selection.first)),
              ),
              const SizedBox(height: 10),
              Text(
                '${_rules.set.label} · ${_rules.set.tileCount} dominoes · '
                '${_rules.roundCount} rounds'
                '${handSize == null ? '' : ' · deal $handSize each'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (handSize == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$playerCount players is a stretch for this set — '
                    'a larger set deals more comfortably.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              _SectionLabel('House rules'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _rules.doubleBlankPenaltyEnabled,
                      onChanged: (value) => setState(() => _rules =
                          _rules.copyWith(doubleBlankPenaltyEnabled: value)),
                      title: const Text('Double-blank penalty'),
                      subtitle: Text(
                        'Holding the 0–0 at the end of a round costs '
                        '${_rules.doubleBlankPenalty} points',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: _rules.endOnDoublePenaltyEnabled,
                      onChanged: (value) => setState(() => _rules =
                          _rules.copyWith(endOnDoublePenaltyEnabled: value)),
                      title: const Text('Ending on a double'),
                      subtitle: Text(
                        'Going out on a double costs '
                        '${_rules.endOnDoublePenalty} points',
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
              child: FilledButton.icon(
                onPressed: _starting ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start · ${_rules.roundCount} rounds'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
