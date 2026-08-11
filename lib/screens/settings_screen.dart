import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_game_provider.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'APPEARANCE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {settings.valueOrNull?.themeMode ?? ThemeMode.system},
                onSelectionChanged: (selection) => ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(selection.first),
              ),
              const SizedBox(height: 32),
              Text(
                'DATA',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: const Text('Delete all games'),
                  subtitle: const Text(
                    'Clears history and any game in progress. '
                    'Nothing leaves this device, and nothing is backed up.',
                  ),
                  onTap: () => _wipe(context, ref),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Scores are stored locally on this device only.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete every game?'),
        content: const Text(
          'All history and the game in progress are permanently removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(gameDaoProvider).deleteAll();
    ref.read(activeGameProvider.notifier).dismiss();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All games deleted.')),
    );
  }
}
