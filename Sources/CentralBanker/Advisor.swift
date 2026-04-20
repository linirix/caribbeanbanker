import Foundation

enum AdvisorTopic: CaseIterable {
    case general
    case inflation
    case growth
    case currency
    case reserves
    case balanceOfPayments
    case debt
    case credibility
    case approval
    case crisis

    var title: String {
        switch self {
        case .general: return "General Triage"
        case .inflation: return "Inflation Control"
        case .growth: return "Growth and Employment"
        case .currency: return "Currency Defense"
        case .reserves: return "Reserve Rebuilding"
        case .balanceOfPayments: return "Balance of Payments"
        case .debt: return "External Debt"
        case .credibility: return "Credibility"
        case .approval: return "Politics and Approval"
        case .crisis: return "Crisis Management"
        }
    }

    var aliases: [String] {
        switch self {
        case .general:
            return ["general", "triage", "overview", "urgent", "priority"]
        case .inflation:
            return ["inflation", "prices", "cpi", "disinflation"]
        case .growth:
            return ["growth", "recession", "output", "jobs", "employment", "unemployment"]
        case .currency:
            return ["currency", "fx", "exchange", "exchange rate", "devaluation"]
        case .reserves:
            return ["reserves", "reserve", "fx reserves", "buffers"]
        case .balanceOfPayments:
            return ["balance of payments", "bop", "current account", "capital account", "external balance"]
        case .debt:
            return ["debt", "external debt", "debt burden"]
        case .credibility:
            return ["credibility", "trust", "confidence"]
        case .approval:
            return ["approval", "politics", "political pressure", "cabinet"]
        case .crisis:
            return ["crisis", "emergency", "panic"]
        }
    }

    static func parse(_ raw: String?) -> AdvisorTopic? {
        guard let raw else { return .general }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return .general }

        for topic in Self.allCases {
            if topic.aliases.contains(normalized) {
                return topic
            }
        }

        if normalized.contains("balance") || normalized.contains("bop") {
            return .balanceOfPayments
        }
        if normalized.contains("curr") || normalized.contains("fx") || normalized.contains("exchange") {
            return .currency
        }
        if normalized.contains("reserve") {
            return .reserves
        }
        if normalized.contains("debt") {
            return .debt
        }
        if normalized.contains("infl") || normalized.contains("price") {
            return .inflation
        }
        if normalized.contains("growth") || normalized.contains("recession")
            || normalized.contains("job") || normalized.contains("unemploy") {
            return .growth
        }
        if normalized.contains("credib") || normalized.contains("trust") {
            return .credibility
        }
        if normalized.contains("approval") || normalized.contains("polit") || normalized.contains("cabinet") {
            return .approval
        }
        if normalized.contains("crisis") || normalized.contains("panic") || normalized.contains("emerg") {
            return .crisis
        }
        return nil
    }
}

struct AdvisorBrief {
    let requestedTopic: AdvisorTopic
    let requestedTopicRecognized: Bool
    let requestedTopicText: String?
    let urgentTopic: AdvisorTopic
    let urgentHeadline: String
    let urgentDetail: String
    let rateHeadline: String
    let rateDetail: String
    let focusTitle: String
    let recommendations: [String]
    let watchItems: [String]
}

func advisorBrief(for simulator: EconomicSimulator, topicText: String?) -> AdvisorBrief {
    let requested = AdvisorTopic.parse(topicText)
    let effectiveTopic = requested ?? .general
    let urgentTopic = mostUrgentAdvisorTopic(for: simulator)
    let urgentMessage = advisorUrgencyMessage(for: simulator, topic: urgentTopic)
    let rateGuidance = advisorRateGuidance(for: simulator)
    let focusTopic = effectiveTopic == .general ? urgentTopic : effectiveTopic
    let focusPlan = advisorRecommendations(for: simulator, topic: focusTopic)

    return AdvisorBrief(
        requestedTopic: effectiveTopic,
        requestedTopicRecognized: requested != nil,
        requestedTopicText: topicText,
        urgentTopic: urgentTopic,
        urgentHeadline: urgentMessage.headline,
        urgentDetail: urgentMessage.detail,
        rateHeadline: rateGuidance.headline,
        rateDetail: rateGuidance.detail,
        focusTitle: focusTopic.title,
        recommendations: focusPlan.recommendations,
        watchItems: focusPlan.watchItems
    )
}

