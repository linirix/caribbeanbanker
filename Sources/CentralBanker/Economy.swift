import Foundation

// The pure numeric state of the domestic economy. All rates are stored as
// annual fractions (e.g. 0.06 = 6%); quarterly simulation divides by 4
// where needed.
//
// Exogenous environment (world rates, oil, trading-partner growth) lives
// on `ExternalEnvironment`. Narrative news and chart history live on
// `SessionLog`. Keeping those separate makes `EconomicState` easy to diff,
// serialise, and reason about in isolation.
struct EconomicState: Codable {
    // --- Real Economy ---
    var realGDP: Double = 100.0
    var potentialGDP: Double = 100.0
    var outputGap: Double = 0.0           // (Y - Y*)/Y*
    var gdpGrowthQoQ: Double = 0.0        // quarterly real growth rate

    // --- Prices ---
    var priceLevel: Double = 100.0
    var inflation: Double = 0.055         // annual CPI
    var coreInflation: Double = 0.050
    var expectedInflation: Double = 0.050

    // --- Labor ---
    var unemployment: Double = 0.065
    var nairu: Double = 0.070             // natural rate (high in 70s)

    // --- Monetary ---
    var policyRate: Double = 0.060        // central bank discount rate
    var reserveRequirement: Double = 0.12
    var m2Growth: Double = 0.080
    var bankCreditGrowth: Double = 0.100
    var credibility: Double = 0.70        // 0–1

    // --- External financial position ---
    var exchangeRate: Double = 2.00       // SLD per USD
    var exchangeRateQoQChange: Double = 0.0
    var currentAccountGDP: Double = -0.025
    var capitalAccountGDP: Double = 0.008
    var foreignReservesMonths: Double = 4.20
    var capitalControls: Double = 0.30    // 0=open, 1=closed
    var externalDebtGDP: Double = 0.30

    // --- Fiscal ---
    var fiscalBalanceGDP: Double = -0.040
    var governmentDebtGDP: Double = 0.500

    // --- Political ---
    var politicalPressure: Double = 24.0  // 0–100
    var publicApproval: Double = 52.0     // 0–100

    // --- Quarter-over-quarter deltas (set each simulation step) ---
    var inflationDelta: Double = 0.0
    var expectedInflationDelta: Double = 0.0
    var outputGapDelta: Double = 0.0

    // --- Time ---
    var quarter: Int = 1
    var year: Int = 1973

    var quarterLabel: String { "Q\(quarter) \(year)" }
    var annualizedGDPGrowth: Double { gdpGrowthQoQ * 4.0 }
    var realInterestRate: Double { policyRate - expectedInflation }

    mutating func advanceTime() {
        quarter += 1
        if quarter > 4 { quarter = 1; year += 1 }
    }
}

enum GameOutcome: String, Codable, Hashable {
    case ongoing
    case currencyCrisis
    case hyperinflation
    case depression
    case politicalOuster
    case success
}

class EconomicSimulator {
    var state: EconomicState
    var environment: ExternalEnvironment
    var log: SessionLog
    var scoreCard: ScoreCard
    var communicationStance: CommunicationStance = .balanced
    var activeCabinetRequest: CabinetRequest? = nil
    var crisisCooldownQuarters: Int = 0
    let params: ModelParameters
    // The difficulty label this simulator was constructed under. Used for
    // display and save/load; the coefficient values themselves live on
    // `params`, which is what the sim actually reads. Kept here (not on
    // `EconomicState`) because difficulty is a session-level property, not
    // part of the domestic economy's numeric state.
    let difficulty: Difficulty
    // The simulator owns its RNG. External code (e.g. `generateEvents`) that
    // needs shared randomness should pass `&simulator.rng` as `inout` so that
    // every stochastic choice in the session draws from a single, seeded stream.
    var rng: SeededRandomGenerator
    // Internal (not private) so save/load can persist the full deterministic
    // state. They're part of the sim's AR(1) noise processes: zeroing them on
    // load would create a one-quarter discontinuity in demand/supply shocks.
    var demandNoiseCarry: Double = 0.0
    var supplyNoiseCarry: Double = 0.0
    // Short-lived support from successful external-defense actions. These let
    // intervention and tighter controls buy a few quarters of breathing room
    // instead of disappearing immediately after one turn.
    var interventionSupportCarry: Double = 0.0
    var controlsReliefCarry: Double = 0.0

