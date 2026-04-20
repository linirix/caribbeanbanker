import Foundation

// Running tally of "how the decade went." Updated once per quarter by the
// simulator; consulted by `drawGameOver` to produce the end-of-game breakdown.
//
// Kept separate from `SessionLog` (which is about news + chart buffers) and
// `EconomicState` (which is the instantaneous snapshot): this is where the
// integral-over-time measurements live, the kind of thing you can't recover
// from a final-quarter state alone.
struct ScoreCard: Codable {
    // Quarter counters. Thresholds here should match the thresholds the game
    // uses elsewhere so the scorecard tells the same story the dashboard did.
    var quartersSimulated: Int = 0
    var highInflationQuarters: Int = 0      // inflation > 8%
    var severeInflationQuarters: Int = 0    // inflation > 15%
    var recessionQuarters: Int = 0          // annualized GDP growth < -0.5%
    var stagflationQuarters: Int = 0        // high inflation AND recession
    var highUnemploymentQuarters: Int = 0   // unemployment > 8.5%
    var lowCredibilityQuarters: Int = 0     // credibility < 0.50
    var nearOusterQuarters: Int = 0         // political pressure > 70

    // Extremes — peaks and troughs reached over the run.
    var peakInflation: Double = 0.0
    var troughGrowthAnnualized: Double = 0.0   // most negative
    var peakUnemployment: Double = 0.0
    var lowestCredibility: Double = 1.0
    var lowestReserves: Double = 99.0
    var peakPoliticalPressure: Double = 0.0
    var peakExternalDebtGDP: Double = 0.0

    // Policy-choice highlights. Not scored — just reported, so the player
    // sees what tools they actually reached for.
    var peakPolicyRate: Double = 0.0
    var peakCapitalControls: Double = 0.0
    var peakReserveRequirement: Double = 0.0

    // Call once per simulated quarter, after all dynamics have been applied
    // but before `advanceTime()`. The simulator wires this in next to
    // `log.recordQuarter`.
    mutating func record(_ s: EconomicState) {
        let scoring = GameConfigs.tuning.scoring
        quartersSimulated += 1
        if s.inflation > scoring.tracking.highInflationThreshold { highInflationQuarters += 1 }
        if s.inflation > scoring.tracking.severeInflationThreshold { severeInflationQuarters += 1 }
        if s.annualizedGDPGrowth < scoring.tracking.recessionGrowthThreshold { recessionQuarters += 1 }
        if s.inflation > scoring.tracking.highInflationThreshold
            && s.annualizedGDPGrowth < scoring.tracking.recessionGrowthThreshold { stagflationQuarters += 1 }
        if s.unemployment > scoring.tracking.highUnemploymentThreshold { highUnemploymentQuarters += 1 }
        if s.credibility < scoring.tracking.lowCredibilityThreshold { lowCredibilityQuarters += 1 }
        if s.politicalPressure > scoring.tracking.nearOusterThreshold { nearOusterQuarters += 1 }

        peakInflation = Swift.max(peakInflation, s.inflation)
        troughGrowthAnnualized = Swift.min(troughGrowthAnnualized, s.annualizedGDPGrowth)
        peakUnemployment = Swift.max(peakUnemployment, s.unemployment)
        lowestCredibility = Swift.min(lowestCredibility, s.credibility)
        lowestReserves = Swift.min(lowestReserves, s.foreignReservesMonths)
        peakPoliticalPressure = Swift.max(peakPoliticalPressure, s.politicalPressure)
        peakExternalDebtGDP = Swift.max(peakExternalDebtGDP, s.externalDebtGDP)
        peakPolicyRate = Swift.max(peakPolicyRate, s.policyRate)
        peakCapitalControls = Swift.max(peakCapitalControls, s.capitalControls)
        peakReserveRequirement = Swift.max(peakReserveRequirement, s.reserveRequirement)
    }
}

// Computes the end-of-game score as a transparent deduction sheet: the
// player sees exactly how the 100-point baseline was reduced. Returns both
// the final score and the list of line items, so the display can table
// them verbatim.
//
// Scoring philosophy: this is pedagogical, not a precision instrument.
// Coefficients are tuned so that:
//   • A near-perfect run (no high-inflation quarters, credibility intact,
//     reserves healthy) scores ~90+.
//   • A rough-but-survived run (historical-mode default play) scores ~55-75.
//   • A game-over outcome wipes out most of the score, regardless of other
//     merits, because losing is losing.
struct ScoreBreakdown {
    struct LineItem {
        let label: String
        let points: Int           // negative = deduction, positive = bonus
    }
    var baseline: Int
    var items: [LineItem]
    var final: Int

    // A headline label for the end screen — "Volcker-Class Operator" for
    // pure runs, down to a neutral disaster label for failed mandates.
    var headline: String
}

