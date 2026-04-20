import Foundation
import Darwin

// Terminal shell for the game. Owns everything CLI-specific: stdio, ANSI,
// interactive menus, the REPL, and the stderr/exit translation for CLI
// errors. Lives in the core library as a pragmatic choice — no other shells
// exist yet, and elevating ~40 core types to `package` access to cleanly
// move this out is a lot of churn for a theoretical win.
//
// What matters is that the *pure* argument parser lives in `CLIOptions.swift`
// with no `print`, no `exit`, no stdio touching. All failure modes surface
// there as `CLIParseError`; this shell is the only place that maps them onto
// "print usage and exit 0" or "write stderr and exit 2". Tests hit the pure
// parser directly without mocking stdio.
//
// If a non-terminal shell is ever needed, clone this file — the pure parser
// can be reused as-is, and the `package` types in core can be elevated to
// `public` at that point in a targeted way.

// ─── Intro & mode selection ───────────────────────────────────────────────────

private func waitForAnyKey() {
    let fd = STDIN_FILENO

    guard isatty(fd) == 1 else {
        _ = readLine()
        return
    }

    var original = termios()
    guard tcgetattr(fd, &original) == 0 else {
        _ = readLine()
        return
    }

    var raw = original
    raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
    withUnsafeMutablePointer(to: &raw.c_cc) { pointer in
        let cc = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: cc_t.self)
        cc[Int(VMIN)] = 1
        cc[Int(VTIME)] = 0
    }

    guard tcsetattr(fd, TCSANOW, &raw) == 0 else {
        _ = readLine()
        return
    }

    defer {
        tcsetattr(fd, TCSANOW, &original)
        tcflush(fd, TCIFLUSH)
        print("")
    }

    var byte: UInt8 = 0
    _ = withUnsafeMutableBytes(of: &byte) { buffer in
        Darwin.read(fd, buffer.baseAddress, 1)
    }
}

func printIntro() {
    print(A.clearScreen)
    print()
    print(horizLine("╔", "═", "╗"))
    print(fullRow(""))
    print(fullRow(A.bold + A.cyan + "    CENTRAL BANK OF SOLAVERDE" + A.reset))
    print(fullRow(A.dim +  "    A monetary policy simulation" + A.reset))
    print(fullRow(""))
    print(horizLine("╠", "═", "╣"))
    print(fullRow(""))
    print(fullRow("  You are the newly appointed Governor of the Central Bank of Solaverde,"))
    print(fullRow("  a small tropical island economy in the Caribbean."))
    print(fullRow(""))
    print(fullRow("  Your mandate: maintain price stability and support sustainable growth."))
    print(fullRow("  Your tools: interest rates, reserve requirements, capital controls,"))
    print(fullRow("  and foreign exchange intervention."))
    print(fullRow(""))
    print(fullRow("  Your challenge may be a focused crisis run or a forty-year career,"))
    print(fullRow("  depending on the timeline you choose."))
    print(fullRow(""))
    print(horizLine("╠", "═", "╣"))
    print(fullRow("  Type " + A.bold + "help" + A.reset + " at any time for a full command reference and model notes."))
    print(fullRow("  Type " + A.bold + "tutorial" + A.reset + " for a guided opening briefing."))
    print(fullRow("  Type " + A.bold + "advance" + A.reset + " (or " + A.bold + "n" + A.reset + ") to progress one quarter."))
    print(fullRow("  Set policy before advancing: " + A.bold + "rate 7.5" + A.reset + "  " + A.bold + "reserve 14" + A.reset + "  " + A.bold + "controls 3" + A.reset))
    print(fullRow(""))
    print(horizLine("╚", "═", "╝"))
    print()
}

func selectMode() -> GameMode {
    print(horizLine("╔", "═", "╗"))
    print(fullRow(A.bold + A.cyan + "  SELECT GAME MODE" + A.reset))
    print(horizLine("╠", "═", "╣"))
    print(fullRow(""))
    print(fullRow("  " + A.bold + "[1] HISTORICAL" + A.reset))
    print(fullRow("      Macro-events follow the selected real-world timeline."))
    print(fullRow("      Short mode tracks the 1973–1982 crisis arc; extended mode adds"))
    print(fullRow("      Bretton Woods calm, the 1970s shocks, the 1980s debt era, and"))
    print(fullRow("      the 1990s emerging-market turbulence on schedule."))
    print(fullRow(""))
    print(fullRow("  " + A.bold + "[2] RANDOMISED" + A.reset))
    print(fullRow("      Same chosen span, same win/lose conditions, but all major"))
    print(fullRow("      macro-events — oil shocks, recessions, debt crises, IMF reviews"))
    print(fullRow("      — are procedurally scheduled before the game begins. You won't"))
    print(fullRow("      know when or how hard they'll hit. No two playthroughs alike."))
    print(fullRow(""))
    print(horizLine("╠", "═", "╣"))
    print(fullRow("  Enter " + A.bold + "1" + A.reset + " or " + A.bold + "2" + A.reset + ": "))
    print(horizLine("╚", "═", "╝"))
    print()

    while true {
        print("  > ", terminator: "")
        fflush(stdout)
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch input {
        case "1": return .historical
        case "2": return .randomized
        default: print("  Please enter 1 or 2.")
        }
    }
}

