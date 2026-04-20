import Foundation

private enum ConfigFiles {
    static let directory = "Config"
    static let tuning = "game_tuning.json"
    static let historicalShort = "historical_short.json"
    static let historicalExtended = "historical_extended.json"
    static let scenarios = "scenarios.json"
}

private func configURLs(for fileName: String) -> [URL] {
    var urls: [URL] = []

    if let overrideDir = ProcessInfo.processInfo.environment["CENTRALBANKER_CONFIG_DIR"],
       !overrideDir.isEmpty {
        let expanded = (overrideDir as NSString).expandingTildeInPath
        urls.append(
            URL(fileURLWithPath: expanded)
                .appendingPathComponent(fileName)
        )
    }

    urls.append(
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(ConfigFiles.directory)
            .appendingPathComponent(fileName)
    )

    if let bundled = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: ConfigFiles.directory) {
        urls.append(bundled)
    }

    return urls
}

// Logging helper for config I/O. Writes to stderr (the one place a game CLI
// should complain when *its own data files* are broken) and is cheap enough
// to call unconditionally on anomalies. Tests redirect stderr if they need
// to silence it; gameplay users see a clear "your edit didn't work" signal.
private func warnConfig(_ message: String) {
    FileHandle.standardError.write(Data("⚠︎  [CentralBanker config] \(message)\n".utf8))
}

// Load a config file with loud failure. The previous implementation swallowed
// every error with `try?` and silently fell through to the compiled Swift
// fallbacks — which made "I edited game_tuning.json and nothing changed"
// undebuggable.
//
// New contract:
//   • Missing-file at a candidate path is silent (the resolver walks several
//     URLs and only the last miss matters).
//   • Present-but-broken (unreadable or undecodable) file emits a diagnostic
//     to stderr naming the path and the decoder error. We still fall through
//     so the game remains playable — loud, not fatal.
//   • If *no* candidate URL yielded a decoded value, we fall back to the
//     compiled-in constants and note that at the end.
private func loadConfig<T: Decodable>(_ fileName: String, fallback: @autoclosure () -> T) -> T {
    var sawAnyFile = false
    for url in configURLs(for: fileName) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            continue   // candidate path wasn't present; try the next one
        } catch let err as NSError where err.domain == NSCocoaErrorDomain
                                     && err.code == NSFileReadNoSuchFileError {
            continue
        } catch {
            sawAnyFile = true
            warnConfig("could not read \(url.path): \(error.localizedDescription)")
            continue
        }
        sawAnyFile = true
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            warnConfig("failed to decode \(url.path) as \(T.self): \(error)")
            continue
        }
    }
    if sawAnyFile {
        warnConfig("all candidate \(fileName) files failed to decode; using compiled fallback.")
    }
    return fallback()
}

struct StateConditionConfig: Codable {
    var minPoliticalPressure: Double? = nil
    var maxPoliticalPressure: Double? = nil
    var minUnemployment: Double? = nil
    var maxUnemployment: Double? = nil
    var minInflation: Double? = nil
    var maxInflation: Double? = nil
    var minPolicyRate: Double? = nil
    var minExchangeRateQoQChange: Double? = nil
    var minExternalDebtGDP: Double? = nil
    var maxExternalDebtGDP: Double? = nil
    var minForeignReservesMonths: Double? = nil
    var minCredibility: Double? = nil
    var minPublicApproval: Double? = nil
    var maxCapitalControls: Double? = nil
    var maxForeignReservesMonths: Double? = nil
    var maxCapitalAccountGDP: Double? = nil
    var maxAnnualizedGDPGrowth: Double? = nil
    var maxOutputGap: Double? = nil
    var minOutputGap: Double? = nil
    var anyOf: [StateConditionConfig]? = nil

    func matches(_ state: EconomicState) -> Bool {
        if let minPoliticalPressure, state.politicalPressure < minPoliticalPressure { return false }
        if let maxPoliticalPressure, state.politicalPressure > maxPoliticalPressure { return false }
        if let minUnemployment, state.unemployment < minUnemployment { return false }
        if let maxUnemployment, state.unemployment > maxUnemployment { return false }
        if let minInflation, state.inflation < minInflation { return false }
        if let maxInflation, state.inflation > maxInflation { return false }
        if let minPolicyRate, state.policyRate < minPolicyRate { return false }
        if let minExchangeRateQoQChange, state.exchangeRateQoQChange < minExchangeRateQoQChange { return false }
        if let minExternalDebtGDP, state.externalDebtGDP < minExternalDebtGDP { return false }
        if let maxExternalDebtGDP, state.externalDebtGDP > maxExternalDebtGDP { return false }
        if let minForeignReservesMonths, state.foreignReservesMonths < minForeignReservesMonths { return false }
        if let minCredibility, state.credibility < minCredibility { return false }
        if let minPublicApproval, state.publicApproval < minPublicApproval { return false }
        if let maxCapitalControls, state.capitalControls > maxCapitalControls { return false }
        if let maxForeignReservesMonths, state.foreignReservesMonths > maxForeignReservesMonths { return false }
        if let maxCapitalAccountGDP, state.capitalAccountGDP > maxCapitalAccountGDP { return false }
        if let maxAnnualizedGDPGrowth, state.annualizedGDPGrowth > maxAnnualizedGDPGrowth { return false }
        if let maxOutputGap, state.outputGap > maxOutputGap { return false }
        if let minOutputGap, state.outputGap < minOutputGap { return false }
        if let anyOf, !anyOf.isEmpty {
            return anyOf.contains { $0.matches(state) }
        }
        return true
    }
}

struct ConfiguredEffectBundle: Codable {
    var policyRateDelta: Double? = nil
    var reserveRequirementDelta: Double? = nil
    var capitalControlsDelta: Double? = nil
    var fxInterventionMonths: Double? = nil
    var foreignReservesMonthsDelta: Double? = nil
    var capitalAccountGDPDelta: Double? = nil
    var currentAccountGDPDelta: Double? = nil
    var credibilityDelta: Double? = nil
    var expectedInflationDelta: Double? = nil
    var outputGapDelta: Double? = nil
    var publicApprovalDelta: Double? = nil
    var politicalPressureDelta: Double? = nil
    var externalDebtGDPDelta: Double? = nil
    var inflationDelta: Double? = nil
    var interventionSupportCarryDelta: Double? = nil
    var controlsReliefCarryDelta: Double? = nil
}

struct DifficultyConfig: Codable {
    var displayName: String
    var tagline: String
    var expectationsBaseAdaptSpeed: Double
    var expectationsCredibilityAmplifier: Double
    var credibilitySurpriseDecrement: Double
    var credibilityCalmIncrement: Double
    var credibilityHighInflationDecrement: Double? = nil
    var credibilitySustainedLowBonus: Double
    var credibilityCapitalControlsDrag: Double
    var inflationPhillipsSlope: Double
    var exchangeRateCurrentAccountPressure: Double? = nil
    var capitalAccountExpectationsSensitivity: Double? = nil
    var politicalInflationCoef: Double
    var politicalUnemploymentCoef: Double
    var politicalRecessionBump: Double
    var politicalSmoothingRetain: Double? = nil
    var approvalInflationCoef: Double
    var approvalUnemploymentCoef: Double? = nil
    var approvalCapitalControlsCoef: Double

    func applied(to params: ModelParameters) -> ModelParameters {
        var p = params
        p.expectations.baseAdaptSpeed = expectationsBaseAdaptSpeed
        p.expectations.credibilityAmplifier = expectationsCredibilityAmplifier
        p.credibility.surpriseDecrement = credibilitySurpriseDecrement
        p.credibility.calmIncrement = credibilityCalmIncrement
        if let credibilityHighInflationDecrement {
            p.credibility.highInflationDecrement = credibilityHighInflationDecrement
        }
        p.credibility.sustainedLowBonus = credibilitySustainedLowBonus
        p.credibility.capitalControlsDrag = credibilityCapitalControlsDrag
        p.inflation.phillipsSlope = inflationPhillipsSlope
        if let exchangeRateCurrentAccountPressure {
            p.exchangeRate.currentAccountPressure = exchangeRateCurrentAccountPressure
        }
        if let capitalAccountExpectationsSensitivity {
            p.capitalAccount.expectationsSensitivity = capitalAccountExpectationsSensitivity
        }
        p.political.inflationCoef = politicalInflationCoef
        p.political.unemploymentCoef = politicalUnemploymentCoef
        p.political.recessionBump = politicalRecessionBump
        if let politicalSmoothingRetain {
            p.political.smoothingRetain = politicalSmoothingRetain
        }
        p.approval.inflationCoef = approvalInflationCoef
        if let approvalUnemploymentCoef {
            p.approval.unemploymentCoef = approvalUnemploymentCoef
        }
        p.approval.capitalControlsCoef = approvalCapitalControlsCoef
        return p
    }
}

struct LengthModelAdjustments: Codable {
    var exchangeRateUIPMultiplier: Double
    var exchangeRateCurrentAccountPressureMultiplier: Double
    var capitalAccountInterestSensitivityMultiplier: Double
    var capitalAccountExpectationsSensitivityMultiplier: Double
    var currentAccountAbsorptionMultiplier: Double
    var currentAccountPartnerSensitivityMultiplier: Double
    var reservesCriticalMonths: Double
    var reservesWarningMonths: Double
    var outcomesCurrencyCrisisReserves: Double
}