    init(state: EconomicState = EconomicState(),
         environment: ExternalEnvironment = ExternalEnvironment(),
         log: SessionLog = SessionLog(),
         scoreCard: ScoreCard = ScoreCard(),
         params: ModelParameters = .default,
         difficulty: Difficulty = .governor,
         seed: UInt64 = freshSeed()) {
        self.state = state
        self.environment = environment
        self.log = log
        self.scoreCard = scoreCard
        self.params = params
        self.difficulty = difficulty
        self.rng = SeededRandomGenerator(seed: seed)
    }

    @discardableResult
    func simulateQuarter(events: [EconomicEvent]) -> QuarterReport {
        let stateBefore = state
        var s = state
        var env = environment

        // News accumulator — all quarter-narrative lines land here, in
        // emission order, instead of being pushed into `log` directly.
        // At the end we apply them as a batch, so the simulation itself has
        // no side effects on the session log.
        var news: [String] = []

        // Snapshot pre-simulation values for delta display
        let snapInflation = s.inflation
        let snapExpectedInflation = s.expectedInflation
        let snapOutputGap = s.outputGap

        // --- Apply exogenous shocks from events ---
        // Events may contribute to inflation (oil, strikes, drought) and to the
        // fiscal balance (debt refinancing, foreign aid). Those deltas are
        // accumulated here so that later baseline calculations don't overwrite them.
        var oilInflationImpact: Double = 0.0
        var fiscalEventDelta: Double = 0.0
        for event in events {
            let impact = event.type.apply(to: &s, environment: &env, news: &news, rng: &rng)
            oilInflationImpact += impact.oilImpact
            fiscalEventDelta += impact.fiscalDelta
        }

        let p = params

        // --- Money supply / credit ---
        // Calibrated so that at baseline conditions (rate=6%, reserve=12%, deficit=3.2%)
        // m2Growth ≈ 8% and bankCreditGrowth ≈ 10%.
        let fiscalMonetization =
            max(0, (-s.fiscalBalanceGDP - p.money.fiscalMonetizationThreshold))
            * p.money.fiscalMonetizationCoef
        let rateGap = s.policyRate - p.money.baselineRate
        let reserveGap = s.reserveRequirement - p.money.baselineReserve
        let reserveTightening = max(0.0, reserveGap)
        let reserveOverhang = max(0.0, s.reserveRequirement - p.outputGap.reserveRequirementDragThreshold)
        s.m2Growth = p.money.m2Bounds.clamping(
            p.money.baseM2Growth
            - p.money.m2RateSensitivity * rateGap
            - p.money.m2ReserveSensitivity * reserveGap
            + fiscalMonetization)
        s.bankCreditGrowth = p.money.creditBounds.clamping(
            p.money.baseCreditGrowth
            - p.money.creditRateSensitivity * rateGap
            - p.money.creditReserveSensitivity * reserveGap)

        // --- Potential GDP ---
        let capitalControlsOverhang = max(0.0, s.capitalControls - p.outputGap.capitalControlsDragThreshold)
        let potentialGrowthQ = max(
            0.0,
            p.outputGap.potentialGrowthAnnual / 4.0
                - (p.outputGap.capitalControlsPotentialGrowthDrag * capitalControlsOverhang / 4.0)
        )
        s.potentialGDP *= (1.0 + potentialGrowthQ)

        // --- Output gap (IS dynamics, quarterly) ---
        let realRate = s.policyRate - s.expectedInflation
        let realRateGap = realRate - p.outputGap.neutralRealRate
        let creditImpulse = p.outputGap.creditImpulse * (s.bankCreditGrowth - p.outputGap.creditBaseline)
        let externalDemand = p.outputGap.externalDemand
            * (env.tradingPartnerGrowth / 4.0 - p.outputGap.partnerQuarterlyBaseline)
        let currentAccountSupport = p.outputGap.currentAccountSupport * s.currentAccountGDP
        let reserveDemandDrag = p.outputGap.reserveRequirementDemandDrag * reserveOverhang
        let controlsDemandDrag = p.outputGap.capitalControlsDemandDrag * capitalControlsOverhang
        demandNoiseCarry = p.outputGap.demandNoiseCarry * demandNoiseCarry
            + normalRandom(std: p.outputGap.demandNoiseStd)
        let prevGap = s.outputGap
        s.outputGap = p.outputGap.bounds.clamping(
            p.outputGap.persistence * s.outputGap
            - (p.outputGap.isCoefficient / 4.0) * realRateGap
            + creditImpulse
            + externalDemand
            + currentAccountSupport
            - reserveDemandDrag
            - controlsDemandDrag
            + demandNoiseCarry)

        let gdpGrowthQ = potentialGrowthQ + (s.outputGap - prevGap)
        s.realGDP *= (1.0 + gdpGrowthQ)
        s.gdpGrowthQoQ = gdpGrowthQ

        // --- Inflation (expectations-augmented Phillips curve, quarterly) ---
        // Exchange rate passthrough: depreciation raises import prices
        let erPassthrough = p.inflation.exchangeRatePassthrough * s.exchangeRateQoQChange
        supplyNoiseCarry = p.inflation.supplyNoiseCarry * supplyNoiseCarry
            + normalRandom(std: p.inflation.supplyNoiseStd)
        let qExpectedInf = s.expectedInflation / 4.0
        let qInflation = qExpectedInf
            + (p.inflation.phillipsSlope / 4.0) * s.outputGap
            + erPassthrough / 4.0
            + oilInflationImpact / 4.0
            + supplyNoiseCarry
        s.inflation = p.inflation.bounds.clamping(qInflation * 4.0)
        s.coreInflation = max(0.0, s.inflation - oilInflationImpact - erPassthrough)
        s.priceLevel *= (1.0 + qInflation)

        // --- Inflation expectations (adaptive, modulated by credibility) ---
        // Lower credibility → faster de-anchoring of expectations
        let adaptSpeed = p.expectations.baseAdaptSpeed
            + (1.0 - s.credibility) * p.expectations.credibilityAmplifier
        s.expectedInflation = p.expectations.bounds.clamping(
            adaptSpeed * s.inflation + (1.0 - adaptSpeed) * s.expectedInflation)

        // Credibility: erodes when inflation surprises upward, slowly rebuilds
        if s.inflation > s.expectedInflation + p.credibility.surpriseThreshold {
            s.credibility = p.credibility.bounds.clamping(s.credibility - p.credibility.surpriseDecrement)
        } else if s.inflation < s.expectedInflation + p.credibility.calmInflationMargin
                  && s.inflation < p.credibility.calmInflationCeiling {
            s.credibility = p.credibility.bounds.clamping(s.credibility + p.credibility.calmIncrement)
        } else if s.inflation > p.credibility.highInflationThreshold {
            s.credibility = p.credibility.bounds.clamping(s.credibility - p.credibility.highInflationDecrement)
        }

        // Sustained-discipline bonus: two consecutive quarters with inflation
        // below `sustainedLowThreshold` earns a meaningful credibility boost,
        // on top of any calm-quarter increment above. The previous quarter's
        // inflation comes from the log (not yet updated with the current
        // quarter). This rewards "stick with it" play without breaking the
        // surprise/erosion asymmetry.
        let prevInflation = log.inflationHistory.last ?? Double.infinity
        if s.inflation < p.credibility.sustainedLowThreshold
            && prevInflation < p.credibility.sustainedLowThreshold {
            s.credibility = p.credibility.bounds.clamping(
                s.credibility + p.credibility.sustainedLowBonus)
        }

        // Capital-controls drag: heavy controls signal desperation to markets.
        // No cost below the threshold; linear thereafter. At max controls (1.0)
        // this is ~1.3pp of credibility per quarter — enough to matter in a
        // sustained crisis but not punitive for brief emergency use.
        if s.capitalControls > p.credibility.capitalControlsThreshold {
            let drag = (s.capitalControls - p.credibility.capitalControlsThreshold)
                     * p.credibility.capitalControlsDrag
            s.credibility = p.credibility.bounds.clamping(s.credibility - drag)
        }

        // --- Unemployment (Okun's law, sluggish adjustment) ---
        let targetU = s.nairu - p.labor.okunSensitivity * s.outputGap
        let uPersist = p.labor.unemploymentPersistence
        s.unemployment = p.labor.bounds.clamping(
            uPersist * s.unemployment + (1.0 - uPersist) * targetU)

        // --- Exchange rate (UIP + PPP drift, capital controls dampen flows) ---
        let openness = 1.0 - s.capitalControls
        let interestDiff = s.policyRate - env.worldInterestRate
        let uipAppreciation = openness * p.exchangeRate.uipCoefficient * interestDiff / 4.0
        let pppDrift = (s.inflation - env.worldInflation) / 4.0   // relative inflation erodes rate
        let caEffect = p.exchangeRate.currentAccountPressure * s.currentAccountGDP / 4.0
        let erNoise = normalRandom(std: p.exchangeRate.noiseStd)
        let defenseSupport = interventionSupportCarry + controlsReliefCarry * 0.7
        // Positive change = depreciation (more SLD per USD)
        let erChange = pppDrift - uipAppreciation + caEffect + erNoise - defenseSupport
        s.exchangeRateQoQChange = erChange
        s.exchangeRate = max(p.exchangeRate.floor, s.exchangeRate * (1.0 + erChange))

        // --- Current account ---
        // Real appreciation worsens competitiveness
        let realAppreciation = -erChange + (env.worldInflation - s.inflation) / 4.0
        let caCompetitiveness = p.currentAccount.competitiveness * realAppreciation
        let caAbsorption = p.currentAccount.absorption * s.outputGap
        let caPartner = p.currentAccount.partnerSensitivity
            * (env.tradingPartnerGrowth - p.currentAccount.partnerBaseline)
        let caReserveCompression = p.currentAccount.reserveDemandCompression * reserveTightening
        let caPersist = p.currentAccount.persistence
        let caTarget = caCompetitiveness + caAbsorption + caPartner + caReserveCompression
        s.currentAccountGDP = p.currentAccount.bounds.clamping(
            caPersist * s.currentAccountGDP
            + (1.0 - caPersist) * caTarget)

        // --- Capital account ---
        let kaInterest = openness * p.capitalAccount.interestSensitivity * interestDiff
        let kaExpectations = openness * p.capitalAccount.expectationsSensitivity * erChange * 4.0
        let reserveStability = p.capitalAccount.reserveStabilitySupport * reserveTightening
        let controlsCapitalPenalty = max(0.0, s.capitalControls - p.capitalAccount.controlsPenaltyThreshold)
            * p.capitalAccount.controlsPenalty
        let defenseFlowSupport = interventionSupportCarry * 0.85 + controlsReliefCarry
        s.capitalAccountGDP = p.capitalAccount.bounds.clamping(
            kaInterest + kaExpectations + defenseFlowSupport + reserveStability - controlsCapitalPenalty
        )

        // --- Foreign reserves ---
        // BOP surplus/deficit in months of imports
        let bop = s.currentAccountGDP + s.capitalAccountGDP
        let monthlyImportShare = p.reserves.importShareOfGDP / 12.0
        s.foreignReservesMonths += (bop / (monthlyImportShare * 12.0)) * 0.25
        s.foreignReservesMonths = max(0.0, s.foreignReservesMonths)

        // Reserve alarm news
        if s.foreignReservesMonths < p.reserves.criticalMonths {
            news.append("CRITICAL: Reserves near exhaustion (\(String(format: "%.1f", s.foreignReservesMonths)) months). Devaluation imminent.")
        } else if s.foreignReservesMonths < p.reserves.warningMonths {
            news.append("WARNING: Reserves dangerously low at \(String(format: "%.1f", s.foreignReservesMonths)) months of imports.")
        }

        // --- Fiscal dynamics ---
        // Cyclical revenue loss in recessions, plus any one-off event costs
        // (e.g. higher debt-service from a .debtRefinancing event).
        let cyclicalRevenue = p.fiscal.cyclicalRevenueCoef * s.outputGap
        s.fiscalBalanceGDP = p.fiscal.baselineDeficit + cyclicalRevenue + fiscalEventDelta
        s.governmentDebtGDP +=
            (-s.fiscalBalanceGDP + s.externalDebtGDP * p.fiscal.debtServiceRate * p.fiscal.debtServiceFactor) / 4.0
        s.governmentDebtGDP = max(p.fiscal.governmentDebtFloor, s.governmentDebtGDP)

        // --- External debt stock ---
        // Current-account deficits accumulate into external debt; surpluses pay it down.
        s.externalDebtGDP = p.fiscal.externalDebtBounds.clamping(
            s.externalDebtGDP + (-s.currentAccountGDP) / 4.0)

        // --- Political dynamics ---
        let uPressure = max(0, s.unemployment - p.political.unemploymentThreshold) * p.political.unemploymentCoef
        let infPressure = max(0, s.inflation - p.political.inflationThreshold) * p.political.inflationCoef
        let recPressure = s.annualizedGDPGrowth < p.political.recessionThreshold ? p.political.recessionBump : 0.0
        s.politicalPressure = p.political.bounds.clamping(
            p.political.smoothingRetain * s.politicalPressure
            + p.political.smoothingAdd * (uPressure + infPressure + recPressure))

        let approvalInflation = (s.inflation - p.approval.inflationBaseline) * p.approval.inflationCoef
        let approvalU = (s.unemployment - p.approval.unemploymentBaseline) * p.approval.unemploymentCoef
        let approvalGrowth = s.annualizedGDPGrowth * p.approval.growthCoef
        // Controls are politically unpopular — the public reads them as "we've
        // lost our grip on the currency." Linear in control level.
        let approvalControls = s.capitalControls * p.approval.capitalControlsCoef
        let rawApproval = p.approval.bounds.clamping(
            p.approval.neutralLevel + approvalInflation + approvalU + approvalGrowth + approvalControls)
        s.publicApproval = p.approval.bounds.clamping(
            p.approval.smoothingRetain * s.publicApproval + p.approval.smoothingAdd * rawApproval)

        // --- Communication strategy ---
        applyCommunicationEffects(to: &s, news: &news)

        // --- Quarter-over-quarter deltas ---
        s.inflationDelta = s.inflation - snapInflation
        s.expectedInflationDelta = s.expectedInflation - snapExpectedInflation
        s.outputGapDelta = s.outputGap - snapOutputGap

        // --- Auto-generated economic commentary ---
        generateCommentary(for: s, news: &news)

        // Decay temporary stabilization support after it has influenced the
        // quarter, so emergency action buys a short runway rather than a
        // permanent subsidy.
        interventionSupportCarry *= 0.60
        controlsReliefCarry *= 0.72
        if crisisCooldownQuarters > 0 {
            crisisCooldownQuarters -= 1
        }

        // Apply the accumulated news + chart history to the session log as a
        // single batch. This is the one and only point where the simulation
        // touches the log — everything above accumulated into `news` locally.
        let label = s.quarterLabel
        for msg in news { log.addNews(msg, quarterLabel: label) }
        log.recordQuarter(s)
        scoreCard.record(s)

        s.advanceTime()
        state = s
        environment = env
        return QuarterReport(
            stateBefore: stateBefore,
            stateAfter: state,
            events: events,
            news: news
        )
    }

