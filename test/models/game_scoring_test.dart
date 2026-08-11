import 'package:chicken_foot/models/domino_set.dart';
import 'package:chicken_foot/models/game.dart';
import 'package:chicken_foot/models/game_rules.dart';
import 'package:chicken_foot/models/player.dart';
import 'package:chicken_foot/models/round.dart';
import 'package:chicken_foot/models/round_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final _players = [
  const Player(id: 'a', name: 'Ann', seatOrder: 0),
  const Player(id: 'b', name: 'Bo', seatOrder: 1),
  const Player(id: 'c', name: 'Cy', seatOrder: 2),
];

Game _game({GameRules rules = const GameRules(set: DominoSet.double6)}) => Game(
      id: 'g',
      createdAt: DateTime(2026),
      rules: rules,
      players: _players,
      rounds: const [],
    );

Round _round(int index, int startingDouble, List<RoundEntry> entries) => Round(
      index: index,
      startingDouble: startingDouble,
      entries: entries,
      completedAt: DateTime(2026, 1, index + 1),
    );

void main() {
  group('DominoSet', () {
    test('round count is one per double down to double-blank', () {
      expect(DominoSet.double6.roundCount, 7);
      expect(DominoSet.double9.roundCount, 10);
      expect(DominoSet.double12.roundCount, 13);
      expect(DominoSet.double15.roundCount, 16);
    });

    test('rounds step down from the highest double to zero', () {
      final set = DominoSet.double9;
      expect(set.startingDoubleFor(0), 9);
      expect(set.startingDoubleFor(1), 8);
      expect(set.startingDoubleFor(set.roundCount - 1), 0);
    });

    test('total pips matches the known set totals', () {
      expect(DominoSet.double6.totalPips, 168);
      expect(DominoSet.double9.totalPips, 495);
      expect(DominoSet.double12.totalPips, 1092);
    });

    test('recommended hand sizes follow the customary double-9 table', () {
      expect(DominoSet.double9.recommendedHandSize(2), 21);
      expect(DominoSet.double9.recommendedHandSize(4), 11);
      expect(DominoSet.double9.recommendedHandSize(7), 6);
      expect(DominoSet.double9.recommendedHandSize(9), isNull);
    });
  });

  group('RoundEntry scoring', () {
    const rules = GameRules(
      set: DominoSet.double6,
      doubleBlankPenaltyEnabled: true,
      endOnDoublePenaltyEnabled: true,
    );

    test('counts pips left in hand', () {
      const entry = RoundEntry(playerId: 'a', pips: 17);
      expect(entry.totalUnder(rules), 17);
    });

    test('the player who goes out scores zero regardless of pips', () {
      const entry = RoundEntry(playerId: 'a', pips: 17, wentOut: true);
      expect(entry.totalUnder(rules), 0);
    });

    test('double-blank adds the penalty when the rule is on', () {
      const entry = RoundEntry(playerId: 'a', pips: 4, hadDoubleBlank: true);
      expect(entry.totalUnder(rules), 54);
    });

    test('double-blank costs nothing when the rule is off', () {
      const off = GameRules(
        set: DominoSet.double6,
        doubleBlankPenaltyEnabled: false,
      );
      const entry = RoundEntry(playerId: 'a', pips: 4, hadDoubleBlank: true);
      expect(entry.totalUnder(off), 4);
    });

    test('ending on a double adds the penalty when the rule is on', () {
      const entry = RoundEntry(playerId: 'a', wentOut: true, endedOnDouble: true);
      expect(entry.totalUnder(rules), 50);
    });

    test('ending on a double costs nothing when the rule is off', () {
      const off = GameRules(set: DominoSet.double6);
      const entry = RoundEntry(playerId: 'a', wentOut: true, endedOnDouble: true);
      expect(entry.totalUnder(off), 0);
    });

    test('both penalties stack', () {
      const entry = RoundEntry(
        playerId: 'a',
        pips: 3,
        hadDoubleBlank: true,
        endedOnDouble: true,
      );
      expect(entry.totalUnder(rules), 103);
    });
  });

  group('Game progression', () {
    test('starts on the highest double and steps down', () {
      var game = _game();
      expect(game.currentRoundIndex, 0);
      expect(game.currentStartingDouble, 6);

      game = game.withRound(_round(0, 6, const [
        RoundEntry(playerId: 'a', wentOut: true),
        RoundEntry(playerId: 'b', pips: 5),
        RoundEntry(playerId: 'c', pips: 9),
      ]));
      expect(game.currentRoundIndex, 1);
      expect(game.currentStartingDouble, 5);
      expect(game.isComplete, isFalse);
    });

    test('is complete after one round per double', () {
      var game = _game();
      for (var i = 0; i < DominoSet.double6.roundCount; i++) {
        game = game.withRound(_round(i, 6 - i, const [
          RoundEntry(playerId: 'a', wentOut: true),
          RoundEntry(playerId: 'b', pips: 2),
          RoundEntry(playerId: 'c', pips: 3),
        ]));
      }
      expect(game.isComplete, isTrue);
      expect(game.currentRoundIndex, isNull);
      expect(game.completedAt, isNotNull);
    });

    test('re-scoring a round replaces it instead of appending', () {
      var game = _game().withRound(_round(0, 6, const [
        RoundEntry(playerId: 'a', pips: 10),
        RoundEntry(playerId: 'b', pips: 5),
        RoundEntry(playerId: 'c', pips: 9),
      ]));
      game = game.withRound(_round(0, 6, const [
        RoundEntry(playerId: 'a', pips: 1),
        RoundEntry(playerId: 'b', pips: 5),
        RoundEntry(playerId: 'c', pips: 9),
      ]));
      expect(game.rounds, hasLength(1));
      expect(game.totalFor('a'), 1);
    });
  });

  group('Standings', () {
    test('accumulate across rounds, lowest first', () {
      var game = _game()
          .withRound(_round(0, 6, const [
            RoundEntry(playerId: 'a', pips: 12),
            RoundEntry(playerId: 'b', wentOut: true),
            RoundEntry(playerId: 'c', pips: 4),
          ]))
          .withRound(_round(1, 5, const [
            RoundEntry(playerId: 'a', pips: 3),
            RoundEntry(playerId: 'b', pips: 20),
            RoundEntry(playerId: 'c', wentOut: true),
          ]));

      expect(game.totalFor('a'), 15);
      expect(game.totalFor('b'), 20);
      expect(game.totalFor('c'), 4);

      final board = game.standings;
      expect([for (final s in board) s.player.id], ['c', 'a', 'b']);
      expect(board.first.total, 4);
      expect(board.first.lastRoundScore, 0);
      expect(game.leader!.id, 'c');
    });

    test('report ranks with ties sharing a position', () {
      final game = _game().withRound(_round(0, 6, const [
        RoundEntry(playerId: 'a', pips: 5),
        RoundEntry(playerId: 'b', pips: 5),
        RoundEntry(playerId: 'c', pips: 9),
      ]));
      final ranks = {for (final s in game.standings) s.player.id: s.rank};
      expect(ranks, {'a': 1, 'b': 1, 'c': 3});
      // A shared lead has no single leader.
      expect(game.leader, isNull);
    });

    test('track rank movement between rounds', () {
      final game = _game()
          .withRound(_round(0, 6, const [
            RoundEntry(playerId: 'a', pips: 30),
            RoundEntry(playerId: 'b', pips: 1),
            RoundEntry(playerId: 'c', pips: 10),
          ]))
          .withRound(_round(1, 5, const [
            RoundEntry(playerId: 'a', wentOut: true),
            RoundEntry(playerId: 'b', pips: 60),
            RoundEntry(playerId: 'c', pips: 5),
          ]));

      final byId = {for (final s in game.standings) s.player.id: s};
      // c: 15 (was rank 2, now 1), a: 30 (was 3, now 2), b: 61 (was 1, now 3)
      expect(byId['c']!.rank, 1);
      expect(byId['c']!.rankDelta, 1);
      expect(byId['b']!.rank, 3);
      expect(byId['b']!.rankDelta, -2);
    });

    test('standings can be replayed at an earlier round', () {
      final game = _game()
          .withRound(_round(0, 6, const [
            RoundEntry(playerId: 'a', pips: 1),
            RoundEntry(playerId: 'b', pips: 2),
            RoundEntry(playerId: 'c', pips: 3),
          ]))
          .withRound(_round(1, 5, const [
            RoundEntry(playerId: 'a', pips: 100),
            RoundEntry(playerId: 'b', pips: 0),
            RoundEntry(playerId: 'c', pips: 0),
          ]));
      expect(game.standingsAfterRound(1).first.player.id, 'a');
      expect(game.standings.first.player.id, 'b');
    });
  });

  group('Winner', () {
    Game playOut(List<int> perRoundPipsForA) {
      var game = _game();
      for (var i = 0; i < DominoSet.double6.roundCount; i++) {
        game = game.withRound(_round(i, 6 - i, [
          RoundEntry(playerId: 'a', pips: perRoundPipsForA[i]),
          const RoundEntry(playerId: 'b', pips: 5),
          const RoundEntry(playerId: 'c', pips: 5),
        ]));
      }
      return game;
    }

    test('is empty while the game is in progress', () {
      expect(_game().winners, isEmpty);
    });

    test('is the lowest total once complete', () {
      final game = playOut(const [0, 0, 0, 0, 0, 0, 0]);
      expect(game.winners.map((p) => p.id), ['a']);
    });

    test('includes everyone tied for lowest', () {
      final game = playOut(const [5, 5, 5, 5, 5, 5, 5]);
      expect(game.winners.map((p) => p.id).toSet(), {'a', 'b', 'c'});
    });
  });
}