struct OpeningBaselineConfig: Codable {
    var inflation: Double
    var coreInflation: Double
    var expectedInflation: Double
    var unemployment: Double
    var nairu: Double
    var policyRate: Double
    var reserveRequirement: Double
    var m2Growth: Double
    var bankCreditGrowth: Double
    var credibility: Double
    var exchangeRate: Double
    var exchangeRateQoQChange: Double
    var currentAccountGDP: Double
    var capitalAccountGDP: Double
    var foreignReservesMonths: Double
    var capitalControls: Double
    var externalDebtGDP: Double
    var fiscalBalanceGDP: Double
    var governmentDebtGDP: Double
    var politicalPressure: Double
    var publicApproval: Double
    var worldInterestRate: Double
    var worldInflation: Double
    var tradingPartnerGrowth: Double
    var oilPriceIndex: Double
    var commodityPriceIndex: Double
    var termsOfTrade: Double

    func apply(to simulator: EconomicSimulator) {
        simulator.state.inflation = inflation
        simulator.state.coreInflation = coreInflation
        simulator.state.expectedInflation = expectedInflation
        simulator.state.unemployment = unemployment
        simulator.state.nairu = nairu
        simulator.state.policyRate = policyRate
        simulator.state.reserveRequirement = reserveRequirement
        simulator.state.m2Growth = m2Growth
        simulator.state.bankCreditGrowth = bankCreditGrowth
        simulator.state.credibility = credibility
        simulator.state.exchangeRate = exchangeRate
        simulator.state.exchangeRateQoQChange = exchangeRateQoQChange
        simulator.state.currentAccountGDP = currentAccountGDP
        simulator.state.capitalAccountGDP = capitalAccountGDP
        simulator.state.foreignReservesMonths = foreignReservesMonths
        simulator.state.capitalControls = capitalControls
        simulator.state.externalDebtGDP = externalDebtGDP
        simulator.state.fiscalBalanceGDP = fiscalBalanceGDP
        simulator.state.governmentDebtGDP = governmentDebtGDP
        simulator.state.politicalPressure = politicalPressure
        simulator.state.publicApproval = publicApproval

        simulator.environment.worldInterestRate = worldInterestRate
        simulator.environment.worldInflation = worldInflation
        simulator.environment.tradingPartnerGrowth = tradingPartnerGrowth
        simulator.environment.oilPriceIndex = oilPriceIndex
        simulator.environment.commodityPriceIndex = commodityPriceIndex
        simulator.environment.termsOfTrade = termsOfTrade
    }
}

struct OpeningConfig: Codable {
    var historicalGrowth: [String: Double]
    var randomizedGrowthOffsetMin: Double
    var randomizedGrowthOffsetMax: Double
    var randomizedGrowthMin: Double
    var randomizedGrowthMax: Double
    var baselines: [String: OpeningBaselineConfig]
}

struct ScenarioStateOverrideConfig: Codable {
    var inflation: Double? = nil
    var coreInflation: Double? = nil
    var expectedInflation: Double? = nil
    var unemployment: Double? = nil
    var nairu: Double? = nil
    var policyRate: Double? = nil
    var reserveRequirement: Double? = nil
    var m2Growth: Double? = nil
    var bankCreditGrowth: Double? = nil
    var credibility: Double? = nil
    var exchangeRate: Double? = nil
    var exchangeRateQoQChange: Double? = nil
    var currentAccountGDP: Double? = nil
    var capitalAccountGDP: Double? = nil
    var foreignReservesMonths: Double? = nil
    var capitalControls: Double? = nil
    var externalDebtGDP: Double? = nil
    var fiscalBalanceGDP: Double? = nil
    var governmentDebtGDP: Double? = nil
    var politicalPressure: Double? = nil
    var publicApproval: Double? = nil

    func apply(to simulator: EconomicSimulator) {
        if let inflation { simulator.state.inflation = inflation }
        if let coreInflation { simulator.state.coreInflation = coreInflation }
        if let expectedInflation { simulator.state.expectedInflation = expectedInflation }
        if let unemployment { simulator.state.unemployment = unemployment }
        if let nairu { simulator.state.nairu = nairu }
        if let policyRate { simulator.state.policyRate = policyRate }
        if let reserveRequirement { simulator.state.reserveRequirement = reserveRequirement }
        if let m2Growth { simulator.state.m2Growth = m2Growth }
        if let bankCreditGrowth { simulator.state.bankCreditGrowth = bankCreditGrowth }
        if let credibility { simulator.state.credibility = credibility }
        if let exchangeRate { simulator.state.exchangeRate = exchangeRate }
        if let exchangeRateQoQChange { simulator.state.exchangeRateQoQChange = exchangeRateQoQChange }
        if let currentAccountGDP { simulator.state.currentAccountGDP = currentAccountGDP }
        if let capitalAccountGDP { simulator.state.capitalAccountGDP = capitalAccountGDP }
        if let foreignReservesMonths { simulator.state.foreignReservesMonths = foreignReservesMonths }
        if let capitalControls { simulator.state.capitalControls = capitalControls }
        if let externalDebtGDP { simulator.state.externalDebtGDP = externalDebtGDP }
        if let fiscalBalanceGDP { simulator.state.fiscalBalanceGDP = fiscalBalanceGDP }
        if let governmentDebtGDP { simulator.state.governmentDebtGDP = governmentDebtGDP }
        if let politicalPressure { simulator.state.politicalPressure = politicalPressure }
        if let publicApproval { simulator.state.publicApproval = publicApproval }
    }
}

struct ScenarioEnvironmentOverrideConfig: Codable {
    var worldInterestRate: Double? = nil
    var worldInflation: Double? = nil
    var tradingPartnerGrowth: Double? = nil
    var oilPriceIndex: Double? = nil
    var commodityPriceIndex: Double? = nil
    var termsOfTrade: Double? = nil

    func apply(to simulator: EconomicSimulator) {
        if let worldInterestRate { simulator.environment.worldInterestRate = worldInterestRate }
        if let worldInflation { simulator.environment.worldInflation = worldInflation }
        if let tradingPartnerGrowth { simulator.environment.tradingPartnerGrowth = tradingPartnerGrowth }
        if let oilPriceIndex { simulator.environment.oilPriceIndex = oilPriceIndex }
        if let commodityPriceIndex { simulator.environment.commodityPriceIndex = commodityPriceIndex }
        if let termsOfTrade { simulator.environment.termsOfTrade = termsOfTrade }
    }
}

struct ScenarioGoalConfig: Codable {
    var description: String
    var condition: StateConditionConfig
}

struct ScenarioConfig: Codable {
    var title: String
    var summary: String
    var briefing: String
    var teachingFocus: [String]? = nil
    var gameLength: GameLength
    var startYear: Int
    var startQuarter: Int
    var endYear: Int
    var endQuarter: Int
    var openingAnnualizedGrowth: Double? = nil
    var stateOverrides: ScenarioStateOverrideConfig? = nil
    var environmentOverrides: ScenarioEnvironmentOverrideConfig? = nil
    var introNews: [String]? = nil
    var goals: [ScenarioGoalConfig] = []
}

struct ScenarioCatalogConfig: Codable {
    var scenarios: [String: ScenarioConfig]
}

struct ScoreTrackingConfig: Codable {
    var highInflationThreshold: Double
    var severeInflationThreshold: Double
    var recessionGrowthThreshold: Double
    var highUnemploymentThreshold: Double
    var lowCredibilityThreshold: Double
    var nearOusterThreshold: Double
}

struct ScoreOutcomePenaltiesConfig: Codable {
    var currencyCrisis: Int
    var hyperinflation: Int
    var depression: Int
    var politicalOuster: Int
}

struct ScorePerQuarterPenaltyConfig: Codable {
    var highInflation: Int
    var severeInflation: Int
    var stagflation: Int
    var recession: Int
    var highUnemployment: Int
    var lowCredibility: Int
    var nearOuster: Int
}

struct ScoreExtremeConfig: Codable {
    var peakInflationThreshold: Double
    var lowestReservesThreshold: Double
    var lowestCredibilityThreshold: Double
    var peakPoliticalPressureThreshold: Double
    var peakInflationPenalty: Int
    var lowestReservesPenalty: Int
    var lowestCredibilityPenalty: Int
    var peakPoliticalPressurePenalty: Int
}

struct ScoreSuccessBonusConfig: Codable {
    var peakInflationThreshold: Double
    var lowestCredibilityThreshold: Double
    var lowestReservesThreshold: Double
    var inflationContainedBonus: Int
    var credibilityBonus: Int
    var laborMarketBonus: Int
    var externalPositionBonus: Int
}

struct ScoreDifficultyPenaltyScaleConfig: Codable {
    var apprentice: Double
    var governor: Double
    var volcker: Double
}

struct ScoreCalibrationConfig: Codable {
    var shortMandateHeldBonus: Int
    var extendedMandateHeldBonus: Int
    var shortEnduranceBonusMax: Int
    var extendedEnduranceBonusMax: Int
    var difficultyPenaltyScale: ScoreDifficultyPenaltyScaleConfig
    var topEndCompressionThreshold: Int
    var topEndCompressionFactor: Double
}

struct ScoreHeadlineBand: Codable {
    var minScore: Int
    var label: String
}

