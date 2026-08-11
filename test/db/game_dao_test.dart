import 'package:chicken_foot/db/database.dart';
import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/models/game.dart';
import 'package:chicken_foot/models/game_rules.dart';
import 'package:chicken_foot/models/player.dart';
import 'package:chicken_foot/models/round.dart';
import 'package:chicken_foot/models/round_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Game sample({DateTime? completedAt}) => Game(
        id: 'g1',
        createdAt: DateTime(2026, 8, 11, 12),
        completedAt: completedAt,
        rules: const GameRules(
          set: DominoSet.double6,
          endOnDoublePenaltyEnabled: true,
        ),
        players: const [
          Player(id: 'p1', name: 'Ann', seatOrder: 0),
          Player(id: 'p2', name: 'Bo', seatOrder: 1),
        ],
        rounds: [
          Round(
            index: 0,
            startingDouble: 6,
            completedAt: DateTime(2026, 8, 11, 12, 30),
            entries: const [
              RoundEntry(playerId: 'p1', wentOut: true, endedOnDouble: true),
              RoundEntry(playerId: 'p2', pips: 14, hadDoubleBlank: true),
            ],
          ),
        ],
      );

  test('round-trips a game with its rules, players and rounds', () async {
    await db.gameDao.save(sample());
    final loaded = await db.gameDao.load('g1');

    expect(loaded, isNotNull);
    expect(loaded!.rules.set, DominoSet.double6);
    expect(loaded.rules.endOnDoublePenaltyEnabled, isTrue);
    expect(loaded.rules.doubleBlankPenaltyEnabled, isTrue);
    expect([for (final p in loaded.players) p.name], ['Ann', 'Bo']);

    final round = loaded.rounds.single;
    expect(round.startingDouble, 6);
    expect(round.isComplete, isTrue);
    expect(round.entryFor('p1')!.endedOnDouble, isTrue);
    expect(round.entryFor('p2')!.pips, 14);
    // 14 pips + 50 double-blank; p1 went out but ate the end-on-double penalty.
    expect(loaded.totalFor('p2'), 64);
    expect(loaded.totalFor('p1'), 50);
  });

  test('saving again replaces rounds rather than duplicating them', () async {
    final game = sample();
    await db.gameDao.save(game);

    final withSecondRound = game.withRound(
      Round(
        index: 1,
        startingDouble: 5,
        completedAt: DateTime(2026, 8, 11, 13),
        entries: const [
          RoundEntry(playerId: 'p1', pips: 3),
          RoundEntry(playerId: 'p2', wentOut: true),
        ],
      ),
    );
    await db.gameDao.save(withSecondRound);

    final loaded = await db.gameDao.load('g1');
    expect(loaded!.rounds, hasLength(2));
    expect(loaded.rounds.map((r) => r.index), [0, 1]);
    expect(await db.select(db.roundEntries).get(), hasLength(4));
  });

  test('loadActive finds the unfinished game and ignores finished ones',
      () async {
    await db.gameDao.save(sample(completedAt: DateTime(2026, 8, 10)));
    expect(await db.gameDao.loadActive(), isNull);

    final inProgress = Game(
      id: 'g2',
      createdAt: DateTime(2026, 8, 11, 18),
      rules: const GameRules(),
      players: const [Player(id: 'p9', name: 'Cy', seatOrder: 0)],
      rounds: const [],
    );
    await db.gameDao.save(inProgress);

    final active = await db.gameDao.loadActive();
    expect(active!.id, 'g2');
  });

  test('watchCompleted emits only finished games', () async {
    await db.gameDao.save(sample());
    expect(await db.gameDao.watchCompleted().first, isEmpty);

    await db.gameDao.save(sample(completedAt: DateTime(2026, 8, 11, 14)));
    final completed = await db.gameDao.watchCompleted().first;
    expect(completed.map((g) => g.id), ['g1']);
  });

  test('deleting a game cascades to its players, rounds and entries', () async {
    await db.gameDao.save(sample());
    await db.gameDao.deleteGame('g1');

    expect(await db.gameDao.load('g1'), isNull);
    expect(await db.select(db.players).get(), isEmpty);
    expect(await db.select(db.rounds).get(), isEmpty);
    expect(await db.select(db.roundEntries).get(), isEmpty);
  });

  test('entries come back in seat order regardless of insert order', () async {
    final game = sample().copyWith(
      rounds: [
        Round(
          index: 0,
          startingDouble: 6,
          completedAt: DateTime(2026, 8, 11, 12, 30),
          entries: const [
            RoundEntry(playerId: 'p2', pips: 4),
            RoundEntry(playerId: 'p1', pips: 9),
          ],
        ),
      ],
    );
    await db.gameDao.save(game);

    final loaded = await db.gameDao.load('g1');
    expect(
      [for (final e in loaded!.rounds.single.entries) e.playerId],
      ['p1', 'p2'],
    );
  });
}