func selectLength() -> GameLength {
    print(horizLine("╔", "═", "╗"))
    print(fullRow(A.bold + A.cyan + "  SELECT GAME LENGTH" + A.reset))
    print(horizLine("╠", "═", "╣"))
    print(fullRow(""))
    print(fullRow("  " + A.bold + "[1] SHORT" + A.reset))
    print(fullRow("      1973–1982. 36 quarters. The current crisis-focused campaign."))
    print(fullRow(""))
    print(fullRow("  " + A.bold + "[2] EXTENDED" + A.reset))
    print(fullRow("      1960–2000. 160 quarters. A full central-banking career through"))
    print(fullRow("      Bretton Woods, stagflation, the debt era, and 1990s volatility."))
    print(fullRow(""))
    print(horizLine("╠", "═", "╣"))
    print(fullRow("  Enter " + A.bold + "1" + A.reset + " or " + A.bold + "2" + A.reset + ": "))
    print(horizLine("╚", "═", "╝"))
    print()

    while true {
        print("  > ", terminator: "")
        fflush(stdout)
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch input {
        case "1": return .short
        case "2": return .extended
        default: print("  Please enter 1 or 2.")
        }
    }
}

func selectHistoricalScenario(for gameLength: GameLength) -> String? {
    let scenarios = scenarioDefinitions(for: gameLength)
    guard !scenarios.isEmpty else { return nil }

    func wrappedSelectionLines(_ text: String, width: Int = 68) -> [String] {
        guard !text.isEmpty else { return [""] }
        var lines: [String] = []
        var current = ""

        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let token = String(word)
            let candidate = current.isEmpty ? token : current + " " + token
            if candidate.count <= width {
                current = candidate
            } else {
                if !current.isEmpty {
                    lines.append(current)
                }
                current = token
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    print(horizLine("╔", "═", "╗"))
    print(fullRow(A.bold + A.cyan + "  SELECT HISTORICAL SETUP" + A.reset))
    print(horizLine("╠", "═", "╣"))
    print(fullRow(""))
    print(fullRow("  " + A.bold + "[0] STANDARD CAMPAIGN" + A.reset))
    print(fullRow("      Play the full \(gameLength.displayName.lowercased()) historical campaign."))
    print(fullRow(""))
    for (index, scenario) in scenarios.enumerated() {
        let teachingTag = scenario.teachingFocus.isEmpty ? "" : " " + A.bGreen + A.bold + "[TEACHING]" + A.reset
        print(fullRow("  " + A.bold + "[\(index + 1)] " + scenario.title.uppercased() + A.reset + teachingTag))
        let wrapped = wrappedSelectionLines(scenario.rangeLabel + " — " + scenario.summary)
        for line in wrapped {
            print(fullRow("      " + line))
        }
        print(fullRow(""))
    }
    print(horizLine("╠", "═", "╣"))
    print(fullRow("  Enter " + A.bold + "0" + A.reset + " for the campaign, or pick a scenario: "))
    print(horizLine("╚", "═", "╝"))
    print()

    while true {
        print("  > ", terminator: "")
        fflush(stdout)
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
              let choice = Int(input) else {
            print("  Please enter a number.")
            continue
        }
        if choice == 0 { return nil }
        if choice >= 1 && choice <= scenarios.count {
            return scenarios[choice - 1].id
        }
        print("  Please choose one of the listed options.")
    }
}

func selectDifficulty() -> Difficulty {
    print(horizLine("╔", "═", "╗"))
    print(fullRow(A.bold + A.cyan + "  SELECT DIFFICULTY" + A.reset))
    print(horizLine("╠", "═", "╣"))
    print(fullRow(""))
    for (i, d) in Difficulty.allCases.enumerated() {
        print(fullRow("  " + A.bold + "[\(i+1)] " + d.displayName.uppercased() + A.reset))
        print(fullRow("      " + d.tagline))
        print(fullRow(""))
    }
    print(horizLine("╠", "═", "╣"))
    print(fullRow("  Enter " + A.bold + "1" + A.reset + ", " + A.bold + "2" + A.reset
                  + ", or " + A.bold + "3" + A.reset + ": "))
    print(horizLine("╚", "═", "╝"))
    print()

    while true {
        print("  > ", terminator: "")
        fflush(stdout)
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch input {
        case "1": return .apprentice
        case "2": return .governor
        case "3": return .volcker
        default:  print("  Please enter 1, 2, or 3.")
        }
    }
}

// ─── Entry point ──────────────────────────────────────────────────────────────

package func runTerminalApp() {
    // Resolve CLI args. `parseCLIArgs` is pure — we translate its errors into
    // stdio + exit codes here, which is the one thing the core library isn't
    // allowed to do.
    let cli: CLIOptions
    do {
        cli = try parseCLIArgs()
    } catch CLIParseError.helpRequested {
        print(cliUsageText)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(2)
    }

    if cli.balance {
        let modes = cli.mode.map { [$0] } ?? GameMode.allCasesForBalance
        let lengths = cli.length.map { [$0] } ?? [.short]
        let difficulties = cli.difficulty.map { [$0] } ?? Difficulty.allCases
        let bots = cli.bot.map { [$0] } ?? BalanceBot.allCases
        let config = BalanceConfig(
            runsPerCell: cli.runs ?? 100,
            baseSeed: cli.seed ?? 0xBA1A_ACE0_1973,
            lengths: lengths,
            modes: modes,
            difficulties: difficulties,
            bots: bots,
            reportPath: cli.reportPath)
        runBalanceHarness(config)
        return
    }

    printIntro()

    let gameMode = cli.mode ?? selectMode()
    let selectedLength = cli.length ?? selectLength()
    let scenarioID: String? = gameMode == .historical
        ? (cli.scenarioID ?? selectHistoricalScenario(for: selectedLength))
        : nil
    let difficulty = cli.difficulty ?? selectDifficulty()
    let sessionSeed = cli.seed ?? freshSeed()
    var session = GameSession(
        mode: gameMode,
        gameLength: selectedLength,
        difficulty: difficulty,
        scenarioID: scenarioID,
        sessionSeed: sessionSeed)
    var lastMessage: String? = nil
    var gameRunning = true

    if let scenario = session.scenario {
        drawScenarioBriefing(scenario)
        waitForAnyKey()
    }

    drawDashboard(session.simulator)

    while gameRunning {
        if let msg = lastMessage {
            print()
            print("  " + A.bYellow + "→ " + A.reset + msg)
            lastMessage = nil
        }

        print()
        print("  " + A.bold + "Governor > " + A.reset, terminator: "")
        fflush(stdout)

        guard let input = readLine(), !input.isEmpty else { continue }

        let cmd = parseCommand(input)

        switch cmd {
        case .advance:
            let outcome = session.advance()
            if outcome != .ongoing {
                drawGameOver(
                    outcome,
                    session.simulator,
                    gameLength: session.gameLength,
                    scenarioID: session.scenarioID)
                waitForAnyKey()
                gameRunning = false
                break
            }
            drawDashboard(session.simulator)

        case .preview(let changes):
            let preview = session.preview(changes: changes)
            drawPreview(preview.estimate, headerNote: preview.note)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .save(let path):
            do {
                try session.save(to: path)
                lastMessage = A.bGreen + "Saved to " + A.reset + resolvedSavePath(path)
            } catch {
                lastMessage = A.bRed + "Save failed: " + A.reset + "\(error)"
            }

        case .load(let path):
            do {
                session = try GameSession.load(from: path)
                drawDashboard(session.simulator)
                lastMessage = A.bGreen + "Loaded " + A.reset + resolvedSavePath(path)
                    + A.dim + "  (seed \(session.sessionSeed), \(session.loadDescription()))" + A.reset
            } catch {
                lastMessage = A.bRed + "Load failed: " + A.reset + "\(error)"
            }

        case .history:
            drawHistory(session.simulator)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .news:
            drawNewsLog(session.simulator)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .crisis:
            drawCrisisOptions(session.simulator)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .report:
            drawCampaignReport(session.simulator, gameLength: session.gameLength, scenarioID: session.scenarioID)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .debrief:
            drawQuarterDebrief(session.simulator)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .tutorial:
            drawTutorial(session.simulator, mode: session.mode, gameLength: session.gameLength, scenarioID: session.scenarioID)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .advisor(let topic):
            drawAdvisor(session.simulator, topic: topic)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .status:
            drawStatus(session.simulator, gameLength: session.gameLength, scenarioID: session.scenarioID)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .help:
            drawHelp(gameLength: session.gameLength, scenarioID: session.scenarioID)
            waitForAnyKey()
            drawDashboard(session.simulator)

        case .quit:
            print()
            print("  Farewell, Governor. Solaverde will have to find someone else.")
            print()
            gameRunning = false

        case .invalid(let msg):
            if !msg.isEmpty {
                lastMessage = A.bRed + "Error: " + A.reset + msg
            }

        default:
            if let msg = applyCommand(cmd, simulator: session.simulator) {
                lastMessage = msg
                drawDashboard(session.simulator)
            }
        }
    }
}
