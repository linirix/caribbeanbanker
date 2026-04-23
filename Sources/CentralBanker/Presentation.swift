import Foundation

package enum SeverityLevel {
    case good
    case warning
    case danger
    case neutral
}

package enum TrendDirection {
    case up
    case down
    case flat
}

package enum ActionAvailability {
    case available
    case recommended
    case dormant
    case locked
    case cooldown
}

package enum ActionGroup: String, CaseIterable {
    case policy
    case next
    case cabinet
    case crisis
    case info
    case files

    var title: String {
        switch self {
        case .policy: return "POLICY"
        case .next: return "NEXT"
        case .cabinet: return "CABINET"
        case .crisis: return "CRISIS"
        case .info: return "INFO"
        case .files: return "FILES"
        }
    }
}

package enum MetricDisplayStyle {
    case plain
    case bar(maxValue: Double)
}

package struct ActionDescriptor {
    package let id: String
    package let label: String
    package let argumentHint: String?
    package let availability: ActionAvailability
    package let reasonIfUnavailable: String?
    package let group: ActionGroup
}

package struct MetricDescriptor {
    package let id: String
    package let label: String
    package let primaryValue: String
    package let deltaText: String?
    package let trend: TrendDirection?
    package let severity: SeverityLevel
    package let note: String?
    package let numericValue: Double?
    package let displayStyle: MetricDisplayStyle
}

package struct InfoSection {
    package let heading: String
    package let rows: [String]
    package let bullets: [String]
    package let emphasis: String?

    package init(heading: String, rows: [String] = [], bullets: [String] = [], emphasis: String? = nil) {
        self.heading = heading
        self.rows = rows
        self.bullets = bullets
        self.emphasis = emphasis
    }
}

package struct GamePresentationSnapshot {
    package let campaignTitle: String
    package let campaignRange: String
    package let quarterLabel: String
    package let difficultyLabel: String
    package let scenarioTitle: String?
    package let scenarioSummary: String?
    package let totalCampaignQuarters: Int
}

package struct MetricRowDescriptor {
    package let left: MetricDescriptor?
    package let right: MetricDescriptor?
}

package struct DashboardMetricSection {
    package let leftHeading: String
    package let rightHeading: String
    package let rows: [MetricRowDescriptor]
}

package struct ActionSectionDescriptor {
    package let group: ActionGroup
    package let title: String
    package let actions: [ActionDescriptor]
}

package struct DashboardSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let subtitle: String
    package let metricSections: [DashboardMetricSection]
    package let advisorySections: [InfoSection]
    package let recentNews: [String]
    package let actionSections: [ActionSectionDescriptor]
    package let footerLegend: String
}

package struct ComparisonDescriptor {
    package let id: String
    package let label: String
    package let beforeValue: String
    package let afterValue: String
    package let deltaText: String
    package let severity: SeverityLevel
    package let note: String?
}

package struct PreviewSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let subtitle: String
    package let headerNote: String?
    package let explanation: String
    package let eventHeadlines: [String]
    package let projections: [ComparisonDescriptor]
    package let analysisSections: [InfoSection]
    package let footerNote: String
}

package struct AdvisorSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let requestedFocusLine: String?
    package let urgentSection: InfoSection
    package let rateSection: InfoSection
    package let recommendationSection: InfoSection
    package let watchSection: InfoSection
    package let topicSuggestions: [String]
}

package struct ScenarioGoalDescriptor {
    package let description: String
    package let met: Bool
}

package struct ScenarioAssessmentSnapshot {
    package let heading: String
    package let severity: SeverityLevel
    package let overview: String
    package let focus: [String]
    package let missedObjectives: [String]
}

package struct RecentQuarterSnapshot {
    package let quarterLabel: String
    package let inflation: String
    package let growth: String
    package let unemployment: String
    package let reserves: String
    package let rate: String
    package let pressure: String
}

package struct ReportSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let summarySection: InfoSection
    package let averages: [MetricDescriptor]
    package let extremes: [MetricDescriptor]
    package let recentQuarters: [RecentQuarterSnapshot]
    package let scenarioGoals: [ScenarioGoalDescriptor]
    package let scenarioAssessment: ScenarioAssessmentSnapshot?
}

package struct DebriefSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let summaryRows: [String]
    package let mainMoves: [MetricDescriptor]
    package let analysisSections: [InfoSection]
    package let interpretations: [String]
    package let headlines: [String]
}

package struct TutorialSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let stageTitle: String
    package let focus: [String]
    package let experiments: [String]
    package let success: [String]
    package let scenarioGoals: [ScenarioGoalDescriptor]
    package let companionActions: [ActionDescriptor]
}

package struct ScenarioBriefingSnapshot {
    package let title: String
    package let rangeLabel: String
    package let briefing: String
    package let teachingFocus: [String]
    package let objectives: [String]
}

package struct HistoryChartSnapshot {
    package let label: String
    package let values: [Double]
    package let scale: Double
    package let latestValue: String
    package let goodRange: Range<Double>
    package let warningRange: Range<Double>
    package let positiveThreshold: Double?
}

package struct HistorySnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let charts: [HistoryChartSnapshot]
    package let recentQuarters: [RecentQuarterSnapshot]
    package let emptyState: String?
}

package struct NewsSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let entries: [String]
    package let emptyState: String?
}

package struct HelpCommandDescriptor {
    package let command: String
    package let details: [String]
}

package struct HelpSectionSnapshot {
    package let heading: String
    package let commands: [HelpCommandDescriptor]
    package let paragraphs: [String]
}

package struct HelpSnapshot {
    package let title: String
    package let subtitle: String
    package let sections: [HelpSectionSnapshot]
}

package struct CrisisOptionsSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let summaryRows: [String]
    package let measures: [CrisisMeasure]
}

package struct StatusSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let sections: [InfoSection]
}

package struct GameOverSnapshot {
    package let context: GamePresentationSnapshot
    package let title: String
    package let introduction: [String]
    package let finalStateSection: InfoSection
    package let scenarioGoals: [ScenarioGoalDescriptor]
    package let scenarioAssessment: ScenarioAssessmentSnapshot?
    package let reviewSection: InfoSection
    package let failureDiagnosisSection: InfoSection?
    package let scoreSection: InfoSection
}

extension GameSession {
    package func makePresentationSnapshot() -> GamePresentationSnapshot {
        GamePresentationSnapshot(
            campaignTitle: campaignTitle,
            campaignRange: campaignRange,
            quarterLabel: simulator.state.quarterLabel,
            difficultyLabel: difficulty.displayName,
            scenarioTitle: scenario?.title,
            scenarioSummary: scenario?.summary,
            totalCampaignQuarters: totalCampaignQuarters
        )
    }

    package func makeDashboardSnapshot() -> DashboardSnapshot {
        buildDashboardSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot()
        )
    }

    package func makePreviewSnapshot(changes: [PolicyChange]) -> PreviewSnapshot {
        let preview = preview(changes: changes)
        return buildPreviewSnapshot(
            estimate: preview.estimate,
            context: makePresentationSnapshot(),
            headerNote: preview.note,
            baselineEstimate: pendingPreviewReview?.baselineEstimate,
            params: simulator.params
        )
    }

    package func makeAdvisorSnapshot(topic: String? = nil) -> AdvisorSnapshot {
        buildAdvisorSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot(),
            topicText: topic
        )
    }

    package func makeReportSnapshot() -> ReportSnapshot {
        buildReportSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot(),
            difficulty: difficulty,
            gameLength: gameLength,
            scenarioID: scenarioID
        )
    }

    package func makeDebriefSnapshot() -> DebriefSnapshot {
        buildDebriefSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot(),
            report: lastQuarterReport,
            forecastReview: lastForecastReview
        )
    }

    package func makeTutorialSnapshot() -> TutorialSnapshot {
        buildTutorialSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot(),
            mode: mode,
            gameLength: gameLength,
            scenarioID: scenarioID
        )
    }

    package func makeScenarioBriefingSnapshot() -> ScenarioBriefingSnapshot? {
        guard let scenario else { return nil }
        return buildScenarioBriefingSnapshot(scenario: scenario)
    }

    package func makeHistorySnapshot() -> HistorySnapshot {
        buildHistorySnapshot(
            simulator: simulator,
            context: makePresentationSnapshot()
        )
    }

    package func makeNewsSnapshot() -> NewsSnapshot {
        buildNewsSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot()
        )
    }

    package func makeCrisisOptionsSnapshot() -> CrisisOptionsSnapshot {
        buildCrisisOptionsSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot()
        )
    }

    package func makeStatusSnapshot() -> StatusSnapshot {
        buildStatusSnapshot(
            simulator: simulator,
            context: makePresentationSnapshot(),
            gameLength: gameLength,
            scenarioID: scenarioID
        )
    }

    package func makeGameOverSnapshot(outcome: GameOutcome) -> GameOverSnapshot {
        buildGameOverSnapshot(
            outcome: outcome,
            simulator: simulator,
            context: makePresentationSnapshot(),
            difficulty: difficulty,
            gameLength: gameLength,
            scenarioID: scenarioID
        )
    }
}

package func makeDashboardSnapshot(simulator: EconomicSimulator,
                                   gameLength: GameLength = .short,
                                   scenarioID: String? = nil) -> DashboardSnapshot {
    buildDashboardSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID)
    )
}

package func makePreviewSnapshot(estimate: ForecastEstimate,
                                 gameLength: GameLength = .short,
                                 scenarioID: String? = nil,
                                 headerNote: String? = nil,
                                 baselineEstimate: ForecastEstimate? = nil) -> PreviewSnapshot {
    buildPreviewSnapshot(
        estimate: estimate,
        context: makePresentationContext(simulator: nil, gameLength: gameLength, scenarioID: scenarioID, quarterLabel: estimate.estimatedAfter.quarterLabel),
        headerNote: headerNote,
        baselineEstimate: baselineEstimate,
        params: .default
    )
}

package func makeAdvisorSnapshot(simulator: EconomicSimulator,
                                 topicText: String? = nil,
                                 gameLength: GameLength = .short,
                                 scenarioID: String? = nil) -> AdvisorSnapshot {
    buildAdvisorSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        topicText: topicText
    )
}

package func makeReportSnapshot(simulator: EconomicSimulator,
                                gameLength: GameLength,
                                scenarioID: String? = nil) -> ReportSnapshot {
    buildReportSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        gameLength: gameLength,
        scenarioID: scenarioID
    )
}

package func makeDebriefSnapshot(simulator: EconomicSimulator,
                                 gameLength: GameLength = .short,
                                 scenarioID: String? = nil) -> DebriefSnapshot {
    buildDebriefSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        report: nil,
        forecastReview: nil
    )
}

package func makeTutorialSnapshot(simulator: EconomicSimulator,
                                  mode: GameMode,
                                  gameLength: GameLength,
                                  scenarioID: String? = nil) -> TutorialSnapshot {
    buildTutorialSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        mode: mode,
        gameLength: gameLength,
        scenarioID: scenarioID
    )
}

package func makeScenarioBriefingSnapshot(scenario: ScenarioDefinition) -> ScenarioBriefingSnapshot {
    buildScenarioBriefingSnapshot(scenario: scenario)
}

private func buildScenarioBriefingSnapshot(scenario: ScenarioDefinition) -> ScenarioBriefingSnapshot {
    ScenarioBriefingSnapshot(
        title: scenario.title,
        rangeLabel: scenario.rangeLabel,
        briefing: scenario.briefing,
        teachingFocus: scenario.teachingFocus,
        objectives: scenario.goals.map(\.description)
    )
}

package func makeHistorySnapshot(simulator: EconomicSimulator,
                                 gameLength: GameLength = .short,
                                 scenarioID: String? = nil) -> HistorySnapshot {
    buildHistorySnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID)
    )
}

package func makeNewsSnapshot(simulator: EconomicSimulator,
                              gameLength: GameLength = .short,
                              scenarioID: String? = nil) -> NewsSnapshot {
    buildNewsSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID)
    )
}

package func makeCrisisOptionsSnapshot(simulator: EconomicSimulator,
                                       gameLength: GameLength = .short,
                                       scenarioID: String? = nil) -> CrisisOptionsSnapshot {
    buildCrisisOptionsSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID)
    )
}

package func makeStatusSnapshot(simulator: EconomicSimulator,
                                gameLength: GameLength,
                                scenarioID: String? = nil) -> StatusSnapshot {
    buildStatusSnapshot(
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        gameLength: gameLength,
        scenarioID: scenarioID
    )
}

package func makeGameOverSnapshot(outcome: GameOutcome,
                                  simulator: EconomicSimulator,
                                  gameLength: GameLength,
                                  scenarioID: String? = nil) -> GameOverSnapshot {
    buildGameOverSnapshot(
        outcome: outcome,
        simulator: simulator,
        context: makePresentationContext(simulator: simulator, gameLength: gameLength, scenarioID: scenarioID),
        gameLength: gameLength,
        scenarioID: scenarioID
    )
}