    private func applyCommunicationEffects(to s: inout EconomicState, news: inout [String]) {
        switch communicationStance {
        case .balanced:
            return

        case .hawkish:
            let hawkishPressureBump =
                (s.inflation > 0.10 || s.outputGap > 0.02) ? 0.5 : 2.0
            s.politicalPressure = params.political.bounds.clamping(s.politicalPressure + hawkishPressureBump)
            if isHawkishCommunicationConsistent(state: s) {
                s.credibility = params.credibility.bounds.clamping(s.credibility + 0.010)
                s.expectedInflation = params.expectations.bounds.clamping(s.expectedInflation - 0.003)
                news.append("COMMUNICATION: Hawkish anti-inflation guidance reinforced by policy stance.")
            } else {
                s.credibility = params.credibility.bounds.clamping(s.credibility - 0.015)
                s.expectedInflation = params.expectations.bounds.clamping(s.expectedInflation + 0.002)
                news.append("COMMUNICATION: Hawkish rhetoric rings hollow against an accommodative stance.")
            }

        case .dovish:
            s.politicalPressure = params.political.bounds.clamping(s.politicalPressure - 2.0)
            if s.inflation > 0.08 {
                s.credibility = params.credibility.bounds.clamping(s.credibility - 0.015)
                s.expectedInflation = params.expectations.bounds.clamping(s.expectedInflation + 0.004)
                news.append("COMMUNICATION: Dovish messaging amid high inflation unsettles markets and lifts inflation expectations.")
            } else {
                s.publicApproval = params.approval.bounds.clamping(s.publicApproval + 1.5)
                news.append("COMMUNICATION: Dovish reassurance calms households and buys modest political goodwill.")
            }

        case .opaque:
            s.politicalPressure = params.political.bounds.clamping(s.politicalPressure - 1.0)
            s.credibility = params.credibility.bounds.clamping(s.credibility - 0.008)
            news.append("COMMUNICATION: Deliberately opaque guidance buys short-term breathing room but leaves markets uneasy.")
        }
    }

