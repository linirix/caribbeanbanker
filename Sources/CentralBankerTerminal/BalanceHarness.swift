import Foundation
import CentralBankerCore

enum BalanceBot: String, CaseIterable, Codable {
    case passive
    case rateOnly = "rate_only"
    case fullReactive = "full_reactive"
    case hawkish
    case balanced
    case dovish
    case glonzo

    var displayName: String {
        switch self {
        case .passive: return "Passive"
        case .rateOnly: return "RateOnly"
        case .fullReactive: return "FullReactive"
        case .hawkish: return "Hawkish"
        case .balanced: return "Balanced"
        case .dovish: return "Dovish"
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
                                     gameLength: gameLength,
                                     difficulty: difficulty).final
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
    case .hawkish:
        return applyStyleBot(.hawkish, to: simulator)
    case .balanced:
        return applyStyleBot(.balanced, to: simulator)
    case .dovish:
        return applyStyleBot(.dovish, to: simulator)
    case .glonzo:
        return applyGlonzoBot(to: simulator)
    }
}

private enum PolicyStyle {
    case hawkish
    case balanced
    case dovish
}

private enum BalanceBotTuning {
    enum Shared {
        static let policyRateRange: ClosedRange<Double> = 0.0...0.28
        static let reserveRequirementRange: ClosedRange<Double> = 0.05...0.25
        static let reserveAdjustmentRange: ClosedRange<Double> = 0.0...0.50
        static let capitalControlsRange: ClosedRange<Double> = 0.0...1.0
    }

    enum RateOnly {
        static let inflationTarget = 0.05
        static let reserveStressFloor = 2.5
        static let reserveStressWeight = 0.010
        static let inflationWeight = 1.10
        static let outputWeight = 0.50
        static let maxRateStep = 0.010
        static let deadband = 0.0075
        static let maxPolicyRate = 0.25
        static let cabinetCutInflationCeiling = 0.08
        static let cabinetCutReserveFloor = 2.0
        static let cabinetControlsReserveTrigger = 1.8
        static let cabinetDefendReserveFloor = 1.4
    }

    enum FullReactive {
        static let inflationTarget = 0.05
        static let reserveStressFloor = 2.7
        static let reserveStressWeight = 0.010
        static let fxStressTrigger = 0.015
        static let fxStressWeight = 0.75
        static let inflationWeight = 1.35
        static let outputWeight = 0.75
        static let maxRateStep = 0.015
        static let deadband = 0.010
        static let reserveTightenInflation = 0.10
        static let reserveTightenCredit = 0.13
        static let reserveTightenReserveFloor = 2.4
        static let reserveTightenCeiling = 0.22
        static let reserveTightenStep = 0.03
        static let reserveTightenRange: ClosedRange<Double> = 0.06...0.24
        static let earlyDefenseInflation = 0.10
        static let earlyDefenseFXChange = 0.015
        static let earlyDefenseCurrentAccount = -0.025
        static let earlyDefenseCapitalAccount = -0.005
        static let stressedControlsReserveFloor = 1.8
        static let stressedControlsCeiling = 0.45
        static let emergencyControlsCeiling = 0.90
        static let stressedControlsStep = 0.08
        static let emergencyControlsStep = 0.15
        static let controlsUnwindReserveFloor = 5.2
        static let controlsUnwindInflationCeiling = 0.08
        static let controlsUnwindFloor = 0.20
        static let controlsUnwindStep = 0.10
        static let controlsDefenseReserveFloor = 2.8
        static let controlsDefenseFXChange = 0.020
        static let interventionEarlyReserveFloor = 2.6
        static let interventionEarlyFXChange = 0.020
        static let interventionEarlyMaxMonths = 0.35
        static let interventionEarlyReserveBuffer = 1.5
        static let interventionReserveFloor = 2.2
        static let interventionFXChange = 0.030
        static let interventionMaxMonths = 0.50
        static let interventionReserveBuffer = 1.2
        static let interventionLastStandReserveFloor = 1.6
        static let interventionLastStandFXChange = 0.045
        static let interventionLastStandMaxMonths = 0.30
        static let interventionLastStandReserveBuffer = 1.0
        static let reserveAccumulationFloor = 4.8
        static let reserveAccumulationCurrentAccount = 0.01
        static let reserveAccumulationFXChange = -0.03
        static let reserveAccumulationMonths = 0.30
        static let hawkishInflationFloor = 0.09
        static let hawkishOutputGapFloor = -0.015
        static let hawkishFXChange = 0.025
        static let hawkishExitOutputGap = -0.02
        static let hawkishExitInflation = 0.12
        static let hawkishExitFXChange = 0.035
        static let dovishOutputGap = -0.04
        static let dovishInflation = 0.06
        static let balancedResetInflation = 0.05
        static let balancedResetFXChange = 0.01
        static let balancedResetOutputGap = -0.01
        static let cabinetCutInflation = 0.07
        static let cabinetCutOutputGap = -0.02
        static let cabinetCutReserveFloor = 2.2
        static let cabinetControlsReserveTrigger = 3.0
        static let cabinetControlsFXTrigger = 0.015
        static let cabinetDefendReserveFloor = 1.6
        static let cabinetDefendFXTrigger = 0.01
    }

    enum Glonzo {
        static let crisisMeasureChance = 0.20
        static let leverCountRange: ClosedRange<Int> = 0...2
        static let rateDeltaRange: ClosedRange<Double> = -0.035...0.035
        static let reserveDeltaRange: ClosedRange<Double> = -0.04...0.04
        static let controlsDeltaRange: ClosedRange<Double> = -0.22...0.22
        static let interventionMagnitudeRange: ClosedRange<Double> = 0.15...0.75
    }

