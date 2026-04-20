import Foundation

enum BalanceBot: String, CaseIterable, Codable {
    case passive
    case rateOnly = "rate_only"
    case fullReactive = "full_reactive"
    case glonzo

    var displayName: String {
        switch self {
        case .passive: return "Passive"
        case .rateOnly: return "RateOnly"
        case .fullReactive: return "FullReactive"
        case .glonzo: return "Glonzo"
        }
    }
}

struct BalanceConfig {
    var runsPerCell: Int
    var baseSeed: UInt64
    var lengths: [GameLength]
    var modes: [GameMode]
    var difficulties: [Difficulty]
    var bots: [BalanceBot]
    var scenarioIDs: [String]? = nil
    var reportPath: String? = nil
}

struct BalanceTurnStats {
    var policyActions: Int = 0
    var activeQuarter: Bool = false
    var rateMoveAbs: Double = 0.0
    var reserveMoveAbs: Double = 0.0
    var controlsMoveAbs: Double = 0.0
    var interventionMonthsAbs: Double = 0.0
    var crisisMeasuresUsed: Int = 0
    var imfProgramsUsed: Int = 0
    var bankHolidaysUsed: Int = 0
    var emergencyLiquidityUsed: Int = 0
}

struct BalanceRunResult {
    var gameLength: GameLength
    var mode: GameMode
    var scenarioID: String?
    var scenarioTitle: String?
    var difficulty: Difficulty
    var bot: BalanceBot
    var seed: UInt64
    var outcome: GameOutcome
    var score: Int
    var quartersSimulated: Int
    var activePolicyQuarters: Int
    var totalPolicyActions: Int
    var totalRateMoveAbs: Double
    var totalReserveMoveAbs: Double
    var totalControlsMoveAbs: Double
    var totalInterventionMonthsAbs: Double
    var totalCrisisMeasuresUsed: Int
    var totalIMFProgramsUsed: Int
    var totalBankHolidaysUsed: Int
    var totalEmergencyLiquidityUsed: Int
    var finalInflation: Double
    var lowestReserves: Double
    var lowestCredibility: Double
    var peakPoliticalPressure: Double
}

struct BalanceSummary: Codable {
    var gameLength: GameLength
    var mode: GameMode
    var scenarioID: String?
    var scenarioTitle: String?
    var difficulty: Difficulty
    var bot: BalanceBot
    var runs: Int
    var survivalRate: Double
    var medianScore: Int
    var p25Score: Int
    var p75Score: Int
    var averageActiveQuarterRate: Double
    var averagePolicyActions: Double
    var averageQuartersSimulated: Double
    var averageRateMoveAbs: Double
    var averageControlsMoveAbs: Double
    var averageInterventionMonthsAbs: Double
    var averageCrisisMeasuresUsed: Double
    var averageIMFProgramsUsed: Double
    var averageBankHolidaysUsed: Double
    var averageEmergencyLiquidityUsed: Double
    var averageFinalInflation: Double
    var averageLowestReserves: Double
    var averageLowestCredibility: Double
    var averagePeakPoliticalPressure: Double
    var outcomeCounts: [String: Int]
}

func runBalanceHarness(_ config: BalanceConfig) {
    print("Balance harness")
    print("  Runs per cell: \(config.runsPerCell)")
    print("  Base seed: \(config.baseSeed)")
    if let scenarioIDs = config.scenarioIDs, !scenarioIDs.isEmpty {
        print("  Scenario cells: \(scenarioIDs.count)")
    }
    print("")

    var summaries: [BalanceSummary] = []
    if let scenarioIDs = config.scenarioIDs, !scenarioIDs.isEmpty {
        for scenarioID in scenarioIDs {
            guard let scenario = scenarioDefinition(id: scenarioID) else { continue }
            for difficulty in config.difficulties {
                for bot in config.bots {
                    var runs: [BalanceRunResult] = []
                    for i in 0..<config.runsPerCell {
                        let seed = config.baseSeed &+ UInt64(i)
                        runs.append(runBalanceGame(
                            gameLength: scenario.gameLength,
                            mode: .historical,
                            difficulty: difficulty,
                            bot: bot,
                            seed: seed,
                            scenarioID: scenarioID))
                    }
                    summaries.append(summarizeBalanceRuns(runs))
                }
            }
        }
    } else {
        for gameLength in config.lengths {
            for mode in config.modes {
                for difficulty in config.difficulties {
                    for bot in config.bots {
                        var runs: [BalanceRunResult] = []
                        for i in 0..<config.runsPerCell {
                            let seed = config.baseSeed &+ UInt64(i)
                            runs.append(runBalanceGame(gameLength: gameLength, mode: mode, difficulty: difficulty, bot: bot, seed: seed))
                        }
                        summaries.append(summarizeBalanceRuns(runs))
                    }
                }
            }
        }
    }

    printBalanceSummaries(summaries)
    printBalanceDiagnostics(summaries)
    if let path = config.reportPath {
        do {
            try writeBalanceReport(summaries, config: config, to: path)
            print("")
            print("Wrote balance report to \(resolvedSavePath(path))")
        } catch {
            print("")
            print("Failed to write balance report: \(error)")
        }
    }
}