package func makeHelpSnapshot(gameLength: GameLength,
                              scenarioID: String? = nil) -> HelpSnapshot {
    let scenarioNote = scenarioID.flatMap { scenarioDefinition(id: $0) }.map { scenario in
        "Current scenario: \(scenario.title). Its objectives override generic survival instincts."
    }

    return HelpSnapshot(
        title: "HELP & REFERENCE",
        subtitle: "Commands, metric definitions, and strategy notes.",
        sections: [
            HelpSectionSnapshot(
                heading: "CORE COMMANDS",
                commands: [
                    HelpCommandDescriptor(command: "rate <value>", details: [
                        "Set the policy or discount rate. Example: rate 8.5 sets the rate to 8.5%."
                    ]),
                    HelpCommandDescriptor(command: "reserve <value>", details: [
                        "Set the reserve requirement. Example: reserve 15 sets the requirement to 15%."
                    ]),
                    HelpCommandDescriptor(command: "controls <0-10>", details: [
                        "Set the capital-control level. 0 means mostly open; 10 means near-total closure."
                    ]),
                    HelpCommandDescriptor(command: "intervene <±value>", details: [
                        "FX intervention in months of reserves.",
                        "Positive means buy reserves and weaken SLD.",
                        "Negative means spend reserves to defend SLD."
                    ]),
                    HelpCommandDescriptor(command: "comm <stance>", details: [
                        "Set the communication stance until you change it.",
                        "Available stances: hawkish, balanced, dovish, opaque."
                    ]),
                    HelpCommandDescriptor(command: "advance", details: [
                        "Advance one quarter and run the simulation. Aliases: next, n."
                    ]),
                    HelpCommandDescriptor(command: "preview", details: [
                        "Dry-run the next quarter under current policy.",
                        "You can also test hypothetical overrides, for example:",
                        "preview rate 12.5",
                        "preview reserve 15 controls 6",
                        "No state changes. Forecasts are informative, not exact."
                    ])
                ],
                paragraphs: []
            ),
            HelpSectionSnapshot(
                heading: "POLITICS & CRISIS",
                commands: [
                    HelpCommandDescriptor(command: "cabinet", details: [
                        "Show the active cabinet demand for this quarter."
                    ]),
                    HelpCommandDescriptor(command: "accept / reject / delay", details: [
                        "Respond to the current cabinet demand."
                    ]),
                    HelpCommandDescriptor(command: "crisis", details: [
                        "Show emergency measures unlocked by severe stress."
                    ]),
                    HelpCommandDescriptor(command: "measure <name>", details: [
                        "Use an emergency tool when available.",
                        "Available names: imf, holiday, liquidity."
                    ])
                ],
                paragraphs: []
            ),
            HelpSectionSnapshot(
                heading: "INFORMATION & FILES",
                commands: [
                    HelpCommandDescriptor(command: "status", details: [
                        "Show the extended economic report."
                    ]),
                    HelpCommandDescriptor(command: "history", details: [
                        "Show whole-run trend charts plus a recent-quarter table."
                    ]),
                    HelpCommandDescriptor(command: "news", details: [
                        "Show the full retained news log for the run."
                    ]),
                    HelpCommandDescriptor(command: "report", details: [
                        "Show a campaign summary with averages and extremes."
                    ]),
                    HelpCommandDescriptor(command: "why", details: [
                        "Show a plain-language debrief of the last completed quarter.",
                        "Useful when you know what moved but not why it moved."
                    ]),
                    HelpCommandDescriptor(command: "advisor [topic]", details: [
                        "Show staff advice on the most urgent current problem, plus lever suggestions.",
                        "You can also ask for a focus explicitly, for example: advisor currency, advisor inflation, advisor debt, advisor growth, or advisor balance of payments."
                    ]),
                    HelpCommandDescriptor(command: "tutorial", details: [
                        "Show a guided opening briefing with concrete advice for the current stage of the run."
                    ]),
                    HelpCommandDescriptor(command: "save [path]", details: [
                        "Save the current session. Default path: ./solaverde.save.json."
                    ]),
                    HelpCommandDescriptor(command: "load [path]", details: [
                        "Load a saved session. Default path: ./solaverde.save.json."
                    ]),
                    HelpCommandDescriptor(command: "help / quit", details: [
                        "Show this screen or exit the game."
                    ])
                ],
                paragraphs: [
                    "CLI flags: --seed <uint64>, --mode <h|r>, --length <s|e>, and --difficulty <a|g|v> skip the startup menus."
                ]
            ),
            HelpSectionSnapshot(
                heading: "WHAT THE MAIN METRICS MEAN",
                commands: [
                    HelpCommandDescriptor(command: "Inflation / Exp. Inflation", details: [
                        "Current price growth, and what households and firms expect next.",
                        "Once expectations rise, inflation gets harder to bring down."
                    ]),
                    HelpCommandDescriptor(command: "Output Gap / GDP Growth", details: [
                        "How hot or weak the economy is relative to trend.",
                        "A negative gap means slack and recession pressure."
                    ]),
                    HelpCommandDescriptor(command: "Current Account", details: [
                        "Trade, services, and income flow with the rest of the world.",
                        "Negative means the country is spending more abroad than it earns.",
                        "Persistent deficits build external debt."
                    ]),
                    HelpCommandDescriptor(command: "Capital Account", details: [
                        "Net private money moving in or out.",
                        "Positive means inflows and easier external financing.",
                        "Negative means capital flight or weak investor appetite."
                    ]),
                    HelpCommandDescriptor(command: "FX Reserves", details: [
                        "Months of imports the central bank can cover with foreign currency.",
                        "This is your main crisis buffer."
                    ]),
                    HelpCommandDescriptor(command: "Exchange Rate", details: [
                        "Displayed as USD per SLD.",
                        "A higher number means a stronger Solan Dollar.",
                        "A lower number means a weaker Solan Dollar."
                    ]),
                    HelpCommandDescriptor(command: "External Debt", details: [
                        "Stock of obligations owed abroad.",
                        "In this model it rises mainly when current-account deficits persist and falls only through sustained surpluses."
                    ]),
                    HelpCommandDescriptor(command: "Credibility", details: [
                        "How much markets and households believe the central bank will do what it says.",
                        "Higher credibility makes inflation easier to control."
                    ]),
                    HelpCommandDescriptor(command: "Political Pressure / Approval", details: [
                        "Your political runway.",
                        "High pressure or low approval means correct policy can still get you removed."
                    ])
                ],
                paragraphs: []
            ),
            HelpSectionSnapshot(
                heading: "HOW TO MOVE THEM",
                commands: [
                    HelpCommandDescriptor(command: "Lower inflation", details: [
                        "Raise rate, keep communication credible, and avoid currency weakness if imported prices are biting."
                    ]),
                    HelpCommandDescriptor(command: "Support growth", details: [
                        "Lower rate if inflation and reserves allow it; emergency liquidity is the crisis backstop for deep recession stress."
                    ]),
                    HelpCommandDescriptor(command: "Strengthen the currency", details: [
                        "Use tighter rates, tighter controls, and limited reserve defense during panic. Do not burn reserves defending an inconsistent stance."
                    ]),
                    HelpCommandDescriptor(command: "Rebuild reserves", details: [
                        "Reduce reserve drain, improve the balance of payments, and use calmer quarters to rebuild buffers."
                    ]),
                    HelpCommandDescriptor(command: "Improve current / capital accounts", details: [
                        "Current account improves with softer domestic demand and a more competitive currency. Capital account improves when flight slows and financing confidence returns."
                    ]),
                    HelpCommandDescriptor(command: "Lower external debt", details: [
                        "Sustain current-account improvement over time. Reserve defense alone does not repay external debt."
                    ]),
                    HelpCommandDescriptor(command: "Rebuild credibility", details: [
                        "Contain inflation surprises, align communication with policy, and avoid unnecessary reversals."
                    ]),
                    HelpCommandDescriptor(command: "Use reserve requirements", details: [
                        "Reserve requirements are a secondary tightening tool when you want to lean against credit without relying only on the policy rate."
                    ])
                ],
                paragraphs: []
            ),
            HelpSectionSnapshot(
                heading: "CRISIS MEASURES",
                commands: [
                    HelpCommandDescriptor(command: "imf", details: [
                        "External financing bridge. Helps reserves and expectations, but hurts growth, politics, and debt."
                    ]),
                    HelpCommandDescriptor(command: "holiday", details: [
                        "Run-stopper. Good for panic containment, but bad for confidence and approval."
                    ]),
                    HelpCommandDescriptor(command: "liquidity", details: [
                        "Credit-market support. Best for recession or credit stress, but inflation risk rises."
                    ])
                ],
                paragraphs: []
            ),
            HelpSectionSnapshot(
                heading: "MODEL NOTES",
                commands: [],
                paragraphs: [
                    "Historical mode follows scripted macro timelines; randomized mode schedules shocks procedurally before the run starts.",
                    "Previews are approximate forecasts, not perfect foresight.",
                    scenarioNote
                ].compactMap { $0 }
            )
        ]
    )
}

package func makePresentationContext(simulator: EconomicSimulator?,
                                     gameLength: GameLength,
                                     scenarioID: String?,
                                     quarterLabel: String? = nil) -> GamePresentationSnapshot {
    let scenario = scenarioDefinition(id: scenarioID)
    return GamePresentationSnapshot(
        campaignTitle: campaignDisplayTitle(gameLength: gameLength, scenarioID: scenarioID),
        campaignRange: campaignRangeLabel(gameLength: gameLength, scenarioID: scenarioID),
        quarterLabel: quarterLabel ?? simulator?.state.quarterLabel ?? "Unknown Quarter",
        difficultyLabel: simulator?.difficulty.displayName ?? "Governor",
        scenarioTitle: scenario?.title,
        scenarioSummary: scenario?.summary,
        totalCampaignQuarters: campaignTotalQuarters(gameLength: gameLength, scenarioID: scenarioID)
    )
}