    enum Hawkish {
        static let inflationTarget = 0.045
        static let inflationWeight = 1.60
        static let outputWeight = 0.45
        static let reserveWeight = 0.012
        static let fxWeight = 0.90
        static let maxRateStep = 0.015
        static let rateDeadband = 0.008
        static let reserveStressFloor = 2.7
        static let fxStressTrigger = 0.010
        static let overheatInflation = 0.10
        static let overheatOutputGap = 0.01
        static let overheatRateBump = 0.010
        static let reserveTightenInflation = 0.08
        static let reserveTightenCredit = 0.11
        static let reserveTightenCeiling = 0.24
        static let reserveTightenStep = 0.03
        static let reserveTightenRange: ClosedRange<Double> = 0.06...0.26
        static let reserveEaseOutputGap = -0.05
        static let reserveEaseInflation = 0.05
        static let reserveEaseFloor = 0.10
        static let reserveEaseStep = 0.02
        static let controlsCeilingSafe = 0.45
        static let controlsCeilingStress = 0.70
        static let defenseFXTrigger = 0.015
        static let defenseReserveFloor = 2.2
        static let defenseCurrentAccountFloor = -0.02
        static let controlsTightenStep = 0.10
        static let controlsUnwindReserveFloor = 4.5
        static let controlsUnwindInflation = 0.07
        static let controlsUnwindFloor = 0.20
        static let controlsUnwindStep = 0.06
        static let interventionReserveFloor = 2.0
        static let interventionFXTrigger = 0.020
        static let interventionMaxMonths = 0.45
        static let interventionReserveBuffer = 1.2
        static let interventionLastStandReserveFloor = 1.4
        static let interventionLastStandFXTrigger = 0.040
        static let interventionLastStandMaxMonths = 0.30
        static let interventionLastStandReserveBuffer = 1.0
        static let hawkishInflation = 0.06
        static let hawkishFXTrigger = 0.015
        static let cabinetCutInflation = 0.05
        static let cabinetCutOutputGap = -0.04
        static let cabinetCutReserveFloor = 2.0
        static let cabinetControlsReserveTrigger = 3.2
        static let cabinetControlsFXTrigger = 0.012
        static let cabinetDefendReserveFloor = 1.4
        static let crisisBankHolidayReserve = 0.60
        static let crisisBankHolidayFX = 0.075
        static let crisisBankHolidayCapitalAccount = -0.015
        static let crisisBankHolidayCurrentAccount = -0.045
        static let crisisIMFReserve = 0.60
        static let crisisIMFNearReserve = 0.90
        static let crisisIMFCurrentAccount = -0.060
        static let crisisIMFFX = 0.060
        static let crisisIMFDebt = 1.05
        static let crisisLiquidityOutputGap = -0.040
        static let crisisLiquidityUnemployment = 0.095
        static let crisisLiquidityInflation = 0.080
    }

    enum Balanced {
        static let inflationTarget = 0.050
        static let inflationWeight = 1.20
        static let outputWeight = 0.40
        static let reserveWeight = 0.010
        static let fxWeight = 0.65
        static let maxRateStep = 0.012
        static let rateDeadband = 0.008
        static let reserveStressFloor = 2.7
        static let fxStressTrigger = 0.015
        static let reserveTightenInflation = 0.09
        static let reserveTightenCredit = 0.13
        static let reserveTightenCeiling = 0.20
        static let reserveTightenStep = 0.02
        static let reserveTightenRange: ClosedRange<Double> = 0.06...0.22
        static let reserveEaseOutputGap = -0.04
        static let reserveEaseInflation = 0.06
        static let reserveEaseFloor = 0.10
        static let reserveEaseStep = 0.02
        static let controlsCeilingSafe = 0.35
        static let controlsCeilingStress = 0.70
        static let defenseFXTrigger = 0.018
        static let defenseReserveFloor = 2.2
        static let defenseCurrentAccountFloor = -0.03
        static let controlsTightenStep = 0.07
        static let controlsUnwindReserveFloor = 4.5
        static let controlsUnwindInflation = 0.07
        static let controlsUnwindFloor = 0.10
        static let controlsUnwindStep = 0.08
        static let interventionReserveFloor = 2.2
        static let interventionFXTrigger = 0.028
        static let interventionMaxMonths = 0.35
        static let interventionReserveBuffer = 1.2
        static let reserveAccumulationFloor = 4.5
        static let reserveAccumulationCurrentAccount = 0.01
        static let reserveAccumulationFXChange = -0.03
        static let reserveAccumulationMonths = 0.25
        static let hawkishInflation = 0.09
        static let hawkishFXTrigger = 0.030
        static let dovishOutputGap = -0.045
        static let dovishInflation = 0.055
        static let cabinetCutInflation = 0.065
        static let cabinetCutOutputGap = -0.025
        static let cabinetCutReserveFloor = 2.0
        static let cabinetControlsReserveTrigger = 2.6
        static let cabinetControlsFXTrigger = 0.020
        static let cabinetDefendReserveFloor = 1.5
        static let cabinetDefendFXTrigger = 0.012
    }

    enum Dovish {
        static let inflationTarget = 0.055
        static let inflationWeight = 1.15
        static let outputWeight = 0.75
        static let reserveWeight = 0.012
        static let fxWeight = 0.70
        static let maxRateStep = 0.012
        static let rateDeadband = 0.007
        static let reserveStressFloor = 2.3
        static let fxStressTrigger = 0.020
        static let easingOutputGap = -0.03
        static let easingInflation = 0.075
        static let easingRateCut = 0.010
        static let stressInflation = 0.085
        static let stressFX = 0.030
        static let stressRateBump = 0.015
        static let panicInflation = 0.10
        static let panicFX = 0.040
        static let panicRateBump = 0.010
        static let reserveTightenInflation = 0.11
        static let reserveTightenCredit = 0.15
        static let reserveTightenFX = 0.018
        static let reserveTightenCeiling = 0.20
        static let reserveTightenStep = 0.02
        static let reserveTightenRange: ClosedRange<Double> = 0.06...0.22
        static let reserveEaseOutputGap = -0.02
        static let reserveEaseInflation = 0.075
        static let reserveEaseFloor = 0.08
        static let reserveEaseStep = 0.02
        static let controlsCeilingSafe = 0.40
        static let controlsCeilingStress = 0.60
        static let defenseFXTrigger = 0.014
        static let defenseReserveFloor = 2.1
        static let defenseCurrentAccountFloor = -0.03
        static let controlsTightenStep = 0.08
        static let controlsUnwindReserveFloor = 4.5
        static let controlsUnwindInflation = 0.07
        static let controlsUnwindFloor = 0.10
        static let controlsUnwindStep = 0.08
        static let interventionReserveFloor = 2.0
        static let interventionFXTrigger = 0.025
        static let interventionMaxMonths = 0.30
        static let interventionReserveBuffer = 1.3
        static let interventionLastStandReserveFloor = 1.6
        static let interventionLastStandFXTrigger = 0.040
        static let interventionLastStandMaxMonths = 0.22
        static let interventionLastStandReserveBuffer = 1.1
        static let hawkishInflation = 0.12
        static let hawkishFXTrigger = 0.050
        static let balancedInflation = 0.085
        static let balancedFXTrigger = 0.025
        static let dovishOutputGap = -0.015
        static let dovishInflation = 0.07
        static let cabinetCutInflation = 0.085
        static let cabinetCutOutputGap = -0.015
        static let cabinetControlsReserveTrigger = 2.0
        static let cabinetControlsFXTrigger = 0.020
        static let cabinetDefendReserveFloor = 1.7
        static let cabinetDefendFXTrigger = 0.018
        static let crisisLiquidityOutputGap = -0.022
        static let crisisLiquidityUnemployment = 0.082
        static let crisisLiquidityInflation = 0.095
        static let crisisLiquidityReserveFloor = 1.0
        static let crisisLiquidityFXCeiling = 0.045
        static let crisisBankHolidayReserve = 0.90
        static let crisisBankHolidayFX = 0.050
        static let crisisBankHolidayCapitalAccount = -0.010
        static let crisisBankHolidayCurrentAccount = -0.040
        static let crisisIMFReserve = 1.00
        static let crisisIMFNearReserve = 1.20
        static let crisisIMFCurrentAccount = -0.045
        static let crisisIMFFX = 0.040
        static let crisisIMFDebt = 0.85
    }