func runBalanceGame(gameLength: GameLength,
                    mode: GameMode,
                    difficulty: Difficulty,
                    bot: BalanceBot,
                    seed: UInt64,
                    scenarioID: String? = nil) -> BalanceRunResult {
    let session = GameSession(
        mode: mode,
        gameLength: gameLength,
        difficulty: difficulty,
        scenarioID: scenarioID,
        sessionSeed: seed)
    let simulator = session.simulator

    var activePolicyQuarters = 0
    var totalPolicyActions = 0
    var totalRateMoveAbs = 0.0
    var totalReserveMoveAbs = 0.0
    var totalControlsMoveAbs = 0.0
    var totalInterventionMonthsAbs = 0.0
    var totalCrisisMeasuresUsed = 0
    var totalIMFProgramsUsed = 0
    var totalBankHolidaysUsed = 0
    var totalEmergencyLiquidityUsed = 0

    while true {
        let turn = applyBalanceBotTurn(bot, to: simulator)
        if turn.activeQuarter { activePolicyQuarters += 1 }
        totalPolicyActions += turn.policyActions
        totalRateMoveAbs += turn.rateMoveAbs
        totalReserveMoveAbs += turn.reserveMoveAbs
        totalControlsMoveAbs += turn.controlsMoveAbs
        totalInterventionMonthsAbs += turn.interventionMonthsAbs
        totalCrisisMeasuresUsed += turn.crisisMeasuresUsed
        totalIMFProgramsUsed += turn.imfProgramsUsed
        totalBankHolidaysUsed += turn.bankHolidaysUsed
        totalEmergencyLiquidityUsed += turn.emergencyLiquidityUsed

        let outcome = session.advance()
        if outcome != .ongoing {
            let score = computeScore(outcome: outcome,
                                     card: simulator.scoreCard,
                                     gameLength: gameLength).final
            return BalanceRunResult(
                gameLength: gameLength,
                mode: mode,
                scenarioID: scenarioID,
                scenarioTitle: scenarioID == nil ? nil : session.campaignTitle,
                difficulty: difficulty,
                bot: bot,
                seed: seed,
                outcome: outcome,
                score: score,
                quartersSimulated: simulator.scoreCard.quartersSimulated,
                activePolicyQuarters: activePolicyQuarters,
                totalPolicyActions: totalPolicyActions,
                totalRateMoveAbs: totalRateMoveAbs,
                totalReserveMoveAbs: totalReserveMoveAbs,
                totalControlsMoveAbs: totalControlsMoveAbs,
                totalInterventionMonthsAbs: totalInterventionMonthsAbs,
                totalCrisisMeasuresUsed: totalCrisisMeasuresUsed,
                totalIMFProgramsUsed: totalIMFProgramsUsed,
                totalBankHolidaysUsed: totalBankHolidaysUsed,
                totalEmergencyLiquidityUsed: totalEmergencyLiquidityUsed,
                finalInflation: simulator.state.inflation,
                lowestReserves: simulator.scoreCard.lowestReserves,
                lowestCredibility: simulator.scoreCard.lowestCredibility,
                peakPoliticalPressure: simulator.scoreCard.peakPoliticalPressure)
        }
    }
}

