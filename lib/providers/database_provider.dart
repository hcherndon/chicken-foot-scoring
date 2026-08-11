import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/game_dao.dart';

/// The single app-wide database handle. Overridden in tests with an in-memory
/// database via `ProviderScope(overrides: [...])`.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final gameDaoProvider = Provider<GameDao>((ref) {
  return ref.watch(databaseProvider).gameDao;
});