    enum CrisisReactive {
        static let liquidityOutputGap = -0.028
        static let liquidityUnemployment = 0.088
        static let liquidityInflation = 0.105
        static let liquidityReserveFloor = 1.15
        static let liquidityFXCeiling = 0.050
        static let bankHolidayReserve = 1.05
        static let bankHolidayFX = 0.045
        static let bankHolidayCapitalAccount = -0.006
        static let imfReserve = 0.90
        static let imfNearReserve = 1.20
        static let imfCurrentAccount = -0.055
        static let imfFX = 0.050
        static let imfDebt = 0.80
    }
}

private func applyRateOnlyBot(to simulator: EconomicSimulator) -> BalanceTurnStats {
    var stats = BalanceTurnStats()
    let s = simulator.state
    let inflationTarget = BalanceBotTuning.RateOnly.inflationTarget
    let neutralNominal = simulator.neutralRealRate + inflationTarget
    let reserveStress = s.foreignReservesMonths < BalanceBotTuning.RateOnly.reserveStressFloor
        ? BalanceBotTuning.RateOnly.reserveStressWeight
        : 0.0
    let targetRate = (0.0...BalanceBotTuning.RateOnly.maxPolicyRate).clamping(
        neutralNominal
        + BalanceBotTuning.RateOnly.inflationWeight * (s.inflation - inflationTarget)
        + BalanceBotTuning.RateOnly.outputWeight * s.outputGap
        + reserveStress)
    adjustPolicyRate(on: simulator,
                     toward: targetRate,
                     maxStep: BalanceBotTuning.RateOnly.maxRateStep,
                     deadband: BalanceBotTuning.RateOnly.deadband,
                     stats: &stats)
    resolveCabinetDemand(for: .rateOnly, simulator: simulator, stats: &stats)
    return stats
}