func applyBalanceBotTurn(_ bot: BalanceBot,
                         to simulator: EconomicSimulator) -> BalanceTurnStats {
    switch bot {
    case .passive:
        return BalanceTurnStats()
    case .rateOnly:
        return applyRateOnlyBot(to: simulator)
    case .fullReactive:
        return applyFullReactiveBot(to: simulator)
    case .glonzo:
        return applyGlonzoBot(to: simulator)
    }
}

private func applyRateOnlyBot(to simulator: EconomicSimulator) -> BalanceTurnStats {
    var stats = BalanceTurnStats()
    let s = simulator.state
    let inflationTarget = 0.05
    let neutralNominal = simulator.params.outputGap.neutralRealRate + inflationTarget
    let reserveStress = s.foreignReservesMonths < 2.5 ? 0.010 : 0.0
    let targetRate = (0.0...0.25).clamping(
        neutralNominal
        + 1.10 * (s.inflation - inflationTarget)
        - 0.50 * s.outputGap
        + reserveStress)
    adjustPolicyRate(on: simulator, toward: targetRate, maxStep: 0.010, deadband: 0.0075, stats: &stats)
    resolveCabinetDemand(for: .rateOnly, simulator: simulator, stats: &stats)
    return stats
}

private func applyFullReactiveBot(to simulator: EconomicSimulator) -> BalanceTurnStats {
    var stats = BalanceTurnStats()

    maybeUseCrisisMeasure(on: simulator, stats: &stats)
    let s = simulator.state

    let inflationTarget = 0.05
    let neutralNominal = simulator.params.outputGap.neutralRealRate + inflationTarget
    let reserveStress = max(0.0, 2.7 - s.foreignReservesMonths) * 0.010
    let fxStress = max(0.0, s.exchangeRateQoQChange - 0.015) * 0.75
    let targetRate = (0.0...0.28).clamping(
        neutralNominal
        + 1.35 * (s.inflation - inflationTarget)
        - 0.75 * s.outputGap
        + reserveStress
        + fxStress)
    adjustPolicyRate(on: simulator, toward: targetRate, maxStep: 0.015, deadband: 0.010, stats: &stats)

    if simulator.state.inflation > 0.11
        && simulator.state.bankCreditGrowth > 0.14
        && simulator.state.foreignReservesMonths > 2.8
        && simulator.state.reserveRequirement < 0.20 {
        adjustReserveRequirement(on: simulator,
                                 toward: (0.06...0.24).clamping(simulator.state.reserveRequirement + 0.02),
                                 maxStep: 0.02,
                                 deadband: 0.010,
                                 stats: &stats)
    }

    if simulator.state.foreignReservesMonths < 2.8
        && simulator.state.exchangeRateQoQChange > 0.020
        && simulator.state.capitalControls < 0.9 {
        let move = min(0.15, 1.0 - simulator.state.capitalControls)
        if move > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls + move)
            stats.controlsMoveAbs += move
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.state.foreignReservesMonths > 5.2
                && simulator.state.inflation < 0.08
                && simulator.state.capitalControls > 0.2 {
        let move = min(0.10, simulator.state.capitalControls)
        if move > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls - move)
            stats.controlsMoveAbs += move
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    }

    let interventionMonths: Double
    if simulator.state.foreignReservesMonths > 2.2 && simulator.state.exchangeRateQoQChange > 0.030 {
        interventionMonths = -min(0.50, simulator.state.foreignReservesMonths - 1.2)
    } else if simulator.state.foreignReservesMonths > 1.6 && simulator.state.exchangeRateQoQChange > 0.045 {
        interventionMonths = -min(0.30, simulator.state.foreignReservesMonths - 1.0)
    } else if simulator.state.foreignReservesMonths > 4.8
                && simulator.state.currentAccountGDP > 0.01
                && simulator.state.exchangeRateQoQChange < -0.03 {
        interventionMonths = 0.30
    } else {
        interventionMonths = 0.0
    }
    if abs(interventionMonths) > 0.0001 {
        simulator.applyFXIntervention(months: interventionMonths)
        stats.interventionMonthsAbs += abs(interventionMonths)
        stats.policyActions += 1
        stats.activeQuarter = true
    }

    if simulator.state.inflation > 0.07 || simulator.state.exchangeRateQoQChange > 0.02 {
        if simulator.communicationStance != .hawkish {
            simulator.communicationStance = .hawkish
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.state.outputGap < -0.04 && simulator.state.inflation < 0.06 {
        if simulator.communicationStance != .dovish {
            simulator.communicationStance = .dovish
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.communicationStance == .hawkish
                && simulator.state.inflation < 0.05
                && simulator.state.exchangeRateQoQChange < 0.01 {
        simulator.communicationStance = .balanced
        stats.policyActions += 1
        stats.activeQuarter = true
    } else if simulator.communicationStance == .dovish
                && simulator.state.outputGap > -0.01 {
        simulator.communicationStance = .balanced
        stats.policyActions += 1
        stats.activeQuarter = true
    }

    resolveCabinetDemand(for: .fullReactive, simulator: simulator, stats: &stats)
    return stats
}

private func applyGlonzoBot(to simulator: EconomicSimulator) -> BalanceTurnStats {
    enum GlonzoLever: CaseIterable {
        case rate
        case reserveRequirement
        case controls
        case intervention
    }

    var stats = BalanceTurnStats()
    let leverCount = Int.random(in: 0...2, using: &simulator.rng)
    guard leverCount > 0 else { return stats }

    var levers = GlonzoLever.allCases
    levers.shuffle(using: &simulator.rng)

    for lever in levers.prefix(leverCount) {
        switch lever {
        case .rate:
            let delta = Double.random(in: -0.035...0.035, using: &simulator.rng)
            let nextRate = (0.0...0.28).clamping(simulator.state.policyRate + delta)
            let move = abs(nextRate - simulator.state.policyRate)
            guard move > 0.0001 else { continue }
            simulator.state.policyRate = nextRate
            stats.rateMoveAbs += move

        case .reserveRequirement:
            let delta = Double.random(in: -0.04...0.04, using: &simulator.rng)
            let nextReserve = (0.05...0.25).clamping(simulator.state.reserveRequirement + delta)
            let move = abs(nextReserve - simulator.state.reserveRequirement)
            guard move > 0.0001 else { continue }
            simulator.state.reserveRequirement = nextReserve
            stats.reserveMoveAbs += move

        case .controls:
            let delta = Double.random(in: -0.22...0.22, using: &simulator.rng)
            let nextControls = (0.0...1.0).clamping(simulator.state.capitalControls + delta)
            let move = abs(nextControls - simulator.state.capitalControls)
            guard move > 0.0001 else { continue }
            simulator.setCapitalControls(nextControls)
            stats.controlsMoveAbs += move

        case .intervention:
            let sign = Bool.random(using: &simulator.rng) ? 1.0 : -1.0
            let months = sign * Double.random(in: 0.15...0.75, using: &simulator.rng)
            simulator.applyFXIntervention(months: months)
            stats.interventionMonthsAbs += abs(months)
        }

        stats.policyActions += 1
        stats.activeQuarter = true
    }

    return stats
}

private func maybeUseCrisisMeasure(on simulator: EconomicSimulator,
                                   stats: inout BalanceTurnStats) {
    let available = Set(simulator.availableCrisisMeasures().map(\.type))
    guard !available.isEmpty else { return }

    let s = simulator.state
    let chosen: CrisisMeasureType?
    if available.contains(.emergencyLiquidity)
        && s.outputGap < -0.028
        && s.unemployment > 0.088
        && s.inflation < 0.105
        && s.foreignReservesMonths > 1.15
        && s.exchangeRateQoQChange < 0.050 {
        chosen = .emergencyLiquidity
    } else if available.contains(.bankHoliday)
                && (s.foreignReservesMonths < 1.05
                    || (s.exchangeRateQoQChange > 0.045 && s.capitalAccountGDP < -0.006)) {
        chosen = .bankHoliday
    } else if available.contains(.imfProgram)
        && (s.foreignReservesMonths < 0.90
            || (s.foreignReservesMonths < 1.20
                && s.currentAccountGDP < -0.055
                && s.exchangeRateQoQChange > 0.050)
            || s.externalDebtGDP > 0.80) {
        chosen = .imfProgram
    } else {
        chosen = nil
    }

    guard let measure = chosen else { return }
    _ = simulator.enactCrisisMeasure(measure)
    stats.policyActions += 1
    stats.activeQuarter = true
    stats.crisisMeasuresUsed += 1
    switch measure {
    case .imfProgram:
        stats.imfProgramsUsed += 1
    case .bankHoliday:
        stats.bankHolidaysUsed += 1
    case .emergencyLiquidity:
        stats.emergencyLiquidityUsed += 1
    }
}

private func adjustPolicyRate(on simulator: EconomicSimulator,
                              toward target: Double,
                              maxStep: Double,
                              deadband: Double,
                              stats: inout BalanceTurnStats) {
    let delta = target - simulator.state.policyRate
    guard abs(delta) >= deadband else { return }
    let move = min(abs(delta), maxStep) * (delta.sign == .minus ? -1.0 : 1.0)
    simulator.state.policyRate = max(0.0, simulator.state.policyRate + move)
    stats.rateMoveAbs += abs(move)
    stats.policyActions += 1
    stats.activeQuarter = true
}

private func adjustReserveRequirement(on simulator: EconomicSimulator,
                                      toward target: Double,
                                      maxStep: Double,
                                      deadband: Double,
                                      stats: inout BalanceTurnStats) {
    let delta = target - simulator.state.reserveRequirement
    guard abs(delta) >= deadband else { return }
    let move = min(abs(delta), maxStep) * (delta.sign == .minus ? -1.0 : 1.0)
    simulator.state.reserveRequirement = (0.0...0.50).clamping(simulator.state.reserveRequirement + move)
    stats.reserveMoveAbs += abs(move)
    stats.policyActions += 1
    stats.activeQuarter = true
}

private func resolveCabinetDemand(for bot: BalanceBot,
                                  simulator: EconomicSimulator,
                                  stats: inout BalanceTurnStats) {
    guard let request = simulator.activeCabinetRequest else { return }

    let acted: Bool
    switch bot {
    case .passive:
        acted = false

    case .glonzo:
        acted = false

    case .rateOnly:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < 0.08 && simulator.state.foreignReservesMonths > 2.0)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < 1.8)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > 1.4)
        }

    case .fullReactive:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < 0.07
                                        && simulator.state.outputGap < -0.02
                                        && simulator.state.foreignReservesMonths > 2.2)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < 3.0
                                        || simulator.state.exchangeRateQoQChange > 0.015)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > 1.6
                                        && simulator.state.exchangeRateQoQChange > 0.01)
        }
    }

    if acted {
        stats.policyActions += 1
        stats.activeQuarter = true
    }
}

