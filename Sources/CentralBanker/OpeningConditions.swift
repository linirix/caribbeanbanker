import Foundation

// Opening conditions shown on the first dashboard should feel like a real
// economy already in motion, not a just-reset simulator. We keep this logic
// deterministic and separate from the simulator RNG so changing the starting
// snapshot does not perturb event scheduling or future quarter randomness.

private let openingGrowthSeedSalt: UInt64 = 0x4F50_454E_4752_4F57

func openingAnnualizedGDPGrowth(mode: GameMode,
                                gameLength: GameLength = .short,
                                scenarioID: String? = nil,
                                sessionSeed: UInt64,
                                params: ModelParameters) -> Double {
    if let scenario = scenarioDefinition(id: scenarioID),
       let growth = scenario.openingAnnualizedGrowth {
        return growth
    }
    let opening = GameConfigs.tuning.opening
    switch mode {
    case .historical:
        return GameConfigs.openingHistoricalGrowth(for: gameLength)

    case .randomized:
        var rng = SeededRandomGenerator(seed: sessionSeed ^ openingGrowthSeedSalt)
        let centered = params.outputGap.potentialGrowthAnnual
            + Double.random(in: opening.randomizedGrowthOffsetMin...opening.randomizedGrowthOffsetMax, using: &rng)
        return (opening.randomizedGrowthMin...opening.randomizedGrowthMax).clamping(centered)
    }
}

func applyOpeningConditions(to simulator: EconomicSimulator,
                            mode: GameMode,
                            gameLength: GameLength = .short,
                            scenarioID: String? = nil,
                            sessionSeed: UInt64) {
    let scenario = scenarioDefinition(id: scenarioID)
    simulator.state.year = scenario?.startYear ?? gameLength.startYear
    simulator.state.quarter = scenario?.startQuarter ?? 1
    applyOpeningBaseline(to: simulator, gameLength: gameLength, scenarioID: scenarioID)
    simulator.state.gdpGrowthQoQ = openingAnnualizedGDPGrowth(
        mode: mode,
        gameLength: gameLength,
        scenarioID: scenarioID,
        sessionSeed: sessionSeed,
        params: simulator.params) / 4.0
}

private func applyOpeningBaseline(to simulator: EconomicSimulator,
                                  gameLength: GameLength,
                                  scenarioID: String?) {
    GameConfigs.openingBaseline(for: gameLength).apply(to: simulator)
    scenarioDefinition(id: scenarioID)?.applyOpeningOverrides(to: simulator)
}