private func applyFullReactiveBot(to simulator: EconomicSimulator) -> BalanceTurnStats {
    var stats = BalanceTurnStats()

    maybeUseCrisisMeasure(on: simulator, stats: &stats)
    let s = simulator.state

    let inflationTarget = BalanceBotTuning.FullReactive.inflationTarget
    let neutralNominal = simulator.neutralRealRate + inflationTarget
    let reserveStress = max(0.0, BalanceBotTuning.FullReactive.reserveStressFloor - s.foreignReservesMonths)
        * BalanceBotTuning.FullReactive.reserveStressWeight
    let fxStress = max(0.0, s.exchangeRateQoQChange - BalanceBotTuning.FullReactive.fxStressTrigger)
        * BalanceBotTuning.FullReactive.fxStressWeight
    let targetRate = BalanceBotTuning.Shared.policyRateRange.clamping(
        neutralNominal
        + BalanceBotTuning.FullReactive.inflationWeight * (s.inflation - inflationTarget)
        + BalanceBotTuning.FullReactive.outputWeight * s.outputGap
        + reserveStress
        + fxStress)
    adjustPolicyRate(on: simulator,
                     toward: targetRate,
                     maxStep: BalanceBotTuning.FullReactive.maxRateStep,
                     deadband: BalanceBotTuning.FullReactive.deadband,
                     stats: &stats)

    if simulator.state.inflation > BalanceBotTuning.FullReactive.reserveTightenInflation
        && simulator.state.bankCreditGrowth > BalanceBotTuning.FullReactive.reserveTightenCredit
        && simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.reserveTightenReserveFloor
        && simulator.state.reserveRequirement < BalanceBotTuning.FullReactive.reserveTightenCeiling {
        adjustReserveRequirement(on: simulator,
                                 toward: BalanceBotTuning.FullReactive.reserveTightenRange.clamping(
                                    simulator.state.reserveRequirement + BalanceBotTuning.FullReactive.reserveTightenStep),
                                 maxStep: BalanceBotTuning.FullReactive.reserveTightenStep,
                                 deadband: BalanceBotTuning.FullReactive.deadband,
                                 stats: &stats)
    }

    let earlyExternalDefense = simulator.state.inflation > BalanceBotTuning.FullReactive.earlyDefenseInflation
        && (simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.earlyDefenseFXChange
            || simulator.state.currentAccountGDP < BalanceBotTuning.FullReactive.earlyDefenseCurrentAccount
            || simulator.state.capitalAccountGDP < BalanceBotTuning.FullReactive.earlyDefenseCapitalAccount)
    let controlsCeiling = earlyExternalDefense && simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.stressedControlsReserveFloor
        ? BalanceBotTuning.FullReactive.stressedControlsCeiling
        : BalanceBotTuning.FullReactive.emergencyControlsCeiling
    if ((simulator.state.foreignReservesMonths < BalanceBotTuning.FullReactive.controlsDefenseReserveFloor
            && simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.controlsDefenseFXChange)
        || earlyExternalDefense)
        && simulator.state.capitalControls < controlsCeiling {
        let move = earlyExternalDefense
            ? min(BalanceBotTuning.FullReactive.stressedControlsStep, controlsCeiling - simulator.state.capitalControls)
            : min(BalanceBotTuning.FullReactive.emergencyControlsStep, controlsCeiling - simulator.state.capitalControls)
        if move > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls + move)
            stats.controlsMoveAbs += move
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.controlsUnwindReserveFloor
                && simulator.state.inflation < BalanceBotTuning.FullReactive.controlsUnwindInflationCeiling
                && simulator.state.capitalControls > BalanceBotTuning.FullReactive.controlsUnwindFloor {
        let move = min(BalanceBotTuning.FullReactive.controlsUnwindStep, simulator.state.capitalControls)
        if move > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls - move)
            stats.controlsMoveAbs += move
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    }

    let interventionMonths: Double
    if simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.interventionEarlyReserveFloor
        && simulator.state.exchangeRateQoQChange >= BalanceBotTuning.FullReactive.interventionEarlyFXChange
        && earlyExternalDefense {
        interventionMonths = -min(BalanceBotTuning.FullReactive.interventionEarlyMaxMonths,
                                  simulator.state.foreignReservesMonths - BalanceBotTuning.FullReactive.interventionEarlyReserveBuffer)
    } else if simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.interventionReserveFloor
                && simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.interventionFXChange {
        interventionMonths = -min(BalanceBotTuning.FullReactive.interventionMaxMonths,
                                  simulator.state.foreignReservesMonths - BalanceBotTuning.FullReactive.interventionReserveBuffer)
    } else if simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.interventionLastStandReserveFloor
                && simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.interventionLastStandFXChange {
        interventionMonths = -min(BalanceBotTuning.FullReactive.interventionLastStandMaxMonths,
                                  simulator.state.foreignReservesMonths - BalanceBotTuning.FullReactive.interventionLastStandReserveBuffer)
    } else if simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.reserveAccumulationFloor
                && simulator.state.currentAccountGDP > BalanceBotTuning.FullReactive.reserveAccumulationCurrentAccount
                && simulator.state.exchangeRateQoQChange < BalanceBotTuning.FullReactive.reserveAccumulationFXChange {
        interventionMonths = BalanceBotTuning.FullReactive.reserveAccumulationMonths
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
        (simulator.state.inflation > BalanceBotTuning.FullReactive.hawkishInflationFloor
            && (simulator.state.outputGap > BalanceBotTuning.FullReactive.hawkishOutputGapFloor
                || simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.hawkishFXChange))
        || simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.hawkishExitFXChange
    let coolingEnoughToStopJawboning =
        simulator.state.outputGap < BalanceBotTuning.FullReactive.hawkishExitOutputGap
        && simulator.state.inflation < BalanceBotTuning.FullReactive.hawkishExitInflation
        && simulator.state.exchangeRateQoQChange < BalanceBotTuning.FullReactive.hawkishExitFXChange

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
    } else if simulator.state.outputGap < BalanceBotTuning.FullReactive.dovishOutputGap
                && simulator.state.inflation < BalanceBotTuning.FullReactive.dovishInflation {
        if simulator.communicationStance != .dovish {
            simulator.communicationStance = .dovish
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.communicationStance == .hawkish
                && simulator.state.inflation < BalanceBotTuning.FullReactive.balancedResetInflation
                && simulator.state.exchangeRateQoQChange < BalanceBotTuning.FullReactive.balancedResetFXChange {
        simulator.communicationStance = .balanced
        stats.policyActions += 1
        stats.activeQuarter = true
    } else if simulator.communicationStance == .dovish
                && simulator.state.outputGap > BalanceBotTuning.FullReactive.balancedResetOutputGap {
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
        && Double.random(in: 0...1, using: &simulator.rng) < BalanceBotTuning.Glonzo.crisisMeasureChance {
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

    let leverCount = Int.random(in: BalanceBotTuning.Glonzo.leverCountRange, using: &simulator.rng)
    guard leverCount > 0 else { return stats }

    var levers = GlonzoLever.allCases
    levers.shuffle(using: &simulator.rng)

    for lever in levers.prefix(leverCount) {
        switch lever {
        case .rate:
            let delta = Double.random(in: BalanceBotTuning.Glonzo.rateDeltaRange, using: &simulator.rng)
            let nextRate = BalanceBotTuning.Shared.policyRateRange.clamping(simulator.state.policyRate + delta)
            let move = abs(nextRate - simulator.state.policyRate)
            guard move > 0.0001 else { continue }
            simulator.state.policyRate = nextRate
            stats.rateMoveAbs += move

        case .reserveRequirement:
            let delta = Double.random(in: BalanceBotTuning.Glonzo.reserveDeltaRange, using: &simulator.rng)
            let nextReserve = BalanceBotTuning.Shared.reserveRequirementRange.clamping(simulator.state.reserveRequirement + delta)
            let move = abs(nextReserve - simulator.state.reserveRequirement)
            guard move > 0.0001 else { continue }
            simulator.state.reserveRequirement = nextReserve
            stats.reserveMoveAbs += move

        case .controls:
            let delta = Double.random(in: BalanceBotTuning.Glonzo.controlsDeltaRange, using: &simulator.rng)
            let nextControls = BalanceBotTuning.Shared.capitalControlsRange.clamping(simulator.state.capitalControls + delta)
            let move = abs(nextControls - simulator.state.capitalControls)
            guard move > 0.0001 else { continue }
            simulator.setCapitalControls(nextControls)
            stats.controlsMoveAbs += move

        case .intervention:
            let sign = Bool.random(using: &simulator.rng) ? 1.0 : -1.0
            let months = sign * Double.random(in: BalanceBotTuning.Glonzo.interventionMagnitudeRange, using: &simulator.rng)
            simulator.applyFXIntervention(months: months)
            stats.interventionMonthsAbs += abs(months)
        }

        stats.policyActions += 1
        stats.activeQuarter = true
    }

    return stats
}

private func applyStyleBot(_ style: PolicyStyle,
                           to simulator: EconomicSimulator) -> BalanceTurnStats {
    var stats = BalanceTurnStats()
    maybeUseCrisisMeasure(style: style, on: simulator, stats: &stats)
    let s = simulator.state
    let inflationTarget: Double
    let inflationWeight: Double
    let outputWeight: Double
    let reserveWeight: Double
    let fxWeight: Double
    let maxRateStep: Double
    let rateDeadband: Double
    let reserveStressFloor: Double
    let fxStressTrigger: Double

    switch style {
    case .hawkish:
        inflationTarget = BalanceBotTuning.Hawkish.inflationTarget
        inflationWeight = BalanceBotTuning.Hawkish.inflationWeight
        outputWeight = BalanceBotTuning.Hawkish.outputWeight
        reserveWeight = BalanceBotTuning.Hawkish.reserveWeight
        fxWeight = BalanceBotTuning.Hawkish.fxWeight
        maxRateStep = BalanceBotTuning.Hawkish.maxRateStep
        rateDeadband = BalanceBotTuning.Hawkish.rateDeadband
        reserveStressFloor = BalanceBotTuning.Hawkish.reserveStressFloor
        fxStressTrigger = BalanceBotTuning.Hawkish.fxStressTrigger
    case .balanced:
        inflationTarget = BalanceBotTuning.Balanced.inflationTarget
        inflationWeight = BalanceBotTuning.Balanced.inflationWeight
        outputWeight = BalanceBotTuning.Balanced.outputWeight
        reserveWeight = BalanceBotTuning.Balanced.reserveWeight
        fxWeight = BalanceBotTuning.Balanced.fxWeight
        maxRateStep = BalanceBotTuning.Balanced.maxRateStep
        rateDeadband = BalanceBotTuning.Balanced.rateDeadband
        reserveStressFloor = BalanceBotTuning.Balanced.reserveStressFloor
        fxStressTrigger = BalanceBotTuning.Balanced.fxStressTrigger
    case .dovish:
        inflationTarget = BalanceBotTuning.Dovish.inflationTarget
        inflationWeight = BalanceBotTuning.Dovish.inflationWeight
        outputWeight = BalanceBotTuning.Dovish.outputWeight
        reserveWeight = BalanceBotTuning.Dovish.reserveWeight
        fxWeight = BalanceBotTuning.Dovish.fxWeight
        maxRateStep = BalanceBotTuning.Dovish.maxRateStep
        rateDeadband = BalanceBotTuning.Dovish.rateDeadband
        reserveStressFloor = BalanceBotTuning.Dovish.reserveStressFloor
        fxStressTrigger = BalanceBotTuning.Dovish.fxStressTrigger
    }

    let neutralNominal = simulator.neutralRealRate + inflationTarget
    let reserveStress = max(0.0, reserveStressFloor - s.foreignReservesMonths) * reserveWeight
    let fxStress = max(0.0, s.exchangeRateQoQChange - fxStressTrigger) * fxWeight

    var targetRate = neutralNominal
        + inflationWeight * (s.inflation - inflationTarget)
        + outputWeight * s.outputGap
        + reserveStress
        + fxStress

    if style == .dovish && s.outputGap < BalanceBotTuning.Dovish.easingOutputGap && s.inflation < BalanceBotTuning.Dovish.easingInflation {
        targetRate -= BalanceBotTuning.Dovish.easingRateCut
    }
    if style == .dovish && (s.inflation > BalanceBotTuning.Dovish.stressInflation || s.exchangeRateQoQChange > BalanceBotTuning.Dovish.stressFX) {
        targetRate += BalanceBotTuning.Dovish.stressRateBump
    }
    if style == .dovish && (s.inflation > BalanceBotTuning.Dovish.panicInflation || s.exchangeRateQoQChange > BalanceBotTuning.Dovish.panicFX) {
        targetRate += BalanceBotTuning.Dovish.panicRateBump
    }
    if style == .hawkish && s.inflation > BalanceBotTuning.Hawkish.overheatInflation && s.outputGap > BalanceBotTuning.Hawkish.overheatOutputGap {
        targetRate += BalanceBotTuning.Hawkish.overheatRateBump
    }

    adjustPolicyRate(on: simulator,
                     toward: BalanceBotTuning.Shared.policyRateRange.clamping(targetRate),
                     maxStep: maxRateStep,
                     deadband: rateDeadband,
                     stats: &stats)

    switch style {
    case .hawkish:
        if simulator.state.inflation > BalanceBotTuning.Hawkish.reserveTightenInflation
            && simulator.state.bankCreditGrowth > BalanceBotTuning.Hawkish.reserveTightenCredit
            && simulator.state.reserveRequirement < BalanceBotTuning.Hawkish.reserveTightenCeiling {
            let desired = BalanceBotTuning.Hawkish.reserveTightenRange.clamping(
                simulator.state.reserveRequirement + BalanceBotTuning.Hawkish.reserveTightenStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Hawkish.reserveTightenStep,
                                     deadband: 0.010,
                                     stats: &stats)
        } else if simulator.state.outputGap < BalanceBotTuning.Hawkish.reserveEaseOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Hawkish.reserveEaseInflation
                    && simulator.state.reserveRequirement > BalanceBotTuning.Hawkish.reserveEaseFloor {
            let desired = max(BalanceBotTuning.Hawkish.reserveEaseFloor,
                              simulator.state.reserveRequirement - BalanceBotTuning.Hawkish.reserveEaseStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Hawkish.reserveEaseStep,
                                     deadband: 0.010,
                                     stats: &stats)
        }

    case .balanced:
        if simulator.state.inflation > BalanceBotTuning.Balanced.reserveTightenInflation
            && simulator.state.bankCreditGrowth > BalanceBotTuning.Balanced.reserveTightenCredit
            && simulator.state.reserveRequirement < BalanceBotTuning.Balanced.reserveTightenCeiling {
            let desired = BalanceBotTuning.Balanced.reserveTightenRange.clamping(
                simulator.state.reserveRequirement + BalanceBotTuning.Balanced.reserveTightenStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Balanced.reserveTightenStep,
                                     deadband: 0.010,
                                     stats: &stats)
        } else if simulator.state.outputGap < BalanceBotTuning.Balanced.reserveEaseOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Balanced.reserveEaseInflation
                    && simulator.state.reserveRequirement > BalanceBotTuning.Balanced.reserveEaseFloor {
            let desired = max(BalanceBotTuning.Balanced.reserveEaseFloor,
                              simulator.state.reserveRequirement - BalanceBotTuning.Balanced.reserveEaseStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Balanced.reserveEaseStep,
                                     deadband: 0.010,
                                     stats: &stats)
        }

    case .dovish:
        if simulator.state.inflation > BalanceBotTuning.Dovish.reserveTightenInflation
            && simulator.state.bankCreditGrowth > BalanceBotTuning.Dovish.reserveTightenCredit
            && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.reserveTightenFX
            && simulator.state.reserveRequirement < BalanceBotTuning.Dovish.reserveTightenCeiling {
            let desired = BalanceBotTuning.Dovish.reserveTightenRange.clamping(
                simulator.state.reserveRequirement + BalanceBotTuning.Dovish.reserveTightenStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Dovish.reserveTightenStep,
                                     deadband: 0.010,
                                     stats: &stats)
        } else if simulator.state.outputGap < BalanceBotTuning.Dovish.reserveEaseOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Dovish.reserveEaseInflation
                    && simulator.state.reserveRequirement > BalanceBotTuning.Dovish.reserveEaseFloor {
            let desired = max(BalanceBotTuning.Dovish.reserveEaseFloor,
                              simulator.state.reserveRequirement - BalanceBotTuning.Dovish.reserveEaseStep)
            adjustReserveRequirement(on: simulator,
                                     toward: desired,
                                     maxStep: BalanceBotTuning.Dovish.reserveEaseStep,
                                     deadband: 0.010,
                                     stats: &stats)
        }
    }

    let controlsCeiling: Double
    switch style {
    case .hawkish:
        controlsCeiling = simulator.state.foreignReservesMonths > 1.8
            ? BalanceBotTuning.Hawkish.controlsCeilingSafe
            : BalanceBotTuning.Hawkish.controlsCeilingStress
    case .balanced:
        controlsCeiling = simulator.state.foreignReservesMonths > 1.8
            ? BalanceBotTuning.Balanced.controlsCeilingSafe
            : BalanceBotTuning.Balanced.controlsCeilingStress
    case .dovish:
        controlsCeiling = simulator.state.foreignReservesMonths > 1.8
            ? BalanceBotTuning.Dovish.controlsCeilingSafe
            : BalanceBotTuning.Dovish.controlsCeilingStress
    }
    let needsExternalDefense: Bool
    switch style {
    case .hawkish:
        needsExternalDefense =
            simulator.state.exchangeRateQoQChange > BalanceBotTuning.Hawkish.defenseFXTrigger
            || simulator.state.foreignReservesMonths < BalanceBotTuning.Hawkish.defenseReserveFloor
            || simulator.state.currentAccountGDP < BalanceBotTuning.Hawkish.defenseCurrentAccountFloor
    case .balanced:
        needsExternalDefense =
            simulator.state.exchangeRateQoQChange > BalanceBotTuning.Balanced.defenseFXTrigger
            || simulator.state.foreignReservesMonths < BalanceBotTuning.Balanced.defenseReserveFloor
            || simulator.state.currentAccountGDP < BalanceBotTuning.Balanced.defenseCurrentAccountFloor
    case .dovish:
        needsExternalDefense =
            simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.defenseFXTrigger
            || simulator.state.foreignReservesMonths < BalanceBotTuning.Dovish.defenseReserveFloor
            || simulator.state.currentAccountGDP < BalanceBotTuning.Dovish.defenseCurrentAccountFloor
    }

    if needsExternalDefense && simulator.state.capitalControls < controlsCeiling {
        let move: Double
        switch style {
        case .hawkish:
            move = min(BalanceBotTuning.Hawkish.controlsTightenStep, controlsCeiling - simulator.state.capitalControls)
        case .balanced:
            move = min(BalanceBotTuning.Balanced.controlsTightenStep, controlsCeiling - simulator.state.capitalControls)
        case .dovish:
            move = min(BalanceBotTuning.Dovish.controlsTightenStep, controlsCeiling - simulator.state.capitalControls)
        }
        if move > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls + move)
            stats.controlsMoveAbs += move
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    } else if simulator.state.foreignReservesMonths > (style == .hawkish
                    ? BalanceBotTuning.Hawkish.controlsUnwindReserveFloor
                    : style == .balanced
                        ? BalanceBotTuning.Balanced.controlsUnwindReserveFloor
                        : BalanceBotTuning.Dovish.controlsUnwindReserveFloor)
                && simulator.state.inflation < (style == .hawkish
                    ? BalanceBotTuning.Hawkish.controlsUnwindInflation
                    : style == .balanced
                        ? BalanceBotTuning.Balanced.controlsUnwindInflation
                        : BalanceBotTuning.Dovish.controlsUnwindInflation)
                && simulator.state.capitalControls > (style == .hawkish
                    ? BalanceBotTuning.Hawkish.controlsUnwindFloor
                    : style == .balanced
                        ? BalanceBotTuning.Balanced.controlsUnwindFloor
                        : BalanceBotTuning.Dovish.controlsUnwindFloor) {
        let unwind = min(style == .hawkish
                            ? BalanceBotTuning.Hawkish.controlsUnwindStep
                            : style == .balanced
                                ? BalanceBotTuning.Balanced.controlsUnwindStep
                                : BalanceBotTuning.Dovish.controlsUnwindStep,
                         simulator.state.capitalControls)
        if unwind > 0 {
            simulator.setCapitalControls(simulator.state.capitalControls - unwind)
            stats.controlsMoveAbs += unwind
            stats.policyActions += 1
            stats.activeQuarter = true
        }
    }

    let interventionMonths: Double
    switch style {
    case .hawkish:
        if simulator.state.foreignReservesMonths > BalanceBotTuning.Hawkish.interventionReserveFloor
            && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Hawkish.interventionFXTrigger {
            interventionMonths = -min(BalanceBotTuning.Hawkish.interventionMaxMonths,
                                      simulator.state.foreignReservesMonths - BalanceBotTuning.Hawkish.interventionReserveBuffer)
        } else if simulator.state.foreignReservesMonths > BalanceBotTuning.Hawkish.interventionLastStandReserveFloor
                    && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Hawkish.interventionLastStandFXTrigger {
            interventionMonths = -min(BalanceBotTuning.Hawkish.interventionLastStandMaxMonths,
                                      simulator.state.foreignReservesMonths - BalanceBotTuning.Hawkish.interventionLastStandReserveBuffer)
        } else {
            interventionMonths = 0.0
        }
    case .balanced:
        if simulator.state.foreignReservesMonths > BalanceBotTuning.Balanced.interventionReserveFloor
            && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Balanced.interventionFXTrigger {
            interventionMonths = -min(BalanceBotTuning.Balanced.interventionMaxMonths,
                                      simulator.state.foreignReservesMonths - BalanceBotTuning.Balanced.interventionReserveBuffer)
        } else if simulator.state.foreignReservesMonths > BalanceBotTuning.Balanced.reserveAccumulationFloor
                    && simulator.state.currentAccountGDP > BalanceBotTuning.Balanced.reserveAccumulationCurrentAccount
                    && simulator.state.exchangeRateQoQChange < BalanceBotTuning.Balanced.reserveAccumulationFXChange {
            interventionMonths = BalanceBotTuning.Balanced.reserveAccumulationMonths
        } else {
            interventionMonths = 0.0
        }
    case .dovish:
        if simulator.state.foreignReservesMonths > BalanceBotTuning.Dovish.interventionReserveFloor
            && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.interventionFXTrigger {
            interventionMonths = -min(BalanceBotTuning.Dovish.interventionMaxMonths,
                                      simulator.state.foreignReservesMonths - BalanceBotTuning.Dovish.interventionReserveBuffer)
        } else if simulator.state.foreignReservesMonths > BalanceBotTuning.Dovish.interventionLastStandReserveFloor
                    && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.interventionLastStandFXTrigger {
            interventionMonths = -min(BalanceBotTuning.Dovish.interventionLastStandMaxMonths,
                                      simulator.state.foreignReservesMonths - BalanceBotTuning.Dovish.interventionLastStandReserveBuffer)
        } else {
            interventionMonths = 0.0
        }
    }
    if abs(interventionMonths) > 0.0001 {
        simulator.applyFXIntervention(months: interventionMonths)
        stats.interventionMonthsAbs += abs(interventionMonths)
        stats.policyActions += 1
        stats.activeQuarter = true
    }

    let nextStance: CommunicationStance
    switch style {
    case .hawkish:
        if simulator.state.inflation > BalanceBotTuning.Hawkish.hawkishInflation
            || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Hawkish.hawkishFXTrigger {
            nextStance = .hawkish
        } else if simulator.state.outputGap < BalanceBotTuning.Hawkish.reserveEaseOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Hawkish.reserveEaseInflation {
            nextStance = .balanced
        } else {
            nextStance = .balanced
        }
    case .balanced:
        if simulator.state.inflation > BalanceBotTuning.Balanced.hawkishInflation
            || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Balanced.hawkishFXTrigger {
            nextStance = .hawkish
        } else if simulator.state.outputGap < BalanceBotTuning.Balanced.dovishOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Balanced.dovishInflation {
            nextStance = .dovish
        } else {
            nextStance = .balanced
        }
    case .dovish:
        if simulator.state.inflation > BalanceBotTuning.Dovish.hawkishInflation
            || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.hawkishFXTrigger {
            nextStance = .hawkish
        } else if simulator.state.inflation > BalanceBotTuning.Dovish.balancedInflation
                    || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.balancedFXTrigger {
            nextStance = .balanced
        } else if simulator.state.outputGap < BalanceBotTuning.Dovish.dovishOutputGap
                    && simulator.state.inflation < BalanceBotTuning.Dovish.dovishInflation {
            nextStance = .dovish
        } else {
            nextStance = .balanced
        }
    }
    if simulator.communicationStance != nextStance {
        simulator.communicationStance = nextStance
        stats.policyActions += 1
        stats.activeQuarter = true
    }

    resolveCabinetDemand(for: style, simulator: simulator, stats: &stats)
    return stats
}

private func maybeUseCrisisMeasure(on simulator: EconomicSimulator,
                                   stats: inout BalanceTurnStats) {
    let available = Set(simulator.availableCrisisMeasures().map(\.type))
    guard !available.isEmpty else { return }

    let s = simulator.state
    let chosen: CrisisMeasureType?
    if available.contains(.emergencyLiquidity)
        && s.outputGap < BalanceBotTuning.CrisisReactive.liquidityOutputGap
        && s.unemployment > BalanceBotTuning.CrisisReactive.liquidityUnemployment
        && s.inflation < BalanceBotTuning.CrisisReactive.liquidityInflation
        && s.foreignReservesMonths > BalanceBotTuning.CrisisReactive.liquidityReserveFloor
        && s.exchangeRateQoQChange < BalanceBotTuning.CrisisReactive.liquidityFXCeiling {
        chosen = .emergencyLiquidity
    } else if available.contains(.bankHoliday)
                && (s.foreignReservesMonths < BalanceBotTuning.CrisisReactive.bankHolidayReserve
                    || (s.exchangeRateQoQChange > BalanceBotTuning.CrisisReactive.bankHolidayFX
                        && s.capitalAccountGDP < BalanceBotTuning.CrisisReactive.bankHolidayCapitalAccount)) {
        chosen = .bankHoliday
    } else if available.contains(.imfProgram)
        && (s.foreignReservesMonths < BalanceBotTuning.CrisisReactive.imfReserve
            || (s.foreignReservesMonths < BalanceBotTuning.CrisisReactive.imfNearReserve
                && s.currentAccountGDP < BalanceBotTuning.CrisisReactive.imfCurrentAccount
                && s.exchangeRateQoQChange > BalanceBotTuning.CrisisReactive.imfFX)
            || s.externalDebtGDP > BalanceBotTuning.CrisisReactive.imfDebt) {
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

private func maybeUseCrisisMeasure(style: PolicyStyle,
                                   on simulator: EconomicSimulator,
                                   stats: inout BalanceTurnStats) {
    let available = Set(simulator.availableCrisisMeasures().map(\.type))
    guard !available.isEmpty else { return }

    let s = simulator.state
    let chosen: CrisisMeasureType?

    switch style {
    case .hawkish:
        if available.contains(.bankHoliday)
            && (s.foreignReservesMonths < BalanceBotTuning.Hawkish.crisisBankHolidayReserve
                || (s.exchangeRateQoQChange > BalanceBotTuning.Hawkish.crisisBankHolidayFX
                    && s.capitalAccountGDP < BalanceBotTuning.Hawkish.crisisBankHolidayCapitalAccount
                    && s.currentAccountGDP < BalanceBotTuning.Hawkish.crisisBankHolidayCurrentAccount)) {
            chosen = .bankHoliday
        } else if available.contains(.imfProgram)
                    && (s.foreignReservesMonths < BalanceBotTuning.Hawkish.crisisIMFReserve
                        || (s.foreignReservesMonths < BalanceBotTuning.Hawkish.crisisIMFNearReserve
                            && s.currentAccountGDP < BalanceBotTuning.Hawkish.crisisIMFCurrentAccount
                            && s.exchangeRateQoQChange > BalanceBotTuning.Hawkish.crisisIMFFX)
                        || s.externalDebtGDP > BalanceBotTuning.Hawkish.crisisIMFDebt) {
            chosen = .imfProgram
        } else if available.contains(.emergencyLiquidity)
                    && s.outputGap < BalanceBotTuning.Hawkish.crisisLiquidityOutputGap
                    && s.unemployment > BalanceBotTuning.Hawkish.crisisLiquidityUnemployment
                    && s.inflation < BalanceBotTuning.Hawkish.crisisLiquidityInflation {
            chosen = .emergencyLiquidity
        } else {
            chosen = nil
        }

    case .balanced:
        return maybeUseCrisisMeasure(on: simulator, stats: &stats)

    case .dovish:
        if available.contains(.emergencyLiquidity)
            && s.outputGap < BalanceBotTuning.Dovish.crisisLiquidityOutputGap
            && s.unemployment > BalanceBotTuning.Dovish.crisisLiquidityUnemployment
            && s.inflation < BalanceBotTuning.Dovish.crisisLiquidityInflation
            && s.foreignReservesMonths > BalanceBotTuning.Dovish.crisisLiquidityReserveFloor
            && s.exchangeRateQoQChange < BalanceBotTuning.Dovish.crisisLiquidityFXCeiling {
            chosen = .emergencyLiquidity
        } else if available.contains(.bankHoliday)
                    && (s.foreignReservesMonths < BalanceBotTuning.Dovish.crisisBankHolidayReserve
                        || (s.exchangeRateQoQChange > BalanceBotTuning.Dovish.crisisBankHolidayFX
                            && s.capitalAccountGDP < BalanceBotTuning.Dovish.crisisBankHolidayCapitalAccount
                            && s.currentAccountGDP < BalanceBotTuning.Dovish.crisisBankHolidayCurrentAccount)) {
            chosen = .bankHoliday
        } else if available.contains(.imfProgram)
                    && (s.foreignReservesMonths < BalanceBotTuning.Dovish.crisisIMFReserve
                        || (s.foreignReservesMonths < BalanceBotTuning.Dovish.crisisIMFNearReserve
                            && s.currentAccountGDP < BalanceBotTuning.Dovish.crisisIMFCurrentAccount
                            && s.exchangeRateQoQChange > BalanceBotTuning.Dovish.crisisIMFFX)
                        || s.externalDebtGDP > BalanceBotTuning.Dovish.crisisIMFDebt) {
            chosen = .imfProgram
        } else {
            chosen = nil
        }
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
    simulator.state.reserveRequirement = BalanceBotTuning.Shared.reserveAdjustmentRange.clamping(simulator.state.reserveRequirement + move)
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

    case .hawkish, .balanced, .dovish:
        acted = false

    case .rateOnly:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < BalanceBotTuning.RateOnly.cabinetCutInflationCeiling
                                        && simulator.state.foreignReservesMonths > BalanceBotTuning.RateOnly.cabinetCutReserveFloor)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < BalanceBotTuning.RateOnly.cabinetControlsReserveTrigger)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > BalanceBotTuning.RateOnly.cabinetDefendReserveFloor)
        }

    case .fullReactive:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < BalanceBotTuning.FullReactive.cabinetCutInflation
                                        && simulator.state.outputGap < BalanceBotTuning.FullReactive.cabinetCutOutputGap
                                        && simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.cabinetCutReserveFloor)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < BalanceBotTuning.FullReactive.cabinetControlsReserveTrigger
                                        || simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.cabinetControlsFXTrigger)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > BalanceBotTuning.FullReactive.cabinetDefendReserveFloor
                                        && simulator.state.exchangeRateQoQChange > BalanceBotTuning.FullReactive.cabinetDefendFXTrigger)
        }
    }

    if acted {
        stats.policyActions += 1
        stats.activeQuarter = true
    }
}