private func resolveCabinet(_ simulator: EconomicSimulator, accept: Bool) -> Bool {
    if accept {
        _ = simulator.acceptCabinetRequest()
    } else {
        _ = simulator.rejectCabinetRequest()
    }
    return true
}

func summarizeBalanceRuns(_ runs: [BalanceRunResult]) -> BalanceSummary {
    precondition(!runs.isEmpty)
    let scores = runs.map(\.score).sorted()
    let totalRuns = runs.count
    let totalQuarters = runs.reduce(0) { $0 + $1.quartersSimulated }
    let totalActiveQuarters = runs.reduce(0) { $0 + $1.activePolicyQuarters }
    let totalPolicyActions = runs.reduce(0) { $0 + $1.totalPolicyActions }
    let totalCrisisMeasuresUsed = runs.reduce(0) { $0 + $1.totalCrisisMeasuresUsed }
    let totalIMFProgramsUsed = runs.reduce(0) { $0 + $1.totalIMFProgramsUsed }
    let totalBankHolidaysUsed = runs.reduce(0) { $0 + $1.totalBankHolidaysUsed }
    let totalEmergencyLiquidityUsed = runs.reduce(0) { $0 + $1.totalEmergencyLiquidityUsed }
    let survivalCount = runs.filter { $0.outcome == .success }.count
    var outcomeCounts: [GameOutcome: Int] = [:]
    for run in runs {
        outcomeCounts[run.outcome, default: 0] += 1
    }
    return BalanceSummary(
        gameLength: runs[0].gameLength,
        mode: runs[0].mode,
        scenarioID: runs[0].scenarioID,
        scenarioTitle: runs[0].scenarioTitle,
        difficulty: runs[0].difficulty,
        bot: runs[0].bot,
        runs: totalRuns,
        survivalRate: Double(survivalCount) / Double(totalRuns),
        medianScore: percentile(scores, 0.50),
        p25Score: percentile(scores, 0.25),
        p75Score: percentile(scores, 0.75),
        averageActiveQuarterRate: totalQuarters == 0 ? 0.0 : Double(totalActiveQuarters) / Double(totalQuarters),
        averagePolicyActions: Double(totalPolicyActions) / Double(totalRuns),
        averageQuartersSimulated: Double(totalQuarters) / Double(totalRuns),
        averageRateMoveAbs: runs.map(\.totalRateMoveAbs).reduce(0, +) / Double(totalRuns),
        averageControlsMoveAbs: runs.map(\.totalControlsMoveAbs).reduce(0, +) / Double(totalRuns),
        averageInterventionMonthsAbs: runs.map(\.totalInterventionMonthsAbs).reduce(0, +) / Double(totalRuns),
        averageCrisisMeasuresUsed: Double(totalCrisisMeasuresUsed) / Double(totalRuns),
        averageIMFProgramsUsed: Double(totalIMFProgramsUsed) / Double(totalRuns),
        averageBankHolidaysUsed: Double(totalBankHolidaysUsed) / Double(totalRuns),
        averageEmergencyLiquidityUsed: Double(totalEmergencyLiquidityUsed) / Double(totalRuns),
        averageFinalInflation: runs.map(\.finalInflation).reduce(0, +) / Double(totalRuns),
        averageLowestReserves: runs.map(\.lowestReserves).reduce(0, +) / Double(totalRuns),
        averageLowestCredibility: runs.map(\.lowestCredibility).reduce(0, +) / Double(totalRuns),
        averagePeakPoliticalPressure: runs.map(\.peakPoliticalPressure).reduce(0, +) / Double(totalRuns),
        outcomeCounts: outcomeCounts.reduce(into: [:]) { partial, item in
            partial[item.key.label] = item.value
        })
}

