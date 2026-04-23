import Foundation

package struct ScenarioDefinition {
    package let id: String
    let config: ScenarioConfig

    package var title: String { config.title }
    package var summary: String { config.summary }
    package var briefing: String { config.briefing }
    package var teachingFocus: [String] { config.teachingFocus ?? [] }
    package var gameLength: GameLength { config.gameLength }
    package var startYear: Int { config.startYear }
    package var startQuarter: Int { config.startQuarter }
    package var endYear: Int { config.endYear }
    package var endQuarter: Int { config.endQuarter }
    package var openingAnnualizedGrowth: Double? { config.openingAnnualizedGrowth }
    package var introNews: [String] { config.introNews ?? [] }
    var goals: [ScenarioGoalConfig] { config.goals }

    package var rangeLabel: String {
        "Q\(startQuarter) \(startYear)–Q\(endQuarter) \(endYear)"
    }

    package var totalQuarters: Int {
        ((endYear - startYear) * 4) + (endQuarter - startQuarter) + 1
    }

    package var baseIndexLabel: String {
        "Q\(startQuarter) \(startYear)"
    }

    package func applyOpeningOverrides(to simulator: EconomicSimulator) {
        config.stateOverrides?.apply(to: simulator)
        config.environmentOverrides?.apply(to: simulator)
    }
}

package struct ScenarioGoalStatus {
    package let description: String
    package let met: Bool
}

package func scenarioDefinition(id: String?) -> ScenarioDefinition? {
    guard let id, let config = GameConfigs.scenario(id: id) else { return nil }
    return ScenarioDefinition(id: id, config: config)
}

package func scenarioDefinitions(for gameLength: GameLength) -> [ScenarioDefinition] {
    GameConfigs.scenarioIDs(for: gameLength).compactMap { scenarioDefinition(id: $0) }
}

package func campaignRangeLabel(gameLength: GameLength, scenarioID: String?) -> String {
    scenarioDefinition(id: scenarioID)?.rangeLabel ?? gameLength.rangeLabel
}

package func campaignBaseIndexLabel(gameLength: GameLength, scenarioID: String?) -> String {
    scenarioDefinition(id: scenarioID)?.baseIndexLabel ?? gameLength.baseIndexLabel
}

package func campaignTotalQuarters(gameLength: GameLength, scenarioID: String?) -> Int {
    scenarioDefinition(id: scenarioID)?.totalQuarters ?? gameLength.totalQuarters
}

package func campaignDisplayTitle(gameLength: GameLength, scenarioID: String?) -> String {
    if let scenario = scenarioDefinition(id: scenarioID) {
        return scenario.title
    }
    return gameLength.displayName
}

package func isCampaignComplete(state: EconomicState,
                                gameLength: GameLength,
                                scenarioID: String?) -> Bool {
    if let scenario = scenarioDefinition(id: scenarioID) {
        if state.year > scenario.endYear { return true }
        if state.year == scenario.endYear && state.quarter > scenario.endQuarter { return true }
        return false
    }
    return state.year >= gameLength.successYear
}

package func evaluateScenarioGoals(scenarioID: String?,
                                   state: EconomicState) -> [ScenarioGoalStatus] {
    guard let scenario = scenarioDefinition(id: scenarioID) else { return [] }
    return scenario.goals.map {
        ScenarioGoalStatus(description: $0.description, met: $0.condition.matches(state))
    }
}
