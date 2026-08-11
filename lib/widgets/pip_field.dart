import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_rules.dart';
import '../models/player.dart';
import '../models/round_entry.dart';
import '../theme/app_theme.dart';

/// One player's row on the round-entry screen: pips left in hand, whether they
/// went out, and any penalties that applied.
class PipField extends StatelessWidget {
  const PipField({
    super.key,
    required this.player,
    required this.entry,
    required this.rules,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final Player player;
  final RoundEntry entry;
  final GameRules rules;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<RoundEntry> onChanged;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wentOut = entry.wentOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: wentOut
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !wentOut,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textAlign: TextAlign.center,
                  textInputAction: textInputAction,
                  onSubmitted: (_) => onSubmitted?.call(),
                  onChanged: (value) => onChanged(
                    entry.copyWith(pips: int.tryParse(value) ?? 0),
                  ),
                  style: AppTheme.tabular.merge(
                    theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  decoration: InputDecoration(
                    hintText: wentOut ? '0' : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Toggle(
                label: 'Went out',
                icon: Icons.flag_rounded,
                selected: wentOut,
                onChanged: (value) =>
                    onChanged(entry.copyWith(wentOut: value)),
              ),
              if (rules.doubleBlankPenaltyEnabled)
                _Toggle(
                  label: 'Held 0–0  +${rules.doubleBlankPenalty}',
                  selected: entry.hadDoubleBlank,
                  onChanged: (value) =>
                      onChanged(entry.copyWith(hadDoubleBlank: value)),
                ),
              if (rules.endOnDoublePenaltyEnabled)
                _Toggle(
                  label: 'Ended on a double  +${rules.endOnDoublePenalty}',
                  selected: entry.endedOnDouble,
                  onChanged: (value) =>
                      onChanged(entry.copyWith(endedOnDouble: value)),
                ),
            ],
          ),
          if (entry.penaltyUnder(rules) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Scores ${entry.totalUnder(rules)} this round',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18),
      selected: selected,
      showCheckmark: icon == null,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
    );
  }
}
