import Foundation
import CentralBankerCore

// Pure, testable CLI argument parsing. This used to live in `TerminalApp.swift`
// with embedded `print` / `exit` / `FileHandle.standardError` calls, which
// made it unusable from anything that wasn't a terminal and impossible to
// unit-test without mocking stdio. The split here:
//
//   • `CLIOptions`      — the parsed bundle.
//   • `CLIParseError`   — every failure mode the parser can produce.
//   • `parseCLIArgs(_:)` — pure function. Never calls `exit`, never prints.
//
// The terminal app shell wraps this with the print-usage / exit-on-error
// behaviour that the previous API hard-coded. Other shells (TUI, web, tests)
// can consume the errors however they like.

struct CLIOptions: Equatable {
    var seed: UInt64? = nil
    var mode: GameMode? = nil
    var length: GameLength? = nil
    var difficulty: Difficulty? = nil
    var scenarioID: String? = nil
    var balance: Bool = false
    var validateModel: Bool = false
    var runs: Int? = nil
    var bot: BalanceBot? = nil
    var reportPath: String? = nil

    init() {}
}

enum CLIParseError: Error, Equatable, CustomStringConvertible {
    /// `--help` / `-h` was passed. The caller should print usage and exit 0.
    case helpRequested
    /// `--flag` appeared without the argument it requires.
    case missingArgument(flag: String, expected: String)
    /// `--flag value` where `value` didn't match any accepted form.
    case invalidValue(flag: String, got: String, expected: String)
    /// An argument was passed that we don't recognise.
    case unknownArgument(String)
    /// `--scenario` referenced an id that has no matching definition.
    case unknownScenario(String)
    /// `--scenario` was combined with `--mode r`.
    case scenarioModeConflict

    var description: String {
        switch self {
        case .helpRequested:
            return "help requested"
        case .missingArgument(let flag, let expected):
            return "\(flag) requires \(expected)"
        case .invalidValue(let flag, let got, let expected):
            return "\(flag) got \"\(got)\"; expected \(expected)"
        case .unknownArgument(let a):
            return "Unknown argument: \(a)"
        case .unknownScenario(let id):
            return "Unknown scenario id: \(id)"
        case .scenarioModeConflict:
            return "--scenario is only supported in historical mode"
        }
    }
}

/// Usage text for `--help`. Printed by the terminal shell; lives here so the
/// list of flags stays next to the parser that understands them.
let cliUsageText: String = """
Usage: CentralBanker [options]
  --seed <uint64>        Fix session seed for reproducible runs.
  --mode <h|r>           Start in historical (h) or randomized (r) mode,
                         skipping the menu.
  --length <s|e>         Use short (1973–1982) or extended (1960–2000) play.
  --difficulty <a|g|v>   Apprentice / Governor / Volcker,
                         skipping the difficulty selector.
  --scenario <id>        Start a historical scenario by id.
  --balance              Run the headless balance harness instead of the game.
  --validate-model       Run the expectation-based model-validation sweep.
  --runs <int>           Runs per balance cell (default: 100).
  --bot <name>           Limit balance harness to passive, rate_only, full_reactive,
                         hawkish, balanced, dovish, or glonzo.
  --report <path>        Write harness results as JSON when running --balance or --validate-model.
  --help                 Show this message.
"""

/// Parse a CentralBanker argument vector. `rawArgs` is expected in the usual
/// `CommandLine.arguments` shape (argv[0] is the program name and is ignored).
///
/// Pure: no `print`, no `exit`, no side effects. All failure modes surface as
/// `CLIParseError`. `--help` is reported as `.helpRequested` so the caller
/// decides whether to print usage and with what exit code.
func parseCLIArgs(_ rawArgs: [String] = CommandLine.arguments) throws -> CLIOptions {
    var options = CLIOptions()
    let args = rawArgs.dropFirst()
    var i = args.startIndex

    // Grab the argument after flag `flag` (at current position `i`), advance
    // `i` past it, and return it. Throws `.missingArgument` if absent.
    func consumeArg(flag: String, expected: String) throws -> String {
        let next = args.index(after: i)
        guard next < args.endIndex else {
            throw CLIParseError.missingArgument(flag: flag, expected: expected)
        }
        let v = args[next]
        i = args.index(after: next)
        return String(v)
    }

    while i < args.endIndex {
        let a = args[i]
        switch a {
        case "--help", "-h":
            throw CLIParseError.helpRequested
        case "--seed":
            let raw = try consumeArg(flag: "--seed", expected: "a uint64")
            guard let v = UInt64(raw) else {
                throw CLIParseError.invalidValue(flag: "--seed", got: raw, expected: "uint64")
            }
            options.seed = v
            continue
        case "--balance":
            options.balance = true
        case "--validate-model":
            options.validateModel = true
        case "--length":
            let raw = try consumeArg(flag: "--length", expected: "s|e")
            switch raw.lowercased() {
            case "s", "short": options.length = .short
            case "e", "ext", "extended": options.length = .extended
            default:
                throw CLIParseError.invalidValue(flag: "--length", got: raw, expected: "s or e")
            }
            continue
        case "--runs":
            let raw = try consumeArg(flag: "--runs", expected: "a positive integer")
            guard let v = Int(raw), v > 0 else {
                throw CLIParseError.invalidValue(flag: "--runs", got: raw, expected: "positive integer")
            }
            options.runs = v
            continue
        case "--bot":
            let raw = try consumeArg(flag: "--bot", expected: "passive|rate_only|full_reactive|hawkish|balanced|dovish|glonzo")
            guard let bot = BalanceBot(rawValue: raw.lowercased()) else {
                throw CLIParseError.invalidValue(
                    flag: "--bot", got: raw, expected: "passive, rate_only, full_reactive, hawkish, balanced, dovish, or glonzo")
            }
            options.bot = bot
            continue
        case "--report":
            options.reportPath = try consumeArg(flag: "--report", expected: "a path")
            continue
        case "--mode":
            let raw = try consumeArg(flag: "--mode", expected: "h|r")
            switch raw.lowercased() {
            case "h", "hist", "historical":  options.mode = .historical
            case "r", "rand", "randomized":  options.mode = .randomized
            default:
                throw CLIParseError.invalidValue(flag: "--mode", got: raw, expected: "h or r")
            }
            continue
        case "--difficulty":
            let raw = try consumeArg(flag: "--difficulty", expected: "a|g|v")
            switch raw.lowercased() {
            case "a", "apprentice": options.difficulty = .apprentice
            case "g", "governor":   options.difficulty = .governor
            case "v", "volcker":    options.difficulty = .volcker
            default:
                throw CLIParseError.invalidValue(flag: "--difficulty", got: raw, expected: "a, g, or v")
            }
            continue
        case "--scenario":
            options.scenarioID = try consumeArg(flag: "--scenario", expected: "a scenario id")
            continue
        default:
            throw CLIParseError.unknownArgument(String(a))
        }
        i = args.index(after: i)
    }

    // Scenario post-processing: scenarios imply historical mode and adopt the
    // scenario's own game length. Must happen after the main loop because the
    // scenario flag can appear before `--mode` / `--length` in argv.
    if let scenarioID = options.scenarioID {
        guard let scenario = scenarioDefinition(id: scenarioID) else {
            throw CLIParseError.unknownScenario(scenarioID)
        }
        if let mode = options.mode, mode != .historical {
            throw CLIParseError.scenarioModeConflict
        }
        options.mode = .historical
        options.length = scenario.gameLength
    }

    return options
}