struct ScoringConfig: Codable {
    var baseline: Int
    var extendedBonusScale: Double
    var tracking: ScoreTrackingConfig
    var outcomePenalties: ScoreOutcomePenaltiesConfig
    var perQuarterPenalties: ScorePerQuarterPenaltyConfig
    var extremes: ScoreExtremeConfig
    var successBonuses: ScoreSuccessBonusConfig
    var calibration: ScoreCalibrationConfig
    var headlineBands: [ScoreHeadlineBand]
}

struct CabinetRequestConfig: Codable {
    var detail: String
    var trigger: StateConditionConfig
    var acceptEffects: ConfiguredEffectBundle
    var rejectEffects: ConfiguredEffectBundle
}

struct CabinetConfig: Codable {
    var delayEffects: ConfiguredEffectBundle
    var requests: [String: CabinetRequestConfig]
}

struct CrisisMeasureConfig: Codable {
    var detail: String
    var tradeoff: String
    var availability: StateConditionConfig
    var effects: ConfiguredEffectBundle
    var newsLine: String
    var resultMessage: String
}

struct CrisisConfig: Codable {
    var cooldownQuarters: Int
    var measures: [String: CrisisMeasureConfig]
}

struct EventDescriptorConfig: Codable {
    var kind: String
    var value: Double? = nil
    var minValue: Double? = nil
    var maxValue: Double? = nil

    func makeEventType(using rng: inout SeededRandomGenerator) -> EventType {
        func sampledValue() -> Double {
            if let value { return value }
            if let minValue, let maxValue {
                return Double.random(in: minValue...maxValue, using: &rng)
            }
            return 0.0
        }

        switch kind {
        case "oilShock": return .oilShock(magnitude: sampledValue())
        case "oilRecovery": return .oilRecovery(magnitude: sampledValue())
        case "tradingPartnerRecession": return .tradingPartnerRecession(severity: sampledValue())
        case "tradingPartnerRecovery": return .tradingPartnerRecovery
        case "speculativeAttack": return .speculativeAttack
        case "commodityBoom": return .commodityBoom(magnitude: sampledValue())
        case "commoditySlump": return .commoditySlump(magnitude: sampledValue())
        case "droughtOrDisaster": return .droughtOrDisaster
        case "politicalDemand": return .politicalDemand
        case "imfReview": return .imfReview
        case "capitalFlight": return .capitalFlight
        case "debtRefinancing": return .debtRefinancing
        case "tourismBoom": return .tourismBoom
        case "tourismCollapse": return .tourismCollapse
        case "workerStrike": return .workerStrike
        case "creditCrunch": return .creditCrunch
        case "foreignAid": return .foreignAid
        default:
            return .foreignAid
        }
    }

    func makeEventType() -> EventType {
        var rng = SeededRandomGenerator(seed: 1)
        return makeEventType(using: &rng)
    }
}

struct CommonRandomEventConfig: Codable {
    var event: EventDescriptorConfig
    var probability: Double
    var condition: StateConditionConfig? = nil
}

struct MacroEventConfig: Codable {
    var event: EventDescriptorConfig
    var totalProbability: Double
    var earliestQuarterIndex: Int
    var latestQuarterIndex: Int
    var condition: StateConditionConfig? = nil
}

struct RandomEventsConfig: Codable {
    var cycleLength: Int
    var commonPool: [CommonRandomEventConfig]
    var macroPool: [MacroEventConfig]
}

struct RandomizedWorldRatesConfig: Codable {
    var baseRate: Double
    var floorRate: Double
    var ceilingRate: Double
    var jumpProbability: Double
    var jumpMin: Double
    var jumpMax: Double
    var driftMin: Double
    var driftMax: Double
    var trendMax: Double
}

struct GameTuningConfig: Codable {
    var difficulties: [String: DifficultyConfig]
    var gameLengths: [String: LengthModelAdjustments]
    var opening: OpeningConfig
    var scoring: ScoringConfig
    var cabinet: CabinetConfig
    var crisis: CrisisConfig
    var randomEvents: RandomEventsConfig
    var randomizedWorldRates: RandomizedWorldRatesConfig
}

struct HistoricalQuarterEventsConfig: Codable {
    var quarter: String
    var events: [EventDescriptorConfig]
}

struct HistoricalWorldRateSegment: Codable {
    var startYear: Int
    var endYear: Int
    var rate: Double
}

struct HistoricalTrackConfig: Codable {
    var scriptedEvents: [HistoricalQuarterEventsConfig]
    var worldRates: [HistoricalWorldRateSegment]

    func eventsByQuarter() -> [String: [EconomicEvent]] {
        var out: [String: [EconomicEvent]] = [:]
        for entry in scriptedEvents {
            out[entry.quarter] = entry.events.map { EconomicEvent(type: $0.makeEventType(), isScripted: true) }
        }
        return out
    }

    func worldRate(for year: Int) -> Double? {
        worldRates.first { year >= $0.startYear && year <= $0.endYear }?.rate
    }
}

enum GameConfigs {
    static let tuning = loadConfig(ConfigFiles.tuning, fallback: GameTuningConfig.fallback)
    static let historicalShort = loadConfig(ConfigFiles.historicalShort, fallback: HistoricalTrackConfig.shortFallback)
    static let historicalExtended = loadConfig(ConfigFiles.historicalExtended, fallback: HistoricalTrackConfig.extendedFallback)
    static let scenarios = loadConfig(ConfigFiles.scenarios, fallback: ScenarioCatalogConfig.fallback)

    static func historicalTrack(for length: GameLength) -> HistoricalTrackConfig {
        switch length {
        case .short: return historicalShort
        case .extended: return historicalExtended
        }
    }

    static func difficulty(_ difficulty: Difficulty) -> DifficultyConfig {
        tuning.difficulties[difficulty.rawValue] ?? GameTuningConfig.fallback.difficulties[difficulty.rawValue]!
    }

    static func lengthAdjustments(for gameLength: GameLength) -> LengthModelAdjustments? {
        tuning.gameLengths[gameLength.rawValue]
    }

    static func openingBaseline(for gameLength: GameLength) -> OpeningBaselineConfig {
        tuning.opening.baselines[gameLength.rawValue] ?? GameTuningConfig.fallback.opening.baselines[gameLength.rawValue]!
    }

    static func openingHistoricalGrowth(for gameLength: GameLength) -> Double {
        tuning.opening.historicalGrowth[gameLength.rawValue]
            ?? GameTuningConfig.fallback.opening.historicalGrowth[gameLength.rawValue]
            ?? 0.04
    }

    static func cabinetRequest(_ type: CabinetRequestType) -> CabinetRequestConfig {
        tuning.cabinet.requests[type.rawValue] ?? GameTuningConfig.fallback.cabinet.requests[type.rawValue]!
    }

    static func crisisMeasure(_ type: CrisisMeasureType) -> CrisisMeasureConfig {
        tuning.crisis.measures[type.rawValue] ?? GameTuningConfig.fallback.crisis.measures[type.rawValue]!
    }

    static func scenario(id: String) -> ScenarioConfig? {
        scenarios.scenarios[id]
    }

    static func scenarioIDs(for gameLength: GameLength) -> [String] {
        scenarios.scenarios
            .filter { $0.value.gameLength == gameLength }
            .sorted { lhs, rhs in
                if lhs.value.startYear != rhs.value.startYear {
                    return lhs.value.startYear < rhs.value.startYear
                }
                if lhs.value.startQuarter != rhs.value.startQuarter {
                    return lhs.value.startQuarter < rhs.value.startQuarter
                }
                return lhs.value.title < rhs.value.title
            }
            .map(\.key)
    }
}

extension EconomicSimulator {
    func applyConfiguredEffects(_ effects: ConfiguredEffectBundle) {
        if let delta = effects.policyRateDelta {
            state.policyRate = max(0.0, state.policyRate + delta)
        }
        if let delta = effects.reserveRequirementDelta {
            state.reserveRequirement = (0.0...0.50).clamping(state.reserveRequirement + delta)
        }
        if let delta = effects.capitalControlsDelta {
            setCapitalControls(state.capitalControls + delta)
        }
        if let months = effects.fxInterventionMonths {
            applyFXIntervention(months: months)
        }
        if let delta = effects.foreignReservesMonthsDelta {
            state.foreignReservesMonths = max(0.0, state.foreignReservesMonths + delta)
        }
        if let delta = effects.capitalAccountGDPDelta {
            state.capitalAccountGDP = params.capitalAccount.bounds.clamping(state.capitalAccountGDP + delta)
        }
        if let delta = effects.currentAccountGDPDelta {
            state.currentAccountGDP = params.currentAccount.bounds.clamping(state.currentAccountGDP + delta)
        }
        if let delta = effects.credibilityDelta {
            state.credibility = params.credibility.bounds.clamping(state.credibility + delta)
        }
        if let delta = effects.expectedInflationDelta {
            state.expectedInflation = params.expectations.bounds.clamping(state.expectedInflation + delta)
        }
        if let delta = effects.outputGapDelta {
            state.outputGap = params.outputGap.bounds.clamping(state.outputGap + delta)
        }
        if let delta = effects.publicApprovalDelta {
            state.publicApproval = params.approval.bounds.clamping(state.publicApproval + delta)
        }
        if let delta = effects.politicalPressureDelta {
            state.politicalPressure = params.political.bounds.clamping(state.politicalPressure + delta)
        }
        if let delta = effects.externalDebtGDPDelta {
            state.externalDebtGDP = params.fiscal.externalDebtBounds.clamping(state.externalDebtGDP + delta)
        }
        if let delta = effects.inflationDelta {
            state.inflation = params.inflation.bounds.clamping(state.inflation + delta)
        }
        if let delta = effects.interventionSupportCarryDelta {
            interventionSupportCarry = min(0.050, max(0.0, interventionSupportCarry + delta))
        }
        if let delta = effects.controlsReliefCarryDelta {
            controlsReliefCarry = min(0.050, max(0.0, controlsReliefCarry + delta))
        }
    }
}

