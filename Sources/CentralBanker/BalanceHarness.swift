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
        + 0.50 * s.outputGap
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
        + 0.75 * s.outputGap
        + reserveStress
        + fxStress)
    adjustPolicyRate(on: simulator, toward: targetRate, maxStep: 0.015, deadband: 0.010, stats: &stats)

    if simulator.state.inflation > 0.10
        && simulator.state.bankCreditGrowth > 0.13
        && simulator.state.foreignReservesMonths > 2.4
        && simulator.state.reserveRequirement < 0.22 {
        adjustReserveRequirement(on: simulator,
                                 toward: (0.06...0.24).clamping(simulator.state.reserveRequirement + 0.03),
                                 maxStep: 0.03,
                                 deadband: 0.010,
                                 stats: &stats)
    }

    let earlyExternalDefense = simulator.state.inflation > 0.10
        && (simulator.state.exchangeRateQoQChange > 0.015
            || simulator.state.currentAccountGDP < -0.025
            || simulator.state.capitalAccountGDP < -0.005)
    let controlsCeiling = earlyExternalDefense && simulator.state.foreignReservesMonths > 1.8 ? 0.45 : 0.9
    if ((simulator.state.foreignReservesMonths < 2.8 && simulator.state.exchangeRateQoQChange > 0.020)
        || earlyExternalDefense)
        && simulator.state.capitalControls < controlsCeiling {
        let move = earlyExternalDefense ? min(0.08, controlsCeiling - simulator.state.capitalControls)
                                        : min(0.15, controlsCeiling - simulator.state.capitalControls)
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
    if simulator.state.foreignReservesMonths > 2.6
        && simulator.state.exchangeRateQoQChange >= 0.020
        && earlyExternalDefense {
        interventionMonths = -min(0.35, simulator.state.foreignReservesMonths - 1.5)
    } else if simulator.state.foreignReservesMonths > 2.2 && simulator.state.exchangeRateQoQChange > 0.030 {
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

    let stillNeedsHawkishGuidance =
        (simulator.state.inflation > 0.09
            && (simulator.state.outputGap > -0.015 || simulator.state.exchangeRateQoQChange > 0.025))
        || simulator.state.exchangeRateQoQChange > 0.035
    let coolingEnoughToStopJawboning =
        simulator.state.outputGap < -0.02
        && simulator.state.inflation < 0.12
        && simulator.state.exchangeRateQoQChange < 0.035

    if stillNeedsHawkishGuidance {
        if simulator.communicationStance != .hawkish {
            simulator.communicationStance = .hawkish
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.communicationStance == .hawkish && coolingEnoughToStopJawboning {
        simulator.communicationStance = .balanced
        stats.policyActions += 1
        stats.activeQuarter = true
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
    let availableMeasures = simulator.availableCrisisMeasures().map(\.type)
    if !availableMeasures.isEmpty
        && Double.random(in: 0...1, using: &simulator.rng) < 0.20 {
        let idx = Int.random(in: 0..<availableMeasures.count, using: &simulator.rng)
        let measure = availableMeasures[idx]
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

struct ValidationSummary: Codable {
    var profileID: String
    var profileTitle: String
    var gameLength: GameLength
    var mode: GameMode
    var horizonQuarters: Int
    var difficulty: Difficulty
    var bot: BalanceBot
    var runs: Int
    var survivalRate: Double
    var medianScore: Int
    var averageQuartersSimulated: Double
    var averageFinalInflation: Double
    var averageFinalOutputGap: Double
    var averageFinalReserves: Double
    var averageFinalCredibility: Double
    var averageFinalApproval: Double
    var averageFinalExternalDebt: Double
    var averageFinalExchangeRateChange: Double
    var averagePeakInflation: Double
    var averageLowestReserves: Double
    var outcomeCounts: [String: Int]
}

struct ValidationFinding: Codable {
    var profileID: String
    var difficulty: Difficulty?
    var headline: String
    var detail: String
}

private struct ValidationRunResult {
    var profileID: String
    var profileTitle: String
    var gameLength: GameLength
    var mode: GameMode
    var horizonQuarters: Int
    var difficulty: Difficulty
    var bot: BalanceBot
    var outcome: GameOutcome
    var score: Int
    var quartersSimulated: Int
    var finalInflation: Double
    var finalOutputGap: Double
    var finalReserves: Double
    var finalCredibility: Double
    var finalApproval: Double
    var finalExternalDebt: Double
    var finalExchangeRateChange: Double
    var peakInflation: Double
    var lowestReserves: Double
}

private struct ValidationProfile {
    let id: String
    let title: String
    let gameLength: GameLength
    let mode: GameMode
    let horizonQuarters: Int
    let apply: (inout EconomicState, inout ExternalEnvironment) -> Void
}

private struct ValidationReport: Codable {
    let generatedAt: String
    let runsPerCell: Int
    let baseSeed: UInt64
    let summaries: [ValidationSummary]
    let findings: [ValidationFinding]
}

func runValidationHarness(_ config: BalanceConfig) {
    let profiles = validationProfiles().filter {
        config.lengths.contains($0.gameLength) && config.modes.contains($0.mode)
    }
    guard !profiles.isEmpty else {
        print("Model validation harness")
        print("  No validation profiles matched the requested length/mode filters.")
        return
    }

    print("Model validation harness")
    print("  Runs per cell: \(config.runsPerCell)")
    print("  Base seed: \(config.baseSeed)")
    print("  Profiles: \(profiles.count)")
    print("")

    var summaries: [ValidationSummary] = []
    for profile in profiles {
        for difficulty in config.difficulties {
            for bot in config.bots {
                var runs: [ValidationRunResult] = []
                for i in 0..<config.runsPerCell {
                    let seed = config.baseSeed &+ UInt64(i)
                    runs.append(runValidationProfile(profile, difficulty: difficulty, bot: bot, seed: seed))
                }
                summaries.append(summarizeValidationRuns(runs))
            }
        }
    }

    let findings = validationFindings(from: summaries)
    printValidationSummaries(summaries)
    printValidationFindings(findings)
    if let path = config.reportPath {
        do {
            try writeValidationReport(summaries, findings: findings, config: config, to: path)
            print("")
            print("Wrote validation report to \(resolvedSavePath(path))")
        } catch {
            print("")
            print("Failed to write validation report: \(error)")
        }
    }
}

private func runValidationProfile(_ profile: ValidationProfile,
                                  difficulty: Difficulty,
                                  bot: BalanceBot,
                                  seed: UInt64) -> ValidationRunResult {
    let session = GameSession(
        mode: profile.mode,
        gameLength: profile.gameLength,
        difficulty: difficulty,
        scenarioID: nil,
        sessionSeed: seed)

    profile.apply(&session.simulator.state, &session.simulator.environment)

    var outcome: GameOutcome = .ongoing
    for _ in 0..<profile.horizonQuarters {
        _ = applyBalanceBotTurn(bot, to: session.simulator)
        outcome = session.advance()
        if outcome != .ongoing { break }
    }

    let currentOutcome = outcome == .ongoing ? session.currentOutcome() : outcome
    let score = computeValidationScore(
        outcome: currentOutcome,
        simulator: session.simulator,
        gameLength: profile.gameLength,
        horizonQuarters: profile.horizonQuarters
    )

    return ValidationRunResult(
        profileID: profile.id,
        profileTitle: profile.title,
        gameLength: profile.gameLength,
        mode: profile.mode,
        horizonQuarters: profile.horizonQuarters,
        difficulty: difficulty,
        bot: bot,
        outcome: currentOutcome,
        score: score,
        quartersSimulated: session.simulator.scoreCard.quartersSimulated,
        finalInflation: session.simulator.state.inflation,
        finalOutputGap: session.simulator.state.outputGap,
        finalReserves: session.simulator.state.foreignReservesMonths,
        finalCredibility: session.simulator.state.credibility,
        finalApproval: session.simulator.state.publicApproval,
        finalExternalDebt: session.simulator.state.externalDebtGDP,
        finalExchangeRateChange: session.simulator.state.exchangeRateQoQChange,
        peakInflation: session.simulator.scoreCard.peakInflation,
        lowestReserves: session.simulator.scoreCard.lowestReserves
    )
}

private func summarizeValidationRuns(_ runs: [ValidationRunResult]) -> ValidationSummary {
    precondition(!runs.isEmpty)
    let totalRuns = runs.count
    let scores = runs.map(\.score).sorted()
    let survivalCount = runs.filter { $0.outcome == .success || $0.outcome == .ongoing }.count
    var outcomeCounts: [GameOutcome: Int] = [:]
    for run in runs {
        outcomeCounts[run.outcome, default: 0] += 1
    }

    return ValidationSummary(
        profileID: runs[0].profileID,
        profileTitle: runs[0].profileTitle,
        gameLength: runs[0].gameLength,
        mode: runs[0].mode,
        horizonQuarters: runs[0].horizonQuarters,
        difficulty: runs[0].difficulty,
        bot: runs[0].bot,
        runs: totalRuns,
        survivalRate: Double(survivalCount) / Double(totalRuns),
        medianScore: percentile(scores, 0.50),
        averageQuartersSimulated: Double(runs.map(\.quartersSimulated).reduce(0, +)) / Double(totalRuns),
        averageFinalInflation: runs.map(\.finalInflation).reduce(0, +) / Double(totalRuns),
        averageFinalOutputGap: runs.map(\.finalOutputGap).reduce(0, +) / Double(totalRuns),
        averageFinalReserves: runs.map(\.finalReserves).reduce(0, +) / Double(totalRuns),
        averageFinalCredibility: runs.map(\.finalCredibility).reduce(0, +) / Double(totalRuns),
        averageFinalApproval: runs.map(\.finalApproval).reduce(0, +) / Double(totalRuns),
        averageFinalExternalDebt: runs.map(\.finalExternalDebt).reduce(0, +) / Double(totalRuns),
        averageFinalExchangeRateChange: runs.map(\.finalExchangeRateChange).reduce(0, +) / Double(totalRuns),
        averagePeakInflation: runs.map(\.peakInflation).reduce(0, +) / Double(totalRuns),
        averageLowestReserves: runs.map(\.lowestReserves).reduce(0, +) / Double(totalRuns),
        outcomeCounts: outcomeCounts.reduce(into: [:]) { partial, item in
            partial[item.key.label] = item.value
        }
    )
}

func validationFindings(from summaries: [ValidationSummary]) -> [ValidationFinding] {
    struct Key: Hashable {
        let profileID: String
        let difficulty: Difficulty
        let bot: BalanceBot
    }

    let summaryByKey = Dictionary(uniqueKeysWithValues: summaries.map {
        (Key(profileID: $0.profileID, difficulty: $0.difficulty, bot: $0.bot), $0)
    })

    func summary(_ profileID: String, _ difficulty: Difficulty, _ bot: BalanceBot) -> ValidationSummary? {
        summaryByKey[Key(profileID: profileID, difficulty: difficulty, bot: bot)]
    }

    func outcomeCount(_ summary: ValidationSummary?, _ label: String) -> Int {
        summary?.outcomeCounts[label] ?? 0
    }

    var findings: [ValidationFinding] = []

    for difficulty in Difficulty.allCases {
        if let passive = summary("overheating_credit_boom", difficulty, .passive),
           let rateOnly = summary("overheating_credit_boom", difficulty, .rateOnly),
           let reactive = summary("overheating_credit_boom", difficulty, .fullReactive),
           let glonzo = summary("overheating_credit_boom", difficulty, .glonzo) {
            if rateOnly.averageFinalInflation >= passive.averageFinalInflation - 0.002 {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Tightening is not cooling an overheated economy",
                    detail: "RateOnly finished with average inflation \(pct(rateOnly.averageFinalInflation)), versus passive \(pct(passive.averageFinalInflation)). That suggests policy tightening is not reliably reducing inflation in the overheating profile."
                ))
            }
            if reactive.averageFinalInflation >= passive.averageFinalInflation - 0.005 {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Full toolkit is not materially better than passive in an overheating boom",
                    detail: "FullReactive ended with average inflation \(pct(reactive.averageFinalInflation)) versus passive \(pct(passive.averageFinalInflation)). Expected gap is missing."
                ))
            }
            if glonzo.medianScore > reactive.medianScore + 1 {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Random flailing is scoring as well as deliberate policy in overheating conditions",
                    detail: "Glonzo median score \(glonzo.medianScore) is not below FullReactive \(reactive.medianScore)."
                ))
            }
        }

        if let passive = summary("reserve_run", difficulty, .passive),
           let reactive = summary("reserve_run", difficulty, .fullReactive) {
            if reactive.survivalRate <= passive.survivalRate {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Reserve-defense toolkit is not improving survival under a run",
                    detail: "FullReactive survival \(pct(reactive.survivalRate)) versus passive \(pct(passive.survivalRate))."
                ))
            }
            if reactive.averageLowestReserves <= passive.averageLowestReserves + 0.10 {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Reserve-defense actions are not preserving reserves in a reserve run",
                    detail: "FullReactive average reserve trough \(months(reactive.averageLowestReserves)) versus passive \(months(passive.averageLowestReserves))."
                ))
            }
            if outcomeCount(reactive, "Currency") >= outcomeCount(passive, "Currency") {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Currency crises are not falling under active reserve defense",
                    detail: "FullReactive currency-crisis count \(outcomeCount(reactive, "Currency")) versus passive \(outcomeCount(passive, "Currency"))."
                ))
            }
        }

        if let passive = summary("deep_recession", difficulty, .passive),
           let rateOnly = summary("deep_recession", difficulty, .rateOnly),
           let reactive = summary("deep_recession", difficulty, .fullReactive),
           let glonzo = summary("deep_recession", difficulty, .glonzo) {
            if reactive.averageFinalOutputGap + 0.005 < rateOnly.averageFinalOutputGap {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "FullReactive is not supporting recovery better than rate-only policy",
                    detail: "FullReactive average output gap \(pctSigned(reactive.averageFinalOutputGap)) versus RateOnly \(pctSigned(rateOnly.averageFinalOutputGap))."
                ))
            }
            if reactive.averageFinalApproval + 2.0 < passive.averageFinalApproval {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Active recession management is not improving political outcomes",
                    detail: "FullReactive average approval \(String(format: "%.1f", reactive.averageFinalApproval)) versus passive \(String(format: "%.1f", passive.averageFinalApproval))."
                ))
            }
            if glonzo.medianScore >= reactive.medianScore {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Random policy is performing too well in recession management",
                    detail: "Glonzo median score \(glonzo.medianScore) versus FullReactive \(reactive.medianScore)."
                ))
            }
        }

        if let passive = summary("capital_lockdown", difficulty, .passive),
           let reactive = summary("capital_lockdown", difficulty, .fullReactive) {
            if reactive.averageFinalCredibility <= passive.averageFinalCredibility {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Unwinding heavy controls is not restoring credibility",
                    detail: "FullReactive average credibility \(pct(reactive.averageFinalCredibility)) versus passive \(pct(passive.averageFinalCredibility))."
                ))
            }
            if reactive.averageFinalApproval <= passive.averageFinalApproval {
                findings.append(.init(
                    profileID: passive.profileID,
                    difficulty: difficulty,
                    headline: "Heavy controls are not generating the expected political drag",
                    detail: "FullReactive average approval \(String(format: "%.1f", reactive.averageFinalApproval)) versus passive \(String(format: "%.1f", passive.averageFinalApproval))."
                ))
            }
        }
    }

    let profileIDs = Set(summaries.map(\.profileID))
    for profileID in profileIDs {
        for bot in BalanceBot.allCases {
            guard let apprentice = summary(profileID, .apprentice, bot),
                  let governor = summary(profileID, .governor, bot),
                  let volcker = summary(profileID, .volcker, bot) else { continue }

            if apprentice.survivalRate + 0.02 < governor.survivalRate {
                findings.append(.init(
                    profileID: profileID,
                    difficulty: nil,
                    headline: "Difficulty ordering is inverted between Apprentice and Governor",
                    detail: "\(bot.displayName) survives \(pct(apprentice.survivalRate)) on Apprentice versus \(pct(governor.survivalRate)) on Governor for \(profileID)."
                ))
            }
            if governor.survivalRate + 0.02 < volcker.survivalRate {
                findings.append(.init(
                    profileID: profileID,
                    difficulty: nil,
                    headline: "Difficulty ordering is inverted between Governor and Volcker",
                    detail: "\(bot.displayName) survives \(pct(governor.survivalRate)) on Governor versus \(pct(volcker.survivalRate)) on Volcker for \(profileID)."
                ))
            }
        }
    }

    return findings
}

