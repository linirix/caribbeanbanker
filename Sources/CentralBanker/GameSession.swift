import Foundation

struct ForecastReviewRecord {
    let estimate: ForecastEstimate
    let note: String?
    let baselineEstimate: ForecastEstimate?
}

final class GameSession {
    private(set) var mode: GameMode
    private(set) var gameLength: GameLength
    private(set) var scenarioID: String?
    private(set) var difficulty: Difficulty
    private(set) var sessionSeed: UInt64
    private(set) var simulator: EconomicSimulator
    private(set) var macroSchedule: [Int: [EventType]]
    private(set) var rateSchedule: [Int: Double]
    private(set) var lastQuarterReport: QuarterReport? = nil
    private(set) var lastForecastReview: ForecastReviewRecord? = nil
    private(set) var pendingPreviewReview: ForecastReviewRecord? = nil

    var scenario: ScenarioDefinition? {
        scenarioDefinition(id: scenarioID)
    }

    var campaignTitle: String {
        campaignDisplayTitle(gameLength: gameLength, scenarioID: scenarioID)
    }

    var campaignRange: String {
        campaignRangeLabel(gameLength: gameLength, scenarioID: scenarioID)
    }

    var totalCampaignQuarters: Int {
        scenarioDefinition(id: scenarioID)?.totalQuarters ?? gameLength.totalQuarters
    }

    init(mode: GameMode,
         gameLength: GameLength,
         difficulty: Difficulty,
         scenarioID: String? = nil,
         sessionSeed: UInt64) {
        let resolvedScenario = scenarioDefinition(id: scenarioID)
        let resolvedMode: GameMode = resolvedScenario == nil ? mode : .historical
        let resolvedGameLength = resolvedScenario?.gameLength ?? gameLength
        let resolvedScenarioID = resolvedScenario?.id

        let simulator = EconomicSimulator(
            params: ModelParameters.preset(difficulty).configured(for: resolvedGameLength),
            difficulty: difficulty,
            seed: sessionSeed)
        let macroSchedule = resolvedMode == .randomized
            ? scheduleMacroEvents(for: resolvedGameLength, using: &simulator.rng)
            : [:]
        let rateSchedule = resolvedMode == .randomized
            ? scheduleWorldRates(for: resolvedGameLength, using: &simulator.rng)
            : [:]

        applyOpeningConditions(
            to: simulator,
            mode: resolvedMode,
            gameLength: resolvedGameLength,
            scenarioID: resolvedScenarioID,
            sessionSeed: sessionSeed)
        self.mode = resolvedMode
        self.gameLength = resolvedGameLength
        self.scenarioID = resolvedScenarioID
        self.difficulty = difficulty
        self.sessionSeed = sessionSeed
        self.simulator = simulator
        self.macroSchedule = macroSchedule
        self.rateSchedule = rateSchedule
        recordOpeningNews()
        self.simulator.maybeIssueCabinetRequest()
    }

    init(save: GameSave) {
        let restored = EconomicSimulator(
            state: save.state,
            environment: save.environment,
            log: save.log,
            scoreCard: save.scoreCard,
            params: ModelParameters.preset(save.difficulty).configured(for: save.gameLength ?? .short),
            difficulty: save.difficulty,
            seed: 0)
        restored.rng = save.rng
        restored.demandNoiseCarry = save.demandNoiseCarry
        restored.supplyNoiseCarry = save.supplyNoiseCarry
        restored.interventionSupportCarry = save.interventionSupportCarry ?? 0.0
        restored.controlsReliefCarry = save.controlsReliefCarry ?? 0.0
        restored.crisisCooldownQuarters = save.crisisCooldownQuarters ?? 0
        restored.communicationStance = save.communicationStance
        restored.activeCabinetRequest = save.activeCabinetRequest

        self.mode = save.mode
        self.gameLength = save.gameLength ?? .short
        self.scenarioID = save.scenarioID
        self.difficulty = save.difficulty
        self.sessionSeed = save.sessionSeed
        self.simulator = restored
        self.macroSchedule = save.macroSchedule
        self.rateSchedule = save.rateSchedule
    }

    static func load(from path: String? = nil) throws -> GameSession {
        try GameSession(save: readSave(from: path))
    }

    func makeSave() -> GameSave {
        GameSave(
            state: simulator.state,
            environment: simulator.environment,
            log: simulator.log,
            scoreCard: simulator.scoreCard,
            difficulty: difficulty,
            communicationStance: simulator.communicationStance,
            activeCabinetRequest: simulator.activeCabinetRequest,
            rng: simulator.rng,
            demandNoiseCarry: simulator.demandNoiseCarry,
            supplyNoiseCarry: simulator.supplyNoiseCarry,
            interventionSupportCarry: simulator.interventionSupportCarry,
            controlsReliefCarry: simulator.controlsReliefCarry,
            crisisCooldownQuarters: simulator.crisisCooldownQuarters,
            sessionSeed: sessionSeed,
            mode: mode,
            gameLength: gameLength,
            scenarioID: scenarioID,
            macroSchedule: macroSchedule,
            rateSchedule: rateSchedule)
    }