private func mostUrgentAdvisorTopic(for simulator: EconomicSimulator) -> AdvisorTopic {
    let s = simulator.state
    let crisisMeasures = simulator.availableCrisisMeasures()

    if !crisisMeasures.isEmpty || s.foreignReservesMonths < 1.4 || s.exchangeRateQoQChange > 0.055 {
        return .currency
    }
    if s.inflation > 0.09 || s.expectedInflation > 0.08 || (s.credibility < 0.45 && s.inflation > 0.07) {
        return .inflation
    }
    if s.externalDebtGDP > 0.58 && s.currentAccountGDP < -0.03 {
        return .debt
    }
    if s.unemployment > 0.10 || s.annualizedGDPGrowth < -0.01 || s.outputGap < -0.025 {
        return .growth
    }
    if s.politicalPressure > 70 || s.publicApproval < 35 {
        return .approval
    }
    if s.foreignReservesMonths < 2.5 {
        return .reserves
    }
    if s.currentAccountGDP < -0.035 || s.capitalAccountGDP < -0.01 {
        return .balanceOfPayments
    }
    return .credibility
}

private func advisorUrgencyMessage(for simulator: EconomicSimulator,
                                   topic: AdvisorTopic) -> (headline: String, detail: String) {
    let s = simulator.state
    switch topic {
    case .currency:
        return (
            "External stability is the urgent problem.",
            String(format: "Reserves are at %.1f months and the currency just moved %+.1f%% q/q. If you lose the external flank, every other objective becomes secondary.",
                   s.foreignReservesMonths,
                   s.exchangeRateQoQChange * 100)
        )
    case .inflation:
        return (
            "Inflation control is the urgent problem.",
            String(format: "CPI is %.1f%% with expected inflation at %.1f%%. If expectations settle this high, later stabilization gets more painful.",
                   s.inflation * 100,
                   s.expectedInflation * 100)
        )
    case .growth:
        return (
            "Activity and employment need attention.",
            String(format: "Growth is running at %+.1f%% annualized with unemployment at %.1f%%. The economy is weak enough that inaction can harden into a deeper slump.",
                   s.annualizedGDPGrowth * 100,
                   s.unemployment * 100)
        )
    case .debt:
        return (
            "External debt is boxing policy in.",
            String(format: "External debt is %.1f%% of GDP and the current account is %+.1f%% of GDP. You need adjustment that lasts, not quarter-by-quarter improvisation.",
                   s.externalDebtGDP * 100,
                   s.currentAccountGDP * 100)
        )
    case .approval:
        return (
            "Political runway is becoming scarce.",
            String(format: "Political pressure is %.0f and approval is %.0f. Even correct policy can fail if you let the politics outrun the economics.",
                   s.politicalPressure,
                   s.publicApproval)
        )
    case .reserves:
        return (
            "Reserve rebuilding should be your next priority.",
            String(format: "At %.1f months of imports, you still have some buffer, but not much. Use calm quarters to rebuild it before markets choose the timing for you.",
                   s.foreignReservesMonths)
        )
    case .balanceOfPayments:
        return (
            "The balance of payments is still too weak.",
            String(format: "Current account: %+.1f%% GDP. Capital account: %+.1f%% GDP. You need either better external earnings, lower import demand, or less flight — preferably all three over time.",
                   s.currentAccountGDP * 100,
                   s.capitalAccountGDP * 100)
        )
    case .credibility:
        return (
            "Credibility is the key stabilizer to protect.",
            String(format: "Credibility is at %.0f%%. If markets and households stop believing you, every lever becomes more expensive to use.",
                   s.credibility * 100)
        )
    case .crisis:
        return (
            "Emergency tools are a last resort, not a plan.",
            "Check whether the current problem is a liquidity panic, a run, or a financing hole. Pick the tool that matches the diagnosis instead of reaching for the biggest hammer."
        )
    case .general:
        return (
            "No single channel is screaming yet.",
            "That usually means this is the right time to fix weak trends before they become a crisis."
        )
    }
}

