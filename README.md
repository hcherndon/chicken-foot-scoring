# Chicken Foot

A score keeper for the domino game [Chicken Foot](https://en.wikipedia.org/wiki/Chickenfoot_(domino_game)) — one Flutter codebase, native builds for macOS, iOS, Android, Windows, Linux and the web.

It replaces the pencil-and-paper score sheet. You play the dominoes; the app tracks the round progression, the running totals, the penalties, and who won.

## How scoring works

Every double in the set gets exactly one round — 7 rounds on a double-6 set, 10 on a double-9, 13 on a double-12, 16 on a double-15.

At the end of each round you enter the pips left in each player's hand. The player who went out scores nothing. **Lowest total once every double has been played wins.**

### Skipping doubles nobody holds

By default the app plays the house rule: a round tries the highest double that has not been played yet, and if nobody can open on it, it drops to the next one down.

The skipped double is **not** spent. It goes back in the pool, and the next round goes looking for it again first:

| Round | Tries | Result |
| --- | --- | --- |
| 1 | 9 | nobody holds it → drops to the 8 and plays it |
| 2 | 9 | somebody holds it this time → plays the 9 |
| 3 | 7 | the 9 and 8 are both spent, so the ladder moves on |

So the doubles come out of order, but every one of them still gets its round and the game is the same length either way. The one that ends up last cannot be skipped — the table draws until it turns up.

On the round entry screen the opening double shows as a domino with **"Nobody had the 9 — try the 8"** beneath it, and an undo. The score sheet heads each column with the domino that round actually opened on, and lists what is still to come underneath.

Turn the rule off for the official version, where players draw until the round's double appears and the doubles come out in strict order.

### House rules

All set per game, and stored with it, so a game in history always re-scores exactly the way it was played:

| Rule | Effect | Default |
| --- | --- | --- |
| Skip doubles nobody holds | Drop to the next double down instead of drawing for it; the skipped one comes back next round | On |
| Double-blank penalty | Holding the 0–0 when the round ends costs 50 | On |
| Ending on a double | Going out on a double costs 50 | Off |

## Look

Settings has a light/dark/system switch and a colour picker with 15 palettes — felt green through to slate — each with its own accent, previewed as you hover the list. The whole app is generated from the chosen seed colour, so everything recolours together.

## Running it

```sh
flutter pub get
dart run build_runner build      # generates the drift database code
flutter run -d macos             # or: chrome, windows, linux, or a device id
```

`flutter devices` lists what's available.

### Web assets

The web build runs SQLite compiled to WASM in a worker. Two files are checked into `web/` for that and must stay in step with the `drift` version in `pubspec.yaml`:

```sh
curl -L -o web/drift_worker.js \
  https://github.com/simolus3/drift/releases/download/drift-<version>/drift_worker.js
curl -L -o web/sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm
```

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

- `test/models/` — scoring rules: penalties, ties, the pool of unplayed doubles, which doubles a round may legally open on, winner selection.
- `test/db/` — SQLite round-trips, cascading deletes, resuming an unfinished game, and the v1→v2 migration against a hand-built version 1 database.
- `test/widget/` — round entry behaviour, the theme picker, and two full games played through the real widget tree: one straight down the ladder, one where a skipped double comes back and is played later.

`test/screenshots_test.dart` renders key screens to `test/goldens/` for eyeballing layout. It is skipped by default; run it with `flutter test test/screenshots_test.dart --run-skipped --update-goldens`.

## How it's built

```
lib/
  models/      pure Dart, no Flutter imports — all scoring lives here
  db/          drift (SQLite) tables, DAO, migrations
  providers/   Riverpod: active game, history, settings
  screens/     home, new game, scoreboard, round entry, results, history, settings
  theme/       palettes and the Material 3 theme built from one seed colour
  widgets/     standings list, score grid, pip entry, domino tile
```

Scoring is deliberately kept out of the database and the UI: `Game`, `Round` and `RoundEntry` are immutable value types, so the rules can be tested without either.

Every round is written to SQLite the moment it is saved, so quitting mid-game loses nothing — the home screen offers to pick up where you left off. A round's opening double is stored with it rather than derived from its position, which is what makes a burned double a fact about the game rather than a guess.

Doubles are modelled as a pool rather than a descending sequence: a game is finished when the pool is empty, and a round may open on anything still in it. Both the house rule and the official rule fall out of that, and it is why re-scoring an earlier round can move it to any double no other round has taken.

**Data stays on the device.** There is no account, no sync, and no backup. Deleting the app deletes the history with it.