private func buildDashboardSnapshot(simulator: EconomicSimulator,
                                    context: GamePresentationSnapshot) -> DashboardSnapshot {
    let s = simulator.state
    let env = simulator.environment
    let log = simulator.log
    let crisisMeasures = simulator.availableCrisisMeasures()
    let hasCabinetRequest = simulator.activeCabinetRequest != nil
    let crisisMenuRelevant = !crisisMeasures.isEmpty || simulator.crisisCooldownQuarters > 0
    let instrumentGuidance = advisorInstrumentGuidance(for: simulator)
    let cp = simulator.params.credibility

    let metricSections = [
        DashboardMetricSection(
            leftHeading: "REAL ECONOMY",
            rightHeading: "MONETARY CONDITIONS",
            rows: [
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "gdp-growth",
                        label: "GDP Growth",
                        primaryValue: percentText(s.annualizedGDPGrowth),
                        deltaText: nil,
                        trend: trendDirection(log.gdpGrowthHistory),
                        severity: growthSeverity(s.annualizedGDPGrowth),
                        note: "ann",
                        numericValue: s.annualizedGDPGrowth,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "policy-rate",
                        label: "Policy Rate",
                        primaryValue: percentText(s.policyRate),
                        deltaText: nil,
                        trend: nil,
                        severity: .good,
                        note: instrumentGuidance.policyRateDashboardNote,
                        numericValue: s.policyRate,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "output-gap",
                        label: "Output Gap",
                        primaryValue: signedPercentText(s.outputGap),
                        deltaText: percentagePointText(s.outputGapDelta, allowZero: false),
                        trend: nil,
                        severity: abs(s.outputGap) < 0.01 ? .good : (abs(s.outputGap) < 0.03 ? .warning : .danger),
                        note: nil,
                        numericValue: s.outputGap,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "reserve-requirement",
                        label: "Reserve Req",
                        primaryValue: percentText(s.reserveRequirement),
                        deltaText: nil,
                        trend: nil,
                        severity: .good,
                        note: instrumentGuidance.reserveRequirementDashboardNote,
                        numericValue: s.reserveRequirement,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "unemployment",
                        label: "Unemployment",
                        primaryValue: percentText(s.unemployment),
                        deltaText: nil,
                        trend: trendDirection(log.unemploymentHistory),
                        severity: unemploymentSeverity(s.unemployment),
                        note: nil,
                        numericValue: s.unemployment,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "inflation-surprise",
                        label: "Infl. Surprise",
                        primaryValue: percentagePointText(s.inflation - s.expectedInflation, allowZero: true) ?? "+0.0pp",
                        deltaText: nil,
                        trend: nil,
                        severity: inflationSurpriseSeverity(s.inflation - s.expectedInflation),
                        note: nil,
                        numericValue: s.inflation - s.expectedInflation,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "inflation",
                        label: "Inflation",
                        primaryValue: percentText(s.inflation),
                        deltaText: percentagePointText(s.inflationDelta, allowZero: false),
                        trend: trendDirection(log.inflationHistory),
                        severity: inflationSeverity(s.inflation),
                        note: nil,
                        numericValue: s.inflation,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "expected-inflation",
                        label: "Exp. Inflation",
                        primaryValue: percentText(s.expectedInflation),
                        deltaText: percentagePointText(s.expectedInflationDelta, allowZero: false),
                        trend: nil,
                        severity: expectedInflationSeverity(s.expectedInflation),
                        note: nil,
                        numericValue: s.expectedInflation,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "core-inflation",
                        label: "Core Inflation",
                        primaryValue: percentText(s.coreInflation),
                        deltaText: nil,
                        trend: nil,
                        severity: inflationSeverity(s.coreInflation),
                        note: nil,
                        numericValue: s.coreInflation,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "real-rate",
                        label: "Real Rate",
                        primaryValue: signedPercentText(s.realInterestRate),
                        deltaText: nil,
                        trend: nil,
                        severity: realRateSeverity(s.realInterestRate),
                        note: nil,
                        numericValue: s.realInterestRate,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: nil,
                    right: MetricDescriptor(
                        id: "credibility",
                        label: "CB Credibility",
                        primaryValue: String(format: "%.0f%%", s.credibility * 100),
                        deltaText: nil,
                        trend: nil,
                        severity: credibilitySeverity(s.credibility),
                        note: nil,
                        numericValue: s.credibility,
                        displayStyle: .bar(maxValue: 1.0))
                ),
                MetricRowDescriptor(
                    left: nil,
                    right: MetricDescriptor(
                        id: "communication-stance",
                        label: "Comm Stance",
                        primaryValue: simulator.communicationStance.dashboardLabel,
                        deltaText: nil,
                        trend: nil,
                        severity: communicationSeverity(simulator.communicationStance),
                        note: nil,
                        numericValue: nil,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: nil,
                    right: MetricDescriptor(
                        id: "cabinet-ask",
                        label: "Cabinet Ask",
                        primaryValue: simulator.activeCabinetRequest?.title.uppercased() ?? "NONE",
                        deltaText: nil,
                        trend: nil,
                        severity: hasCabinetRequest ? .warning : .neutral,
                        note: nil,
                        numericValue: nil,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: nil,
                    right: MetricDescriptor(
                        id: "crisis-tools",
                        label: "Crisis Tools",
                        primaryValue: simulator.crisisStatusText(),
                        deltaText: nil,
                        trend: nil,
                        severity: crisisMeasures.isEmpty
                            ? (simulator.crisisCooldownQuarters > 0 ? .warning : .neutral)
                            : .danger,
                        note: nil,
                        numericValue: nil,
                        displayStyle: .plain)
                )
            ]
        ),
        DashboardMetricSection(
            leftHeading: "EXTERNAL SECTOR",
            rightHeading: "RESERVES & RISK",
            rows: [
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "exchange-rate",
                        label: "Exch. Rate",
                        primaryValue: String(format: "%.3f USD/SLD", displayedExchangeRate(s.exchangeRate)),
                        deltaText: percentText(displayedExchangeRateQoQChange(s.exchangeRateQoQChange)),
                        trend: nil,
                        severity: exchangeRateSeverity(s.exchangeRateQoQChange),
                        note: nil,
                        numericValue: s.exchangeRate,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "fx-reserves",
                        label: "FX Reserves",
                        primaryValue: String(format: "%.1f mo", s.foreignReservesMonths),
                        deltaText: nil,
                        trend: trendDirection(log.quarterSnapshots.map(\.foreignReservesMonths)),
                        severity: reservesSeverity(s.foreignReservesMonths),
                        note: nil,
                        numericValue: s.foreignReservesMonths,
                        displayStyle: .bar(maxValue: 6.0))
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "current-account",
                        label: "Current Acct",
                        primaryValue: signedPercentText(s.currentAccountGDP) + " GDP",
                        deltaText: nil,
                        trend: nil,
                        severity: currentAccountSeverity(s.currentAccountGDP),
                        note: nil,
                        numericValue: s.currentAccountGDP,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "political-pressure",
                        label: "Pol. Pressure",
                        primaryValue: String(format: "%.0f/%.0f", s.politicalPressure, simulator.params.outcomes.politicalOusterPressure),
                        deltaText: nil,
                        trend: nil,
                        severity: politicalPressureSeverity(
                            s.politicalPressure,
                            threshold: simulator.params.outcomes.politicalOusterPressure),
                        note: nil,
                        numericValue: s.politicalPressure,
                        displayStyle: .bar(maxValue: simulator.params.outcomes.politicalOusterPressure))
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "capital-account",
                        label: "Capital Acct",
                        primaryValue: signedPercentText(s.capitalAccountGDP) + " GDP",
                        deltaText: nil,
                        trend: nil,
                        severity: s.capitalAccountGDP >= 0 ? .good : .danger,
                        note: nil,
                        numericValue: s.capitalAccountGDP,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "approval",
                        label: "CB Approval",
                        primaryValue: String(format: "%.0f%%", s.publicApproval),
                        deltaText: nil,
                        trend: nil,
                        severity: approvalSeverity(s.publicApproval),
                        note: nil,
                        numericValue: s.publicApproval,
                        displayStyle: .bar(maxValue: 100.0))
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "capital-controls",
                        label: "Cap. Controls",
                        primaryValue: capitalControlsLabel(s.capitalControls),
                        deltaText: String(format: "(%.0f%%)", s.capitalControls * 100),
                        trend: nil,
                        severity: capitalControlsSeverity(s.capitalControls),
                        note: nil,
                        numericValue: s.capitalControls,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "oil-and-world-rate",
                        label: "Oil Idx / World Rate",
                        primaryValue: String(format: "%.0f / %.1f%%", env.oilPriceIndex, env.worldInterestRate * 100),
                        deltaText: nil,
                        trend: nil,
                        severity: oilSeverity(env.oilPriceIndex),
                        note: nil,
                        numericValue: env.oilPriceIndex,
                        displayStyle: .plain)
                ),
                MetricRowDescriptor(
                    left: MetricDescriptor(
                        id: "external-debt",
                        label: "Ext. Debt",
                        primaryValue: String(format: "%.1f%% GDP", s.externalDebtGDP * 100),
                        deltaText: nil,
                        trend: nil,
                        severity: debtSeverity(s.externalDebtGDP),
                        note: nil,
                        numericValue: s.externalDebtGDP,
                        displayStyle: .plain),
                    right: MetricDescriptor(
                        id: "fiscal-balance",
                        label: "Fiscal Bal",
                        primaryValue: signedPercentText(s.fiscalBalanceGDP) + " GDP",
                        deltaText: nil,
                        trend: nil,
                        severity: fiscalSeverity(s.fiscalBalanceGDP),
                        note: nil,
                        numericValue: s.fiscalBalanceGDP,
                        displayStyle: .plain)
                )
            ]
        )
    ]

    let commandLegend = "Yellow = relevant now. Cyan = generally available. Dim = dormant."
    let actionSections = makeDashboardActionSections(
        simulator: simulator,
        hasCabinetRequest: hasCabinetRequest,
        crisisMenuRelevant: crisisMenuRelevant,
        crisisMeasures: crisisMeasures
    )

    return DashboardSnapshot(
        context: context,
        title: "CENTRAL BANK OF SOLAVERDE — GOVERNOR'S DASHBOARD",
        subtitle: "Solan Dollar (SLD)  |  \(s.quarterLabel)  |  \(simulator.difficulty.displayName)",
        metricSections: metricSections,
        advisorySections: [
            InfoSection(heading: "Advisory", rows: [
                String(format: "Credibility: misses above +%.1fpp hurt; calm sub-%.1f%% inflation rebuilds.",
                       cp.surpriseThreshold * 100,
                       cp.calmInflationCeiling * 100),
                dashboardAdvisoryMessage(for: simulator)
            ])
        ],
        recentNews: Array(log.newsLog.prefix(5)),
        actionSections: actionSections,
        footerLegend: commandLegend
    )
}

private func buildPreviewSnapshot(estimate: ForecastEstimate,
                                  context: GamePresentationSnapshot,
                                  headerNote: String?,
                                  baselineEstimate: ForecastEstimate? = nil,
                                  params: ModelParameters = .default) -> PreviewSnapshot {
    let report = estimate.report
    let before = report.stateBefore
    let after = estimate.estimatedAfter
    let eventHeadlines = report.news.filter(isPresentationEventHeadline)

    return PreviewSnapshot(
        context: context,
        title: "STAFF FORECAST — \(after.quarterLabel)",
        subtitle: "(dry run, no state changed)",
        headerNote: headerNote,
        explanation: "Forecasts are approximate. Realized data may differ modestly next quarter.",
        eventHeadlines: eventHeadlines,
        projections: [
            comparisonDescriptor(id: "inflation", label: "Inflation", before: before.inflation, after: after.inflation, style: .pct),
            comparisonDescriptor(id: "expected-inflation", label: "Expected infl.", before: before.expectedInflation, after: after.expectedInflation, style: .pct),
            comparisonDescriptor(id: "output-gap", label: "Output gap", before: before.outputGap, after: after.outputGap, style: .ppSigned),
            comparisonDescriptor(id: "gdp-growth", label: "GDP growth (ann)", before: before.annualizedGDPGrowth, after: after.annualizedGDPGrowth, style: .ppSigned),
            comparisonDescriptor(id: "unemployment", label: "Unemployment", before: before.unemployment, after: after.unemployment, style: .pct),
            comparisonDescriptor(id: "credibility", label: "Credibility", before: before.credibility, after: after.credibility, style: .ratio),
            comparisonDescriptor(id: "reserves", label: "Reserves (mo)", before: before.foreignReservesMonths, after: after.foreignReservesMonths, style: .months),
            comparisonDescriptor(id: "exchange-rate", label: "Exchange rate", before: before.exchangeRate, after: after.exchangeRate, style: .fx),
            comparisonDescriptor(id: "pressure", label: "Political press.", before: before.politicalPressure, after: after.politicalPressure, style: .score),
            comparisonDescriptor(id: "approval", label: "Public approval", before: before.publicApproval, after: after.publicApproval, style: .score)
        ],
        analysisSections: previewAnalysisSections(
            params: params,
            before: before,
            after: after,
            report: report,
            headerNote: headerNote,
            baselineEstimate: baselineEstimate,
            eventHeadlines: eventHeadlines
        ),
        footerNote: "Press any key to return to dashboard — no changes have been applied."
    )
}

private func buildAdvisorSnapshot(simulator: EconomicSimulator,
                                  context: GamePresentationSnapshot,
                                  topicText: String?) -> AdvisorSnapshot {
    let brief = advisorBrief(for: simulator, topicText: topicText)
    let requestedFocusLine: String?
    if let topicText, !topicText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        if brief.requestedTopicRecognized {
            requestedFocusLine = "Requested focus: \(brief.requestedTopic.title)"
        } else {
            requestedFocusLine = "Requested focus: \(topicText) (not recognized; showing general triage)"
        }
    } else {
        requestedFocusLine = nil
    }

    return AdvisorSnapshot(
        context: context,
        title: "STAFF ADVISOR — \(brief.focusTitle.uppercased())",
        requestedFocusLine: requestedFocusLine,
        urgentSection: InfoSection(
            heading: "Most urgent right now",
            rows: [brief.urgentHeadline, brief.urgentDetail]
        ),
        rateSection: InfoSection(
            heading: "Indicative rate guidance",
            rows: [brief.rateHeadline, brief.rateDetail]
        ),
        recommendationSection: InfoSection(
            heading: "Recommended levers",
            bullets: brief.recommendations
        ),
        watchSection: InfoSection(
            heading: "Watch closely",
            bullets: brief.watchItems
        ),
        topicSuggestions: [
            "advisor inflation",
            "advisor growth",
            "advisor currency",
            "advisor reserves",
            "advisor balance of payments",
            "advisor debt",
            "advisor credibility",
            "advisor crisis"
        ]
    )
}

private func buildReportSnapshot(simulator: EconomicSimulator,
                                 context: GamePresentationSnapshot,
                                 difficulty: Difficulty = .governor,
                                 gameLength: GameLength,
                                 scenarioID: String?) -> ReportSnapshot {
    let snaps = simulator.log.quarterSnapshots
    let card = simulator.scoreCard
    let liveOutcome: GameOutcome = isCampaignComplete(state: simulator.state, gameLength: gameLength, scenarioID: scenarioID) ? .success : simulator.checkOutcome()
    let score = computeScore(outcome: liveOutcome, card: card, gameLength: gameLength, difficulty: difficulty)
    let avgInflation = snaps.isEmpty ? 0.0 : snaps.map(\.inflation).reduce(0, +) / Double(snaps.count)
    let avgGrowth = snaps.isEmpty ? 0.0 : snaps.map(\.annualizedGDPGrowth).reduce(0, +) / Double(snaps.count)
    let avgUnemployment = snaps.isEmpty ? 0.0 : snaps.map(\.unemployment).reduce(0, +) / Double(snaps.count)
    let avgReserves = snaps.isEmpty ? 0.0 : snaps.map(\.foreignReservesMonths).reduce(0, +) / Double(snaps.count)
    let avgRate = snaps.isEmpty ? 0.0 : snaps.map(\.policyRate).reduce(0, +) / Double(snaps.count)
    let goalStatuses = evaluateScenarioGoals(scenarioID: scenarioID, state: simulator.state)
    let scenario = scenarioDefinition(id: scenarioID)
    let assessment = scenario.map { scenarioAssessmentSnapshot(for: $0, goalStatuses: goalStatuses, outcome: liveOutcome) }

    var summaryRows = [
        "Quarters completed: \(card.quartersSimulated)   Current quarter: \(simulator.state.quarterLabel)",
        "Indicative score if ended now: \(score.final) / 100   \(score.headline)"
    ]
    if let scenario {
        summaryRows.insert("Scenario: \(scenario.title)", at: 0)
        summaryRows.append("Scenario objectives met: \(goalStatuses.filter(\.met).count) / \(goalStatuses.count)")
    }
    if let assessment {
        summaryRows.append("Scenario assessment: \(assessment.heading)")
    }

    return ReportSnapshot(
        context: context,
        title: "CAMPAIGN REPORT — \(campaignRangeLabel(gameLength: gameLength, scenarioID: scenarioID))",
        summarySection: InfoSection(heading: "Summary", rows: summaryRows),
        averages: [
            MetricDescriptor(id: "avg-inflation", label: "CPI inflation", primaryValue: percentText(avgInflation, decimals: 2), deltaText: nil, trend: nil, severity: inflationSeverity(avgInflation), note: nil, numericValue: avgInflation, displayStyle: .plain),
            MetricDescriptor(id: "avg-growth", label: "GDP growth (ann.)", primaryValue: signedPercentText(avgGrowth, decimals: 2), deltaText: nil, trend: nil, severity: growthSeverity(avgGrowth), note: nil, numericValue: avgGrowth, displayStyle: .plain),
            MetricDescriptor(id: "avg-unemployment", label: "Unemployment", primaryValue: percentText(avgUnemployment, decimals: 2), deltaText: nil, trend: nil, severity: unemploymentSeverity(avgUnemployment), note: nil, numericValue: avgUnemployment, displayStyle: .plain),
            MetricDescriptor(id: "avg-reserves", label: "FX reserves", primaryValue: String(format: "%.2f months", avgReserves), deltaText: nil, trend: nil, severity: reservesSeverity(avgReserves), note: nil, numericValue: avgReserves, displayStyle: .plain),
            MetricDescriptor(id: "avg-rate", label: "Policy rate", primaryValue: percentText(avgRate, decimals: 2), deltaText: nil, trend: nil, severity: .neutral, note: nil, numericValue: avgRate, displayStyle: .plain)
        ],
        extremes: [
            MetricDescriptor(id: "peak-inflation", label: "Peak inflation", primaryValue: percentText(card.peakInflation), deltaText: nil, trend: nil, severity: inflationSeverity(card.peakInflation), note: nil, numericValue: card.peakInflation, displayStyle: .plain),
            MetricDescriptor(id: "growth-trough", label: "Growth trough", primaryValue: signedPercentText(card.troughGrowthAnnualized), deltaText: nil, trend: nil, severity: growthSeverity(card.troughGrowthAnnualized), note: nil, numericValue: card.troughGrowthAnnualized, displayStyle: .plain),
            MetricDescriptor(id: "peak-unemployment", label: "Unemployment peak", primaryValue: percentText(card.peakUnemployment), deltaText: nil, trend: nil, severity: unemploymentSeverity(card.peakUnemployment), note: nil, numericValue: card.peakUnemployment, displayStyle: .plain),
            MetricDescriptor(id: "reserve-low", label: "Reserve low", primaryValue: String(format: "%.1f months", card.lowestReserves), deltaText: nil, trend: nil, severity: reservesSeverity(card.lowestReserves), note: nil, numericValue: card.lowestReserves, displayStyle: .plain),
            MetricDescriptor(id: "credibility-trough", label: "Credibility trough", primaryValue: String(format: "%.0f%%", card.lowestCredibility * 100), deltaText: nil, trend: nil, severity: credibilitySeverity(card.lowestCredibility), note: nil, numericValue: card.lowestCredibility, displayStyle: .plain),
            MetricDescriptor(id: "peak-pressure", label: "Political pressure", primaryValue: String(format: "%.0f", card.peakPoliticalPressure), deltaText: nil, trend: nil, severity: politicalPressureSeverity(card.peakPoliticalPressure, threshold: simulator.params.outcomes.politicalOusterPressure), note: nil, numericValue: card.peakPoliticalPressure, displayStyle: .plain)
        ],
        recentQuarters: snaps.suffix(6).reversed().map(recentQuarterSnapshot),
        scenarioGoals: goalStatuses.map { ScenarioGoalDescriptor(description: $0.description, met: $0.met) },
        scenarioAssessment: assessment
    )
}

