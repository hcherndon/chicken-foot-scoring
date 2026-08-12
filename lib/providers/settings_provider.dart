import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/domino_set.dart';
import '../models/game_rules.dart';
import '../theme/app_palette.dart';

/// Preferences that outlive a single game: the theme, and the setup the new
/// game screen should pre-fill from last time.
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.palette = AppPalette.fallback,
    this.defaultRules = const GameRules(),
    this.lastPlayerNames = const [],
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final GameRules defaultRules;
  final List<String> lastPlayerNames;

  Settings copyWith({
    ThemeMode? themeMode,
    AppPalette? palette,
    GameRules? defaultRules,
    List<String>? lastPlayerNames,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
      defaultRules: defaultRules ?? this.defaultRules,
      lastPlayerNames: lastPlayerNames ?? this.lastPlayerNames,
    );
  }
}

const _kThemeMode = 'themeMode';
const _kPalette = 'palette';
const _kMaxDouble = 'rules.maxDouble';
const _kBlankEnabled = 'rules.doubleBlankEnabled';
const _kBlankPenalty = 'rules.doubleBlankPenalty';
const _kEndDoubleEnabled = 'rules.endOnDoubleEnabled';
const _kEndDoublePenalty = 'rules.endOnDoublePenalty';
const _kPlayerNames = 'lastPlayerNames';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<Settings> {
  late SharedPreferences _prefs;

  @override
  Future<Settings> build() async {
    _prefs = await SharedPreferences.getInstance();
    const fallback = GameRules();
    return Settings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_kThemeMode),
        orElse: () => ThemeMode.system,
      ),
      palette: AppPalette.byName(_prefs.getString(_kPalette)),
      defaultRules: GameRules(
        set: DominoSet.fromMaxDouble(
          _prefs.getInt(_kMaxDouble) ?? fallback.set.maxDouble,
        ),
        doubleBlankPenaltyEnabled: _prefs.getBool(_kBlankEnabled) ??
            fallback.doubleBlankPenaltyEnabled,
        doubleBlankPenalty:
            _prefs.getInt(_kBlankPenalty) ?? fallback.doubleBlankPenalty,
        endOnDoublePenaltyEnabled: _prefs.getBool(_kEndDoubleEnabled) ??
            fallback.endOnDoublePenaltyEnabled,
        endOnDoublePenalty:
            _prefs.getInt(_kEndDoublePenalty) ?? fallback.endOnDoublePenalty,
      ),
      lastPlayerNames: _prefs.getStringList(_kPlayerNames) ?? const [],
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
    state = AsyncData((state.valueOrNull ?? const Settings()).copyWith(
      themeMode: mode,
    ));
  }

  Future<void> setPalette(AppPalette palette) async {
    await _prefs.setString(_kPalette, palette.name);
    state = AsyncData((state.valueOrNull ?? const Settings()).copyWith(
      palette: palette,
    ));
  }

  /// Remembers the setup of the game just started, so the next new game screen
  /// opens ready to go with the same table.
  Future<void> rememberSetup(GameRules rules, List<String> playerNames) async {
    await Future.wait([
      _prefs.setInt(_kMaxDouble, rules.set.maxDouble),
      _prefs.setBool(_kBlankEnabled, rules.doubleBlankPenaltyEnabled),
      _prefs.setInt(_kBlankPenalty, rules.doubleBlankPenalty),
      _prefs.setBool(_kEndDoubleEnabled, rules.endOnDoublePenaltyEnabled),
      _prefs.setInt(_kEndDoublePenalty, rules.endOnDoublePenalty),
      _prefs.setStringList(_kPlayerNames, playerNames),
    ]);
    state = AsyncData((state.valueOrNull ?? const Settings()).copyWith(
      defaultRules: rules,
      lastPlayerNames: playerNames,
    ));
  }
}
