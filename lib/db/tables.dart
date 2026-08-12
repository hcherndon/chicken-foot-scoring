import 'package:drift/drift.dart';

/// One game, plus the house rules it was played under. The rules are stored
/// per-game so a historical game always re-scores the way it was played.
@DataClassName('GameRow')
class Games extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// The set's highest double: 6, 9, 12 or 15.
  IntColumn get maxDouble => integer()();

  /// House rule: burn a double nobody holds and open on the next one down.
  BoolColumn get skipUnheldDoubles =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get doubleBlankPenaltyEnabled => boolean()();
  IntColumn get doubleBlankPenalty => integer()();
  BoolColumn get endOnDoublePenaltyEnabled => boolean()();
  IntColumn get endOnDoublePenalty => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlayerRow')
class Players extends Table {
  TextColumn get id => text()();
  TextColumn get gameId =>
      text().references(Games, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get seatOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoundRow')
class Rounds extends Table {
  TextColumn get id => text()();
  TextColumn get gameId =>
      text().references(Games, #id, onDelete: KeyAction.cascade)();

  /// Zero-based position in the game.
  IntColumn get roundIndex => integer()();

  /// The double this round opened on.
  IntColumn get startingDouble => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {gameId, roundIndex},
      ];
}

@DataClassName('RoundEntryRow')
class RoundEntries extends Table {
  TextColumn get id => text()();
  TextColumn get roundId =>
      text().references(Rounds, #id, onDelete: KeyAction.cascade)();
  TextColumn get playerId =>
      text().references(Players, #id, onDelete: KeyAction.cascade)();

  IntColumn get pips => integer().withDefault(const Constant(0))();
  BoolColumn get wentOut => boolean().withDefault(const Constant(false))();
  BoolColumn get hadDoubleBlank =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get endedOnDouble =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {roundId, playerId},
      ];
}