private func printValidationSummaries(_ summaries: [ValidationSummary]) {
    let header =
        column("Profile", 22) +
        column("Length", 9) +
        column("Difficulty", 10) +
        column("Bot", 13) +
        column("Runs", 5, rightAligned: true) +
        column("Survive", 9, rightAligned: true) +
        column("Median", 8, rightAligned: true) +
        column("Final CPI", 10, rightAligned: true) +
        column("Gap", 8, rightAligned: true) +
        column("Reserves", 10, rightAligned: true) +
        column("Cred", 8, rightAligned: true) +
        column("Appr", 8, rightAligned: true) +
        column("ExtDebt", 9, rightAligned: true)
    print(header)
    print(String(repeating: "-", count: header.count))

    let sorted = summaries.sorted {
        ($0.profileTitle, $0.difficulty.displayName, $0.bot.displayName)
            < ($1.profileTitle, $1.difficulty.displayName, $1.bot.displayName)
    }

    for s in sorted {
        let row =
            column(s.profileTitle, 22) +
            column(s.gameLength.displayName, 9) +
            column(s.difficulty.displayName, 10) +
            column(s.bot.displayName, 13) +
            column("\(s.runs)", 5, rightAligned: true) +
            column(String(format: "%.0f%%", s.survivalRate * 100.0), 9, rightAligned: true) +
            column("\(s.medianScore)", 8, rightAligned: true) +
            column(String(format: "%.1f%%", s.averageFinalInflation * 100.0), 10, rightAligned: true) +
            column(String(format: "%+.1f%%", s.averageFinalOutputGap * 100.0), 8, rightAligned: true) +
            column(String(format: "%.1f mo", s.averageFinalReserves), 10, rightAligned: true) +
            column(String(format: "%.0f%%", s.averageFinalCredibility * 100.0), 8, rightAligned: true) +
            column(String(format: "%.0f", s.averageFinalApproval), 8, rightAligned: true) +
            column(String(format: "%.0f%%", s.averageFinalExternalDebt * 100.0), 9, rightAligned: true)
        print(row)
        print("  Outcomes: \(outcomeSummary(s.outcomeCounts))")
    }
}