private func advisorRateGuidance(for simulator: EconomicSimulator) -> (headline: String, detail: String) {
    let s = simulator.state
    let neutralNominal = max(0.04, s.expectedInflation) + simulator.params.outputGap.neutralRealRate
    let inflationGap = s.inflation - 0.04
    var center = neutralNominal
        + 0.90 * inflationGap
        + 0.35 * s.outputGap

    if s.foreignReservesMonths < 2.0 && s.exchangeRateQoQChange > 0.03 {
        center += 0.015
    }
    if s.unemployment > 0.10 && s.inflation < 0.06 {
        center -= 0.012
    }

    center = min(0.25, max(0.0, center))

    let width = min(0.02, 0.0075
        + (s.foreignReservesMonths < 2.0 ? 0.005 : 0.0)
        + (abs(s.outputGap) > 0.03 ? 0.003 : 0.0))
    let lower = max(0.0, center - width)
    let upper = min(0.25, center + width)

    let headline: String
    if center > s.policyRate + 0.0075 {
        headline = "Rate bias: tighten."
    } else if center < s.policyRate - 0.0075 {
        headline = "Rate bias: ease."
    } else {
        headline = "Rate bias: hold near current."
    }

    let detail = String(
        format: "Indicative policy-rate range: %.1f–%.1f%%. Current rate: %.1f%%. This is a staff heuristic based on inflation, activity, expectations, and external stress — not a perfect forecast.",
        lower * 100,
        upper * 100,
        s.policyRate * 100
    )

    return (headline, detail)
}