private func buildDebriefSnapshot(simulator: EconomicSimulator,
                                  context: GamePresentationSnapshot,
                                  report: QuarterReport?,
                                  forecastReview: ForecastReviewRecord?) -> DebriefSnapshot {
    let snaps = simulator.log.quarterSnapshots
    guard let last = snaps.last else {
        return DebriefSnapshot(
            context: context,
            title: "WHY THINGS MOVED",
            summaryRows: ["No completed quarter yet — advance once to get a debrief."],
            mainMoves: [],
            analysisSections: [],
            interpretations: [],
            headlines: []
        )
    }

    let previous = snaps.dropLast().last
    let reportToExplain = report ?? syntheticQuarterReport(from: simulator, lastSnapshot: last, previousSnapshot: previous)
    let quarterEntries = Array(Array(simulator.log.fullNewsLog
        .filter { $0.hasPrefix("[\(last.quarterLabel)]") }
        .prefix(8))
        .reversed())
    let eventHeadlines = quarterEntries
        .filter(isPresentationQuarterHeadline)
        .map(strippingQuarterPrefix)
    let s = simulator.state
    let inflationMove = s.inflationDelta * 100
    let expectedMove = s.expectedInflationDelta * 100
    let gapMove = s.outputGapDelta * 100
    let reservesMove = previous.map { last.foreignReservesMonths - $0.foreignReservesMonths } ?? 0.0
    let approvalMove = previous.map { last.publicApproval - $0.publicApproval } ?? 0.0
    let pressureMove = previous.map { last.politicalPressure - $0.politicalPressure } ?? 0.0
    let growthMove = previous.map { last.annualizedGDPGrowth - $0.annualizedGDPGrowth } ?? 0.0

    return DebriefSnapshot(
        context: context,
        title: "WHY THINGS MOVED",
        summaryRows: [
            "Last completed quarter: \(last.quarterLabel)",
            "This brief explains the moves that carried into \(simulator.state.quarterLabel)."
        ],
        mainMoves: [
            MetricDescriptor(id: "debrief-inflation", label: "Inflation", primaryValue: percentagePointText(inflationMove / 100, allowZero: true) ?? "+0.0pp", deltaText: nil, trend: nil, severity: inflationMove > 0.3 ? .danger : (inflationMove < -0.3 ? .good : .neutral), note: nil, numericValue: inflationMove / 100, displayStyle: .plain),
            MetricDescriptor(id: "debrief-expected", label: "Expected inflation", primaryValue: percentagePointText(expectedMove / 100, allowZero: true) ?? "+0.0pp", deltaText: nil, trend: nil, severity: expectedMove > 0.3 ? .danger : (expectedMove < -0.3 ? .good : .neutral), note: nil, numericValue: expectedMove / 100, displayStyle: .plain),
            MetricDescriptor(id: "debrief-gap", label: "Output gap", primaryValue: percentagePointText(gapMove / 100, allowZero: true) ?? "+0.0pp", deltaText: nil, trend: nil, severity: gapMove > 0.7 ? .warning : (gapMove < -0.7 ? .danger : .neutral), note: nil, numericValue: gapMove / 100, displayStyle: .plain),
            MetricDescriptor(id: "debrief-growth", label: "GDP growth (ann.)", primaryValue: percentagePointText(growthMove, allowZero: true) ?? "+0.0pp", deltaText: nil, trend: nil, severity: growthMove > 0 ? .good : (growthMove < 0 ? .warning : .neutral), note: nil, numericValue: growthMove, displayStyle: .plain),
            MetricDescriptor(id: "debrief-reserves", label: "Reserves", primaryValue: String(format: "%+.1f months", reservesMove), deltaText: nil, trend: nil, severity: reservesMove > 0 ? .good : (reservesMove < 0 ? .danger : .neutral), note: nil, numericValue: reservesMove, displayStyle: .plain),
            MetricDescriptor(id: "debrief-approval", label: "Approval", primaryValue: String(format: "%+.1f", approvalMove), deltaText: nil, trend: nil, severity: approvalMove > 0 ? .good : (approvalMove < 0 ? .warning : .neutral), note: nil, numericValue: approvalMove, displayStyle: .plain),
            MetricDescriptor(id: "debrief-pressure", label: "Political pressure", primaryValue: String(format: "%+.1f", pressureMove), deltaText: nil, trend: nil, severity: pressureMove > 0 ? .danger : (pressureMove < 0 ? .good : .neutral), note: nil, numericValue: pressureMove, displayStyle: .plain)
        ],
        analysisSections: debriefAnalysisSections(
            simulator: simulator,
            report: reportToExplain,
            rawQuarterEntries: quarterEntries,
            eventHeadlines: eventHeadlines,
            forecastReview: forecastReview
        ),
        interpretations: debriefInterpretations(
            simulator: simulator,
            lastQuarterEntries: quarterEntries,
            lastSnapshot: last,
            previousSnapshot: previous
        ),
        headlines: quarterEntries
    )
}