private func percentile(_ sortedValues: [Int], _ q: Double) -> Int {
    guard let first = sortedValues.first else { return 0 }
    if sortedValues.count == 1 { return first }
    let idx = Int((Double(sortedValues.count - 1) * q).rounded())
    return sortedValues[max(0, min(sortedValues.count - 1, idx))]
}

private func printBalanceSummaries(_ summaries: [BalanceSummary]) {
    let includesScenarios = summaries.contains { $0.scenarioTitle != nil }
    let sorted = summaries.sorted {
        ($0.scenarioTitle ?? "", $0.gameLength.displayName, $0.mode.displayName, $0.difficulty.displayName, $0.bot.displayName)
            < ($1.scenarioTitle ?? "", $1.gameLength.displayName, $1.mode.displayName, $1.difficulty.displayName, $1.bot.displayName)
    }

    let header =
        column("Length", 9) +
        column("Mode", 11) +
        (includesScenarios ? column("Scenario", 24) : "") +
        column("Difficulty", 10) +
        column("Bot", 13) +
        column("Runs", 5, rightAligned: true) +
        column("Survive", 9, rightAligned: true) +
        column("Median", 8, rightAligned: true) +
        column("Score IQR", 11, rightAligned: true) +
        column("Avg Qtrs", 9, rightAligned: true) +
        column("ActiveQ%", 10, rightAligned: true) +
        column("Acts/Run", 10, rightAligned: true) +
        column("Rate pp", 10, rightAligned: true) +
        column("Ctrl Steps", 11, rightAligned: true) +
        column("FX Mo", 9, rightAligned: true)
    print(header)
    print(String(repeating: "-", count: header.count))

    for s in sorted {
        let row =
            column(s.gameLength.displayName, 9) +
            column(s.mode.displayName, 11) +
            (includesScenarios ? column(s.scenarioTitle ?? "-", 24) : "") +
            column(s.difficulty.displayName, 10) +
            column(s.bot.displayName, 13) +
            column("\(s.runs)", 5, rightAligned: true) +
            column(String(format: "%.0f%%", s.survivalRate * 100.0), 9, rightAligned: true) +
            column("\(s.medianScore)", 8, rightAligned: true) +
            column("\(s.p25Score)-\(s.p75Score)", 11, rightAligned: true) +
            column(String(format: "%.1f", s.averageQuartersSimulated), 9, rightAligned: true) +
            column(String(format: "%.0f%%", s.averageActiveQuarterRate * 100.0), 10, rightAligned: true) +
            column(String(format: "%.1f", s.averagePolicyActions), 10, rightAligned: true) +
            column(String(format: "%.1f", s.averageRateMoveAbs * 100.0), 10, rightAligned: true) +
            column(String(format: "%.1f", s.averageControlsMoveAbs * 10.0), 11, rightAligned: true) +
            column(String(format: "%.1f", s.averageInterventionMonthsAbs), 9, rightAligned: true)
        print(row)
        print("  Outcomes: \(outcomeSummary(s.outcomeCounts))")
        print(String(format: "  Crisis use %.2f/run | IMF %.2f | Holiday %.2f | Liquidity %.2f",
                     s.averageCrisisMeasuresUsed,
                     s.averageIMFProgramsUsed,
                     s.averageBankHolidaysUsed,
                     s.averageEmergencyLiquidityUsed))
        print(String(format: "  Avg final CPI %.1f%% | Avg low reserves %.1f mo | Avg cred trough %.0f%% | Avg peak pressure %.0f",
                     s.averageFinalInflation * 100.0,
                     s.averageLowestReserves,
                     s.averageLowestCredibility * 100.0,
                     s.averagePeakPoliticalPressure))
    }
}