extension GameTuningConfig {
    static let fallback = GameTuningConfig(
        difficulties: [
            "apprentice": DifficultyConfig(
                displayName: "Apprentice",
                tagline: "Forgiving. Expectations anchor easily; political shocks pass quickly.",
                expectationsBaseAdaptSpeed: 0.13,
                expectationsCredibilityAmplifier: 0.22,
                credibilitySurpriseDecrement: 0.018,
                credibilityCalmIncrement: 0.012,
                credibilitySustainedLowBonus: 0.028,
                credibilityCapitalControlsDrag: 0.010,
                inflationPhillipsSlope: 0.16,
                politicalInflationCoef: 90.0,
                politicalUnemploymentCoef: 140.0,
                politicalRecessionBump: 12.0,
                approvalInflationCoef: -200.0,
                approvalCapitalControlsCoef: -18.0),
            "governor": DifficultyConfig(
                displayName: "Governor",
                tagline: "The default model. Historically plausible rigidity and fragility.",
                expectationsBaseAdaptSpeed: 0.21,
                expectationsCredibilityAmplifier: 0.45,
                credibilitySurpriseDecrement: 0.025,
                credibilityCalmIncrement: 0.007,
                credibilitySustainedLowBonus: 0.012,
                credibilityCapitalControlsDrag: 0.022,
                inflationPhillipsSlope: 0.26,
                politicalInflationCoef: 170.0,
                politicalUnemploymentCoef: 220.0,
                politicalRecessionBump: 24.0,
                approvalInflationCoef: -360.0,
                approvalUnemploymentCoef: -520.0,
                approvalCapitalControlsCoef: -25.0),
            "volcker": DifficultyConfig(
                displayName: "Volcker",
                tagline: "Punishing. Expectations de-anchor fast; credibility is precious.",
                expectationsBaseAdaptSpeed: 0.25,
                expectationsCredibilityAmplifier: 0.58,
                credibilitySurpriseDecrement: 0.040,
                credibilityCalmIncrement: 0.005,
                credibilityHighInflationDecrement: 0.018,
                credibilitySustainedLowBonus: 0.010,
                credibilityCapitalControlsDrag: 0.028,
                inflationPhillipsSlope: 0.29,
                exchangeRateCurrentAccountPressure: -0.25,
                capitalAccountExpectationsSensitivity: -0.62,
                politicalInflationCoef: 190.0,
                politicalUnemploymentCoef: 250.0,
                politicalRecessionBump: 28.0,
                politicalSmoothingRetain: 0.84,
                approvalInflationCoef: -390.0,
                approvalUnemploymentCoef: -560.0,
                approvalCapitalControlsCoef: -34.0)
        ],
        gameLengths: [
            "extended": LengthModelAdjustments(
                exchangeRateUIPMultiplier: 1.10,
                exchangeRateCurrentAccountPressureMultiplier: 0.78,
                capitalAccountInterestSensitivityMultiplier: 1.10,
                capitalAccountExpectationsSensitivityMultiplier: 0.75,
                currentAccountAbsorptionMultiplier: 0.85,
                currentAccountPartnerSensitivityMultiplier: 1.10,
                reservesCriticalMonths: 0.70,
                reservesWarningMonths: 2.20,
                outcomesCurrencyCrisisReserves: 0.50)
        ],
        opening: OpeningConfig(
            historicalGrowth: [
                "short": 0.042,
                "extended": 0.048
            ],
            randomizedGrowthOffsetMin: -0.010,
            randomizedGrowthOffsetMax: 0.020,
            randomizedGrowthMin: 0.015,
            randomizedGrowthMax: 0.060,
            baselines: [
                "short": OpeningBaselineConfig(
                    inflation: 0.055,
                    coreInflation: 0.050,
                    expectedInflation: 0.050,
                    unemployment: 0.065,
                    nairu: 0.070,
                    policyRate: 0.060,
                    reserveRequirement: 0.12,
                    m2Growth: 0.080,
                    bankCreditGrowth: 0.100,
                    credibility: 0.70,
                    exchangeRate: 2.00,
                    exchangeRateQoQChange: 0.0,
                    currentAccountGDP: -0.025,
                    capitalAccountGDP: 0.008,
                    foreignReservesMonths: 4.20,
                    capitalControls: 0.30,
                    externalDebtGDP: 0.30,
                    fiscalBalanceGDP: -0.040,
                    governmentDebtGDP: 0.500,
                    politicalPressure: 24.0,
                    publicApproval: 52.0,
                    worldInterestRate: 0.060,
                    worldInflation: 0.055,
                    tradingPartnerGrowth: 0.035,
                    oilPriceIndex: 100.0,
                    commodityPriceIndex: 100.0,
                    termsOfTrade: 1.0),
                "extended": OpeningBaselineConfig(
                    inflation: 0.032,
                    coreInflation: 0.030,
                    expectedInflation: 0.030,
                    unemployment: 0.055,
                    nairu: 0.062,
                    policyRate: 0.055,
                    reserveRequirement: 0.11,
                    m2Growth: 0.070,
                    bankCreditGrowth: 0.085,
                    credibility: 0.78,
                    exchangeRate: 1.65,
                    exchangeRateQoQChange: 0.0,
                    currentAccountGDP: -0.004,
                    capitalAccountGDP: 0.012,
                    foreignReservesMonths: 6.8,
                    capitalControls: 0.25,
                    externalDebtGDP: 0.18,
                    fiscalBalanceGDP: -0.025,
                    governmentDebtGDP: 0.32,
                    politicalPressure: 18.0,
                    publicApproval: 58.0,
                    worldInterestRate: 0.045,
                    worldInflation: 0.025,
                    tradingPartnerGrowth: 0.042,
                    oilPriceIndex: 100.0,
                    commodityPriceIndex: 100.0,
                    termsOfTrade: 1.02)
            ]),
        scoring: ScoringConfig(
            baseline: 100,
            extendedBonusScale: 1.5,
            tracking: ScoreTrackingConfig(
                highInflationThreshold: 0.08,
                severeInflationThreshold: 0.15,
                recessionGrowthThreshold: -0.005,
                highUnemploymentThreshold: 0.085,
                lowCredibilityThreshold: 0.50,
                nearOusterThreshold: 70.0),
            outcomePenalties: ScoreOutcomePenaltiesConfig(
                currencyCrisis: 60,
                hyperinflation: 70,
                depression: 55,
                politicalOuster: 50),
            perQuarterPenalties: ScorePerQuarterPenaltyConfig(
                highInflation: 3,
                severeInflation: 4,
                stagflation: 3,
                recession: 2,
                highUnemployment: 2,
                lowCredibility: 1,
                nearOuster: 2),
            extremes: ScoreExtremeConfig(
                peakInflationThreshold: 0.25,
                lowestReservesThreshold: 2.5,
                lowestCredibilityThreshold: 0.35,
                peakPoliticalPressureThreshold: 80.0,
                peakInflationPenalty: 8,
                lowestReservesPenalty: 8,
                lowestCredibilityPenalty: 8,
                peakPoliticalPressurePenalty: 6),
            successBonuses: ScoreSuccessBonusConfig(
                peakInflationThreshold: 0.07,
                lowestCredibilityThreshold: 0.75,
                lowestReservesThreshold: 3.0,
                inflationContainedBonus: 10,
                credibilityBonus: 8,
                laborMarketBonus: 6,
                externalPositionBonus: 6),
            calibration: ScoreCalibrationConfig(
                shortMandateHeldBonus: 2,
                extendedMandateHeldBonus: 6,
                shortEnduranceBonusMax: 2,
                extendedEnduranceBonusMax: 6,
                difficultyPenaltyScale: ScoreDifficultyPenaltyScaleConfig(
                    apprentice: 1.0,
                    governor: 0.68,
                    volcker: 0.52),
                topEndCompressionThreshold: 70,
                topEndCompressionFactor: 0.6),
            headlineBands: [
                ScoreHeadlineBand(minScore: 95, label: "VOLCKER-CLASS OPERATOR"),
                ScoreHeadlineBand(minScore: 82, label: "Competent Technocrat"),
                ScoreHeadlineBand(minScore: 68, label: "Steady Hand, Choppy Decade"),
                ScoreHeadlineBand(minScore: 52, label: "Muddled Through"),
                ScoreHeadlineBand(minScore: 36, label: "Credibility in Tatters"),
                ScoreHeadlineBand(minScore: 18, label: "Accidental Arsonist"),
                ScoreHeadlineBand(minScore: 0, label: "Mandate in Ruins")
            ]),
        cabinet: CabinetConfig(
            delayEffects: ConfiguredEffectBundle(politicalPressureDelta: 3.0),
            requests: [
                "cutRates": CabinetRequestConfig(
                    detail: "Cabinet argues unemployment is politically intolerable and demands rate relief.",
                    trigger: StateConditionConfig(anyOf: [
                        StateConditionConfig(minUnemployment: 0.09),
                        StateConditionConfig(maxOutputGap: -0.03),
                        StateConditionConfig(minPoliticalPressure: 55.0)
                    ]),
                    acceptEffects: ConfiguredEffectBundle(
                        policyRateDelta: -0.01,
                        credibilityDelta: -0.010,
                        publicApprovalDelta: 3.0,
                        politicalPressureDelta: -8.0
                    ),
                    rejectEffects: ConfiguredEffectBundle(
                        credibilityDelta: 0.008,
                        publicApprovalDelta: -2.0,
                        politicalPressureDelta: 8.0
                    )),
                "tightenControls": CabinetRequestConfig(
                    detail: "Ministers want tighter capital controls to slow reserve losses and show crisis management.",
                    trigger: StateConditionConfig(maxCapitalControls: 0.69, maxForeignReservesMonths: 3.0),
                    acceptEffects: ConfiguredEffectBundle(
                        capitalControlsDelta: 0.10,
                        capitalAccountGDPDelta: 0.008,
                        credibilityDelta: -0.010,
                        publicApprovalDelta: -2.0,
                        politicalPressureDelta: -4.0
                    ),
                    rejectEffects: ConfiguredEffectBundle(
                        credibilityDelta: 0.005,
                        politicalPressureDelta: 5.0)),
                "defendCurrency": CabinetRequestConfig(
                    detail: "The Prime Minister wants visible action to arrest SLD weakness before confidence collapses.",
                    trigger: StateConditionConfig(
                        minForeignReservesMonths: 0.8,
                        anyOf: [
                            StateConditionConfig(minExchangeRateQoQChange: 0.035),
                            StateConditionConfig(maxForeignReservesMonths: 2.2)
                        ]),
                    acceptEffects: ConfiguredEffectBundle(
                        fxInterventionMonths: -0.50,
                        credibilityDelta: 0.005,
                        publicApprovalDelta: 1.0,
                        politicalPressureDelta: -5.0
                    ),
                    rejectEffects: ConfiguredEffectBundle(
                        credibilityDelta: -0.005,
                        publicApprovalDelta: -3.0,
                        politicalPressureDelta: 6.0
                    ))
            ]),
        crisis: CrisisConfig(
            cooldownQuarters: 4,
            measures: [
                "imfProgram": CrisisMeasureConfig(
                    detail: "Request an IMF package to stabilize reserves and reopen external financing.",
                    tradeoff: "Adds reserves and credibility, but hurts growth, approval, and raises external debt.",
                    availability: StateConditionConfig(anyOf: [
                        StateConditionConfig(maxForeignReservesMonths: 1.15),
                        StateConditionConfig(minExternalDebtGDP: 0.74),
                        StateConditionConfig(minExchangeRateQoQChange: 0.065)
                    ]),
                    effects: ConfiguredEffectBundle(
                        foreignReservesMonthsDelta: 1.1,
                        capitalAccountGDPDelta: 0.007,
                        credibilityDelta: 0.007,
                        expectedInflationDelta: -0.002,
                        outputGapDelta: -0.014,
                        publicApprovalDelta: -7.5,
                        politicalPressureDelta: 5.5,
                        externalDebtGDPDelta: 0.032,
                        interventionSupportCarryDelta: 0.009),
                    newsLine: "CRISIS MEASURE: IMF program agreed. Reserves replenished, but austerity politics turn ugly.",
                    resultMessage: "IMF program enacted. Reserves rise, expectations cool, but growth and approval take a hit."),
                "bankHoliday": CrisisMeasureConfig(
                    detail: "Shut banks briefly and tighten emergency controls to stop a run on the system.",
                    tradeoff: "Buys FX relief fast, but damages approval, credibility, and alarms the public.",
                    availability: StateConditionConfig(anyOf: [
                        StateConditionConfig(maxForeignReservesMonths: 1.4),
                        StateConditionConfig(maxCapitalAccountGDP: -0.01),
                        StateConditionConfig(minExchangeRateQoQChange: 0.035)
                    ]),
                    effects: ConfiguredEffectBundle(
                        capitalControlsDelta: 0.3,
                        foreignReservesMonthsDelta: 0.6,
                        capitalAccountGDPDelta: 0.028,
                        credibilityDelta: -0.012,
                        expectedInflationDelta: 0.001,
                        publicApprovalDelta: -6.0,
                        politicalPressureDelta: 2.0,
                        interventionSupportCarryDelta: 0.016,
                        controlsReliefCarryDelta: 0.022
                    ),
                    newsLine: "CRISIS MEASURE: Bank holiday declared. Authorities halt the run and tighten controls.",
                    resultMessage: "Bank holiday enacted. External pressure eases, but confidence and approval suffer."),
                "emergencyLiquidity": CrisisMeasureConfig(
                    detail: "Backstop banks and credit markets before recession turns into a collapse.",
                    tradeoff: "Supports demand and politics now, but lifts inflation risk and dents credibility.",
                    availability: StateConditionConfig(anyOf: [
                        StateConditionConfig(minUnemployment: 0.09),
                        StateConditionConfig(maxOutputGap: -0.025),
                        StateConditionConfig(maxAnnualizedGDPGrowth: -0.005)
                    ]),
                    effects: ConfiguredEffectBundle(
                        foreignReservesMonthsDelta: -0.03,
                        credibilityDelta: -0.006,
                        expectedInflationDelta: 0.001,
                        outputGapDelta: 0.025,
                        publicApprovalDelta: 4.0,
                        politicalPressureDelta: -5.0,
                        inflationDelta: 0.004
                    ),
                    newsLine: "CRISIS MEASURE: Emergency liquidity window opened. Credit panic slows, but inflation risk rises.",
                    resultMessage: "Emergency liquidity opened. Recession pressure eases now, but inflation and credibility worsen.")
            ]),
        randomEvents: RandomEventsConfig(
            cycleLength: 36,
            commonPool: [
                CommonRandomEventConfig(event: EventDescriptorConfig(kind: "tourismBoom"), probability: 0.06),
                CommonRandomEventConfig(event: EventDescriptorConfig(kind: "tourismCollapse"), probability: 0.08),
                CommonRandomEventConfig(event: EventDescriptorConfig(kind: "commodityBoom", value: 0.15), probability: 0.05),
                CommonRandomEventConfig(event: EventDescriptorConfig(kind: "commoditySlump", value: 0.12), probability: 0.08),
                CommonRandomEventConfig(event: EventDescriptorConfig(kind: "droughtOrDisaster"), probability: 0.07),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "workerStrike"),
                    probability: 0.10,
                    condition: StateConditionConfig(anyOf: [
                        StateConditionConfig(minUnemployment: 0.08),
                        StateConditionConfig(minInflation: 0.10)
                    ])),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "politicalDemand"),
                    probability: 0.14,
                    condition: StateConditionConfig(anyOf: [
                        StateConditionConfig(minPoliticalPressure: 35.0),
                        StateConditionConfig(minUnemployment: 0.085),
                        StateConditionConfig(minInflation: 0.08)
                    ])),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "speculativeAttack"),
                    probability: 0.10,
                    condition: StateConditionConfig(maxCapitalControls: 0.69, maxForeignReservesMonths: 4.0)),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "capitalFlight"),
                    probability: 0.10,
                    condition: StateConditionConfig(anyOf: [
                        StateConditionConfig(minInflation: 0.10),
                        StateConditionConfig(maxForeignReservesMonths: 3.4)
                    ])),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "creditCrunch"),
                    probability: 0.04,
                    condition: StateConditionConfig(minPolicyRate: 0.14)),
                CommonRandomEventConfig(
                    event: EventDescriptorConfig(kind: "foreignAid"),
                    probability: 0.03,
                    condition: StateConditionConfig(maxForeignReservesMonths: 2.5))
            ],
            macroPool: [
                MacroEventConfig(event: EventDescriptorConfig(kind: "oilShock", minValue: 1.0, maxValue: 2.8), totalProbability: 0.90, earliestQuarterIndex: 2, latestQuarterIndex: 28),
                MacroEventConfig(event: EventDescriptorConfig(kind: "oilShock", minValue: 0.6, maxValue: 1.4), totalProbability: 0.80, earliestQuarterIndex: 10, latestQuarterIndex: 34),
                MacroEventConfig(event: EventDescriptorConfig(kind: "oilRecovery", minValue: 0.10, maxValue: 0.25), totalProbability: 0.55, earliestQuarterIndex: 8, latestQuarterIndex: 34),
                MacroEventConfig(event: EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.025), totalProbability: 0.85, earliestQuarterIndex: 2, latestQuarterIndex: 28),
                MacroEventConfig(event: EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.020), totalProbability: 0.65, earliestQuarterIndex: 16, latestQuarterIndex: 34),
                MacroEventConfig(event: EventDescriptorConfig(kind: "tradingPartnerRecovery"), totalProbability: 0.65, earliestQuarterIndex: 6, latestQuarterIndex: 30),
                MacroEventConfig(event: EventDescriptorConfig(kind: "debtRefinancing"), totalProbability: 0.80, earliestQuarterIndex: 4, latestQuarterIndex: 24),
                MacroEventConfig(event: EventDescriptorConfig(kind: "debtRefinancing"), totalProbability: 0.70, earliestQuarterIndex: 18, latestQuarterIndex: 34),
                MacroEventConfig(event: EventDescriptorConfig(kind: "imfReview"), totalProbability: 0.90, earliestQuarterIndex: 4, latestQuarterIndex: 20),
                MacroEventConfig(event: EventDescriptorConfig(kind: "imfReview"), totalProbability: 0.90, earliestQuarterIndex: 22, latestQuarterIndex: 34),
                MacroEventConfig(event: EventDescriptorConfig(kind: "commodityBoom", value: 0.25), totalProbability: 0.40, earliestQuarterIndex: 0, latestQuarterIndex: 28),
                MacroEventConfig(event: EventDescriptorConfig(kind: "commoditySlump", value: 0.30), totalProbability: 0.65, earliestQuarterIndex: 4, latestQuarterIndex: 34)
            ]),
        randomizedWorldRates: RandomizedWorldRatesConfig(
            baseRate: 0.060,
            floorRate: 0.04,
            ceilingRate: 0.18,
            jumpProbability: 0.10,
            jumpMin: -0.012,
            jumpMax: 0.040,
            driftMin: -0.004,
            driftMax: 0.010,
            trendMax: 0.055))
}