private func buildTutorialSnapshot(simulator: EconomicSimulator,
                                   context: GamePresentationSnapshot,
                                   mode: GameMode,
                                   gameLength: GameLength,
                                   scenarioID: String?) -> TutorialSnapshot {
    let card = simulator.scoreCard
    let quarter = card.quartersSimulated
    let goalStatuses = evaluateScenarioGoals(scenarioID: scenarioID, state: simulator.state)

    let stageTitle: String
    var focus: [String] = []
    var experiments: [String] = []
    var success: [String] = []

    switch quarter {
    case 0:
        stageTitle = "ORIENTATION"
        focus = [
            "Start with four gauges: inflation, expected inflation, reserves, and political pressure.",
            "Inflation and expected inflation tell you whether you are winning the nominal battle.",
            "Reserves and the current/capital accounts tell you whether the external side is quietly breaking."
        ]
        experiments = [
            "Use preview with no arguments once, then try preview rate 8.5 and preview controls 5.",
            "Watch which variables move a lot and which barely move. That teaches the model faster than reading theory notes."
        ]
        success = [
            "Do not chase a perfect quarter. First learn which variables are tightly linked and which trade off against each other."
        ]
    case 1...4:
        stageTitle = "OPENING LESSONS"
        focus = [
            "In the opening quarters, your job is usually to decide which risk matters more right now: inflation, recession, or the external side.",
            "If inflation is high but reserves are comfortable, rate policy can do most of the work.",
            "If reserves are low, rates alone may not be enough; think about controls, intervention, or crisis preparation."
        ]
        experiments = [
            "Use why after each quarter. It will tell you whether inflation, growth, or reserves actually moved for the reason you expected.",
            "Try one clean policy stance for two quarters before overreacting. The model rewards consistency more than twitchy quarter-by-quarter flips."
        ]
        success = [
            "A good opening is not 'all green.' It is an opening where no single channel is spiraling beyond your ability to recover."
        ]
    case 5...12:
        stageTitle = "MID-GAME CONTROL"
        focus = [
            "By now the question is less 'what does this tool do?' and more 'which constraint is binding?'",
            "Low credibility makes inflation harder to tame. Weak reserves make every FX scare more expensive. High political pressure shrinks your room to stay tough."
        ]
        experiments = [
            "Use report to see whether your average inflation and reserve position are actually improving over time.",
            "Use history to check whether you are just surviving quarter to quarter or genuinely stabilizing the economy."
        ]
        success = [
            "The best runs usually accept one area of pain temporarily to stop a worse spiral somewhere else."
        ]
    default:
        stageTitle = "LATE-RUN STRATEGY"
        focus = [
            "At this point you are managing legacy problems: debt, credibility, reserves, and political tolerance built up over many quarters.",
            "The winning habit late in the run is not cleverness; it is avoiding unforced reversals that reopen old wounds."
        ]
        experiments = [
            "Use report and history together. If the economy is stable, do less. If one channel is still deteriorating, address that specific weakness rather than everything at once."
        ]
        success = [
            "Late-game quality looks boring on the dashboard: contained inflation, adequate reserves, and no quarter screaming for emergency action."
        ]
    }

    if mode == .historical {
        focus.append("Historical mode gives you a real-world shock path, but your response still determines whether those shocks become a crisis.")
    } else {
        focus.append("Randomized mode is best for learning robustness: if a plan survives unknown shocks, it probably fits the model.")
    }

    if gameLength == .extended {
        focus.append("Extended campaigns reward durable policy frameworks. If you need heroics every quarter, you are probably not actually stable yet.")
    } else {
        focus.append("Short campaigns are about triage. You are not building a perfect economy; you are surviving a concentrated storm.")
    }
    if let scenario = scenarioDefinition(id: scenarioID) {
        focus.append("You are currently inside the scenario \(scenario.title). Treat the scenario objectives as your mandate, not just generic survival.")
    }

    return TutorialSnapshot(
        context: context,
        title: "GUIDED TUTORIAL",
        stageTitle: stageTitle,
        focus: focus,
        experiments: experiments,
        success: success,
        scenarioGoals: goalStatuses.map { ScenarioGoalDescriptor(description: $0.description, met: $0.met) },
        companionActions: [
            ActionDescriptor(id: "preview", label: "preview", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
            ActionDescriptor(id: "debrief", label: "why", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
            ActionDescriptor(id: "advisor", label: "advisor", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
            ActionDescriptor(id: "history", label: "history", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
            ActionDescriptor(id: "report", label: "report", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
            ActionDescriptor(id: "help", label: "help", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info)
        ]
    )
}

private func buildHistorySnapshot(simulator: EconomicSimulator,
                                  context: GamePresentationSnapshot) -> HistorySnapshot {
    let log = simulator.log
    let charts: [HistoryChartSnapshot]
    let emptyState: String?
    if log.inflationHistory.isEmpty {
        charts = []
        emptyState = "No history yet — advance some quarters first."
    } else {
        charts = [
            HistoryChartSnapshot(
                label: "CPI Inflation",
                values: log.inflationHistory,
                scale: 0.25,
                latestValue: String(format: "%.1f%%", (log.inflationHistory.last ?? 0.0) * 100),
                goodRange: 0.0..<0.05,
                warningRange: 0.05..<0.10,
                positiveThreshold: nil
            ),
            HistoryChartSnapshot(
                label: "Unemployment",
                values: log.unemploymentHistory,
                scale: 0.20,
                latestValue: String(format: "%.1f%%", (log.unemploymentHistory.last ?? 0.0) * 100),
                goodRange: 0.0..<0.07,
                warningRange: 0.07..<0.10,
                positiveThreshold: nil
            ),
            HistoryChartSnapshot(
                label: "GDP Growth (ann)",
                values: log.gdpGrowthHistory,
                scale: 0.08,
                latestValue: String(format: "%+.1f%%", (log.gdpGrowthHistory.last ?? 0.0) * 100),
                goodRange: 0.02..<1.0,
                warningRange: -0.01..<0.02,
                positiveThreshold: 0.0
            )
        ]
        emptyState = nil
    }

    return HistorySnapshot(
        context: context,
        title: "ECONOMIC HISTORY — TREND CHARTS",
        charts: charts,
        recentQuarters: log.quarterSnapshots.suffix(12).reversed().map(recentQuarterSnapshot),
        emptyState: emptyState
    )
}

private func buildNewsSnapshot(simulator: EconomicSimulator,
                               context: GamePresentationSnapshot) -> NewsSnapshot {
    let entries = simulator.log.fullNewsLog
    return NewsSnapshot(
        context: context,
        title: "FULL NEWS LOG",
        entries: entries,
        emptyState: entries.isEmpty ? "No news yet — advance some quarters first." : nil
    )
}

private func buildCrisisOptionsSnapshot(simulator: EconomicSimulator,
                                        context: GamePresentationSnapshot) -> CrisisOptionsSnapshot {
    let measures = simulator.availableCrisisMeasures()
    let rows: [String]
    if simulator.crisisCooldownQuarters > 0 {
        rows = [
            "Crisis tools are cooling down for \(simulator.crisisCooldownQuarters) more quarters.",
            "Stabilize the economy with your normal policy tools until they reopen."
        ]
    } else if measures.isEmpty {
        rows = [
            "No emergency measures are currently unlocked.",
            "They appear only under severe external or domestic stress."
        ]
    } else {
        rows = [
            "Available now. You may enact one with measure <name>.",
            "After use, crisis tools go on a four-quarter cooldown."
        ]
    }

    return CrisisOptionsSnapshot(
        context: context,
        title: "CRISIS OPTIONS",
        summaryRows: rows,
        measures: measures
    )
}

private func buildStatusSnapshot(simulator: EconomicSimulator,
                                 context: GamePresentationSnapshot,
                                 gameLength: GameLength,
                                 scenarioID: String?) -> StatusSnapshot {
    let s = simulator.state
    let env = simulator.environment
    var sections: [InfoSection] = []

    if let scenario = scenarioDefinition(id: scenarioID) {
        sections.append(
            InfoSection(
                heading: "Scenario",
                rows: [
                    "Scenario: \(scenario.title)",
                    "Scenario Range: \(scenario.rangeLabel)"
                ]
            )
        )
    }

    sections.append(
        InfoSection(
            heading: "Real Economy",
            rows: [
                String(format: "Real GDP Index: %.2f   (base 100 = %@)", s.realGDP, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID)),
                String(format: "Potential GDP Index: %.2f", s.potentialGDP),
                String(format: "Output Gap: %+.2f%%", s.outputGap * 100)
            ]
        )
    )
    sections.append(
        InfoSection(
            heading: "Prices",
            rows: [
                String(format: "CPI Price Level: %.2f   (base 100 = %@)", s.priceLevel, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID)),
                String(format: "CPI Inflation: %.2f%% ann.", s.inflation * 100),
                String(format: "Core Inflation: %.2f%% ann.", s.coreInflation * 100),
                String(format: "Expected Inflation: %.2f%% ann.", s.expectedInflation * 100)
            ]
        )
    )
    sections.append(
        InfoSection(
            heading: "Policy",
            rows: [
                String(format: "Policy Rate: %.2f%%", s.policyRate * 100),
                "Communication Stance: \(simulator.communicationStance.displayName)",
                "Cabinet Request: \(simulator.activeCabinetRequest?.title ?? "None")",
                String(format: "Real Interest Rate: %+.2f%%", s.realInterestRate * 100),
                String(format: "Reserve Requirement: %.1f%%", s.reserveRequirement * 100),
                String(format: "M2 Growth: %.2f%% ann.", s.m2Growth * 100),
                String(format: "Bank Credit Growth: %.2f%% ann.", s.bankCreditGrowth * 100)
            ]
        )
    )
    sections.append(
        InfoSection(
            heading: "External Sector",
            rows: [
                String(format: "Exchange Rate: %.4f USD/SLD", displayedExchangeRate(s.exchangeRate)),
                String(format: "Qtrly ER Change: %+.2f%% (+ = strengthening)", displayedExchangeRateQoQChange(s.exchangeRateQoQChange) * 100),
                String(format: "Current Account: %+.2f%% GDP", s.currentAccountGDP * 100),
                String(format: "Capital Account: %+.2f%% GDP", s.capitalAccountGDP * 100),
                String(format: "FX Reserves: %.2f months of imports", s.foreignReservesMonths),
                String(format: "Capital Controls: %.0f%% (0=open, 100=closed)", s.capitalControls * 100),
                String(format: "External Debt/GDP: %.1f%%", s.externalDebtGDP * 100)
            ]
        )
    )
    sections.append(
        InfoSection(
            heading: "Fiscal and Global Backdrop",
            rows: [
                String(format: "Government Debt/GDP: %.1f%%", s.governmentDebtGDP * 100),
                String(format: "Fiscal Balance/GDP: %+.2f%%", s.fiscalBalanceGDP * 100),
                String(format: "World Interest Rate: %.2f%%", env.worldInterestRate * 100),
                String(format: "World Inflation: %.2f%%", env.worldInflation * 100),
                String(format: "Trading Partner Grow: %.2f%% ann.", env.tradingPartnerGrowth * 100),
                String(format: "Oil Price Index: %.0f   (base 100 = %@)", env.oilPriceIndex, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID))
            ]
        )
    )

    return StatusSnapshot(
        context: context,
        title: "EXTENDED ECONOMIC BRIEFING — \(s.quarterLabel)",
        sections: sections
    )
}

private func buildGameOverSnapshot(outcome: GameOutcome,
                                   simulator: EconomicSimulator,
                                   context: GamePresentationSnapshot,
                                   difficulty: Difficulty = .governor,
                                   gameLength: GameLength,
                                   scenarioID: String?) -> GameOverSnapshot {
    let s = simulator.state
    let card = simulator.scoreCard
    let score = computeScore(outcome: outcome, card: card, gameLength: gameLength, difficulty: difficulty)
    let scenario = scenarioDefinition(id: scenarioID)
    let goalStatuses = evaluateScenarioGoals(scenarioID: scenarioID, state: s)
    let assessment = scenario.map { scenarioAssessmentSnapshot(for: $0, goalStatuses: goalStatuses, outcome: outcome) }

    let introduction: [String]
    let title: String
    switch outcome {
    case .currencyCrisis:
        title = "CURRENCY CRISIS — GAME OVER"
        introduction = [
            "The Solan Dollar has collapsed. Foreign reserves exhausted;",
            "the SLD enters freefall. The IMF imposes emergency conditionality.",
            "You are dismissed as Governor. Solaverde faces a decade of austerity."
        ]
    case .hyperinflation:
        title = "HYPERINFLATION — GAME OVER"
        introduction = [
            "Inflation has spiralled beyond control. Prices doubling quarterly.",
            "The public has lost all confidence in the Solan Dollar.",
            "Currency reform and dollarisation forced upon the government."
        ]
    case .depression:
        title = "ECONOMIC DEPRESSION — GAME OVER"
        introduction = [
            "The economy has collapsed into severe depression. Mass unemployment.",
            "Social unrest and political chaos force your resignation.",
            "Solaverde appeals for emergency international assistance."
        ]
    case .politicalOuster:
        title = "POLITICAL OUSTER — GAME OVER"
        introduction = [
            "Political pressure has become overwhelming. The Cabinet has voted",
            "to remove you as Governor. Central bank independence is abolished.",
            "Your replacement immediately cuts rates to win the next election."
        ]
    case .success:
        title = "YOU SURVIVED — CONGRATULATIONS, GOVERNOR"
        if let scenario {
            let met = goalStatuses.filter(\.met).count
            introduction = [
                "Scenario completed: \(scenario.title)",
                "Objective results: \(met)/\(goalStatuses.count) met."
            ]
        } else if gameLength == .short {
            introduction = [
                "You have guided Solaverde through one of the most turbulent decades",
                "in monetary history. The 1970s tested every central banker on earth.",
                "Solaverde enters the 1980s battered but intact."
            ]
        } else {
            introduction = [
                "You have completed a forty-year central-banking career without",
                "losing the currency, the economy, or your office. Few governors",
                "survive Bretton Woods, stagflation, debt crises, and the 1990s intact."
            ]
        }
    case .ongoing:
        title = "GAME OVER"
        introduction = []
    }

    let scoreRows = [
        String(format: "Starting baseline: %+3d", score.baseline)
    ] + score.items.map { String(format: "%@%+3d", $0.label + String(repeating: " ", count: max(1, 40 - $0.label.count)), $0.points) } + [
        String(format: "FINAL SCORE: %3d / 100", score.final),
        score.headline
    ]

    return GameOverSnapshot(
        context: context,
        title: title,
        introduction: introduction,
        finalStateSection: InfoSection(
            heading: "FINAL STATE — \(s.quarterLabel)",
            rows: [
                String(format: "Inflation: %.1f%%   Unemployment: %.1f%%   Reserves: %.1f months", s.inflation * 100, s.unemployment * 100, s.foreignReservesMonths),
                String(format: "GDP Growth: %+.1f%%   Credibility: %.0f%%   Approval: %.0f%%", s.annualizedGDPGrowth * 100, s.credibility * 100, s.publicApproval)
            ]
        ),
        scenarioGoals: goalStatuses.map { ScenarioGoalDescriptor(description: $0.description, met: $0.met) },
        scenarioAssessment: assessment,
        reviewSection: InfoSection(
            heading: "CAMPAIGN REVIEW",
            rows: [
                "Quarters with inflation >10%: \(card.highInflationQuarters)",
                "Quarters with inflation >20%: \(card.severeInflationQuarters)",
                "Quarters in recession: \(card.recessionQuarters)",
                "Quarters of stagflation: \(card.stagflationQuarters)",
                "Quarters with unemployment >9%: \(card.highUnemploymentQuarters)",
                "Quarters near political ouster: \(card.nearOusterQuarters)",
                String(format: "Peak inflation: %.1f%%", card.peakInflation * 100),
                String(format: "Trough GDP growth (annualised): %+.1f%%", card.troughGrowthAnnualized * 100),
                String(format: "Peak unemployment: %.1f%%", card.peakUnemployment * 100),
                String(format: "Credibility trough: %.0f%%", card.lowestCredibility * 100),
                String(format: "Reserves low-water mark: %.1f months", card.lowestReserves),
                String(format: "Peak political pressure: %.0f / 92", card.peakPoliticalPressure),
                String(format: "Peak policy rate: %.1f%%", card.peakPolicyRate * 100),
                String(format: "Peak reserve requirement: %.1f%%", card.peakReserveRequirement * 100),
                String(format: "Peak capital controls: %.0f / 10", card.peakCapitalControls * 10)
            ]
        ),
        failureDiagnosisSection: failureDiagnosisSection(outcome: outcome, simulator: simulator),
        scoreSection: InfoSection(
            heading: "SCORECARD",
            rows: scoreRows
        )
    )
}

private func previewAnalysisSections(params: ModelParameters,
                                     before: EconomicState,
                                     after: EconomicState,
                                     report: QuarterReport,
                                     headerNote: String?,
                                     baselineEstimate: ForecastEstimate?,
                                     eventHeadlines: [String]) -> [InfoSection] {
    [
        InfoSection(
            heading: "Policy effect",
            rows: previewPolicyRows(
                params: params,
                before: before,
                after: after,
                headerNote: headerNote,
                baselineEstimate: baselineEstimate,
                report: report
            )
        ),
        InfoSection(
            heading: "Shock effect",
            rows: previewShockRows(
                params: params,
                before: before,
                after: after,
                report: report,
                eventHeadlines: eventHeadlines
            ),
            bullets: eventHeadlines
        ),
        InfoSection(
            heading: "Expectation lag",
            rows: expectationAndCommunicationRows(
                before: before,
                after: after,
                news: report.news,
                previewMode: true,
                report: report,
                params: params
            )
        )
    ]
}

private func debriefAnalysisSections(simulator: EconomicSimulator,
                                     report: QuarterReport,
                                     rawQuarterEntries: [String],
                                     eventHeadlines: [String],
                                     forecastReview: ForecastReviewRecord?) -> [InfoSection] {
    var sections: [InfoSection] = [
        InfoSection(
            heading: "Policy effect",
            rows: debriefPolicyRows(
                simulator: simulator,
                before: report.stateBefore,
                after: report.stateAfter,
                report: report
            )
        ),
        InfoSection(
            heading: "Shock effect",
            rows: debriefShockRows(
                simulator: simulator,
                before: report.stateBefore,
                after: report.stateAfter,
                report: report,
                eventHeadlines: eventHeadlines
            ),
            bullets: eventHeadlines
        ),
        InfoSection(
            heading: "Expectation lag",
            rows: expectationAndCommunicationRows(
                before: report.stateBefore,
                after: report.stateAfter,
                news: rawQuarterEntries,
                previewMode: false,
                report: report,
                params: simulator.params
            )
        )
    ]

    if let forecastReview {
        sections.append(
            InfoSection(
                heading: "Forecast review",
                rows: forecastReviewRows(
                    forecastReview,
                    actual: report.stateAfter
                )
            )
        )
    }

    return sections
}

private func previewPolicyRows(params: ModelParameters,
                               before: EconomicState,
                               after: EconomicState,
                               headerNote: String?,
                               baselineEstimate: ForecastEstimate?,
                               report: QuarterReport) -> [String] {
    var rows: [String] = []
    let outputGapRows = outputGapAttributionRows(
        params: params,
        before: before,
        after: after,
        report: report
    )

    if let headerNote {
        rows.append("This forecast assumes: \(headerNote.replacingOccurrences(of: "Hypothetical: ", with: "")).")
    } else {
        rows.append("This is the hold-steady control case: no new lever changes are applied before the quarter runs.")
    }

    if after.policyRate > before.policyRate + 0.0001 {
        rows.append("A higher policy rate should cool demand with a lag and strengthen the disinflation signal if credibility holds.")
    } else if after.policyRate < before.policyRate - 0.0001 {
        rows.append("A lower policy rate should cushion growth, but it also leaves you with less inflation and currency defense next quarter.")
    }

    if after.reserveRequirement > before.reserveRequirement + 0.0001 {
        rows.append("A higher reserve requirement restrains bank credit and imports, though sustained use will shave growth.")
    } else if after.reserveRequirement < before.reserveRequirement - 0.0001 {
        rows.append("A lower reserve requirement supports credit and domestic demand, but it also loosens the external side.")
    }

    if after.capitalControls > before.capitalControls + 0.0001 {
        rows.append("Tighter capital controls buy short-run external breathing room, but the political and credibility tax rises if you leave them in place.")
    } else if after.capitalControls < before.capitalControls - 0.0001 {
        rows.append("Looser capital controls reduce the long-run drag, but they also expose the currency to a faster market test.")
    }

    rows.append(contentsOf: outputGapRows)

    if let baselineEstimate {
        rows.append(counterfactualPreviewRow(planAfter: after, baselineAfter: baselineEstimate.estimatedAfter))
    }

    return rows
}

private func previewShockRows(params: ModelParameters,
                              before: EconomicState,
                              after: EconomicState,
                              report: QuarterReport,
                              eventHeadlines: [String]) -> [String] {
    var rows = inflationShockRows(
        params: params,
        before: before,
        after: after,
        report: report,
        eventHeadlines: eventHeadlines,
        previewMode: true
    )
    rows.append(contentsOf: reserveAttributionRows(
        params: params,
        before: before,
        after: after,
        report: report
    ))
    return rows
}

private func debriefPolicyRows(simulator: EconomicSimulator,
                               before: EconomicState,
                               after: EconomicState,
                               report: QuarterReport) -> [String] {
    let neutralRealRate = simulator.params.outputGap.neutralRealRate
    let realRateGap = before.realInterestRate - neutralRealRate
    var rows: [String] = []

    if realRateGap > 0.012 {
        rows.append(String(format: "Policy started the quarter clearly restrictive: real rate %+.1f%% versus an estimated neutral rate near %+.1f%%.", before.realInterestRate * 100, neutralRealRate * 100))
    } else if realRateGap < -0.010 {
        rows.append(String(format: "Policy started the quarter soft in real terms: real rate %+.1f%% versus an estimated neutral rate near %+.1f%%.", before.realInterestRate * 100, neutralRealRate * 100))
    } else {
        rows.append(String(format: "Policy started near neutral: real rate %+.1f%% against a neutral benchmark near %+.1f%%, so other forces mattered a lot.", before.realInterestRate * 100, neutralRealRate * 100))
    }

    if before.reserveRequirement >= 0.16 {
        rows.append("Reserve requirements were high enough to restrain credit growth and some import demand.")
    }

    if before.capitalControls >= 0.55 {
        rows.append("Capital controls were doing part of the external-defense work, which helped the balance of payments but carried its own drag and credibility cost.")
    }

    rows.append(contentsOf: outputGapAttributionRows(
        params: simulator.params,
        before: before,
        after: after,
        report: report
    ))

    return rows
}

private func debriefShockRows(simulator: EconomicSimulator,
                              before: EconomicState,
                              after: EconomicState,
                              report: QuarterReport,
                              eventHeadlines: [String]) -> [String] {
    var rows = inflationShockRows(
        params: simulator.params,
        before: before,
        after: after,
        report: report,
        eventHeadlines: eventHeadlines,
        previewMode: false
    )
    rows.append(contentsOf: reserveAttributionRows(
        params: simulator.params,
        before: before,
        after: after,
        report: report
    ))
    return rows
}

private func expectationAndCommunicationRows(before: EconomicState,
                                             after: EconomicState,
                                             news: [String],
                                             previewMode: Bool,
                                             report: QuarterReport,
                                             params: ModelParameters) -> [String] {
    var rows = [
        "Inflation started the quarter with an inherited expectation anchor of \(percentText(before.expectedInflation)); that anchor is the biggest single reason inflation does not respond instantly to new policy."
    ]

    if before.credibility < 0.50 {
        rows.append(String(format: "Credibility began the quarter weak at %.0f%%, so expectations were always likely to adjust only slowly.", before.credibility * 100))
    } else if before.credibility < 0.65 {
        rows.append(String(format: "Credibility began the quarter at %.0f%%, so expectations still carry noticeable inertia.", before.credibility * 100))
    }

    rows.append(expectationUpdateRow(
        params: params,
        before: before,
        after: after,
        previewMode: previewMode,
        report: report
    ))
    rows.append(contentsOf: communicationContributionRows(after: after, news: news, previewMode: previewMode))
    return rows
}

private func communicationContributionRows(after: EconomicState,
                                           news: [String],
                                           previewMode: Bool) -> [String] {
    let communicationLine = news
        .map(strippingQuarterPrefix)
        .first { $0.hasPrefix("COMMUNICATION:") }

    guard let communicationLine else {
        return ["Communication stayed balanced this quarter, so there was no separate messaging shock on expectations or credibility."]
    }

    let phase = previewMode ? "is projected to" : "did"
    if communicationLine.contains("reinforced by policy stance") {
        let pressureBump = (after.inflation > 0.10 || after.outputGap > 0.02) ? 0.5 : 2.0
        return [
            "Communication \(phase) matter here: hawkish guidance aligned with policy, implying roughly credibility +1.0pp, expected inflation -0.3pp, and political pressure \(String(format: "%+.1f", pressureBump))."
        ]
    }
    if communicationLine.contains("rings hollow") {
        let pressureBump = (after.inflation > 0.10 || after.outputGap > 0.02) ? 0.5 : 2.0
        return [
            "Communication \(phase) matter here: hawkish rhetoric was not backed by policy, implying roughly credibility -1.5pp, expected inflation +0.2pp, and political pressure \(String(format: "%+.1f", pressureBump))."
        ]
    }
    if communicationLine.contains("measured reassurance") {
        return [
            "Communication did real work here: dovish guidance fit the slack economy, buying roughly approval +2.0, pressure -2.5, credibility +0.8pp, and expected inflation -0.2pp."
        ]
    }
    if communicationLine.contains("unsettles markets") {
        return [
            "Communication made things worse: dovish guidance against inflation or currency stress implied roughly credibility -1.8pp, expected inflation +0.6pp, and pressure +0.5."
        ]
    }
    if communicationLine.contains("modest political goodwill") {
        return [
            "Communication mostly bought political cover: dovish reassurance implied roughly approval +1.5 and pressure -2.0, but it did not meaningfully re-anchor expectations."
        ]
    }
    if communicationLine.contains("leaves markets uneasy") {
        return [
            "Communication bought short-term room but at a cost: opaque guidance implied roughly credibility -0.8pp and pressure -1.0."
        ]
    }
    return ["Communication had a visible effect this quarter, though the exact mix was dominated by surrounding macro conditions."]
}

private func forecastReviewRows(_ review: ForecastReviewRecord, actual: EconomicState) -> [String] {
    let predicted = review.estimate.estimatedAfter
    let inflationError = abs(predicted.inflation - actual.inflation)
    let expectedError = abs(predicted.expectedInflation - actual.expectedInflation)
    let gapError = abs(predicted.outputGap - actual.outputGap)
    let reservesError = abs(predicted.foreignReservesMonths - actual.foreignReservesMonths)
    let withinBounds = inflationError <= 0.0035
        && expectedError <= 0.0030
        && gapError <= 0.0050
        && reservesError <= 0.25

    var rows = [
        "Preview predicted inflation at \(percentText(predicted.inflation)). Actual inflation printed \(percentText(actual.inflation)).",
        withinBounds
            ? "Forecast error stayed within normal model bounds; the preview was directionally trustworthy."
            : "Forecast error ran wider than normal model bounds, so shocks or expectation lag dominated more than the preview implied."
    ]

    if let baseline = review.baselineEstimate {
        rows.append(counterfactualActualRow(predictedAfter: predicted, actualAfter: actual, baselineAfter: baseline.estimatedAfter))
    }

    return rows
}

private func counterfactualPreviewRow(planAfter: EconomicState, baselineAfter: EconomicState) -> String {
    let strongerWeaker = displayedExchangeRate(planAfter.exchangeRate) >= displayedExchangeRate(baselineAfter.exchangeRate) ? "stronger" : "weaker"
    return "Against holding policy steady, this plan is forecast to put inflation at \(percentText(planAfter.inflation)) instead of \(percentText(baselineAfter.inflation)), reserves at \(String(format: "%.2f", planAfter.foreignReservesMonths)) instead of \(String(format: "%.2f", baselineAfter.foreignReservesMonths)) months, and the SLD \(strongerWeaker)."
}

private func counterfactualActualRow(predictedAfter: EconomicState,
                                     actualAfter: EconomicState,
                                     baselineAfter: EconomicState) -> String {
    let planGain = baselineAfter.inflation - predictedAfter.inflation
    let actualGain = baselineAfter.inflation - actualAfter.inflation
    return "Against the hold-steady counterfactual, the preview said your plan would improve inflation by \(String(format: "%.1f", planGain * 100))pp; the realized improvement came in at \(String(format: "%.1f", actualGain * 100))pp."
}

private func outputGapAttributionRows(params: ModelParameters,
                                      before: EconomicState,
                                      after: EconomicState,
                                      report: QuarterReport) -> [String] {
    let reserveOverhang = max(0.0, before.reserveRequirement - params.outputGap.reserveRequirementDragThreshold)
    let controlsOverhang = max(0.0, before.capitalControls - params.outputGap.capitalControlsDragThreshold)
    let realRateGap = before.realInterestRate - params.outputGap.neutralRealRate
    let rateContribution = -(params.outputGap.isCoefficient / 4.0) * realRateGap
    let reserveContribution = -params.outputGap.reserveRequirementDemandDrag * reserveOverhang
    let controlsContribution = -params.outputGap.capitalControlsDemandDrag * controlsOverhang
    let creditContribution = params.outputGap.creditImpulse * (after.bankCreditGrowth - params.outputGap.creditBaseline)
    let currentAccountContribution = params.outputGap.currentAccountSupport * before.currentAccountGDP
    let directShockContribution = approximateEventOutputGapContribution(report.events)
    let residualNoise = after.outputGap
        - (
            params.outputGap.persistence * before.outputGap
            + rateContribution
            + reserveContribution
            + controlsContribution
            + creditContribution
            + currentAccountContribution
            + directShockContribution
        )

    return [
        "Demand channel: rates contributed \(ppText(rateContribution)); reserve requirements \(ppText(reserveContribution)); capital controls \(ppText(controlsContribution)).",
        "Offsetting support: bank-credit impulse \(ppText(creditContribution)); current-account carry \(ppText(currentAccountContribution)).",
        "Residual demand noise and timing effects came in at \(ppText(residualNoise))."
    ]
}

private func inflationShockRows(params: ModelParameters,
                                before: EconomicState,
                                after: EconomicState,
                                report: QuarterReport,
                                eventHeadlines: [String],
                                previewMode: Bool) -> [String] {
    let demandContribution = params.inflation.phillipsSlope * after.outputGap
    let fxContribution = params.inflation.exchangeRatePassthrough * after.exchangeRateQoQChange
    let shockContribution = approximateEventInflationContribution(report.events)
    let residualNoise = after.inflation - before.expectedInflation - demandContribution - fxContribution - shockContribution

    var rows: [String] = []
    if eventHeadlines.isEmpty {
        rows.append("No named supply shock \(previewMode ? "is expected" : "hit") this quarter; the main non-policy inflation drivers were FX passthrough and residual supply noise.")
    } else {
        rows.append("Named shocks \(previewMode ? "are expected to add" : "added") roughly \(ppText(shockContribution)) to inflation and \(ppText(approximateEventOutputGapContribution(report.events))) to demand.")
    }
    rows.append("Inflation impulse beyond expectations: Phillips demand \(ppText(demandContribution)); FX passthrough \(ppText(fxContribution)); residual supply noise \(ppText(residualNoise)).")
    return rows
}

private func reserveAttributionRows(params: ModelParameters,
                                    before: EconomicState,
                                    after: EconomicState,
                                    report: QuarterReport) -> [String] {
    let bop = after.currentAccountGDP + after.capitalAccountGDP
    let monthlyImportShare = params.reserves.importShareOfGDP / 12.0
    let balanceOfPaymentsFlow = (bop / (monthlyImportShare * 12.0)) * 0.25
    let observedChange = after.foreignReservesMonths - before.foreignReservesMonths
    let directShockOrRelief = observedChange - balanceOfPaymentsFlow

    return [
        "Reserves moved \(String(format: "%+.2f", observedChange)) months overall: underlying balance-of-payments flow \(String(format: "%+.2f", balanceOfPaymentsFlow)); direct shock or relief \(String(format: "%+.2f", directShockOrRelief))."
    ]
}

private func expectationUpdateRow(params: ModelParameters,
                                  before: EconomicState,
                                  after: EconomicState,
                                  previewMode: Bool,
                                  report: QuarterReport) -> String {
    let adaptSpeed = params.expectations.baseAdaptSpeed
        + (1.0 - before.credibility) * params.expectations.credibilityAmplifier
    let preCommunication = params.expectations.bounds.clamping(
        adaptSpeed * after.inflation + (1.0 - adaptSpeed) * before.expectedInflation
    )
    let communicationContribution = after.expectedInflation - preCommunication
    let phase = previewMode ? "would then" : "then"

    return "Adaptive expectations alone would have moved expectations to \(percentText(preCommunication)) at a speed of \(String(format: "%.0f%%", adaptSpeed * 100)); communication \(phase) shift that path by \(ppText(communicationContribution))."
}

private func approximateEventInflationContribution(_ events: [EconomicEvent]) -> Double {
    events.reduce(0.0) { partial, event in
        switch event.type {
        case .oilShock(let magnitude):
            return partial + 0.030 * magnitude
        case .oilRecovery(let magnitude):
            return partial - 0.014 * magnitude
        case .droughtOrDisaster:
            return partial + 0.020
        case .workerStrike:
            return partial + 0.012
        default:
            return partial
        }
    }
}

private func approximateEventOutputGapContribution(_ events: [EconomicEvent]) -> Double {
    events.reduce(0.0) { partial, event in
        switch event.type {
        case .oilShock(let magnitude):
            return partial - 0.012 * magnitude
        case .droughtOrDisaster:
            return partial - 0.014
        case .tourismBoom:
            return partial + 0.005
        case .tourismCollapse:
            return partial - 0.008
        case .workerStrike:
            return partial - 0.012
        case .creditCrunch:
            return partial - 0.007
        default:
            return partial
        }
    }
}

private func ppText(_ value: Double) -> String {
    percentagePointText(value, allowZero: true) ?? "+0.0pp"
}

private func failureDiagnosisSection(outcome: GameOutcome, simulator: EconomicSimulator) -> InfoSection? {
    let s = simulator.state
    let card = simulator.scoreCard
    let hinge = hingeQuarterSnapshot(outcome: outcome, simulator: simulator)

    switch outcome {
    case .currencyCrisis:
        let hingeRow = hinge.map {
            String(format: "The run ended in %@, but it likely became unrecoverable around %@ when reserves were down to %.1f months and credibility to %.0f%%.", s.quarterLabel, $0.quarterLabel, $0.foreignReservesMonths, $0.credibility * 100)
        } ?? "The run ended in \(s.quarterLabel), and it likely became unrecoverable around the point when reserves and credibility could no longer be rebuilt."
        let hingeLever: String
        if card.lowestCredibility < 0.45 {
            hingeLever = "The real hinge was credibility: once it slipped under roughly 45%, later rate hikes stopped moving expectations enough to save the currency."
        } else if card.peakCapitalControls < 0.45 && card.peakPolicyRate < 0.10 {
            hingeLever = "The real hinge was early external defense: you never leaned hard enough on rates or controls while markets were still unsure."
        } else {
            hingeLever = "The real hinge was timing: by the time you defended in earnest, reserves were already too thin to make the defense believable."
        }
        return InfoSection(
            heading: "FAILURE DIAGNOSIS",
            rows: [
                hingeRow,
                hingeLever,
                String(format: "The external side was already failing: current account %+.1f%% GDP, capital account %+.1f%% GDP, with the SLD still under pressure.", s.currentAccountGDP * 100, s.capitalAccountGDP * 100),
                "Next time, defend earlier: tighten or control flows before reserves fall inside roughly two months, and keep communication credible so the market does not test you for free."
            ]
        )
    case .hyperinflation:
        let hingeRow = hinge.map {
            String(format: "The run ended in %@, but it was probably lost around %@ when inflation had already reached %.1f%% and credibility had slipped to %.0f%%.", s.quarterLabel, $0.quarterLabel, $0.inflation * 100, $0.credibility * 100)
        } ?? "The run ended in \(s.quarterLabel), and it was likely lost around the point when expectations could no longer be re-anchored."
        let hingeLever = card.peakPolicyRate < 0.10
            ? "The real hinge was the policy rate: you never tightened decisively enough while credibility was still spendable."
            : "The real hinge was expectations management: once inflation stayed high for too many quarters, later tightening had to work through a much worse expectation base."
        return InfoSection(
            heading: "FAILURE DIAGNOSIS",
            rows: [
                hingeRow,
                hingeLever,
                String(format: "You logged %d quarters above 10%% inflation, %d above 20%%, and credibility sank to %.0f%%.", card.highInflationQuarters, card.severeInflationQuarters, card.lowestCredibility * 100),
                "Next time, move earlier against spirals and avoid dovish or opaque messaging while inflation is still clearly above control."
            ]
        )
    case .depression:
        let hingeRow = hinge.map {
            String(format: "The run ended in %@, but it likely became unrecoverable around %@ when growth was already %+.1f%% and unemployment %.1f%%.", s.quarterLabel, $0.quarterLabel, $0.annualizedGDPGrowth * 100, $0.unemployment * 100)
        } ?? "The run ended in \(s.quarterLabel), and it likely became unrecoverable around the point when demand support could no longer catch up."
        let hingeLever = (card.peakPolicyRate > 0.15 || card.peakReserveRequirement > 0.16)
            ? "The real hinge was easing sooner: the economy spent too long carrying an overtight real stance and high reserve drag once slack had clearly opened."
            : "The real hinge was demand support: you never built enough recovery momentum before unemployment became politically and economically self-reinforcing."
        return InfoSection(
            heading: "FAILURE DIAGNOSIS",
            rows: [
                hingeRow,
                hingeLever,
                String(format: "Peak policy settings reached %.1f%% on rates and %.1f%% on reserve requirements, which suggests the economy stayed too tight for too long once slack opened up.", card.peakPolicyRate * 100, card.peakReserveRequirement * 100),
                "Next time, ease earlier when slack is unmistakable and use communication to support recovery rather than defending a slowdown that is already entrenched."
            ]
        )
    case .politicalOuster:
        let hingeRow = hinge.map {
            String(format: "The run ended in %@, but the coalition probably broke around %@ when political pressure hit %.0f and approval was %.0f%%.", s.quarterLabel, $0.quarterLabel, $0.politicalPressure, $0.publicApproval)
        } ?? "The run ended in \(s.quarterLabel), and political patience likely ran out around the point when the macro repair was no longer visible enough to save you."
        let dominantPain: String
        if card.peakInflation > 0.12 {
            dominantPain = "persistent inflation"
        } else if card.peakUnemployment > 0.10 || card.recessionQuarters >= 4 {
            dominantPain = "recession and unemployment"
        } else {
            dominantPain = "reserve and currency stress"
        }
        let hingeLever = dominantPain == "persistent inflation"
            ? "The real hinge was earlier visible inflation control. Once the public decided inflation was the story, later gains elsewhere no longer bought patience."
            : dominantPain == "recession and unemployment"
                ? "The real hinge was growth support. The economy stayed visibly weak for too long for your independence to survive."
                : "The real hinge was credibility under stress. Markets and politics were both testing you, and neither side believed the stabilization would arrive in time."
        return InfoSection(
            heading: "FAILURE DIAGNOSIS",
            rows: [
                hingeRow,
                hingeLever,
                "The main political wound was \(dominantPain), not just the final headline number on your scorecard.",
                "Next time, address the politically dominant problem earlier and keep communication aligned so you are not paying both economic pain and credibility damage at once."
            ]
        )
    case .success, .ongoing:
        return nil
    }
}

private func hingeQuarterSnapshot(outcome: GameOutcome, simulator: EconomicSimulator) -> QuarterSnapshot? {
    let snaps = simulator.log.quarterSnapshots
    guard !snaps.isEmpty else { return nil }

    switch outcome {
    case .currencyCrisis:
        return snaps.first {
            $0.foreignReservesMonths <= max(2.0, simulator.params.outcomes.currencyCrisisReserves + 0.8)
                || ($0.foreignReservesMonths <= 2.5 && $0.credibility <= 0.50)
        } ?? snaps.last
    case .hyperinflation:
        return snaps.first {
            $0.inflation >= 0.10 && $0.credibility <= 0.55
        } ?? snaps.first {
            $0.inflation >= 0.12
        } ?? snaps.last
    case .depression:
        return snaps.first {
            $0.annualizedGDPGrowth <= -0.03 && $0.unemployment >= 0.09
        } ?? snaps.first {
            $0.annualizedGDPGrowth <= -0.04
        } ?? snaps.last
    case .politicalOuster:
        return snaps.first {
            $0.politicalPressure >= simulator.params.outcomes.politicalOusterPressure * 0.80
                || $0.publicApproval <= 35
        } ?? snaps.last
    case .success, .ongoing:
        return nil
    }
}

private func syntheticQuarterReport(from simulator: EconomicSimulator,
                                    lastSnapshot: QuarterSnapshot,
                                    previousSnapshot: QuarterSnapshot?) -> QuarterReport {
    let before = economicState(from: previousSnapshot ?? lastSnapshot)
    let after = economicState(from: lastSnapshot)
    let news = Array(Array(simulator.log.fullNewsLog
        .filter { $0.hasPrefix("[\(lastSnapshot.quarterLabel)]") }
        .prefix(8))
        .reversed())
        .map(strippingQuarterPrefix)
    return QuarterReport(
        stateBefore: before,
        stateAfter: after,
        events: [],
        news: news
    )
}

private func economicState(from snapshot: QuarterSnapshot) -> EconomicState {
    var state = EconomicState()
    state.inflation = snapshot.inflation
    state.expectedInflation = snapshot.inflation
    state.outputGap = 0.0
    state.gdpGrowthQoQ = snapshot.annualizedGDPGrowth / 4.0
    state.unemployment = snapshot.unemployment
    state.foreignReservesMonths = snapshot.foreignReservesMonths
    state.policyRate = snapshot.policyRate
    state.capitalControls = snapshot.capitalControls
    state.exchangeRate = snapshot.exchangeRate
    state.credibility = snapshot.credibility
    state.publicApproval = snapshot.publicApproval
    state.politicalPressure = snapshot.politicalPressure
    if let parsed = parseQuarterLabel(snapshot.quarterLabel) {
        state.quarter = parsed.quarter
        state.year = parsed.year
    }
    return state
}

private func parseQuarterLabel(_ label: String) -> (quarter: Int, year: Int)? {
    let parts = label.split(separator: " ")
    guard parts.count == 2,
          let quarter = Int(parts[0].dropFirst()),
          let year = Int(parts[1]) else {
        return nil
    }
    return (quarter, year)
}

private func strippingQuarterPrefix(_ text: String) -> String {
    guard text.first == "[", let closing = text.firstIndex(of: "]") else { return text }
    let afterBracket = text.index(after: closing)
    return text[afterBracket...].trimmingCharacters(in: .whitespaces)
}

private func isPresentationQuarterHeadline(_ text: String) -> Bool {
    isPresentationEventHeadline(strippingQuarterPrefix(text))
}

func scenarioAssessmentSnapshot(for scenario: ScenarioDefinition,
                                goalStatuses: [ScenarioGoalStatus],
                                outcome: GameOutcome) -> ScenarioAssessmentSnapshot {
    let metCount = goalStatuses.filter(\.met).count
    let totalGoals = max(goalStatuses.count, 1)
    let ratio = Double(metCount) / Double(totalGoals)
    let missed = goalStatuses.filter { !$0.met }.map(\.description)

    let heading: String
    let severity: SeverityLevel
    let overview: String

    switch outcome {
    case .success where metCount == goalStatuses.count:
        heading = "LESSON MASTERED"
        severity = .good
        overview = "You met the scenario's objectives and handled its core tradeoff with discipline."
    case .success where ratio >= 0.67:
        heading = "STRONG BUT IMPERFECT"
        severity = .warning
        overview = "You held the system together and learned most of the lesson, but one weak flank remained."
    case .success where ratio > 0.0:
        heading = "PARTIAL COMMAND"
        severity = .warning
        overview = "You solved part of the scenario, but the underlying policy lesson was only partly absorbed."
    case .ongoing where ratio > 0.0:
        heading = "PARTIAL COMMAND"
        severity = .warning
        overview = "You solved part of the scenario, but the underlying policy lesson was only partly absorbed."
    default:
        heading = "LESSON MISSED"
        severity = .danger
        overview = "The run failed to secure the scenario's central tradeoff before the crisis or politics closed in."
    }

    return ScenarioAssessmentSnapshot(
        heading: heading,
        severity: severity,
        overview: overview,
        focus: scenario.teachingFocus,
        missedObjectives: missed
    )
}

private enum ComparisonStyle {
    case pct
    case ppSigned
    case ratio
    case months
    case fx
    case score
}

private func comparisonDescriptor(id: String,
                                  label: String,
                                  before: Double,
                                  after: Double,
                                  style: ComparisonStyle) -> ComparisonDescriptor {
    let delta = after - before
    let severity: SeverityLevel = abs(delta) < 1e-9 ? .neutral : (delta > 0 ? .warning : .good)
    switch style {
    case .pct:
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%.2f%%", before * 100),
            afterValue: String(format: "%.2f%%", after * 100),
            deltaText: String(format: "%+.2fpp", delta * 100),
            severity: severity,
            note: nil
        )
    case .ppSigned:
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%+.2f%%", before * 100),
            afterValue: String(format: "%+.2f%%", after * 100),
            deltaText: String(format: "%+.2fpp", delta * 100),
            severity: severity,
            note: nil
        )
    case .ratio:
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%.2f", before),
            afterValue: String(format: "%.2f", after),
            deltaText: String(format: "%+.3f", delta),
            severity: severity,
            note: nil
        )
    case .months:
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%.2f", before),
            afterValue: String(format: "%.2f", after),
            deltaText: String(format: "%+.2f", delta),
            severity: severity,
            note: nil
        )
    case .fx:
        let displayedBefore = displayedExchangeRate(before)
        let displayedAfter = displayedExchangeRate(after)
        let displayedDelta = displayedAfter - displayedBefore
        let displayedSeverity: SeverityLevel = abs(displayedDelta) < 1e-9 ? .neutral : (displayedDelta > 0 ? .good : .warning)
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%.3f USD/SLD", displayedBefore),
            afterValue: String(format: "%.3f USD/SLD", displayedAfter),
            deltaText: String(format: "%+.3f", displayedDelta),
            severity: displayedSeverity,
            note: nil
        )
    case .score:
        return ComparisonDescriptor(
            id: id,
            label: label,
            beforeValue: String(format: "%.1f", before),
            afterValue: String(format: "%.1f", after),
            deltaText: String(format: "%+.1f", delta),
            severity: severity,
            note: nil
        )
    }
}

