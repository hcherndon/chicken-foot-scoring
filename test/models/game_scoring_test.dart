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
      expect(game.nextStartingDouble, 6);

      game = game.withRound(_round(0, 6, const [
        RoundEntry(playerId: 'a', wentOut: true),
        RoundEntry(playerId: 'b', pips: 5),
        RoundEntry(playerId: 'c', pips: 9),
      ]));
      expect(game.currentRoundIndex, 1);
      expect(game.nextStartingDouble, 5);
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

  _skippingDoubles();
  _openingValidation();
}

void _skippingDoubles() {
  group('Skipping doubles nobody holds', () {
    Game gameWith(List<int> doubles, {bool skip = true}) {
      var game = _game(
        rules: GameRules(set: DominoSet.double6, skipUnheldDoubles: skip),
      );
      for (final (index, opening) in doubles.indexed) {
        game = game.withRound(_round(index, opening, const [
          RoundEntry(playerId: 'a', wentOut: true),
          RoundEntry(playerId: 'b', pips: 4),
          RoundEntry(playerId: 'c', pips: 6),
        ]));
      }
      return game;
    }

    test('a skipped double comes back for the next round', () {
      // Nobody held the 6, so round 1 opened on the 5.
      final game = gameWith([5]);
      // Round 2 tries the 6 again, not the 4.
      expect(game.nextStartingDouble, 6);
      expect(game.remainingDoubles, [6, 4, 3, 2, 1, 0]);
    });

    test('once the skipped double is played the pool moves on', () {
      // Round 1 opened on the 5, round 2 came back and got the 6.
      final game = gameWith([5, 6]);
      // Both are spent, so round 3 tries the 4.
      expect(game.nextStartingDouble, 4);
      expect(game.remainingDoubles, [4, 3, 2, 1, 0]);
    });

    test('the pool is what a round may open on, highest first', () {
      expect(gameWith([]).openableDoubles, [6, 5, 4, 3, 2, 1, 0]);
      expect(gameWith([5]).openableDoubles, [6, 4, 3, 2, 1, 0]);
      expect(gameWith([5, 6]).openableDoubles, [4, 3, 2, 1, 0]);
    });

    test('offers only the highest remaining double when the rule is off', () {
      expect(gameWith([], skip: false).openableDoubles, [6]);
      expect(gameWith([6], skip: false).openableDoubles, [5]);
    });

    test('every double is played exactly once, so the count is fixed', () {
      final game = gameWith([5, 6, 3, 4, 0, 2, 1]);
      expect(game.completedRounds, hasLength(7));
      expect(game.isComplete, isTrue);
      expect(game.completedAt, isNotNull);
      expect(game.remainingDoubles, isEmpty);
      expect(game.nextStartingDouble, isNull);
      expect(game.currentRoundIndex, isNull);
    });

    test('is not finished while any double is still unplayed', () {
      // Six rounds in, but the 6 was skipped early and never came back.
      final game = gameWith([5, 4, 3, 2, 1, 0]);
      expect(game.completedRounds, hasLength(6));
      expect(game.isComplete, isFalse);
      expect(game.remainingDoubles, [6]);
      expect(game.nextStartingDouble, 6);
    });

    test('playing the blank early does not end the game', () {
      final game = gameWith([0]);
      expect(game.isComplete, isFalse);
      expect(game.nextStartingDouble, 6);
      expect(game.remainingDoubles, [6, 5, 4, 3, 2, 1]);
    });

    test('the last double left cannot be skipped past', () {
      final game = gameWith([6, 5, 4, 3, 2, 1]);
      expect(game.openableDoubles, [0]);
      expect(game.remainingRounds, 1);
    });

    test('counts the rounds still to play', () {
      expect(gameWith([]).remainingRounds, 7);
      expect(gameWith([5]).remainingRounds, 6);
      expect(gameWith([5, 6, 4]).remainingRounds, 4);
    });

    test('reports the doubles a round passed over on its way down', () {
      final game = gameWith([4, 6]);
      // Round 1 tried the 6 and the 5 before settling on the 4.
      expect(game.skippedIn(game.completedRounds[0]), [6, 5]);
      // Round 2 came back and got the 6 first time.
      expect(game.skippedIn(game.completedRounds[1]), isEmpty);
    });

    test('a round that took the top double skipped nothing', () {
      final game = gameWith([6, 5]);
      expect(game.skippedIn(game.completedRounds[0]), isEmpty);
      expect(game.skippedIn(game.completedRounds[1]), isEmpty);
    });
  });
}

void _openingValidation() {
  group('Legal opening doubles', () {
    Game gameWith(List<int> doubles, {bool skip = true}) {
      var game = _game(
        rules: GameRules(set: DominoSet.double6, skipUnheldDoubles: skip),
      );
      for (final (index, opening) in doubles.indexed) {
        game = game.withRound(_round(index, opening, const [
          RoundEntry(playerId: 'a', wentOut: true),
          RoundEntry(playerId: 'b', pips: 4),
          RoundEntry(playerId: 'c', pips: 6),
        ]));
      }
      return game;
    }

    test('accepts any double still in the pool', () {
      final game = gameWith([]);
      for (var d = 6; d >= 0; d--) {
        expect(game.canOpenRoundOn(0, d), isTrue, reason: 'double $d');
      }
    });

    test('refuses a double another round already took', () {
      final game = gameWith([4]);
      expect(game.canOpenRoundOn(1, 4), isFalse);
      expect(game.canOpenRoundOn(1, 6), isTrue);
      expect(game.canOpenRoundOn(1, 0), isTrue);
    });

    test('refuses a double outside the set', () {
      expect(gameWith([]).canOpenRoundOn(0, -1), isFalse);
      expect(gameWith([]).canOpenRoundOn(0, 7), isFalse);
    });

    test('refuses a round index that would leave a gap', () {
      final game = gameWith([6]);
      expect(game.canOpenRoundOn(1, 5), isTrue);
      expect(game.canOpenRoundOn(2, 5), isFalse);
      expect(game.canOpenRoundOn(-1, 5), isFalse);
    });

    test('lets a played round move to any double still free', () {
      final game = gameWith([5, 6]);
      // Round 0 can go back to its own double, or take any unplayed one.
      expect(game.canOpenRoundOn(0, 5), isTrue);
      expect(game.canOpenRoundOn(0, 4), isTrue);
      // But not the one round 1 is sitting on.
      expect(game.canOpenRoundOn(0, 6), isFalse);
    });

    test('refuses any double but the highest under strict rules', () {
      final game = gameWith([6], skip: false);
      expect(game.canOpenRoundOn(1, 5), isTrue);
      expect(game.canOpenRoundOn(1, 4), isFalse);
      expect(game.canOpenRoundOn(1, 0), isFalse);
    });

    test('refuses another round once every double is spent', () {
      final game = gameWith([6, 5, 4, 3, 2, 1, 0]);
      expect(game.canOpenRoundOn(7, 0), isFalse);
    });
  });
}