extension HistoricalTrackConfig {
    static let shortFallback = HistoricalTrackConfig(
        scriptedEvents: [
            HistoricalQuarterEventsConfig(quarter: "Q4 1973", events: [EventDescriptorConfig(kind: "oilShock", value: 3.0)]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1974", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.030)]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1974", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1975", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1976", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1977", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1979", events: [EventDescriptorConfig(kind: "oilShock", value: 1.40)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1979", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1980", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.025)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1980", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1981", events: [EventDescriptorConfig(kind: "oilRecovery", value: 0.20)])
        ],
        worldRates: [
            HistoricalWorldRateSegment(startYear: 0, endYear: 1974, rate: 0.060),
            HistoricalWorldRateSegment(startYear: 1975, endYear: 1977, rate: 0.065),
            HistoricalWorldRateSegment(startYear: 1978, endYear: 1978, rate: 0.075),
            HistoricalWorldRateSegment(startYear: 1979, endYear: 1979, rate: 0.110),
            HistoricalWorldRateSegment(startYear: 1980, endYear: 1980, rate: 0.135),
            HistoricalWorldRateSegment(startYear: 1981, endYear: 1981, rate: 0.155),
            HistoricalWorldRateSegment(startYear: 1982, endYear: 3000, rate: 0.130)
        ])