private func column(_ value: String, _ width: Int, rightAligned: Bool = false) -> String {
    let clipped = value.count > width ? String(value.prefix(width)) : value
    let padding = String(repeating: " ", count: max(0, width - clipped.count))
    return rightAligned ? padding + clipped + " " : clipped + padding + " "
}

private func printBalanceDiagnostics(_ summaries: [BalanceSummary]) {
    let passiveFlags = summaries.filter {
        $0.bot == .passive && $0.survivalRate >= 0.70 && $0.medianScore >= 75
    }
    guard !passiveFlags.isEmpty else { return }

    print("")
    print("Diagnostics")
    for summary in passiveFlags.sorted(by: {
        ($0.scenarioTitle ?? "", $0.gameLength.displayName, $0.mode.displayName, $0.difficulty.displayName)
            < ($1.scenarioTitle ?? "", $1.gameLength.displayName, $1.mode.displayName, $1.difficulty.displayName)
    }) {
        let cellLabel = summary.scenarioTitle.map { "\($0) / \(summary.difficulty.displayName)" }
            ?? "\(summary.gameLength.displayName) \(summary.mode.displayName) \(summary.difficulty.displayName)"
        print("  Passive looks too safe in \(cellLabel): " +
              "survive \(String(format: "%.0f%%", summary.survivalRate * 100.0)), " +
              "median score \(summary.medianScore).")
    }
}