private func advisorRecommendations(for simulator: EconomicSimulator,
                                    topic: AdvisorTopic) -> (recommendations: [String], watchItems: [String]) {
    let s = simulator.state
    let crisisMeasures = simulator.availableCrisisMeasures().map(\.type.commandName)
    let controlTarget = min(10, max(Int((s.capitalControls * 10).rounded()) + 2, 4))

    switch topic {
    case .inflation:
        return (
            [
                "Raise `rate` if it is still below the advisor's indicative range; inflation and expectations are the main targets here.",
                "Use `comm hawkish` only if your policy stance is actually tight enough to make that message believable.",
                "If credit is still running hot, raise `reserve` modestly rather than trying to do everything with one shock move."
            ],
            [
                "Do not ignore the exchange rate. Currency weakness will feed back into prices through import costs.",
                "If unemployment is already high, expect a political cost and use the cabinet/crisis tools sparingly."
            ]
        )
    case .growth:
        return (
            [
                "If inflation and reserves allow it, lower `rate` toward the advisor's range instead of leaving policy stuck at crisis settings.",
                "Use `comm balanced` or `comm dovish` only when the inflation backdrop is calm enough that easing will be believed as support, not surrender.",
                crisisMeasures.contains("liquidity")
                    ? "If recession stress is severe, `measure liquidity` is available and is the cleanest emergency support tool."
                    : "If recession stress worsens further, watch for `measure liquidity` to unlock."
            ],
            [
                "Do not ease blindly into a currency scare. If reserves are sliding, solve the external problem first.",
                "A small improvement in growth is not enough if unemployment remains politically toxic."
            ]
        )
    case .currency:
        return (
            [
                "Raise `rate` toward the advisor's range if the currency is sliding and credibility is thin.",
                "Tighten `controls` toward roughly \(controlTarget)/10 if capital flight is the main pressure channel.",
                "Use `intervene -0.5` or similar only to smooth panic. Do not spend reserves defending an obviously inconsistent stance.",
                crisisMeasures.isEmpty
                    ? "If pressure becomes acute, keep an eye on `crisis`; the relevant emergency tool will unlock under severe stress."
                    : "Emergency tools now available: `measure " + crisisMeasures.joined(separator: "|") + "`."
            ],
            [
                "The external side is about reserves as much as the spot exchange rate. A temporarily stronger SLD is not success if reserves vanish.",
                "Communication helps only if markets can see matching policy."
            ]
        )
    case .reserves:
        return (
            [
                "Favor policies that reduce reserve drain: tighter `controls`, less defensive intervention, and a stance that slows outflows.",
                "If market conditions calm, a small positive `intervene +x` buys reserves and weakens SLD, which can support external adjustment.",
                "Use calmer quarters to rebuild buffers instead of celebrating too early."
            ],
            [
                "Do not let reserve rebuilding come entirely from panic controls; that can solve one quarter and weaken the next.",
                "Watch the capital account. If it stays negative, reserve gains will not last."
            ]
        )
    case .balanceOfPayments:
        return (
            [
                "To improve the current account, you usually need softer domestic demand and a less overvalued currency.",
                "To improve the capital account, use enough `rate` and `controls` to stop obvious flight.",
                "Think of the balance of payments as current account plus capital account plus reserves. If both flow accounts are weak, one-quarter intervention will not solve it."
            ],
            [
                "A better capital account can buy time, but a persistently weak current account keeps external debt pressure alive.",
                "The balance of payments improves over several quarters, not one."
            ]
        )
    case .debt:
        return (
            [
                "The durable way to lower external debt is to improve the current account over time and avoid repeated external rescues.",
                "A slightly weaker currency, tighter demand, and fewer financing shocks will do more than dramatic one-quarter reserve defense.",
                "If financing is already critical, use crisis tools to buy time — then spend that time improving the external balance."
            ],
            [
                "Spending reserves alone does not repay debt.",
                "Repeated IMF reliance may prevent collapse, but it can keep debt and politics stuck in a bad equilibrium."
            ]
        )
    case .credibility:
        return (
            [
                "Align `comm` with actual policy. Hawkish talk with loose policy is worse than a plain, balanced message.",
                "Contain inflation surprises. That is still the fastest route back to credibility.",
                "Avoid unnecessary reversals and visible panic unless conditions truly force them."
            ],
            [
                "Credibility compounds: once damaged, later stabilization requires more rate pain and buys less political trust.",
                "Capital controls and emergency measures may be necessary, but they are not free in credibility terms."
            ]
        )
    case .approval:
        return (
            [
                "If inflation is no longer the urgent problem, modest easing can buy political runway.",
                "Use `cabinet`, `accept`, `reject`, and `delay` deliberately. Sometimes the political problem is not the demand itself, but the appearance of indifference.",
                "A calm, believable communication stance often buys more approval than a dramatic but inconsistent gesture."
            ],
            [
                "Do not chase approval so hard that you relight inflation or trigger a reserve scare.",
                "Political pressure is easier to manage when the economy looks boring."
            ]
        )
    case .crisis:
        return (
            [
                crisisMeasures.contains("holiday")
                    ? "`measure holiday` is for acute run dynamics and panic containment."
                    : "`measure holiday` is the run-stopper when panic becomes acute.",
                crisisMeasures.contains("liquidity")
                    ? "`measure liquidity` is for recessionary or credit-crunch stress."
                    : "`measure liquidity` is the recession-support tool when it unlocks.",
                crisisMeasures.contains("imf")
                    ? "`measure imf` is the last-resort external financing tool."
                    : "`measure imf` is the last-resort external financing tool when reserves become critically scarce."
            ],
            [
                "Pick the emergency tool that matches the diagnosis. Using the wrong one can buy a quarter and worsen the next.",
                "Crisis tools are bridges, not strategies."
            ]
        )
    case .general:
        let urgent = mostUrgentAdvisorTopic(for: simulator)
        return advisorRecommendations(for: simulator, topic: urgent == .general ? .credibility : urgent)
    }
}
