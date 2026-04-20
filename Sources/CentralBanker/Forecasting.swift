import Foundation

private let forecastSeedSalt: UInt64 = 0x4652_4353_545F_4553

struct ForecastEstimate {
    let report: QuarterReport
    let estimatedAfter: EconomicState
}

func forecastEstimate(for report: QuarterReport,
                      sessionSeed: UInt64,
                      changeSignature: UInt64 = 0) -> ForecastEstimate {
    var rng = SeededRandomGenerator(
        seed: sessionSeed
            ^ forecastSeedSalt
            ^ UInt64(report.stateBefore.year)
            ^ (UInt64(report.stateBefore.quarter) << 8)
            ^ changeSignature)

    let before = report.stateBefore
    let actual = report.stateAfter
    let uncertainty = forecastUncertaintyScale(before: before, actual: actual)

    var estimated = actual
    estimated.inflation = (actual.inflation
        + Double.random(in: -0.003...0.003, using: &rng) * uncertainty).clamped(to: -0.02...0.65)
    estimated.expectedInflation = (actual.expectedInflation
        + Double.random(in: -0.0025...0.0025, using: &rng) * uncertainty).clamped(to: 0.0...0.55)
    estimated.outputGap = (actual.outputGap
        + Double.random(in: -0.004...0.004, using: &rng) * uncertainty).clamped(to: -0.12...0.09)
    estimated.gdpGrowthQoQ = actual.gdpGrowthQoQ
        + Double.random(in: -0.003...0.003, using: &rng) * uncertainty
    estimated.unemployment = (actual.unemployment
        + Double.random(in: -0.002...0.002, using: &rng) * uncertainty).clamped(to: 0.02...0.28)
    estimated.foreignReservesMonths = max(0.0, actual.foreignReservesMonths
        + Double.random(in: -0.16...0.16, using: &rng) * uncertainty)
    let fxMultiplier = 1.0 + Double.random(in: -0.008...0.008, using: &rng) * uncertainty
    estimated.exchangeRate = max(0.30, actual.exchangeRate * fxMultiplier)

    // Softer uncertainty for second-order political and credibility effects.
    estimated.credibility = (actual.credibility
        + Double.random(in: -0.008...0.008, using: &rng) * uncertainty).clamped(to: 0.05...1.0)
    estimated.politicalPressure = (actual.politicalPressure
        + Double.random(in: -1.6...1.6, using: &rng) * uncertainty).clamped(to: 0.0...100.0)
    estimated.publicApproval = (actual.publicApproval
        + Double.random(in: -1.2...1.2, using: &rng) * uncertainty).clamped(to: 0.0...100.0)

    return ForecastEstimate(report: report, estimatedAfter: estimated)
}

func previewChangeSignature(_ changes: [PolicyChange]) -> UInt64 {
    changes.reduce(0x5052_5657_4B45_5953) { partial, change in
        let valueBits: UInt64
        let tag: UInt64
        switch change {
        case .rate(let value):
            valueBits = value.bitPattern
            tag = 1
        case .reserve(let value):
            valueBits = value.bitPattern
            tag = 2
        case .controls(let value):
            valueBits = value.bitPattern
            tag = 3
        }
        return partial &* 1_099_511_628_211 &+ valueBits &+ tag
    }
}

private func forecastUncertaintyScale(before: EconomicState,
                                      actual: EconomicState) -> Double {
    let stress = max(0.0, 2.8 - before.foreignReservesMonths) * 0.20
        + max(0.0, before.inflation - 0.07) * 2.0
        + max(0.0, abs(before.outputGap) - 0.02) * 3.0
        + max(0.0, 0.65 - before.credibility) * 0.8
        + max(0.0, actual.exchangeRateQoQChange) * 6.0
    return min(1.8, 1.0 + stress)
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
