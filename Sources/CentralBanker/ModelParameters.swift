import Foundation

// All of the structural coefficients, sensitivities, and clamp bounds used by
// `EconomicSimulator`. Collecting them in one place keeps `simulateQuarter`
// readable and makes difficulty presets / scenario tuning a single swap.
//
// Defaults here reproduce the pre-refactor literal values exactly.
struct ModelParameters {

    // ─── Money & credit ─────────────────────────────────────────────────────
    struct Money {
        // Baseline stance that the simulator treats as "neutral". Policy-rate
        // and reserve-requirement choices are measured as deviations from these.
        var baselineRate: Double = 0.060
        var baselineReserve: Double = 0.120
        var baseM2Growth: Double = 0.080
        var baseCreditGrowth: Double = 0.100

        // How strongly M2 / credit respond to policy settings
        var m2RateSensitivity: Double = 0.60
        var m2ReserveSensitivity: Double = 3.0
        var creditRateSensitivity: Double = 0.80
        var creditReserveSensitivity: Double = 2.0

        // Fiscal monetisation: deficits beyond this threshold leak into money supply
        var fiscalMonetizationThreshold: Double = 0.030
        var fiscalMonetizationCoef: Double = 0.40

        var m2Bounds: ClosedRange<Double> = -0.04 ... 0.22
        var creditBounds: ClosedRange<Double> = -0.05 ... 0.28
    }

    // ─── Output gap (IS dynamics) ───────────────────────────────────────────
    struct OutputGap {
        var potentialGrowthAnnual: Double = 0.035
        var neutralRealRate: Double = 0.030
        var persistence: Double = 0.72            // autoregressive coefficient
        var isCoefficient: Double = 0.45          // annualised; divided by 4 in-model
        var creditImpulse: Double = 0.10
        var creditBaseline: Double = 0.10         // threshold above which credit stimulates
        var externalDemand: Double = 0.14
        var partnerQuarterlyBaseline: Double = 0.01
        var currentAccountSupport: Double = 0.08
        // Heavy, sustained capital controls distort investment and trade
        // finance. Below the threshold they are mostly a crisis-management
        // tool; above it they start shaving cyclical demand and trend growth.
        var capitalControlsDragThreshold: Double = 0.45
        var capitalControlsDemandDrag: Double = 0.018
        var capitalControlsPotentialGrowthDrag: Double = 0.012
        var demandNoiseCarry: Double = 0.45
        var demandNoiseStd: Double = 0.004
        var bounds: ClosedRange<Double> = -0.12 ... 0.09
    }

    // ─── Inflation (Phillips curve) ─────────────────────────────────────────
    struct Inflation {
        var phillipsSlope: Double = 0.26          // annualised; divided by 4 in-model
        var exchangeRatePassthrough: Double = -0.10
        var supplyNoiseCarry: Double = 0.45
        var supplyNoiseStd: Double = 0.004
        var bounds: ClosedRange<Double> = -0.02 ... 0.65
    }

    // ─── Inflation expectations (adaptive) ──────────────────────────────────
    struct Expectations {
        var baseAdaptSpeed: Double = 0.21
        // Credibility loss speeds adaptation: adapt = base + amplifier*(1-credibility)
        var credibilityAmplifier: Double = 0.45
        var bounds: ClosedRange<Double> = 0.0 ... 0.55
    }

    // ─── Credibility dynamics ──────────────────────────────────────────────
    struct Credibility {
        // Large upside inflation surprises erode credibility fast
        var surpriseThreshold: Double = 0.020
        var surpriseDecrement: Double = 0.025
        // Calm, low-inflation quarters rebuild credibility slowly
        var calmInflationMargin: Double = 0.005
        var calmInflationCeiling: Double = 0.045
        var calmIncrement: Double = 0.007
        // Sustained high inflation drains credibility even without a surprise
        var highInflationThreshold: Double = 0.07
        var highInflationDecrement: Double = 0.014
        // Reward for two consecutive quarters with inflation below the
        // threshold: additional credibility on top of the calm-quarter bump.
        // Gives the player a tangible payoff for sustained discipline.
        var sustainedLowThreshold: Double = 0.030
        var sustainedLowBonus: Double = 0.012
        // Capital controls signal desperation to international markets and
        // drag on credibility above a threshold. Effect is (controls - threshold)
        // * coef per quarter, so moderate controls (≤ 30%) are free, heavy
        // controls (≥ 70%) cost roughly half a surprise-decrement per quarter.
        var capitalControlsThreshold: Double = 0.30
        var capitalControlsDrag: Double = 0.022
        var bounds: ClosedRange<Double> = 0.05 ... 1.0
    }