private func printValidationFindings(_ findings: [ValidationFinding]) {
    print("")
    print("Validation findings")
    if findings.isEmpty {
        print("  No obvious common-sense or reference-model anomalies were detected.")
        return
    }

    for finding in findings {
        let difficultyText = finding.difficulty.map { " [\($0.displayName)]" } ?? ""
        print("  - \(finding.headline)\(difficultyText)")
        print("    \(finding.detail)")
    }
}

private func writeValidationReport(_ summaries: [ValidationSummary],
                                   findings: [ValidationFinding],
                                   config: BalanceConfig,
                                   to path: String) throws {
    let report = ValidationReport(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        runsPerCell: config.runsPerCell,
        baseSeed: config.baseSeed,
        summaries: summaries,
        findings: findings
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    try data.write(to: url, options: .atomic)
}

private func validationProfiles() -> [ValidationProfile] {
    [
        ValidationProfile(
            id: "overheating_credit_boom",
            title: "Overheating Boom",
            gameLength: .short,
            mode: .randomized,
            horizonQuarters: 8
        ) { state, environment in
            state.inflation = 0.140
            state.coreInflation = 0.126
            state.expectedInflation = 0.112
            state.outputGap = 0.042
            state.gdpGrowthQoQ = 0.018
            state.unemployment = 0.054
            state.policyRate = 0.060
            state.reserveRequirement = 0.10
            state.m2Growth = 0.145
            state.bankCreditGrowth = 0.170
            state.credibility = 0.58
            state.exchangeRate = 2.35
            state.exchangeRateQoQChange = 0.030
            state.currentAccountGDP = -0.035
            state.capitalAccountGDP = -0.008
            state.foreignReservesMonths = 3.1
            state.capitalControls = 0.12
            state.externalDebtGDP = 0.42
            state.politicalPressure = 42.0
            state.publicApproval = 49.0
            environment.worldInterestRate = 0.055
            environment.worldInflation = 0.045
            environment.tradingPartnerGrowth = 0.030
        },
        ValidationProfile(
            id: "reserve_run",
            title: "Reserve Run",
            gameLength: .short,
            mode: .randomized,
            horizonQuarters: 6
        ) { state, environment in
            state.inflation = 0.095
            state.coreInflation = 0.082
            state.expectedInflation = 0.086
            state.outputGap = -0.010
            state.gdpGrowthQoQ = -0.004
            state.unemployment = 0.080
            state.policyRate = 0.080
            state.reserveRequirement = 0.12
            state.m2Growth = 0.082
            state.bankCreditGrowth = 0.080
            state.credibility = 0.46
            state.exchangeRate = 2.65
            state.exchangeRateQoQChange = 0.070
            state.currentAccountGDP = -0.060
            state.capitalAccountGDP = -0.045
            state.foreignReservesMonths = 1.15
            state.capitalControls = 0.15
            state.externalDebtGDP = 0.72
            state.politicalPressure = 74.0
            state.publicApproval = 36.0
            environment.worldInterestRate = 0.090
            environment.worldInflation = 0.045
            environment.tradingPartnerGrowth = 0.010
        },
        ValidationProfile(
            id: "deep_recession",
            title: "Deep Recession",
            gameLength: .extended,
            mode: .randomized,
            horizonQuarters: 8
        ) { state, environment in
            state.inflation = 0.035
            state.coreInflation = 0.032
            state.expectedInflation = 0.040
            state.outputGap = -0.055
            state.gdpGrowthQoQ = -0.015
            state.unemployment = 0.110
            state.policyRate = 0.090
            state.reserveRequirement = 0.14
            state.m2Growth = 0.050
            state.bankCreditGrowth = 0.030
            state.credibility = 0.63
            state.exchangeRate = 2.20
            state.exchangeRateQoQChange = 0.010
            state.currentAccountGDP = -0.018
            state.capitalAccountGDP = -0.005
            state.foreignReservesMonths = 3.8
            state.capitalControls = 0.20
            state.externalDebtGDP = 0.48
            state.politicalPressure = 66.0
            state.publicApproval = 34.0
            environment.worldInterestRate = 0.050
            environment.worldInflation = 0.030
            environment.tradingPartnerGrowth = 0.000
        },
        ValidationProfile(
            id: "debt_overhang",
            title: "Debt Overhang",
            gameLength: .extended,
            mode: .randomized,
            horizonQuarters: 12
        ) { state, environment in
            state.inflation = 0.072
            state.coreInflation = 0.064
            state.expectedInflation = 0.075
            state.outputGap = -0.012
            state.gdpGrowthQoQ = -0.003
            state.unemployment = 0.082
            state.policyRate = 0.090
            state.reserveRequirement = 0.12
            state.m2Growth = 0.078
            state.bankCreditGrowth = 0.072
            state.credibility = 0.52
            state.exchangeRate = 2.55
            state.exchangeRateQoQChange = 0.035
            state.currentAccountGDP = -0.045
            state.capitalAccountGDP = -0.015
            state.foreignReservesMonths = 2.1
            state.capitalControls = 0.28
            state.externalDebtGDP = 0.98
            state.politicalPressure = 61.0
            state.publicApproval = 41.0
            environment.worldInterestRate = 0.075
            environment.worldInflation = 0.035
            environment.tradingPartnerGrowth = 0.012
        },
        ValidationProfile(
            id: "capital_lockdown",
            title: "Capital Lockdown",
            gameLength: .extended,
            mode: .randomized,
            horizonQuarters: 12
        ) { state, environment in
            state.inflation = 0.060
            state.coreInflation = 0.054
            state.expectedInflation = 0.064
            state.outputGap = 0.000
            state.gdpGrowthQoQ = 0.006
            state.unemployment = 0.076
            state.policyRate = 0.070
            state.reserveRequirement = 0.12
            state.m2Growth = 0.078
            state.bankCreditGrowth = 0.090
            state.credibility = 0.60
            state.exchangeRate = 2.05
            state.exchangeRateQoQChange = -0.005
            state.currentAccountGDP = 0.008
            state.capitalAccountGDP = 0.002
            state.foreignReservesMonths = 5.4
            state.capitalControls = 0.75
            state.externalDebtGDP = 0.40
            state.politicalPressure = 45.0
            state.publicApproval = 46.0
            environment.worldInterestRate = 0.055
            environment.worldInflation = 0.030
            environment.tradingPartnerGrowth = 0.020
        }
    ]
}

func computeValidationScore(outcome: GameOutcome,
                            simulator: EconomicSimulator,
                            gameLength: GameLength,
                            horizonQuarters: Int) -> Int {
    let card = simulator.scoreCard
    var score = computeScore(outcome: outcome, card: card, gameLength: gameLength).final
    guard outcome == .ongoing else { return score }

    let s = simulator.state
    let persistentHighInflation = card.highInflationQuarters >= max(2, horizonQuarters / 3)
    if persistentHighInflation {
        score -= 12
    }
    if card.severeInflationQuarters > 0 || s.inflation > 0.14 {
        score -= 12
    }
    if s.foreignReservesMonths < 1.5 {
        score -= 8
    } else if s.foreignReservesMonths < 2.0 {
        score -= 4
    }
    if s.credibility < 0.40 {
        score -= 5
    }
    if s.inflation > 0.10 && s.outputGap < -0.02 && s.foreignReservesMonths > 1.5 {
        score += 6
    }
    if s.inflation > 0.10 && s.outputGap < -0.03 && s.foreignReservesMonths > 1.5 {
        score += 4
    }
    if s.inflation > 0.10 && s.outputGap < -0.035 && s.foreignReservesMonths > 1.5 {
        score += 3
    }
    if s.inflation > 0.10 && s.outputGap < -0.04 && s.foreignReservesMonths > 1.5 {
        score += 2
    }
    if s.inflation > 0.15 && s.outputGap > 0.025 {
        score -= 16
    } else if s.inflation > 0.13 && s.outputGap > 0.015 {
        score -= 10
    } else if s.inflation > 0.11 && s.outputGap > 0.01 {
        score -= 6
    }
    if s.outputGap > 0.025 {
        score -= 4
    }
    if s.inflation > 0.10 && s.outputGap > 0.01 {
        score -= 5
    }
    return max(0, min(100, score))
}

private func pct(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100.0)
}

private func pctSigned(_ value: Double) -> String {
    String(format: "%+.1f%%", value * 100.0)
}

private func months(_ value: Double) -> String {
    String(format: "%.1f months", value)
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