private func recentQuarterSnapshot(_ snap: QuarterSnapshot) -> RecentQuarterSnapshot {
    RecentQuarterSnapshot(
        quarterLabel: snap.quarterLabel,
        inflation: String(format: "%5.1f%%", snap.inflation * 100),
        growth: String(format: "%+6.1f%%", snap.annualizedGDPGrowth * 100),
        unemployment: String(format: "%5.1f%%", snap.unemployment * 100),
        reserves: String(format: "%5.1f mo", snap.foreignReservesMonths),
        rate: String(format: "%4.1f%%", snap.policyRate * 100),
        pressure: String(format: "%5.0f", snap.politicalPressure)
    )
}

private func isPresentationEventHeadline(_ text: String) -> Bool {
    guard let colonIdx = text.firstIndex(of: ":") else { return false }
    let prefix = text[..<colonIdx]
    return prefix.count >= 3 && prefix.allSatisfy { $0.isUppercase || $0 == " " || $0 == "-" }
}

private func percentText(_ value: Double, decimals: Int = 1) -> String {
    String(format: "%.\(decimals)f%%", value * 100)
}

private func signedPercentText(_ value: Double, decimals: Int = 1) -> String {
    String(format: "%+.\(decimals)f%%", value * 100)
}

private func percentagePointText(_ value: Double, allowZero: Bool) -> String? {
    if !allowZero && abs(value) < 0.0001 {
        return nil
    }
    return String(format: "%+.\(1)fpp", value * 100)
}

