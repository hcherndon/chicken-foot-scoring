# Chicken Foot

A score keeper for the domino game [Chicken Foot](https://en.wikipedia.org/wiki/Chickenfoot_(domino_game)) — one Flutter codebase, native builds for macOS, iOS, Android, Windows, Linux and the web.

It replaces the pencil-and-paper score sheet. You play the dominoes; the app tracks the round progression, the running totals, the penalties, and who won.

## How scoring works

A game is one round per double, counting down from the set's highest double to the double-blank — 7 rounds on a double-6 set, 10 on a double-9, 13 on a double-12, 16 on a double-15.

At the end of each round you enter the pips left in each player's hand. The player who went out scores nothing. **Lowest total after the final round wins.**

Two optional house rules, set per game:

| Rule | Effect | Default |
| --- | --- | --- |
| Double-blank penalty | Holding the 0–0 when the round ends costs 50 | On |
| Ending on a double | Going out on a double costs 50 | Off |

The rules are stored with each game, so a game in history always re-scores exactly the way it was played.

## Running it

```sh
flutter pub get
dart run build_runner build      # generates the drift database code
flutter run -d macos             # or: chrome, windows, linux, or a device id
```

`flutter devices` lists what's available.

### Building releases

```sh
flutter build macos              # requires Xcode
flutter build ipa                # requires Xcode
flutter build apk                # or: appbundle
flutter build windows            # must run on Windows
flutter build linux              # must run on Linux
flutter build web
```

Desktop binaries can only be produced on their own OS. The GitHub Actions workflow in `.github/workflows/build.yml` builds macOS, Linux, Windows, Android and web on every push.

## Tests

```sh
flutter analyze
flutter test
```

- `test/models/` — scoring rules: penalties, ties, round progression, winner selection.
- `test/db/` — SQLite round-trips, cascading deletes, resuming an unfinished game.
- `test/widget/` — round entry behaviour, and a full game played through the real widget tree.

## How it's built

```
lib/
  models/      pure Dart, no Flutter imports — all scoring lives here
  db/          drift (SQLite) tables, DAO, migrations
  providers/   Riverpod: active game, history, settings
  screens/     home, new game, scoreboard, round entry, results, history, settings
  widgets/     standings list, score grid, pip entry, domino tile
```

Scoring is deliberately kept out of the database and the UI: `Game`, `Round` and `RoundEntry` are immutable value types, so the rules can be tested without either.

Every round is written to SQLite the moment it is saved, so quitting mid-game loses nothing — the home screen offers to pick up where you left off.

**Data stays on the device.** There is no account, no sync, and no backup. Deleting the app deletes the history with it.