    private func generateCommentary(for s: EconomicState, news: inout [String]) {
        var msgs: [String] = []

        if s.inflation > 0.20 {
            msgs.append("Hyperinflation risk: prices rising at \(pct(s.inflation)) annually. Public confidence collapsing.")
        } else if s.inflation > 0.12 {
            msgs.append("Severe stagflation. Inflation at \(pct(s.inflation)) with output \(gapLabel(s.outputGap)).")
        } else if s.annualizedGDPGrowth < -0.03 && s.inflation > 0.08 {
            msgs.append("Classic stagflation: GDP contracting \(pct(-s.annualizedGDPGrowth)) while inflation runs at \(pct(s.inflation)).")
        } else if s.annualizedGDPGrowth < -0.02 {
            msgs.append("Economy in recession. GDP declining at \(pct(-s.annualizedGDPGrowth)) annual rate.")
        } else if s.annualizedGDPGrowth > 0.05 && s.inflation < 0.06 {
            msgs.append("Economy performing well: strong growth with contained inflation.")
        }

        if s.unemployment > 0.14 {
            msgs.append("Unemployment crisis at \(pct(s.unemployment)). Political pressure building rapidly.")
        } else if s.unemployment > 0.10 {
            msgs.append("Labour market weakening: \(pct(s.unemployment)) unemployed. Social tensions rising.")
        }

        if s.credibility < 0.30 {
            msgs.append("Central bank credibility near zero. Markets pricing in sustained high inflation.")
        } else if s.credibility < 0.50 {
            msgs.append("CB credibility eroding. Inflation expectations becoming unanchored.")
        }

        if s.exchangeRateQoQChange > 0.04 {
            msgs.append("Sharp SLD depreciation this quarter. Import prices rising; inflation risk elevated.")
        } else if s.exchangeRateQoQChange < -0.03 {
            msgs.append("SLD strengthening. Import prices easing; exporters face headwinds.")
        }

        if msgs.isEmpty {
            if s.outputGap > 0.02 {
                msgs.append("Economy running above potential. Domestic demand strong; inflation risk building.")
            } else if s.outputGap < -0.03 {
                msgs.append("Significant slack in the economy. Below-potential output; unemployment elevated.")
            } else {
                msgs.append("Economy near equilibrium. Monitor for emerging pressures.")
            }
        }

        news.append(contentsOf: msgs)
    }