package func displayedExchangeRate(_ internalRate: Double) -> Double {
    guard internalRate > 0 else { return 0.0 }
    return 1.0 / internalRate
}

package func displayedExchangeRateQoQChange(_ internalQoQChange: Double) -> Double {
    let denominator = 1.0 + internalQoQChange
    guard denominator > 0 else { return 0.0 }
    return (1.0 / denominator) - 1.0
}

private func trendDirection(_ history: [Double]) -> TrendDirection? {
    guard history.count >= 2 else { return nil }
    let delta = history.last! - history[history.count - 2]
    if abs(delta) < 0.001 { return .flat }
    return delta > 0 ? .up : .down
}

private func growthSeverity(_ value: Double) -> SeverityLevel {
    value > 0.025 ? .good : (value > -0.01 ? .warning : .danger)
}

private func unemploymentSeverity(_ value: Double) -> SeverityLevel {
    value < 0.07 ? .good : (value < 0.10 ? .warning : .danger)
}

private func inflationSeverity(_ value: Double) -> SeverityLevel {
    value < 0.05 ? .good : (value < 0.10 ? .warning : .danger)
}

private func expectedInflationSeverity(_ value: Double) -> SeverityLevel {
    value < 0.05 ? .good : (value < 0.08 ? .warning : .danger)
}

