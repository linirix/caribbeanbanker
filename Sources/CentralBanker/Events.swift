import Foundation

package enum GameMode: Codable {
    case historical
    case randomized
}

package enum EventType: Codable {
    case oilShock(magnitude: Double)         // magnitude = fractional price increase
    case oilRecovery(magnitude: Double)
    case tradingPartnerRecession(severity: Double)
    case tradingPartnerRecovery
    case speculativeAttack
    case commodityBoom(magnitude: Double)
    case commoditySlump(magnitude: Double)
    case droughtOrDisaster
    case politicalDemand
    case imfReview
    case capitalFlight
    case debtRefinancing
    case tourismBoom
    case tourismCollapse
    case workerStrike
    case creditCrunch
    case foreignAid
}

package struct EconomicEvent {
    package let type: EventType
    package let isScripted: Bool
}

// ─── Historical track ────────────────────────────────────────────────────────
// Scripted events keyed by quarterLabel ("Q4 1973", etc.)

private func scriptedEvents(for gameLength: GameLength) -> [String: [EconomicEvent]] {
    GameConfigs.historicalTrack(for: gameLength).eventsByQuarter()
}

// ─── Shared random event pool ─────────────────────────────────────────────────

// ─── Randomised track: procedural macro-events ───────────────────────────────
// Fired in addition to commonRandomPool. Higher stakes, unpredictable timing.

// Quarter index from the selected timeline start.
private func qIndex(_ state: EconomicState, gameLength: GameLength) -> Int {
    (state.year - gameLength.startYear) * 4 + (state.quarter - 1)
}

// Procedurally schedule macro events at game start.
// Returns a dict of quarterIndex → [EventType] to fire that quarter.
func scheduleMacroEvents(for gameLength: GameLength,
                         using rng: inout SeededRandomGenerator) -> [Int: [EventType]] {
    var schedule: [Int: [EventType]] = [:]
    let randomEvents = GameConfigs.tuning.randomEvents
    let cycleLength = randomEvents.cycleLength
    var cycleStart = 0
    while cycleStart < gameLength.totalQuarters {
        let cycleEnd = min(gameLength.totalQuarters - 1, cycleStart + cycleLength - 1)
        for spec in randomEvents.macroPool {
            let earliest = cycleStart + spec.earliestQuarterIndex
            let latest = min(cycleStart + spec.latestQuarterIndex, cycleEnd)
            guard earliest <= latest else { continue }
            guard Double.random(in: 0...1, using: &rng) < spec.totalProbability else { continue }
            let window = latest - earliest
            let qIdx = earliest + (window > 0 ? Int.random(in: 0...window, using: &rng) : 0)
            schedule[qIdx, default: []].append(spec.event.makeEventType(using: &rng))
        }
        cycleStart += cycleLength
    }
    return schedule
}

// ─── World interest rate ──────────────────────────────────────────────────────

package func worldInterestRate(for state: EconomicState,
                               mode: GameMode,
                               gameLength: GameLength = .short,
                               rateSchedule: [Int: Double]) -> Double {
    switch mode {
    case .historical:
        return GameConfigs.historicalTrack(for: gameLength).worldRate(for: state.year)
            ?? GameConfigs.historicalTrack(for: gameLength).worldRates.last?.rate
            ?? 0.060
    case .randomized:
        return rateSchedule[qIndex(state, gameLength: gameLength)] ?? 0.070
    }
}

// Pre-generate a world interest rate path for a randomised game.
// Starts near 6%, drifts over time with a few jumps.
func scheduleWorldRates(for gameLength: GameLength,
                        using rng: inout SeededRandomGenerator) -> [Int: Double] {
    let config = GameConfigs.tuning.randomizedWorldRates
    var rates: [Int: Double] = [:]
    var rate = config.baseRate
    let totalQuarters = gameLength.totalQuarters
    for q in 0..<totalQuarters {
        // Slow drift upward in the 70s (general global inflation)
        let trend = Double(q) / Double(totalQuarters) * config.trendMax
        // Occasional jumps
        let jump: Double
        if Double.random(in: 0...1, using: &rng) < config.jumpProbability {
            jump = Double.random(in: config.jumpMin...config.jumpMax, using: &rng)
        } else {
            jump = Double.random(in: config.driftMin...config.driftMax, using: &rng)
        }
        rate = max(config.floorRate, min(config.ceilingRate, rate + jump))
        rates[q] = rate + trend
    }
    return rates
}

// ─── Main event generator ─────────────────────────────────────────────────────

