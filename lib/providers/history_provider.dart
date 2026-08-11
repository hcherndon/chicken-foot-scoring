import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import 'database_provider.dart';

/// Finished games, newest first.
final historyProvider = StreamProvider<List<Game>>((ref) {
  return ref.watch(gameDaoProvider).watchCompleted();
});