private func inflationSurpriseSeverity(_ value: Double) -> SeverityLevel {
    value > 0.005 ? .danger : (value < -0.005 ? .good : .warning)
}

private func realRateSeverity(_ value: Double) -> SeverityLevel {
    value > 0.005 ? .good : (value > -0.02 ? .warning : .danger)
}

private func credibilitySeverity(_ value: Double) -> SeverityLevel {
    value > 0.6 ? .good : (value > 0.35 ? .warning : .danger)
}

private func communicationSeverity(_ stance: CommunicationStance) -> SeverityLevel {
    switch stance {
    case .balanced: return .good
    case .hawkish: return .neutral
    case .dovish: return .warning
    case .opaque: return .danger
    }
}

private func reservesSeverity(_ value: Double) -> SeverityLevel {
    value > 4.0 ? .good : (value > 2.5 ? .warning : .danger)
}

private func exchangeRateSeverity(_ qoqChange: Double) -> SeverityLevel {
    qoqChange > 0.04 ? .danger : (qoqChange > 0.0 ? .warning : .good)
}

private func currentAccountSeverity(_ value: Double) -> SeverityLevel {
    value > -0.02 ? .good : (value > -0.05 ? .warning : .danger)
}

private func politicalPressureSeverity(_ value: Double, threshold: Double) -> SeverityLevel {
    value < threshold * 0.4 ? .good : (value < threshold * 0.75 ? .warning : .danger)
}

private func approvalSeverity(_ value: Double) -> SeverityLevel {
    value > 55 ? .good : (value > 35 ? .warning : .danger)
}

private func capitalControlsLabel(_ value: Double) -> String {
    switch value {
    case 0.0..<0.20: return "MINIMAL"
    case 0.20..<0.45: return "MODERATE"
    case 0.45..<0.70: return "SUBSTANTIAL"
    default: return "COMPREHENSIVE"
    }
}

private func capitalControlsSeverity(_ value: Double) -> SeverityLevel {
    switch value {
    case 0.0..<0.20: return .warning
    case 0.20..<0.45: return .warning
    case 0.45..<0.70: return .warning
    default: return .danger
    }
}

private func oilSeverity(_ value: Double) -> SeverityLevel {
    value < 200 ? .good : (value < 350 ? .warning : .danger)
}

private func debtSeverity(_ value: Double) -> SeverityLevel {
    value < 0.45 ? .good : (value < 0.65 ? .warning : .danger)
}

private func fiscalSeverity(_ value: Double) -> SeverityLevel {
    value > -0.03 ? .good : (value > -0.06 ? .warning : .danger)
}

private func dashboardAdvisoryMessage(for simulator: EconomicSimulator) -> String {
    let s = simulator.state
    let crisisMeasures = simulator.availableCrisisMeasures()
    if simulator.activeCabinetRequest != nil {
        return "Cabinet pending. Use cabinet, accept, reject, or delay."
    }
    if !crisisMeasures.isEmpty {
        return "Crisis tools available. Use crisis, then measure <name>."
    }
    if simulator.crisisCooldownQuarters > 0 {
        return "Crisis tools cooling down. Use the runway to stabilize the economy."
    }
    if simulator.communicationStance == .hawkish && !simulator.isHawkishCommunicationConsistent(state: s) {
        return "Warning: hawkish guidance is not matched by current policy."
    }
    if simulator.communicationStance != .balanced {
        return "Communication stance stays active until you change it."
    }
    return "Tip: use preview with overrides before advance when conditions feel unstable."
}

private func makeDashboardActionSections(simulator: EconomicSimulator,
                                         hasCabinetRequest: Bool,
                                         crisisMenuRelevant: Bool,
                                         crisisMeasures: [CrisisMeasure]) -> [ActionSectionDescriptor] {
    let crisisMeasureActions: [ActionDescriptor]
    if !crisisMeasures.isEmpty {
        crisisMeasureActions = crisisMeasures.map {
            ActionDescriptor(
                id: "crisis.measure.\($0.type.commandName)",
                label: "measure",
                argumentHint: $0.type.commandName,
                availability: .recommended,
                reasonIfUnavailable: nil,
                group: .crisis
            )
        }
    } else if simulator.crisisCooldownQuarters > 0 {
        crisisMeasureActions = [
            ActionDescriptor(
                id: "crisis.measure",
                label: "measure",
                argumentHint: "<cooldown>",
                availability: .cooldown,
                reasonIfUnavailable: "Crisis tools are cooling down for \(simulator.crisisCooldownQuarters) more quarters.",
                group: .crisis
            )
        ]
    } else {
        crisisMeasureActions = [
            ActionDescriptor(
                id: "crisis.measure",
                label: "measure",
                argumentHint: "<locked>",
                availability: .locked,
                reasonIfUnavailable: "Crisis tools unlock only under severe stress.",
                group: .crisis
            )
        ]
    }

    return [
        ActionSectionDescriptor(
            group: .policy,
            title: ActionGroup.policy.title,
            actions: [
                ActionDescriptor(id: "rate", label: "rate", argumentHint: "<x.x>", availability: .available, reasonIfUnavailable: nil, group: .policy),
                ActionDescriptor(id: "reserve", label: "reserve", argumentHint: "<x>", availability: .available, reasonIfUnavailable: nil, group: .policy),
                ActionDescriptor(id: "controls", label: "controls", argumentHint: "<0-10>", availability: .available, reasonIfUnavailable: nil, group: .policy),
                ActionDescriptor(id: "intervene", label: "intervene", argumentHint: "<±x.x>", availability: .available, reasonIfUnavailable: nil, group: .policy)
            ]
        ),
        ActionSectionDescriptor(
            group: .next,
            title: ActionGroup.next.title,
            actions: [
                ActionDescriptor(id: "preview", label: "preview (p)", argumentHint: "[overrides]", availability: .available, reasonIfUnavailable: nil, group: .next),
                ActionDescriptor(id: "advance", label: "advance (n)", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .next),
                ActionDescriptor(id: "comm", label: "comm", argumentHint: "<stance>", availability: .available, reasonIfUnavailable: nil, group: .next)
            ]
        ),
        ActionSectionDescriptor(
            group: .cabinet,
            title: ActionGroup.cabinet.title,
            actions: [
                ActionDescriptor(id: "cabinet", label: "cabinet", argumentHint: nil, availability: hasCabinetRequest ? .recommended : .dormant, reasonIfUnavailable: hasCabinetRequest ? nil : "No cabinet request is active.", group: .cabinet),
                ActionDescriptor(id: "cabinet.accept", label: "accept", argumentHint: nil, availability: hasCabinetRequest ? .recommended : .dormant, reasonIfUnavailable: hasCabinetRequest ? nil : "No cabinet request is active.", group: .cabinet),
                ActionDescriptor(id: "cabinet.reject", label: "reject", argumentHint: nil, availability: hasCabinetRequest ? .recommended : .dormant, reasonIfUnavailable: hasCabinetRequest ? nil : "No cabinet request is active.", group: .cabinet),
                ActionDescriptor(id: "cabinet.delay", label: "delay", argumentHint: nil, availability: hasCabinetRequest ? .recommended : .dormant, reasonIfUnavailable: hasCabinetRequest ? nil : "No cabinet request is active.", group: .cabinet)
            ]
        ),
        ActionSectionDescriptor(
            group: .crisis,
            title: ActionGroup.crisis.title,
            actions: [
                ActionDescriptor(id: "crisis", label: "crisis", argumentHint: nil, availability: crisisMenuRelevant ? .recommended : .dormant, reasonIfUnavailable: crisisMenuRelevant ? nil : "No crisis tools are relevant right now.", group: .crisis)
            ] + crisisMeasureActions
        ),
        ActionSectionDescriptor(
            group: .info,
            title: ActionGroup.info.title,
            actions: [
                ActionDescriptor(id: "status", label: "status", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "history", label: "history", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "news", label: "news", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "report", label: "report", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "debrief", label: "why", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "advisor", label: "advisor", argumentHint: "[topic]", availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "tutorial", label: "tutorial", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info),
                ActionDescriptor(id: "help", label: "help", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .info)
            ]
        ),
        ActionSectionDescriptor(
            group: .files,
            title: ActionGroup.files.title,
            actions: [
                ActionDescriptor(id: "save", label: "save", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .files),
                ActionDescriptor(id: "load", label: "load", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .files),
                ActionDescriptor(id: "quit", label: "quit", argumentHint: nil, availability: .available, reasonIfUnavailable: nil, group: .files)
            ]
        )
    ]
}

private func debriefInterpretations(simulator: EconomicSimulator,
                                    lastQuarterEntries: [String],
                                    lastSnapshot: QuarterSnapshot,
                                    previousSnapshot: QuarterSnapshot?) -> [String] {
    let s = simulator.state
    let inflationMove = s.inflationDelta * 100
    let gapMove = s.outputGapDelta * 100
    let reservesMove = previousSnapshot.map { lastSnapshot.foreignReservesMonths - $0.foreignReservesMonths } ?? 0.0
    let approvalMove = previousSnapshot.map { lastSnapshot.publicApproval - $0.publicApproval } ?? 0.0
    let pressureMove = previousSnapshot.map { lastSnapshot.politicalPressure - $0.politicalPressure } ?? 0.0
    var interpretations: [String] = []

    if inflationMove > 0.3 {
        if s.exchangeRateQoQChange > 0.02 {
            interpretations.append("Inflation rose because the Solan Dollar weakened and imported prices passed through.")
        } else if lastQuarterEntries.contains(where: { $0.contains("OIL SHOCK") || $0.contains("AGRICULTURAL CRISIS") || $0.contains("GENERAL STRIKE") }) {
            interpretations.append("Inflation rose mainly from a supply shock rather than domestic overheating.")
        } else if s.realInterestRate < 0 {
            interpretations.append("Inflation rose while real rates stayed soft, so policy was not restraining demand enough.")
        } else {
            interpretations.append("Inflation rose despite tighter conditions, which suggests expectations or shocks are still dominating.")
        }
    } else if inflationMove < -0.3 {
        if s.outputGap < 0 {
            interpretations.append("Inflation fell because slack in the economy and tighter conditions are starting to bite.")
        } else {
            interpretations.append("Inflation eased, which gives you some room to stabilize growth or rebuild reserves.")
        }
    } else {
        interpretations.append("Inflation was broadly stable this quarter, so the bigger story was elsewhere.")
    }

    if gapMove < -0.7 {
        if s.realInterestRate > simulator.params.outputGap.neutralRealRate {
            interpretations.append("Growth weakened because policy is restrictive relative to the economy's neutral rate.")
        } else if lastQuarterEntries.contains(where: { $0.contains("EXTERNAL DOWNTURN") || $0.contains("TOURISM COLLAPSE") || $0.contains("CREDIT CRUNCH") }) {
            interpretations.append("Growth weakened mainly from an external or financial hit rather than your own policy choices.")
        } else {
            interpretations.append("Activity softened, so the economy is carrying more recession pressure into the new quarter.")
        }
    } else if gapMove > 0.7 {
        interpretations.append("Growth strengthened, which supports jobs now but can make inflation and the external balance harder to control.")
    }

    if reservesMove < -0.2 {
        if s.currentAccountGDP < -0.03 {
            interpretations.append("Reserves fell because the balance of payments is still too weak to finance imports and debt service comfortably.")
        }
        if lastQuarterEntries.contains(where: { $0.contains("SPECULATIVE ATTACK") || $0.contains("CAPITAL FLIGHT") }) {
            interpretations.append("Reserves were hit by market pressure or flight, so exchange-rate defense is carrying a real cost.")
        } else if s.capitalAccountGDP < 0 {
            interpretations.append("Reserves fell because private capital is leaving or refusing to roll over at comfortable terms.")
        }
    } else if reservesMove > 0.2 {
        interpretations.append("Reserves improved, which gives you more room to defend the currency or absorb another shock.")
    }

    if approvalMove < -1.5 || pressureMove > 2.0 {
        interpretations.append("Politics worsened this quarter, so even technically sound policy may become harder to sustain.")
    } else if approvalMove > 1.5 || pressureMove < -2.0 {
        interpretations.append("The political environment improved, which buys you some room for harder decisions later.")
    }

    if lastQuarterEntries.contains(where: { $0.contains("COMMUNICATION: Hawkish rhetoric rings hollow") }) {
        interpretations.append("Your communication stance backfired because markets saw a mismatch between rhetoric and policy.")
    } else if lastQuarterEntries.contains(where: { $0.contains("COMMUNICATION: Hawkish anti-inflation guidance reinforced") }) {
        interpretations.append("Communication helped because your anti-inflation message was backed by actual policy restraint.")
    }

    return Array(interpretations.prefix(5))
}