func generateEvents(for state: EconomicState,
                    mode: GameMode,
                    gameLength: GameLength = .short,
                    macroSchedule: [Int: [EventType]],
                    using rng: inout SeededRandomGenerator) -> [EconomicEvent] {
    var events: [EconomicEvent] = []

    switch mode {
    case .historical:
        if let scripted = scriptedEvents(for: gameLength)[state.quarterLabel] {
            events.append(contentsOf: scripted)
        }

    case .randomized:
        let qi = qIndex(state, gameLength: gameLength)
        if let macro = macroSchedule[qi] {
            events.append(contentsOf: macro.map { EconomicEvent(type: $0, isScripted: false) })
        }
    }

    // Common random events (at most 2 per quarter)
    var randomCount = 0
    for spec in GameConfigs.tuning.randomEvents.commonPool.shuffled(using: &rng) {
        if randomCount >= 2 { break }
        if let cond = spec.condition, !cond.matches(state) { continue }
        if Double.random(in: 0...1, using: &rng) < spec.probability {
            var localRng = rng
            let eventType = spec.event.makeEventType(using: &localRng)
            rng = localRng
            events.append(EconomicEvent(type: eventType, isScripted: false))
            randomCount += 1
        }
    }

    return events
}

// ─── Preview (dry-run) ───────────────────────────────────────────────────────
// Simulate the next quarter on a *copy* of the simulator so the player can see
// projected outcomes without touching the real state or consuming the RNG
// stream. The copy's world rate is refreshed the same way main.swift does it
// before a real advance, and events are generated from the copy's RNG.
//
// The returned QuarterReport is authoritative for display but throwaway.
// `eventSourceState` lets callers anchor event eligibility to the real,
// pre-hypothetical state so `what_if` compares policy choices under the same
// would-be shock path.
func previewNextQuarter(of simulator: EconomicSimulator,
                        mode: GameMode,
                        gameLength: GameLength = .short,
                        macroSchedule: [Int: [EventType]],
                        rateSchedule: [Int: Double],
                        eventSourceState: EconomicState? = nil) -> QuarterReport {
    let clone = simulator.cloneForPreview()
    clone.environment.worldInterestRate = worldInterestRate(
        for: clone.state, mode: mode, gameLength: gameLength, rateSchedule: rateSchedule)
    let eventState = eventSourceState ?? clone.state
    let events = generateEvents(
        for: eventState, mode: mode, gameLength: gameLength, macroSchedule: macroSchedule, using: &clone.rng)
    return clone.simulateQuarter(events: events)
}

// ─── Event application ───────────────────────────────────────────────────────
// Each event is responsible for its own narrative and state changes. The
// simulator just collects the aggregate impacts (oil-inflation passthrough,
// fiscal deltas) from each event in the quarter's list.

// What an event contributes to the quarter's aggregate shocks. The simulator
// folds these into its main dynamics *after* all events have applied, so that
// later baseline calculations (e.g. the fiscal balance reset) do not wipe out
// event effects.
struct EventImpact {
    var oilImpact: Double = 0.0    // annualised inflation passthrough
    var fiscalDelta: Double = 0.0  // one-off adjustment to fiscal balance / GDP
}