    static let extendedFallback = HistoricalTrackConfig(
        scriptedEvents: [
            HistoricalQuarterEventsConfig(quarter: "Q2 1961", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.015)]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1962", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1965", events: [EventDescriptorConfig(kind: "tourismBoom")]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1967", events: [EventDescriptorConfig(kind: "commoditySlump", value: 0.10)]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1970", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.018)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1971", events: [EventDescriptorConfig(kind: "speculativeAttack")]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1973", events: [EventDescriptorConfig(kind: "oilShock", value: 3.0)]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1974", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.030)]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1974", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1975", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1976", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1977", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1979", events: [EventDescriptorConfig(kind: "oilShock", value: 1.40)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1979", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1980", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.025)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1980", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1981", events: [EventDescriptorConfig(kind: "oilRecovery", value: 0.20)]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1982", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1983", events: [EventDescriptorConfig(kind: "imfReview")]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1985", events: [EventDescriptorConfig(kind: "commoditySlump", value: 0.18)]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1986", events: [EventDescriptorConfig(kind: "oilRecovery", value: 0.15)]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1987", events: [EventDescriptorConfig(kind: "creditCrunch")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1988", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1990", events: [EventDescriptorConfig(kind: "oilShock", value: 0.65)]),
            HistoricalQuarterEventsConfig(quarter: "Q1 1991", events: [EventDescriptorConfig(kind: "tradingPartnerRecession", value: 0.020)]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1992", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1994", events: [EventDescriptorConfig(kind: "debtRefinancing")]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1994", events: [EventDescriptorConfig(kind: "capitalFlight")]),
            HistoricalQuarterEventsConfig(quarter: "Q3 1997", events: [EventDescriptorConfig(kind: "capitalFlight"), EventDescriptorConfig(kind: "speculativeAttack")]),
            HistoricalQuarterEventsConfig(quarter: "Q4 1998", events: [EventDescriptorConfig(kind: "commoditySlump", value: 0.22)]),
            HistoricalQuarterEventsConfig(quarter: "Q2 1999", events: [EventDescriptorConfig(kind: "tradingPartnerRecovery")])
        ],
        worldRates: [
            HistoricalWorldRateSegment(startYear: 0, endYear: 1964, rate: 0.045),
            HistoricalWorldRateSegment(startYear: 1965, endYear: 1968, rate: 0.050),
            HistoricalWorldRateSegment(startYear: 1969, endYear: 1971, rate: 0.060),
            HistoricalWorldRateSegment(startYear: 1972, endYear: 1974, rate: 0.065),
            HistoricalWorldRateSegment(startYear: 1975, endYear: 1977, rate: 0.065),
            HistoricalWorldRateSegment(startYear: 1978, endYear: 1978, rate: 0.075),
            HistoricalWorldRateSegment(startYear: 1979, endYear: 1979, rate: 0.110),
            HistoricalWorldRateSegment(startYear: 1980, endYear: 1980, rate: 0.135),
            HistoricalWorldRateSegment(startYear: 1981, endYear: 1981, rate: 0.155),
            HistoricalWorldRateSegment(startYear: 1982, endYear: 1984, rate: 0.125),
            HistoricalWorldRateSegment(startYear: 1985, endYear: 1988, rate: 0.090),
            HistoricalWorldRateSegment(startYear: 1989, endYear: 1990, rate: 0.100),
            HistoricalWorldRateSegment(startYear: 1991, endYear: 1993, rate: 0.070),
            HistoricalWorldRateSegment(startYear: 1994, endYear: 1995, rate: 0.085),
            HistoricalWorldRateSegment(startYear: 1996, endYear: 1997, rate: 0.075),
            HistoricalWorldRateSegment(startYear: 1998, endYear: 1999, rate: 0.065),
            HistoricalWorldRateSegment(startYear: 2000, endYear: 3000, rate: 0.060)
        ])
}