    func applyFXIntervention(months: Double) {
        // Positive months = accumulate reserves (sell SLD, weaken it → higher SLD/USD)
        // Negative months = spend reserves to defend the SLD (buy SLD, strengthen it → lower SLD/USD)
        state.foreignReservesMonths += months
        state.foreignReservesMonths = max(0, state.foreignReservesMonths)
        // Partial exchange-rate effect. Our convention: exchangeRate is SLD per USD,
        // so an *increase* is depreciation. Positive `months` should therefore raise it.
        let erImpact = months * 0.012
        state.exchangeRate = max(0.30, state.exchangeRate * (1.0 + erImpact))
        state.capitalAccountGDP += months * 0.015
        if months < 0 {
            interventionSupportCarry = min(0.035, interventionSupportCarry + (-months) * 0.020)
        }
    }

    func setCapitalControls(_ value: Double) {
        let old = state.capitalControls
        state.capitalControls = (0.0...1.0).clamping(value)
        let tightening = max(0.0, state.capitalControls - old)
        if tightening > 0 {
            controlsReliefCarry = min(0.040, controlsReliefCarry + tightening * 0.060)
        }
    }

    func checkOutcome() -> GameOutcome {
        let s = state
        let o = params.outcomes
        if s.foreignReservesMonths < o.currencyCrisisReserves { return .currencyCrisis }
        if s.inflation > o.hyperinflationRate && s.expectedInflation > o.hyperinflationExpected {
            return .hyperinflation
        }
        if s.annualizedGDPGrowth < o.depressionGrowth && s.outputGap < o.depressionGap {
            return .depression
        }
        if s.politicalPressure > o.politicalOusterPressure { return .politicalOuster }
        return .ongoing
    }

