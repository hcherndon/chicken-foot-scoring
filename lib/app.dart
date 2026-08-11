import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class ChickenFootApp extends ConsumerWidget {
  const ChickenFootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Settings load from disk in a few milliseconds; fall back to the system
    // theme for that first frame rather than flashing a loading screen.
    final themeMode = ref.watch(
      settingsProvider.select(
        (s) => s.valueOrNull?.themeMode ?? ThemeMode.system,
      ),
    );

    return MaterialApp(
      title: 'Chicken Foot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