private func resolveCabinetDemand(for style: PolicyStyle,
                                  simulator: EconomicSimulator,
                                  stats: inout BalanceTurnStats) {
    guard let request = simulator.activeCabinetRequest else { return }

    let acted: Bool
    switch style {
    case .hawkish:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < BalanceBotTuning.Hawkish.cabinetCutInflation
                                        && simulator.state.outputGap < BalanceBotTuning.Hawkish.cabinetCutOutputGap
                                        && simulator.state.foreignReservesMonths > BalanceBotTuning.Hawkish.cabinetCutReserveFloor)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < BalanceBotTuning.Hawkish.cabinetControlsReserveTrigger
                                        || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Hawkish.cabinetControlsFXTrigger)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > BalanceBotTuning.Hawkish.cabinetDefendReserveFloor)
        }

    case .balanced:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < BalanceBotTuning.Balanced.cabinetCutInflation
                                        && simulator.state.outputGap < BalanceBotTuning.Balanced.cabinetCutOutputGap
                                        && simulator.state.foreignReservesMonths > BalanceBotTuning.Balanced.cabinetCutReserveFloor)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < BalanceBotTuning.Balanced.cabinetControlsReserveTrigger
                                        || simulator.state.exchangeRateQoQChange > BalanceBotTuning.Balanced.cabinetControlsFXTrigger)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > BalanceBotTuning.Balanced.cabinetDefendReserveFloor
                                        && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Balanced.cabinetDefendFXTrigger)
        }

    case .dovish:
        switch request.type {
        case .cutRates:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.inflation < BalanceBotTuning.Dovish.cabinetCutInflation
                                        || simulator.state.outputGap < BalanceBotTuning.Dovish.cabinetCutOutputGap)
        case .tightenControls:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths < BalanceBotTuning.Dovish.cabinetControlsReserveTrigger
                                        && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.cabinetControlsFXTrigger)
        case .defendCurrency:
            acted = resolveCabinet(simulator,
                                   accept: simulator.state.foreignReservesMonths > BalanceBotTuning.Dovish.cabinetDefendReserveFloor
                                        && simulator.state.exchangeRateQoQChange > BalanceBotTuning.Dovish.cabinetDefendFXTrigger)
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
        difficulty: difficulty,
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
                            difficulty: Difficulty = .governor,
                            gameLength: GameLength,
                            horizonQuarters: Int) -> Int {
    let card = simulator.scoreCard
    var score = computeScore(outcome: outcome, card: card, gameLength: gameLength, difficulty: difficulty).final
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