    func maybeIssueCabinetRequest() {
        guard activeCabinetRequest == nil else { return }
        guard let request = generateCabinetRequest(for: state) else { return }
        activeCabinetRequest = request
        log.addNews("CABINET REQUEST: \(request.title). \(request.detail)",
                    quarterLabel: state.quarterLabel)
    }

    func describeCabinetRequest() -> String {
        guard let request = activeCabinetRequest else {
            return "No active cabinet request this quarter."
        }
        return "Cabinet request: \(request.title). \(request.detail) Use accept, reject, or delay."
    }

    func acceptCabinetRequest() -> String {
        guard let request = activeCabinetRequest else {
            return "No active cabinet request to accept."
        }
        let label = state.quarterLabel
        let config = GameConfigs.cabinetRequest(request.type)
        let oldRate = state.policyRate
        let oldControls = state.capitalControls
        let oldReserves = state.foreignReservesMonths
        applyConfiguredEffects(config.acceptEffects)
        activeCabinetRequest = nil

        let news: String
        let message: String
        switch request.type {
        case .cutRates:
            news = String(format: "CABINET: You accepted pressure for a rate cut. Policy rate %.2f%% → %.2f%%.",
                          oldRate * 100, state.policyRate * 100)
            message = String(format: "Accepted cabinet demand. Policy rate cut from %.2f%% to %.2f%%.",
                             oldRate * 100, state.policyRate * 100)
        case .tightenControls:
            news = String(format: "CABINET: You imposed tighter capital controls (%.0f → %.0f of 10).",
                          oldControls * 10, state.capitalControls * 10)
            message = String(format: "Accepted cabinet demand. Controls tightened from %.0f to %.0f (of 10).",
                             oldControls * 10, state.capitalControls * 10)
        case .defendCurrency:
            news = "CABINET: You authorized emergency FX sales to defend the Solan Dollar."
            message = String(format: "Accepted cabinet demand. Reserves %.2f → %.2f months while defending the SLD.",
                             oldReserves, state.foreignReservesMonths)
        }
        log.addNews(news, quarterLabel: label)
        return message
    }