func computeScore(outcome: GameOutcome,
                  card: ScoreCard,
                  gameLength: GameLength = .short) -> ScoreBreakdown {
    let scoring = GameConfigs.tuning.scoring
    let baseline = scoring.baseline
    var items: [ScoreBreakdown.LineItem] = []
    let durationScale = gameLength.scorePenaltyScale
    let bonusScale = gameLength == .extended ? scoring.extendedBonusScale : 1.0

    func scaledPenalty(_ perQuarter: Int, _ quarters: Int) -> Int {
        let raw = Double(perQuarter * quarters) * durationScale
        return Int(raw.rounded(FloatingPointRoundingRule.toNearestOrAwayFromZero))
    }

    func scaledBonus(_ base: Int) -> Int {
        let raw = Double(base) * bonusScale
        return Int(raw.rounded(FloatingPointRoundingRule.toNearestOrAwayFromZero))
    }

    // Hard outcomes: losing dominates the score. A won-with-scars run will
    // still show these deductions in their itemized form when relevant.
    switch outcome {
    case .currencyCrisis:
        items.append(.init(label: "Currency crisis (mandate failure)", points: -scoring.outcomePenalties.currencyCrisis))
    case .hyperinflation:
        items.append(.init(label: "Hyperinflation (mandate failure)",  points: -scoring.outcomePenalties.hyperinflation))
    case .depression:
        items.append(.init(label: "Depression (mandate failure)",      points: -scoring.outcomePenalties.depression))
    case .politicalOuster:
        items.append(.init(label: "Political ouster (independence lost)", points: -scoring.outcomePenalties.politicalOuster))
    case .success, .ongoing:
        break
    }

    // Integral-style penalties. Quarters of bad conditions compound.
    if card.highInflationQuarters > 0 {
        items.append(.init(label: "High-inflation quarters (>10%)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.highInflation, card.highInflationQuarters)))
    }
    if card.severeInflationQuarters > 0 {
        items.append(.init(label: "Severe-inflation quarters (>20%)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.severeInflation, card.severeInflationQuarters)))
    }
    if card.stagflationQuarters > 0 {
        items.append(.init(label: "Stagflation quarters (high inflation + recession)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.stagflation, card.stagflationQuarters)))
    }
    if card.recessionQuarters > 0 {
        items.append(.init(label: "Recession quarters",
                           points: -scaledPenalty(scoring.perQuarterPenalties.recession, card.recessionQuarters)))
    }
    if card.highUnemploymentQuarters > 0 {
        items.append(.init(label: "High-unemployment quarters (>9%)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.highUnemployment, card.highUnemploymentQuarters)))
    }
    if card.lowCredibilityQuarters > 0 {
        items.append(.init(label: "Quarters with eroded credibility (<40%)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.lowCredibility, card.lowCredibilityQuarters)))
    }
    if card.nearOusterQuarters > 0 {
        items.append(.init(label: "Quarters near political ouster (pressure >75)",
                           points: -scaledPenalty(scoring.perQuarterPenalties.nearOuster, card.nearOusterQuarters)))
    }

    // Extremes: a peak that almost took the run down is its own punishment.
    if card.peakInflation > scoring.extremes.peakInflationThreshold {
        items.append(.init(label: String(format: "Peak inflation %.0f%%", card.peakInflation * 100),
                           points: -scoring.extremes.peakInflationPenalty))
    }
    if card.lowestReserves < scoring.extremes.lowestReservesThreshold {
        items.append(.init(label: String(format: "Reserves dropped to %.1f months", card.lowestReserves),
                           points: -scoring.extremes.lowestReservesPenalty))
    }
    if card.lowestCredibility < scoring.extremes.lowestCredibilityThreshold {
        items.append(.init(label: String(format: "Credibility trough %.0f%%", card.lowestCredibility * 100),
                           points: -scoring.extremes.lowestCredibilityPenalty))
    }
    if card.peakPoliticalPressure > scoring.extremes.peakPoliticalPressureThreshold {
        items.append(.init(label: String(format: "Peak political pressure %.0f / 88", card.peakPoliticalPressure),
                           points: -scoring.extremes.peakPoliticalPressurePenalty))
    }

    // Bonuses for a genuinely clean run.
    if outcome == .success && card.peakInflation < scoring.successBonuses.peakInflationThreshold {
        items.append(.init(label: "Inflation contained throughout (peak <7%)",
                           points: +scaledBonus(scoring.successBonuses.inflationContainedBonus)))
    }
    if outcome == .success && card.lowestCredibility > scoring.successBonuses.lowestCredibilityThreshold {
        items.append(.init(label: "Credibility never seriously eroded",
                           points: +scaledBonus(scoring.successBonuses.credibilityBonus)))
    }
    if outcome == .success && card.highUnemploymentQuarters == 0 {
        items.append(.init(label: "Labor market held (no >8.5% quarters)",
                           points: +scaledBonus(scoring.successBonuses.laborMarketBonus)))
    }
    if outcome == .success && card.lowestReserves > scoring.successBonuses.lowestReservesThreshold {
        items.append(.init(label: "External position stayed comfortable",
                           points: +scaledBonus(scoring.successBonuses.externalPositionBonus)))
    }

    let total = items.reduce(baseline) { $0 + $1.points }
    let finalScore = Swift.max(0, Swift.min(100, total))

    let sortedBands = scoring.headlineBands.sorted { $0.minScore > $1.minScore }
    let headline = sortedBands.first(where: { finalScore >= $0.minScore })?.label ?? "Mandate in Ruins"

    return ScoreBreakdown(baseline: baseline, items: items, final: finalScore, headline: headline)
}