    // ─── Labour market (Okun's law) ─────────────────────────────────────────
    struct Labor {
        var okunSensitivity: Double = 0.50        // target_u = NAIRU - sens*gap
        var unemploymentPersistence: Double = 0.82
        var bounds: ClosedRange<Double> = 0.02 ... 0.28
    }

    // ─── Exchange rate (UIP + PPP + CA pressure) ────────────────────────────
    struct ExchangeRate {
        var uipCoefficient: Double = 0.35
        var currentAccountPressure: Double = -0.22
        var noiseStd: Double = 0.012
        var floor: Double = 0.30
    }

    // ─── Current account ────────────────────────────────────────────────────
    struct CurrentAccount {
        var competitiveness: Double = 0.20
        var absorption: Double = -0.28
        var partnerSensitivity: Double = 0.14
        var partnerBaseline: Double = 0.030
        var persistence: Double = 0.82
        var bounds: ClosedRange<Double> = -0.18 ... 0.12
    }

    // ─── Capital account ────────────────────────────────────────────────────
    struct CapitalAccount {
        var interestSensitivity: Double = 0.45
        var expectationsSensitivity: Double = -0.55
        // Beyond a moderate threshold, controls deter legitimate inflows as
        // well as panic outflows, making them weaker as a permanent setting.
        var controlsPenaltyThreshold: Double = 0.45
        var controlsPenalty: Double = 0.08
        var bounds: ClosedRange<Double> = -0.15 ... 0.14
    }

    // ─── Foreign reserves ───────────────────────────────────────────────────
    struct Reserves {
        var importShareOfGDP: Double = 0.28
        var criticalMonths: Double = 1.5
        var warningMonths: Double = 2.5
    }

    // ─── Fiscal ─────────────────────────────────────────────────────────────
    struct Fiscal {
        var baselineDeficit: Double = -0.040
        var cyclicalRevenueCoef: Double = 0.14
        var debtServiceRate: Double = 0.08
        var debtServiceFactor: Double = 0.75
        var governmentDebtFloor: Double = 0.1
        var externalDebtBounds: ClosedRange<Double> = 0.05 ... 1.50
    }

    // ─── Political pressure ─────────────────────────────────────────────────
    struct Political {
        var unemploymentThreshold: Double = 0.080
        var unemploymentCoef: Double = 220.0
        var inflationThreshold: Double = 0.055
        var inflationCoef: Double = 170.0
        var recessionThreshold: Double = -0.010
        var recessionBump: Double = 24.0
        // Each quarter, pressure moves: new = retain*old + add*raw.
        // Retain lowered from 0.83 → 0.75 so pressure decays faster when
        // conditions improve, creating real "windows of opportunity" after a
        // bad quarter instead of a full year of penalty lingering.
        var smoothingRetain: Double = 0.82
        var smoothingAdd: Double = 0.30
        var bounds: ClosedRange<Double> = 0.0 ... 100.0
    }

    // ─── Public approval ────────────────────────────────────────────────────
    struct Approval {
        var inflationBaseline: Double = 0.035
        var inflationCoef: Double = -360.0
        var unemploymentBaseline: Double = 0.065
        var unemploymentCoef: Double = -520.0
        var growthCoef: Double = 150.0
        // Capital controls read as desperation by the public and the business
        // class — approval drops roughly in proportion to how locked-down the
        // capital account is. -25 at full controls is meaningful without
        // dwarfing the inflation/unemployment channels.
        var capitalControlsCoef: Double = -25.0
        var neutralLevel: Double = 48.0
        var smoothingRetain: Double = 0.86
        var smoothingAdd: Double = 0.14
        var bounds: ClosedRange<Double> = 0.0 ... 100.0
    }

    // ─── Game-over thresholds ───────────────────────────────────────────────
    struct Outcomes {
        var currencyCrisisReserves: Double = 0.9
        var hyperinflationRate: Double = 0.35
        var hyperinflationExpected: Double = 0.28
        var depressionGrowth: Double = -0.05
        var depressionGap: Double = -0.08
        var politicalOusterPressure: Double = 88.0
        var successYear: Int = 1982
    }

    var money = Money()
    var outputGap = OutputGap()
    var inflation = Inflation()
    var expectations = Expectations()
    var credibility = Credibility()
    var labor = Labor()
    var exchangeRate = ExchangeRate()
    var currentAccount = CurrentAccount()
    var capitalAccount = CapitalAccount()
    var reserves = Reserves()
    var fiscal = Fiscal()
    var political = Political()
    var approval = Approval()
    var outcomes = Outcomes()

    static let `default` = ModelParameters()
}

// Small helper so the simulator can write `bounds.clamping(x)` instead of
// the nested max/min calls that cluttered the previous version.
extension ClosedRange where Bound == Double {
    func clamping(_ v: Double) -> Double {
        Swift.min(upperBound, Swift.max(lowerBound, v))
    }
}