    func rejectCabinetRequest() -> String {
        guard let request = activeCabinetRequest else {
            return "No active cabinet request to reject."
        }
        let label = state.quarterLabel
        applyConfiguredEffects(GameConfigs.cabinetRequest(request.type).rejectEffects)
        activeCabinetRequest = nil
        log.addNews("CABINET: You rejected the cabinet's request and defended central-bank independence.",
                    quarterLabel: label)
        return "Rejected cabinet request. Political pressure has increased."
    }

    func delayCabinetRequest() -> String {
        guard activeCabinetRequest != nil else {
            return "No active cabinet request to delay."
        }
        applyCabinetDelayPenalty(prefix: "CABINET: You delayed a response, buying time but irritating the cabinet.")
        return "Delayed cabinet request. Pressure ticks higher while the issue remains unresolved."
    }

    func deferCabinetRequestIfNeeded() {
        guard activeCabinetRequest != nil else { return }
        applyCabinetDelayPenalty(prefix: "CABINET: You advanced the quarter without answering. The cabinet reads it as stonewalling.")
    }

    private func applyCabinetDelayPenalty(prefix: String) {
        applyConfiguredEffects(GameConfigs.tuning.cabinet.delayEffects)
        log.addNews(prefix, quarterLabel: state.quarterLabel)
        activeCabinetRequest = nil
    }