extension EventType {
    // Apply this event to the simulator state and external environment.
    // Appends narrative lines to `news`; draws any randomness from `rng`
    // (a shared, seeded stream). Returns the aggregate impact for the
    // simulator to fold into its quarterly dynamics.
    func apply(to s: inout EconomicState,
               environment env: inout ExternalEnvironment,
               news: inout [String],
               rng: inout SeededRandomGenerator) -> EventImpact {
        var impact = EventImpact()
        switch self {
        case .oilShock(let magnitude):
            let prev = env.oilPriceIndex
            env.oilPriceIndex *= (1 + magnitude)
            let pctRise = (env.oilPriceIndex - prev) / prev
            // Annualised inflation impact: ~7pp per 300% oil spike for an import-dependent island
            impact.oilImpact = 0.030 * pctRise
            // Output gap: oil shock is stagflationary
            s.outputGap -= 0.012 * pctRise
            news.append("OIL SHOCK: Global crude prices surge \(String(format: "%.0f", pctRise*100))%. Energy costs spiking; stagflationary shockwave incoming.")

        case .oilRecovery(let magnitude):
            env.oilPriceIndex *= (1 - magnitude)
            impact.oilImpact = -0.014 * magnitude
            news.append("OIL PRICES EASE: Crude down \(String(format: "%.0f", magnitude*100))%. Energy cost relief supports activity and eases inflation.")

        case .tradingPartnerRecession(let severity):
            env.tradingPartnerGrowth = max(-0.04, env.tradingPartnerGrowth - severity)
            news.append("EXTERNAL DOWNTURN: Key trading partners entering recession. Export orders falling sharply.")

        case .tradingPartnerRecovery:
            env.tradingPartnerGrowth = min(0.06, env.tradingPartnerGrowth + 0.02)
            news.append("GLOBAL RECOVERY: Trading partner growth improving. Export outlook brightening.")

        case .speculativeAttack:
            let openness = 1.0 - s.capitalControls
            let severityScale = 0.45 + 0.55 * openness
            let attack = Double.random(in: 0.5...1.4, using: &rng)
            s.foreignReservesMonths -= attack * severityScale
            s.capitalAccountGDP -= 0.035 * severityScale
            news.append("SPECULATIVE ATTACK: Currency markets under siege. Traders selling SLD. Reserves under pressure.")

        case .commodityBoom(let magnitude):
            env.commodityPriceIndex *= (1 + magnitude)
            s.currentAccountGDP += 0.015 * magnitude * 10
            env.termsOfTrade *= (1 + magnitude * 0.6)
            news.append("COMMODITY BOOM: Export prices surging. Terms of trade improving; current account relief.")

        case .commoditySlump(let magnitude):
            env.commodityPriceIndex *= (1 - magnitude)
            s.currentAccountGDP -= 0.012 * magnitude * 10
            env.termsOfTrade *= (1 - magnitude * 0.5)
            news.append("COMMODITY SLUMP: Export commodity prices falling. Current account deteriorating.")

        case .droughtOrDisaster:
            s.outputGap -= 0.014
            impact.oilImpact += 0.020
            news.append("AGRICULTURAL CRISIS: Severe drought devastating crops. Food prices surging; output impacted.")

        case .politicalDemand:
            s.politicalPressure = min(100, s.politicalPressure + 28)
            news.append("POLITICAL PRESSURE: Cabinet demands immediate rate cuts. Prime Minister warns of electoral consequences.")

        case .imfReview:
            var imfMsg = "IMF ARTICLE IV: Fund delegation in Nassau conducting annual review."
            if s.foreignReservesMonths < 3.0 {
                imfMsg += " Mission expresses alarm over reserve adequacy."
            }
            if s.inflation > 0.15 {
                imfMsg += " Fund urges decisive disinflation."
            }
            if s.currentAccountGDP < -0.06 {
                imfMsg += " External imbalances flagged as unsustainable."
            }
            news.append(imfMsg)

        case .capitalFlight:
            if s.capitalControls < 0.75 {
                let openness = 1.0 - s.capitalControls
                let severityScale = 0.35 + 0.65 * openness
                s.capitalAccountGDP -= 0.035 * severityScale
                s.foreignReservesMonths -= 0.45 * severityScale
                news.append("CAPITAL FLIGHT: Investors moving assets offshore. Capital account pressure intensifying.")
            } else {
                news.append("CAPITAL CONTROLS HOLDING: Flight pressure emerging but controls limiting outflows for now.")
            }

        case .debtRefinancing:
            let extraCost = max(0, env.worldInterestRate - 0.055) * s.externalDebtGDP
            impact.fiscalDelta -= extraCost * 0.40
            news.append("DEBT MARKETS: External debt rollovers at elevated world rates. Debt service burden rising.")

        case .tourismBoom:
            s.currentAccountGDP += 0.010
            s.outputGap += 0.005
            news.append("TOURISM BOOM: Record visitor arrivals. Services exports surging; domestic demand boosted.")

        case .tourismCollapse:
            s.currentAccountGDP -= 0.014
            s.outputGap -= 0.008
            news.append("TOURISM COLLAPSE: International travel disrupted. Visitor arrivals plunging; hotels emptying.")

        case .workerStrike:
            s.outputGap -= 0.012
            impact.oilImpact += 0.012
            news.append("GENERAL STRIKE: Labour unrest paralyses key sectors. Output and distribution disrupted.")

        case .creditCrunch:
            s.bankCreditGrowth -= 0.05
            s.outputGap -= 0.007
            news.append("CREDIT CRUNCH: Banks tightening lending standards sharply. Credit to private sector contracting.")

        case .foreignAid:
            s.foreignReservesMonths += 0.8
            impact.fiscalDelta += 0.008
            news.append("FOREIGN AID: Multilateral aid package approved. Balance of payments relief secured.")
        }
        return impact
    }
}