extension ScenarioCatalogConfig {
    static let fallback = ScenarioCatalogConfig(
        scenarios: [
            "soft_landing_1966": ScenarioConfig(
                title: "Soft Landing Lesson",
                summary: "A hot economy still gives you time to act before inflation psychology hardens.",
                briefing: "Growth is strong, unemployment is low, and inflation is only beginning to edge upward. This is a lesson in pre-emption: if you wait until inflation is obvious to everyone, the cure will become much harsher.",
                teachingFocus: [
                    "How to cool demand before inflation and expectations become entrenched.",
                    "How to preserve credibility without needlessly crashing growth.",
                    "Why acting early is politically easier than acting late."
                ],
                gameLength: .short,
                startYear: 1966,
                startQuarter: 1,
                endYear: 1968,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.052,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.041,
                    coreInflation: 0.038,
                    expectedInflation: 0.034,
                    unemployment: 0.048,
                    policyRate: 0.055,
                    reserveRequirement: 0.11,
                    credibility: 0.79,
                    exchangeRate: 1.82,
                    currentAccountGDP: -0.012,
                    capitalAccountGDP: 0.017,
                    foreignReservesMonths: 5.8,
                    externalDebtGDP: 0.16,
                    fiscalBalanceGDP: -0.018,
                    politicalPressure: 14.0,
                    publicApproval: 61.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.048,
                    tradingPartnerGrowth: 0.028,
                    oilPriceIndex: 102.0,
                    commodityPriceIndex: 101.0,
                    termsOfTrade: 1.02),
                introNews: [
                    "SCENARIO: The economy is running hot, but the danger is not yet obvious to most voters.",
                    "This is a teaching run about tightening early enough that later tightening becomes unnecessary."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with inflation below 6%.",
                                       condition: StateConditionConfig(maxInflation: 0.06)),
                    ScenarioGoalConfig(description: "Keep unemployment below 7.5%.",
                                       condition: StateConditionConfig(maxUnemployment: 0.075)),
                    ScenarioGoalConfig(description: "End with credibility at or above 75%.",
                                       condition: StateConditionConfig(minCredibility: 0.75))
                ]),
            "bretton_break_1971": ScenarioConfig(
                title: "Bretton Woods Break",
                summary: "The old monetary order is fraying and imported instability is reaching Solaverde.",
                briefing: "The postwar monetary calm is ending. World rates are shifting, exchange assumptions are less reliable, and a small open economy can no longer treat external stability as a given.",
                gameLength: .extended,
                startYear: 1971,
                startQuarter: 3,
                endYear: 1974,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.032,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.049,
                    coreInflation: 0.044,
                    expectedInflation: 0.040,
                    unemployment: 0.061,
                    policyRate: 0.062,
                    credibility: 0.74,
                    exchangeRate: 1.94,
                    currentAccountGDP: -0.016,
                    capitalAccountGDP: 0.011,
                    foreignReservesMonths: 5.0,
                    externalDebtGDP: 0.22,
                    fiscalBalanceGDP: -0.024,
                    politicalPressure: 18.0,
                    publicApproval: 58.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.060,
                    tradingPartnerGrowth: 0.023,
                    oilPriceIndex: 108.0,
                    commodityPriceIndex: 103.0,
                    termsOfTrade: 1.01),
                introNews: [
                    "SCENARIO: The Bretton Woods system is breaking apart and exchange certainty is evaporating.",
                    "Your task is to keep external stability from becoming imported inflation and domestic panic."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with inflation below 9%.",
                                       condition: StateConditionConfig(maxInflation: 0.09)),
                    ScenarioGoalConfig(description: "Keep reserves above 3.0 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 3.0)),
                    ScenarioGoalConfig(description: "Keep external debt below 35% of GDP.",
                                       condition: StateConditionConfig(maxExternalDebtGDP: 0.35))
                ]),
            "oil_shock_1973": ScenarioConfig(
                title: "First Oil Shock",
                summary: "A sudden import-price spike threatens to turn into a full inflation regime shift.",
                briefing: "Global oil markets have turned violently against Solaverde. Your problem is not just inflation today, but whether expectations start treating this shock as the new normal.",
                gameLength: .short,
                startYear: 1973,
                startQuarter: 3,
                endYear: 1975,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.024,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.071,
                    coreInflation: 0.063,
                    expectedInflation: 0.058,
                    unemployment: 0.062,
                    policyRate: 0.064,
                    credibility: 0.67,
                    currentAccountGDP: -0.032,
                    capitalAccountGDP: 0.004,
                    foreignReservesMonths: 3.3,
                    externalDebtGDP: 0.29,
                    fiscalBalanceGDP: -0.034,
                    politicalPressure: 30.0,
                    publicApproval: 50.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.068,
                    tradingPartnerGrowth: 0.018,
                    oilPriceIndex: 145.0,
                    commodityPriceIndex: 106.0,
                    termsOfTrade: 0.96),
                introNews: [
                    "SCENARIO: The oil embargo has just hit the Caribbean. Every import invoice is about to look worse.",
                    "Your task is to stop a relative-price shock from becoming a permanent inflation psychology."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with inflation below 8.5%.",
                                       condition: StateConditionConfig(maxInflation: 0.085)),
                    ScenarioGoalConfig(description: "Keep reserves above 2.8 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 2.8)),
                    ScenarioGoalConfig(description: "Keep political pressure below 60.",
                                       condition: StateConditionConfig(maxPoliticalPressure: 60.0))
                ]),
            "wage_spiral_1976": ScenarioConfig(
                title: "Wage-Price Spiral",
                summary: "The import shock has faded, but inflation psychology is now feeding on itself.",
                briefing: "Unions, firms, and ministries are writing yesterday's inflation into today's contracts. The challenge is no longer just one bad shock; it is whether indexation becomes the economy's default setting.",
                gameLength: .short,
                startYear: 1976,
                startQuarter: 2,
                endYear: 1978,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.021,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.088,
                    coreInflation: 0.081,
                    expectedInflation: 0.074,
                    unemployment: 0.071,
                    policyRate: 0.082,
                    reserveRequirement: 0.13,
                    credibility: 0.61,
                    exchangeRate: 2.11,
                    currentAccountGDP: -0.028,
                    capitalAccountGDP: 0.006,
                    foreignReservesMonths: 3.6,
                    externalDebtGDP: 0.32,
                    fiscalBalanceGDP: -0.036,
                    politicalPressure: 31.0,
                    publicApproval: 50.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.067,
                    tradingPartnerGrowth: 0.018,
                    oilPriceIndex: 150.0,
                    commodityPriceIndex: 111.0),
                introNews: [
                    "SCENARIO: The immediate oil panic is passing, but inflation is getting written into wages and prices.",
                    "If expectations harden here, every future stabilization attempt will become more painful."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with inflation below 7.5%.",
                                       condition: StateConditionConfig(maxInflation: 0.075)),
                    ScenarioGoalConfig(description: "Restore credibility to at least 65%.",
                                       condition: StateConditionConfig(minCredibility: 0.65)),
                    ScenarioGoalConfig(description: "Keep unemployment below 9.5%.",
                                       condition: StateConditionConfig(maxUnemployment: 0.095))
                ]),
            "volcker_1979": ScenarioConfig(
                title: "Volcker Moment",
                summary: "Inflation is entrenched and the world has turned brutally tight.",
                briefing: "By late 1979, the old gradualism is failing. World rates are rising, credibility is thin, and every compromise risks looking like surrender.",
                gameLength: .short,
                startYear: 1979,
                startQuarter: 3,
                endYear: 1982,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.012,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.118,
                    coreInflation: 0.102,
                    expectedInflation: 0.095,
                    unemployment: 0.078,
                    policyRate: 0.125,
                    reserveRequirement: 0.14,
                    credibility: 0.53,
                    exchangeRate: 2.26,
                    currentAccountGDP: -0.038,
                    capitalAccountGDP: -0.004,
                    foreignReservesMonths: 2.6,
                    externalDebtGDP: 0.38,
                    fiscalBalanceGDP: -0.045,
                    politicalPressure: 38.0,
                    publicApproval: 46.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.110,
                    tradingPartnerGrowth: 0.010,
                    oilPriceIndex: 215.0),
                introNews: [
                    "SCENARIO: Global rates are surging and domestic inflation has become embedded.",
                    "Your problem is no longer just price control. It is whether the public still believes price control is possible."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with inflation below 8%.",
                                       condition: StateConditionConfig(maxInflation: 0.08)),
                    ScenarioGoalConfig(description: "Restore credibility to at least 45%.",
                                       condition: StateConditionConfig(minCredibility: 0.45)),
                    ScenarioGoalConfig(description: "Avoid reserve exhaustion: end above 1.5 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 1.5))
                ]),
            "reserve_run_1981": ScenarioConfig(
                title: "Reserve Run",
                summary: "Markets smell weakness and every month of hesitation is being paid for in reserves.",
                briefing: "By 1981, inflation is still too high, but your immediate constraint is external financing. If reserves vanish, policy choice vanishes with them.",
                gameLength: .short,
                startYear: 1981,
                startQuarter: 1,
                endYear: 1982,
                endQuarter: 4,
                openingAnnualizedGrowth: -0.012,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.124,
                    coreInflation: 0.108,
                    expectedInflation: 0.097,
                    unemployment: 0.086,
                    policyRate: 0.132,
                    reserveRequirement: 0.15,
                    credibility: 0.40,
                    exchangeRate: 2.39,
                    exchangeRateQoQChange: 0.048,
                    currentAccountGDP: -0.052,
                    capitalAccountGDP: -0.028,
                    foreignReservesMonths: 1.40,
                    capitalControls: 0.08,
                    externalDebtGDP: 0.76,
                    fiscalBalanceGDP: -0.052,
                    politicalPressure: 54.0,
                    publicApproval: 40.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.145,
                    tradingPartnerGrowth: -0.002,
                    oilPriceIndex: 232.0,
                    termsOfTrade: 0.88),
                introNews: [
                    "SCENARIO: Traders believe the Solan Dollar is one bad quarter away from a run.",
                    "Your challenge is to keep external financing alive long enough for stabilization to become believable."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with reserves above 2.0 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 2.0)),
                    ScenarioGoalConfig(description: "Keep inflation below 10.5%.",
                                       condition: StateConditionConfig(maxInflation: 0.105)),
                    ScenarioGoalConfig(description: "Keep political pressure below 72.",
                                       condition: StateConditionConfig(maxPoliticalPressure: 72.0))
                ]),
            "debt_crisis_1982": ScenarioConfig(
                title: "Debt Crisis",
                summary: "External financing is disappearing and refinancing risk has become the whole game.",
                briefing: "The easy foreign borrowing of the 1970s is over. Higher global rates and weaker lenders mean every quarter is now a test of whether Solaverde can stay financed.",
                gameLength: .extended,
                startYear: 1982,
                startQuarter: 3,
                endYear: 1986,
                endQuarter: 4,
                openingAnnualizedGrowth: -0.006,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.108,
                    coreInflation: 0.096,
                    expectedInflation: 0.090,
                    unemployment: 0.091,
                    policyRate: 0.135,
                    reserveRequirement: 0.15,
                    credibility: 0.47,
                    exchangeRate: 2.44,
                    currentAccountGDP: -0.054,
                    capitalAccountGDP: -0.022,
                    foreignReservesMonths: 1.9,
                    capitalControls: 0.35,
                    externalDebtGDP: 0.58,
                    fiscalBalanceGDP: -0.056,
                    politicalPressure: 49.0,
                    publicApproval: 43.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.125,
                    tradingPartnerGrowth: -0.003,
                    oilPriceIndex: 205.0,
                    termsOfTrade: 0.92),
                introNews: [
                    "SCENARIO: International lenders are suddenly skeptical of every weak borrower in the region.",
                    "This is an external-financing crisis first and a domestic-policy crisis second."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Stay out of outright reserve collapse: finish above 1.8 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 1.8)),
                    ScenarioGoalConfig(description: "Keep external debt below 70% of GDP.",
                                       condition: StateConditionConfig(maxExternalDebtGDP: 0.70)),
                    ScenarioGoalConfig(description: "Keep inflation below 12%.",
                                       condition: StateConditionConfig(maxInflation: 0.12))
                ]),
            "debt_workout_1984": ScenarioConfig(
                title: "Debt Workout",
                summary: "The panic has eased, but the real lesson is how to shrink debt without killing recovery.",
                briefing: "The crisis headlines are fading, but the balance sheet damage is still there. This scenario is about external adjustment, debt reduction, and the slow work of regaining room to breathe.",
                teachingFocus: [
                    "How to lower external debt by improving the current account over time, not by one-quarter theatrics.",
                    "How to rebuild reserves while keeping a weak recovery alive.",
                    "How to distinguish a debt workout from a full-blown panic."
                ],
                gameLength: .short,
                startYear: 1984,
                startQuarter: 1,
                endYear: 1986,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.004,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.083,
                    coreInflation: 0.076,
                    expectedInflation: 0.071,
                    unemployment: 0.102,
                    policyRate: 0.108,
                    reserveRequirement: 0.14,
                    credibility: 0.49,
                    exchangeRate: 2.56,
                    currentAccountGDP: -0.036,
                    capitalAccountGDP: -0.008,
                    foreignReservesMonths: 2.3,
                    capitalControls: 0.34,
                    externalDebtGDP: 0.64,
                    fiscalBalanceGDP: -0.050,
                    politicalPressure: 44.0,
                    publicApproval: 45.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.102,
                    tradingPartnerGrowth: 0.009,
                    oilPriceIndex: 186.0,
                    commodityPriceIndex: 107.0,
                    termsOfTrade: 0.94),
                introNews: [
                    "SCENARIO: The emergency phase is over, but the debt burden is still strangling policy.",
                    "This lesson is about repairing the external balance patiently enough that the recovery survives."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Reduce external debt below 56% of GDP.",
                                       condition: StateConditionConfig(maxExternalDebtGDP: 0.56)),
                    ScenarioGoalConfig(description: "Finish with reserves above 2.5 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 2.5)),
                    ScenarioGoalConfig(description: "Keep inflation below 9%.",
                                       condition: StateConditionConfig(maxInflation: 0.09))
                ]),
            "lost_decade_recovery_1985": ScenarioConfig(
                title: "Lost Decade Recovery",
                summary: "The panic phase has passed, but debt overhang and damaged credibility are still choking growth.",
                briefing: "By 1985, the crisis is less theatrical but no less dangerous. Solaverde is not collapsing today; it is stagnating. The question is whether recovery can be earned without relighting inflation or sliding back into external dependence.",
                gameLength: .extended,
                startYear: 1985,
                startQuarter: 1,
                endYear: 1989,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.008,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.074,
                    coreInflation: 0.068,
                    expectedInflation: 0.065,
                    unemployment: 0.104,
                    policyRate: 0.102,
                    reserveRequirement: 0.14,
                    credibility: 0.50,
                    exchangeRate: 2.63,
                    currentAccountGDP: -0.034,
                    capitalAccountGDP: -0.006,
                    foreignReservesMonths: 2.5,
                    capitalControls: 0.38,
                    externalDebtGDP: 0.63,
                    fiscalBalanceGDP: -0.048,
                    politicalPressure: 42.0,
                    publicApproval: 45.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.090,
                    tradingPartnerGrowth: 0.012,
                    oilPriceIndex: 172.0,
                    termsOfTrade: 0.95),
                introNews: [
                    "SCENARIO: The emergency is no longer sudden collapse. It is a weak economy carrying too much debt and too little confidence.",
                    "This run is about recovery quality: can you get growth back without losing the nominal anchor again?"
                ],
                goals: [
                    ScenarioGoalConfig(description: "Keep unemployment below 9%.",
                                       condition: StateConditionConfig(maxUnemployment: 0.09)),
                    ScenarioGoalConfig(description: "Reduce external debt below 55% of GDP.",
                                       condition: StateConditionConfig(maxExternalDebtGDP: 0.55)),
                    ScenarioGoalConfig(description: "Restore credibility to at least 55%.",
                                       condition: StateConditionConfig(minCredibility: 0.55))
                ]),
            "recession_relief_1991": ScenarioConfig(
                title: "Recession Relief",
                summary: "Inflation is quieter, but unemployment and weak credit are becoming the real political problem.",
                briefing: "The inflation war has largely been won. Now the danger is doing too little for too long and letting recession harden into stagnation. This scenario teaches easing under uncertainty.",
                teachingFocus: [
                    "How to support activity when inflation is no longer the only enemy.",
                    "How to use communication and liquidity support without throwing away credibility.",
                    "Why easing too late and easing too fast are both costly."
                ],
                gameLength: .short,
                startYear: 1991,
                startQuarter: 1,
                endYear: 1993,
                endQuarter: 4,
                openingAnnualizedGrowth: -0.012,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.046,
                    coreInflation: 0.043,
                    expectedInflation: 0.045,
                    unemployment: 0.108,
                    policyRate: 0.089,
                    reserveRequirement: 0.12,
                    credibility: 0.63,
                    exchangeRate: 2.97,
                    currentAccountGDP: -0.019,
                    capitalAccountGDP: 0.002,
                    foreignReservesMonths: 3.9,
                    capitalControls: 0.12,
                    externalDebtGDP: 0.47,
                    fiscalBalanceGDP: -0.040,
                    politicalPressure: 28.0,
                    publicApproval: 47.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.071,
                    tradingPartnerGrowth: -0.002,
                    oilPriceIndex: 121.0,
                    commodityPriceIndex: 99.0,
                    termsOfTrade: 0.99),
                introNews: [
                    "SCENARIO: Inflation is no longer exploding, but weak demand and rising unemployment are eating away at support.",
                    "This lesson is about knowing when to lean against recession without undoing the nominal gains already won."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Lower unemployment below 8.5%.",
                                       condition: StateConditionConfig(maxUnemployment: 0.085)),
                    ScenarioGoalConfig(description: "Keep inflation below 6.5%.",
                                       condition: StateConditionConfig(maxInflation: 0.065)),
                    ScenarioGoalConfig(description: "Finish with credibility above 55%.",
                                       condition: StateConditionConfig(minCredibility: 0.55))
                ]),
            "asian_contagion_1997": ScenarioConfig(
                title: "Capital Flight, 1997",
                summary: "Confidence is fragile, capital is mobile, and contagion is moving faster than policy committees.",
                briefing: "Regional turmoil has made investors ruthless. Solaverde is not the center of the crisis, but in open capital markets innocence is not protection.",
                gameLength: .extended,
                startYear: 1997,
                startQuarter: 3,
                endYear: 2000,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.024,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.055,
                    coreInflation: 0.050,
                    expectedInflation: 0.048,
                    unemployment: 0.078,
                    policyRate: 0.095,
                    credibility: 0.58,
                    exchangeRate: 3.18,
                    currentAccountGDP: -0.045,
                    capitalAccountGDP: -0.015,
                    foreignReservesMonths: 2.8,
                    capitalControls: 0.18,
                    externalDebtGDP: 0.49,
                    fiscalBalanceGDP: -0.038,
                    politicalPressure: 37.0,
                    publicApproval: 49.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.072,
                    tradingPartnerGrowth: 0.008,
                    oilPriceIndex: 128.0,
                    termsOfTrade: 0.97),
                introNews: [
                    "SCENARIO: Investors are repricing every emerging market with external weakness.",
                    "You have some room, but not much. Confidence can vanish faster than it can be rebuilt."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Finish with reserves above 2.0 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 2.0)),
                    ScenarioGoalConfig(description: "Keep inflation below 8%.",
                                       condition: StateConditionConfig(maxInflation: 0.08)),
                    ScenarioGoalConfig(description: "Keep public approval above 40.",
                                       condition: StateConditionConfig(minPublicApproval: 40.0))
                ]),
            "confidence_rebuild_1998": ScenarioConfig(
                title: "Confidence Rebuild",
                summary: "The panic phase is past, but reserves, approval, and credibility remain too fragile for complacency.",
                briefing: "After contagion, the teaching challenge is reconstruction: rebuilding buffers and trust without imposing needless permanent austerity. The market is calmer, not forgiving.",
                teachingFocus: [
                    "How to rebuild reserves and credibility after a near-crisis.",
                    "How to use controls and intervention as temporary tools rather than permanent crutches.",
                    "How to exit emergency posture without inviting another run."
                ],
                gameLength: .short,
                startYear: 1998,
                startQuarter: 1,
                endYear: 2000,
                endQuarter: 4,
                openingAnnualizedGrowth: 0.010,
                stateOverrides: ScenarioStateOverrideConfig(
                    inflation: 0.061,
                    coreInflation: 0.054,
                    expectedInflation: 0.052,
                    unemployment: 0.088,
                    policyRate: 0.096,
                    reserveRequirement: 0.13,
                    credibility: 0.49,
                    exchangeRate: 3.26,
                    exchangeRateQoQChange: 0.042,
                    currentAccountGDP: -0.031,
                    capitalAccountGDP: -0.014,
                    foreignReservesMonths: 2.05,
                    capitalControls: 0.08,
                    externalDebtGDP: 0.55,
                    fiscalBalanceGDP: -0.041,
                    politicalPressure: 36.0,
                    publicApproval: 45.0),
                environmentOverrides: ScenarioEnvironmentOverrideConfig(
                    worldInterestRate: 0.074,
                    tradingPartnerGrowth: 0.008,
                    oilPriceIndex: 116.0,
                    commodityPriceIndex: 96.0,
                    termsOfTrade: 0.97),
                introNews: [
                    "SCENARIO: The currency survived, but the country is still short of trust, reserves, and patience.",
                    "This lesson is about proving the crisis really is over, not just surviving one quieter quarter."
                ],
                goals: [
                    ScenarioGoalConfig(description: "Rebuild reserves above 2.8 months.",
                                       condition: StateConditionConfig(minForeignReservesMonths: 2.8)),
                    ScenarioGoalConfig(description: "Restore credibility to at least 60%.",
                                       condition: StateConditionConfig(minCredibility: 0.60)),
                    ScenarioGoalConfig(description: "Keep inflation below 7%.",
                                       condition: StateConditionConfig(maxInflation: 0.07))
                ])
        ])
}