    private func generateCabinetRequest(for s: EconomicState) -> CabinetRequest? {
        for type in [CabinetRequestType.defendCurrency, .tightenControls, .cutRates] {
            let config = GameConfigs.cabinetRequest(type)
            if config.trigger.matches(s) {
                return CabinetRequest(type: type, detail: config.detail)
            }
        }
        return nil
    }

    // Produce an independent copy of this simulator for dry-run preview.
    // The copy shares nothing with the original: mutations (state, env, log,
    // rng noise-carries) stay local to the clone. Used by `preview` and
    // `what_if` so the player can see projected outcomes without consuming
    // the session's RNG stream or touching the real state.
    func cloneForPreview() -> EconomicSimulator {
        let c = EconomicSimulator(state: self.state,
                                  environment: self.environment,
                                  log: self.log,
                                  scoreCard: self.scoreCard,
                                  params: self.params,
                                  difficulty: self.difficulty,
                                  seed: 0)   // overwritten below
        c.rng = self.rng
        c.demandNoiseCarry = self.demandNoiseCarry
        c.supplyNoiseCarry = self.supplyNoiseCarry
        c.interventionSupportCarry = self.interventionSupportCarry
        c.controlsReliefCarry = self.controlsReliefCarry
        c.communicationStance = self.communicationStance
        c.activeCabinetRequest = self.activeCabinetRequest
        c.crisisCooldownQuarters = self.crisisCooldownQuarters
        return c
    }

    func isHawkishCommunicationConsistent(state s: EconomicState? = nil) -> Bool {
        let state = s ?? self.state
        return state.policyRate >= state.expectedInflation + 0.01
    }

    private func normalRandom(std: Double) -> Double {
        let u1 = Double.random(in: 0.000001...0.999999, using: &rng)
        let u2 = Double.random(in: 0.000001...0.999999, using: &rng)
        return std * sqrt(-2 * Foundation.log(u1)) * cos(2 * .pi * u2)
    }

    private func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
    private func gapLabel(_ g: Double) -> String { g > 0 ? "above potential" : "below potential" }
}