    func save(to path: String? = nil) throws {
        try writeSave(makeSave(), to: path)
    }

    func loadDescription() -> String {
        "\(mode == .historical ? "historical" : "randomized"), \(campaignTitle.lowercased()), \(difficulty.displayName)"
    }

    func currentOutcome() -> GameOutcome {
        let outcome = simulator.checkOutcome()
        if outcome == .ongoing
            && isCampaignComplete(state: simulator.state, gameLength: gameLength, scenarioID: scenarioID) {
            return .success
        }
        return outcome
    }

    @discardableResult
    func advance() -> GameOutcome {
        let quarterBeingAdvanced = simulator.state.quarterLabel
        let matchingForecast = pendingPreviewReview?.estimate.report.stateBefore.quarterLabel == quarterBeingAdvanced
            ? pendingPreviewReview
            : nil
        simulator.deferCabinetRequestIfNeeded()
        simulator.environment.worldInterestRate = worldInterestRate(
            for: simulator.state,
            mode: mode,
            gameLength: gameLength,
            rateSchedule: rateSchedule)
        let events = generateEvents(
            for: simulator.state,
            mode: mode,
            gameLength: gameLength,
            macroSchedule: macroSchedule,
            using: &simulator.rng)
        let report = simulator.simulateQuarter(events: events)
        lastQuarterReport = report
        lastForecastReview = matchingForecast
        pendingPreviewReview = nil

        let outcome = currentOutcome()
        if outcome == .ongoing {
            simulator.maybeIssueCabinetRequest()
        }
        return outcome
    }

    func preview(changes: [PolicyChange]) -> (estimate: ForecastEstimate, note: String?) {
        let preview = buildPreview(changes: changes)
        let baselineEstimate = changes.isEmpty ? nil : buildPreview(changes: []).estimate
        pendingPreviewReview = ForecastReviewRecord(
            estimate: preview.estimate,
            note: preview.note,
            baselineEstimate: baselineEstimate
        )
        return preview
    }

    private func buildPreview(changes: [PolicyChange]) -> (estimate: ForecastEstimate, note: String?) {
        let clone = simulator.cloneForPreview()
        var note: String? = nil
        if !changes.isEmpty {
            applyPreviewChanges(changes, to: clone)
            note = "Hypothetical: " + changes.map(\.summaryLabel).joined(separator: "  |  ")
        }
        let report = previewNextQuarter(
            of: clone,
            mode: mode,
            gameLength: gameLength,
            macroSchedule: macroSchedule,
            rateSchedule: rateSchedule,
            eventSourceState: simulator.state)
        let estimate = forecastEstimate(
            for: report,
            sessionSeed: sessionSeed,
            changeSignature: previewChangeSignature(changes))
        return (estimate, note)
    }

    private func recordOpeningNews() {
        if mode == .randomized {
            simulator.log.addNews(
                "RANDOMISED MODE: \(gameLength.displayName) timeline generated. Prepare for anything.",
                quarterLabel: simulator.state.quarterLabel)
        }
        simulator.log.addNews(
            "Timeline: \(campaignTitle) (\(campaignRange), \(totalCampaignQuarters) quarters).",
            quarterLabel: simulator.state.quarterLabel)
        simulator.log.addNews(
            "Difficulty: \(difficulty.displayName). " + difficulty.tagline,
            quarterLabel: simulator.state.quarterLabel)
        simulator.log.addNews(
            String(format: "Session seed: %llu", sessionSeed),
            quarterLabel: simulator.state.quarterLabel)
        simulator.log.addNews(
            String(format: "Opening GDP growth: %.1f%% annualized.",
                   simulator.state.annualizedGDPGrowth * 100),
            quarterLabel: simulator.state.quarterLabel)
        if let scenario {
            simulator.log.addNews(
                "Scenario: \(scenario.title). \(scenario.summary)",
                quarterLabel: simulator.state.quarterLabel)
            for line in scenario.introNews {
                simulator.log.addNews(line, quarterLabel: simulator.state.quarterLabel)
            }
        }
    }

    private func applyPreviewChanges(_ changes: [PolicyChange], to simulator: EconomicSimulator) {
        for change in changes {
            switch change {
            case .rate(let r):
                simulator.state.policyRate = r
            case .reserve(let r):
                simulator.state.reserveRequirement = r
            case .controls(let c):
                simulator.setCapitalControls(c)
            }
        }
    }
}
