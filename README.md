# CentralBanker

`CentralBanker` is a terminal-based central banking strategy game and macroeconomic simulation set in the fictional Caribbean island economy of Solaverde.

You play as the governor of the central bank. Your mandate is to contain inflation, support sustainable growth, defend the currency when necessary, and survive the politics of crisis management.

## What the Game Includes

- Historical and randomized campaigns
- Short and extended timelines
- Historical scenarios with bespoke objectives
- Policy tools:
  - interest rate
  - reserve requirement
  - capital controls
  - FX intervention
  - communication stance
- Political and institutional pressure:
  - cabinet demands
  - crisis measures
- Reporting and teaching tools:
  - `history`
  - `news`
  - `report`
  - `why`
  - `tutorial`
- A headless balance harness for large seeded policy sweeps

## Quick Start

From the repo root:

```bash
swift run CentralBanker
```

If your local toolchain is sensitive to non-SDK headers, the included helper uses the active Xcode SDK explicitly:

```bash
./run.sh
```

## CLI Options

```text
Usage: CentralBanker [options]
  --seed <uint64>        Fix session seed for reproducible runs.
  --mode <h|r>           Start in historical (h) or randomized (r) mode.
  --length <s|e>         Use short (1973–1982) or extended (1960–2000) play.
  --difficulty <a|g|v>   Apprentice / Governor / Volcker.
  --scenario <id>        Start a historical scenario by id.
  --balance              Run the headless balance harness instead of the game.
  --runs <int>           Runs per balance cell (default: 100).
  --bot <name>           passive, rate_only, or full_reactive.
  --report <path>        Write balance results as JSON when running --balance.
  --help                 Show usage.
```

Example:

```bash
swift run CentralBanker --mode h --scenario oil_shock_1973 --difficulty g --seed 123
```

## Core In-Game Commands

- `rate <value>`
- `reserve <value>`
- `controls <0-10>`
- `intervene <±value>`
- `comm <hawkish|balanced|dovish|opaque>`
- `preview`
- `advance`
- `cabinet`
- `accept`
- `reject`
- `delay`
- `crisis`
- `measure <imf|holiday|liquidity>`
- `status`
- `history`
- `news`
- `report`
- `why`
- `tutorial`
- `save [path]`
- `load [path]`
- `help`
- `quit`

The game also supports `preview` with hypothetical overrides, for example:

```text
preview rate 12.5
preview reserve 15 controls 6
```

## Scenario IDs

Current historical scenario ids:

- `soft_landing_1966`
- `bretton_break_1971`
- `oil_shock_1973`
- `wage_spiral_1976`
- `volcker_1979`
- `reserve_run_1981`
- `debt_crisis_1982`
- `debt_workout_1984`
- `lost_decade_recovery_1985`
- `recession_relief_1991`
- `asian_contagion_1997`
- `confidence_rebuild_1998`

These are defined in [Config/scenarios.json](Config/scenarios.json).

Several of these are intentionally teaching-oriented scenarios with tighter
instructional focus:

- `soft_landing_1966`
- `debt_workout_1984`
- `recession_relief_1991`
- `confidence_rebuild_1998`

## Versioning and Release Notes

The current release version is recorded in [VERSION](VERSION).

Human-facing release notes live in [CHANGELOG.md](CHANGELOG.md).
The player-facing manual lives in [PLAYER_GUIDE.md](PLAYER_GUIDE.md).

## Balance Harness

The balance harness runs seeded automated playthroughs without the interactive terminal UI.

Examples:

```bash
swift run CentralBanker --balance --runs 100
swift run CentralBanker --balance --mode h --length s --difficulty g --bot passive --runs 50
swift run CentralBanker --balance --mode r --length e --difficulty v --bot full_reactive --runs 60 --report /tmp/balance.json
```

This is the primary tool for balancing:

- campaign survival rates
- score distributions
- policy action frequency
- crisis-tool usage
- difficulty separation

## Config and Tuning

Gameplay tuning is data-driven.

Primary config files:

- [Config/game_tuning.json](Config/game_tuning.json)
- [Config/historical_short.json](Config/historical_short.json)
- [Config/historical_extended.json](Config/historical_extended.json)
- [Config/scenarios.json](Config/scenarios.json)

Config load order is:

1. `CENTRALBANKER_CONFIG_DIR`
2. repo-local `Config/`
3. bundled package resources

Broken config files are intentionally loud on stderr; the game falls back to compiled defaults instead of silently ignoring the problem.

## Project Structure

- [Sources/CentralBanker](Sources/CentralBanker)
  - core model, session lifecycle, display, command parsing, scenarios, tuning, harness
- [Sources/CentralBankerApp](Sources/CentralBankerApp)
  - thin executable entrypoint
- [Tests/CentralBankerTests](Tests/CentralBankerTests)
  - simulation, config, parser, rendering, and harness regression coverage

Important files:

- [GameSession.swift](Sources/CentralBanker/GameSession.swift)
- [Economy.swift](Sources/CentralBanker/Economy.swift)
- [Display.swift](Sources/CentralBanker/Display.swift)
- [GameConfig.swift](Sources/CentralBanker/GameConfig.swift)
- [BalanceHarness.swift](Sources/CentralBanker/BalanceHarness.swift)

## Development

Run tests:

```bash
swift test
```

The suite currently covers:

- macro model determinism
- scenario and save/load behavior
- CLI parsing
- config/fallback sync
- communication, cabinet, and crisis systems
- balance harness behavior
- terminal renderer width/content regressions

## Packaging Releases

For a macOS release bundle:

```bash
./scripts/package_release.sh
```

That script builds a release binary and creates:

- a staged release directory under `dist/`
- a `.zip` archive under `dist/`

The packaged release includes:

- `CentralBanker`
- `run-centralbanker`
- the SwiftPM resource bundle
- `Config/`
- `README.md`
- `PLAYER_GUIDE.md`
- `CHANGELOG.md`
- `VERSION`
- `BUILD_INFO.txt`

Use `run-centralbanker` as the entrypoint. It sets `CENTRALBANKER_CONFIG_DIR` to the packaged `Config/` directory so release builds do not depend on the repo layout or the current working directory.

To smoke-test a packaged release:

```bash
./scripts/smoke_release_bundle.sh dist/<archive-or-directory>
```

That script extracts or copies the package into a temporary directory, runs it from outside the repo, checks `--help`, and runs a one-cell balance harness smoke test to prove that packaged config/resource loading works.

## Platform Notes

The package currently targets macOS in `Package.swift`. The game core is much cleaner than it used to be, but the packaged target is still explicitly macOS-first.

If cross-platform support becomes a priority later, the next likely step is to keep `CentralBankerCore` platform-neutral and treat the terminal shell as one client among several.