private func outcomeSummary(_ counts: [String: Int]) -> String {
    let order = ["Success", "Currency", "Hyperinfl", "Depress", "Ouster"]
    return order.compactMap { outcome in
        guard let count = counts[outcome], count > 0 else { return nil }
        return "\(outcome): \(count)"
    }.joined(separator: " | ")
}

extension GameMode {
    static let allCasesForBalance: [GameMode] = [.historical, .randomized]

    var displayName: String {
        switch self {
        case .historical: return "Historical"
        case .randomized: return "Randomized"
        }
    }
}

private struct BalanceReport: Codable {
    let generatedAt: String
    let runsPerCell: Int
    let baseSeed: UInt64
    let scenarioIDs: [String]?
    let summaries: [BalanceSummary]
}

private func writeBalanceReport(_ summaries: [BalanceSummary],
                                config: BalanceConfig,
                                to path: String) throws {
    let report = BalanceReport(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        runsPerCell: config.runsPerCell,
        baseSeed: config.baseSeed,
        scenarioIDs: config.scenarioIDs,
        summaries: summaries)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    try data.write(to: url, options: .atomic)
}

private extension GameOutcome {
    var label: String {
        switch self {
        case .ongoing: return "Ongoing"
        case .currencyCrisis: return "Currency"
        case .hyperinflation: return "Hyperinfl"
        case .depression: return "Depress"
        case .politicalOuster: return "Ouster"
        case .success: return "Success"
        }
    }
}
