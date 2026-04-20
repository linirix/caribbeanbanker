import Foundation

struct ScenarioDefinition {
    let id: String
    let config: ScenarioConfig

    var title: String { config.title }
    var summary: String { config.summary }
    var briefing: String { config.briefing }
    var teachingFocus: [String] { config.teachingFocus ?? [] }
    var gameLength: GameLength { config.gameLength }
    var startYear: Int { config.startYear }
    var startQuarter: Int { config.startQuarter }
    var endYear: Int { config.endYear }
    var endQuarter: Int { config.endQuarter }
    var openingAnnualizedGrowth: Double? { config.openingAnnualizedGrowth }
    var introNews: [String] { config.introNews ?? [] }
    var goals: [ScenarioGoalConfig] { config.goals }

    var rangeLabel: String {
        "Q\(startQuarter) \(startYear)–Q\(endQuarter) \(endYear)"
    }

    var totalQuarters: Int {
        ((endYear - startYear) * 4) + (endQuarter - startQuarter) + 1
    }

    var baseIndexLabel: String {
        "Q\(startQuarter) \(startYear)"
    }

    func applyOpeningOverrides(to simulator: EconomicSimulator) {
        config.stateOverrides?.apply(to: simulator)
        config.environmentOverrides?.apply(to: simulator)
    }
}

struct ScenarioGoalStatus {
    let description: String
    let met: Bool
}

func scenarioDefinition(id: String?) -> ScenarioDefinition? {
    guard let id, let config = GameConfigs.scenario(id: id) else { return nil }
    return ScenarioDefinition(id: id, config: config)
}

func scenarioDefinitions(for gameLength: GameLength) -> [ScenarioDefinition] {
    GameConfigs.scenarioIDs(for: gameLength).compactMap { scenarioDefinition(id: $0) }
}

func campaignRangeLabel(gameLength: GameLength, scenarioID: String?) -> String {
    scenarioDefinition(id: scenarioID)?.rangeLabel ?? gameLength.rangeLabel
}

func campaignBaseIndexLabel(gameLength: GameLength, scenarioID: String?) -> String {
    scenarioDefinition(id: scenarioID)?.baseIndexLabel ?? gameLength.baseIndexLabel
}

func campaignTotalQuarters(gameLength: GameLength, scenarioID: String?) -> Int {
    scenarioDefinition(id: scenarioID)?.totalQuarters ?? gameLength.totalQuarters
}

func campaignDisplayTitle(gameLength: GameLength, scenarioID: String?) -> String {
    if let scenario = scenarioDefinition(id: scenarioID) {
        return scenario.title
    }
    return gameLength.displayName
}

func isCampaignComplete(state: EconomicState,
                        gameLength: GameLength,
                        scenarioID: String?) -> Bool {
    if let scenario = scenarioDefinition(id: scenarioID) {
        if state.year > scenario.endYear { return true }
        if state.year == scenario.endYear && state.quarter > scenario.endQuarter { return true }
        return false
    }
    return state.year >= gameLength.successYear
}

func evaluateScenarioGoals(scenarioID: String?,
                           state: EconomicState) -> [ScenarioGoalStatus] {
    guard let scenario = scenarioDefinition(id: scenarioID) else { return [] }
    return scenario.goals.map {
        ScenarioGoalStatus(description: $0.description, met: $0.condition.matches(state))
    }
}
