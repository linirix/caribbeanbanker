import XCTest
@testable import CentralBankerCore

// Five "golden path" tests that pin down core sim dynamics. They are not
// exhaustive — they exist so that a parameter-tuning pass (e.g. changing
// Phillips slope, credibility decrements, or IS sensitivities) cannot
// silently break the fundamentals:
//
//   1. Same seed + same inputs = identical state (the RNG injection guarantee).
//   2. A baseline, shock-free decade stays numerically well-behaved.
//   3. Tight money cools the output gap, relative to an easy-money twin run.
//   4. An oil shock raises inflation, relative to a shock-free twin run.
//   5. An inflation surprise erodes credibility.
//
// Each diff-style test (3 and 4) pairs two runs with an identical seed so the
// stochastic noise draws align across runs — the only difference is the
// treatment under test. That's what makes tiny expected effects observable.

final class EconomyTests: XCTestCase {

    // A fixed seed so every test in this file is deterministic and reproducible.
    private let testSeed: UInt64 = 0xC0FFEE_1973

    // Run one quarter of the default economy, with the given events.
    private func stepQuarter(_ sim: EconomicSimulator, events: [EconomicEvent] = []) {
        sim.simulateQuarter(events: events)
    }

    private func renderedLines(_ rendered: String) -> [String] {
        rendered
            .replacingOccurrences(of: A.clearScreen, with: "")
            .components(separatedBy: "\n")
    }

    private func assertRenderedScreenFits(_ rendered: String,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) {
        for row in renderedLines(rendered) {
            XCTAssertLessThanOrEqual(
                displayVisualWidth(row),
                displayFrameWidth,
                "Rendered row exceeded frame width: \(row)",
                file: file,
                line: line)
        }
    }

    // MARK: - 1. Determinism

    func testSameSeedProducesIdenticalState() {
        let a = EconomicSimulator(seed: testSeed)
        let b = EconomicSimulator(seed: testSeed)

        for _ in 0..<8 {
            stepQuarter(a)
            stepQuarter(b)
        }

        XCTAssertEqual(a.state.inflation, b.state.inflation, accuracy: 1e-12,
                       "Determinism: inflation diverged under identical seeds.")
        XCTAssertEqual(a.state.outputGap, b.state.outputGap, accuracy: 1e-12)
        XCTAssertEqual(a.state.unemployment, b.state.unemployment, accuracy: 1e-12)
        XCTAssertEqual(a.state.exchangeRate, b.state.exchangeRate, accuracy: 1e-12)
        XCTAssertEqual(a.state.credibility, b.state.credibility, accuracy: 1e-12)
        XCTAssertEqual(a.state.foreignReservesMonths, b.state.foreignReservesMonths, accuracy: 1e-12)
        XCTAssertEqual(a.state.publicApproval, b.state.publicApproval, accuracy: 1e-12)
    }

    func testOpeningGrowthIsModeAwareAndDeterministic() {
        let historical = openingAnnualizedGDPGrowth(
            mode: .historical,
            sessionSeed: testSeed,
            params: .default)
        XCTAssertEqual(historical, 0.042, accuracy: 1e-12,
                       "Historical mode should start from a fixed plausible growth rate.")

        let randomizedA = openingAnnualizedGDPGrowth(
            mode: .randomized,
            sessionSeed: testSeed,
            params: .default)
        let randomizedB = openingAnnualizedGDPGrowth(
            mode: .randomized,
            sessionSeed: testSeed,
            params: .default)
        XCTAssertEqual(randomizedA, randomizedB, accuracy: 1e-12,
                       "Randomized opening growth should still be deterministic for a fixed seed.")
        XCTAssertGreaterThanOrEqual(randomizedA, 0.015)
        XCTAssertLessThanOrEqual(randomizedA, 0.060)

        let extendedHistorical = openingAnnualizedGDPGrowth(
            mode: .historical,
            gameLength: .extended,
            sessionSeed: testSeed,
            params: .default)
        XCTAssertEqual(extendedHistorical, 0.048, accuracy: 1e-12,
                       "Extended historical mode should start from its own fixed opening pace.")
    }

    func testOpeningConditionsSetTimelineStartYear() {
        let short = EconomicSimulator(seed: testSeed)
        applyOpeningConditions(to: short, mode: .historical, gameLength: .short, sessionSeed: testSeed)
        XCTAssertEqual(short.state.year, 1973)
        XCTAssertEqual(short.state.quarter, 1)

        let extended = EconomicSimulator(seed: testSeed)
        applyOpeningConditions(to: extended, mode: .historical, gameLength: .extended, sessionSeed: testSeed)
        XCTAssertEqual(extended.state.year, 1960)
        XCTAssertEqual(extended.state.quarter, 1)
        XCTAssertGreaterThan(extended.state.foreignReservesMonths, short.state.foreignReservesMonths)
        XCTAssertLessThan(extended.state.inflation, short.state.inflation)
        XCTAssertLessThan(extended.state.externalDebtGDP, short.state.externalDebtGDP)
    }

    func testScenarioOpeningConditionsApplyOverrides() {
        let sim = EconomicSimulator(seed: testSeed)
        applyOpeningConditions(
            to: sim,
            mode: .historical,
            gameLength: .short,
            scenarioID: "oil_shock_1973",
            sessionSeed: testSeed)

        XCTAssertEqual(sim.state.year, 1973)
        XCTAssertEqual(sim.state.quarter, 3)
        XCTAssertEqual(sim.state.inflation, 0.071, accuracy: 1e-12)
        XCTAssertEqual(sim.state.foreignReservesMonths, 3.3, accuracy: 1e-12)
        XCTAssertEqual(sim.environment.oilPriceIndex, 145.0, accuracy: 1e-12)
        XCTAssertEqual(sim.state.annualizedGDPGrowth, 0.024, accuracy: 1e-12)
    }

    func testCLIParsesLengthFlag() throws {
        let options = try parseCLIArgs(["CentralBanker", "--length", "extended", "--mode", "r"])
        XCTAssertEqual(options.length, .extended)
        XCTAssertEqual(options.mode, .randomized)
    }

    func testCLIParsesHistoricalScenarioAndAdoptsItsTimeline() throws {
        let options = try parseCLIArgs(["CentralBanker", "--scenario", "oil_shock_1973"])
        XCTAssertEqual(options.mode, .historical)
        XCTAssertEqual(options.length, .short)
        XCTAssertEqual(options.scenarioID, "oil_shock_1973")
    }

    // The whole point of moving parsing to a pure throwing function is that
    // invalid input can be asserted on directly — no stdio mocking, no
    // process-exit side effect. These pin that contract.
    func testCLIRejectsInvalidFlagsWithStructuredErrors() {
        XCTAssertThrowsError(try parseCLIArgs(["CentralBanker", "--mode", "bogus"])) { err in
            guard case CLIParseError.invalidValue(let flag, let got, _) = err else {
                return XCTFail("Expected .invalidValue, got \(err)")
            }
            XCTAssertEqual(flag, "--mode")
            XCTAssertEqual(got, "bogus")
        }
        XCTAssertThrowsError(try parseCLIArgs(["CentralBanker", "--seed"])) { err in
            guard case CLIParseError.missingArgument(let flag, _) = err else {
                return XCTFail("Expected .missingArgument, got \(err)")
            }
            XCTAssertEqual(flag, "--seed")
        }
        XCTAssertThrowsError(try parseCLIArgs(["CentralBanker", "--nonsense"])) { err in
            guard case CLIParseError.unknownArgument(let a) = err else {
                return XCTFail("Expected .unknownArgument, got \(err)")
            }
            XCTAssertEqual(a, "--nonsense")
        }
        XCTAssertThrowsError(try parseCLIArgs(["CentralBanker", "--help"])) { err in
            guard case CLIParseError.helpRequested = err else {
                return XCTFail("Expected .helpRequested, got \(err)")
            }
        }
        // Scenario + randomized mode is a logic conflict, not a typo.
        XCTAssertThrowsError(try parseCLIArgs(["CentralBanker", "--mode", "r", "--scenario", "oil_shock_1973"])) { err in
            guard case CLIParseError.scenarioModeConflict = err else {
                return XCTFail("Expected .scenarioModeConflict, got \(err)")
            }
        }
    }

    func testParseAdvisorCommandSupportsTargetedTopics() {
        switch parseCommand("advisor balance of payments") {
        case .advisor(let topic):
            XCTAssertEqual(topic, "balance of payments")
        default:
            XCTFail("Expected advisor command with preserved topic text.")
        }
    }

    func testExternalTuningConfigLoads() {
        XCTAssertEqual(GameConfigs.difficulty(.governor).displayName, "Governor")
        XCTAssertFalse(GameConfigs.tuning.randomEvents.commonPool.isEmpty)
        XCTAssertEqual(GameConfigs.tuning.crisis.cooldownQuarters, 4)
        XCTAssertEqual(GameConfigs.historicalTrack(for: .short).worldRate(for: 1979) ?? 0.0, 0.11, accuracy: 1e-12)
        XCTAssertEqual(GameConfigs.scenario(id: "oil_shock_1973")?.title, "First Oil Shock")
        XCTAssertEqual(GameConfigs.scenario(id: "soft_landing_1966")?.title, "Soft Landing Lesson")
        XCTAssertEqual(GameConfigs.scenario(id: "bretton_break_1971")?.title, "Bretton Woods Break")
    }

    func testScenarioCatalogIsExpandedAcrossBothTimelines() {
        XCTAssertGreaterThanOrEqual(scenarioDefinitions(for: .short).count, 8)
        XCTAssertGreaterThanOrEqual(scenarioDefinitions(for: .extended).count, 4)

        let shortIDs = Set(scenarioDefinitions(for: .short).map(\.id))
        let extendedIDs = Set(scenarioDefinitions(for: .extended).map(\.id))

        XCTAssertTrue(shortIDs.contains("soft_landing_1966"))
        XCTAssertTrue(shortIDs.contains("wage_spiral_1976"))
        XCTAssertTrue(shortIDs.contains("reserve_run_1981"))
        XCTAssertTrue(shortIDs.contains("debt_workout_1984"))
        XCTAssertTrue(shortIDs.contains("recession_relief_1991"))
        XCTAssertTrue(shortIDs.contains("confidence_rebuild_1998"))
        XCTAssertTrue(extendedIDs.contains("bretton_break_1971"))
        XCTAssertTrue(extendedIDs.contains("lost_decade_recovery_1985"))
    }

    func testScenarioCompletionAndGoalEvaluation() {
        var state = EconomicState()
        state.year = 1976
        state.quarter = 1
        state.inflation = 0.07
        state.foreignReservesMonths = 3.0
        state.politicalPressure = 55.0

        XCTAssertTrue(isCampaignComplete(state: state, gameLength: .short, scenarioID: "oil_shock_1973"))

        let goals = evaluateScenarioGoals(scenarioID: "oil_shock_1973", state: state)
        XCTAssertEqual(goals.count, 3)
        XCTAssertTrue(goals.allSatisfy(\.met))
    }

    func testGameSessionBootstrapsScenarioAndRoundTripsSave() {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            scenarioID: "oil_shock_1973",
            sessionSeed: testSeed)

        XCTAssertEqual(session.mode, .historical)
        XCTAssertEqual(session.gameLength, .short)
        XCTAssertEqual(session.scenarioID, "oil_shock_1973")
        XCTAssertEqual(session.simulator.state.year, 1973)
        XCTAssertEqual(session.simulator.state.quarter, 3)
        XCTAssertEqual(session.simulator.state.annualizedGDPGrowth, 0.024, accuracy: 1e-12)

        let reloaded = GameSession(save: session.makeSave())
        XCTAssertEqual(reloaded.sessionSeed, testSeed)
        XCTAssertEqual(reloaded.scenarioID, "oil_shock_1973")
        XCTAssertEqual(reloaded.simulator.state.year, 1973)
        XCTAssertEqual(reloaded.simulator.state.quarter, 3)
    }

    func testLateHistoricalScenarioDoesNotAutoSucceedOnStart() {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            scenarioID: "debt_workout_1984",
            sessionSeed: testSeed)

        XCTAssertEqual(session.simulator.state.year, 1984)
        XCTAssertEqual(session.currentOutcome(), .ongoing,
                       "Scenario runs that start after the generic campaign success year must not auto-complete.")
    }

    func testBalanceHarnessScenarioRunUsesScenarioSession() {
        let result = runBalanceGame(
            gameLength: .short,
            mode: .historical,
            difficulty: .governor,
            bot: .passive,
            seed: testSeed,
            scenarioID: "oil_shock_1973")

        XCTAssertEqual(result.scenarioID, "oil_shock_1973")
        XCTAssertEqual(result.scenarioTitle, "First Oil Shock")
        XCTAssertEqual(result.mode, .historical)
        XCTAssertEqual(result.gameLength, .short)
        XCTAssertGreaterThan(result.quartersSimulated, 0)
    }

    func testRenderedDashboardFitsFrameAndShowsAdvisory() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.communicationStance = .hawkish
        sim.activeCabinetRequest = CabinetRequest(
            type: .tightenControls,
            detail: "Cabinet wants tighter controls after market stress.")
        sim.state.inflation = 0.091
        sim.state.expectedInflation = 0.052
        sim.state.foreignReservesMonths = 1.7
        sim.state.politicalPressure = 78
        sim.log.addNews("SPECULATIVE ATTACK: Markets are probing the peg.", quarterLabel: sim.state.quarterLabel)

        let rendered = renderDashboard(makeDashboardSnapshot(simulator: sim))

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains("GOVERNOR'S DASHBOARD"))
        XCTAssertTrue(rendered.contains("Cabinet pending. Use cabinet, accept, reject, or delay."))
        XCTAssertTrue(rendered.contains("POLICY:"))
        XCTAssertTrue(rendered.contains("CABINET:"))
        XCTAssertTrue(rendered.contains("CRISIS:"))
        XCTAssertTrue(rendered.contains("Yellow = relevant now."))
        XCTAssertTrue(rendered.contains("rate <x.x>"))
        XCTAssertTrue(rendered.contains("intervene <±x.x>"))
    }

    func testDashboardSnapshotReflectsCabinetAndCrisisAvailability() throws {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            sessionSeed: testSeed)
        let sim = session.simulator
        sim.activeCabinetRequest = CabinetRequest(
            type: .tightenControls,
            detail: "Cabinet wants tighter controls after market stress.")
        sim.state.foreignReservesMonths = 0.7
        sim.state.exchangeRateQoQChange = 0.08
        sim.state.externalDebtGDP = 0.76
        sim.state.publicApproval = 30
        sim.state.politicalPressure = 82

        let snapshot = session.makeDashboardSnapshot()
        let cabinetSection = try XCTUnwrap(snapshot.actionSections.first(where: { $0.group == .cabinet }))
        let crisisSection = try XCTUnwrap(snapshot.actionSections.first(where: { $0.group == .crisis }))

        XCTAssertTrue(cabinetSection.actions.contains(where: { $0.id == "cabinet.accept" && $0.availability == .recommended }))
        XCTAssertTrue(crisisSection.actions.contains(where: { $0.id == "crisis" && $0.availability == .recommended }))
        XCTAssertTrue(crisisSection.actions.contains(where: { $0.label == "measure" && $0.argumentHint != nil && $0.argumentHint != "<locked>" }))
        XCTAssertTrue(snapshot.advisorySections.flatMap(\.rows).contains(where: { $0.contains("Cabinet pending") }))
    }

    func testRenderedDashboardShowsAvailableCrisisMeasureNames() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.foreignReservesMonths = 0.7
        sim.state.exchangeRateQoQChange = 0.08
        sim.state.externalDebtGDP = 0.78
        sim.state.outputGap = -0.05
        sim.state.unemployment = 0.11
        sim.state.publicApproval = 31
        sim.state.politicalPressure = 83

        let available = sim.availableCrisisMeasures()
        XCTAssertFalse(available.isEmpty, "Expected severe stress to unlock at least one crisis measure.")

        let rendered = renderDashboard(makeDashboardSnapshot(simulator: sim))
        let expectedHint = "measure " + available.map(\.type.commandName).joined(separator: "|")

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains(expectedHint))
    }

    func testRenderedHelpFitsFrameAndRetainsSections() {
        let rendered = renderHelp(makeHelpSnapshot(gameLength: .extended))

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains("HELP & REFERENCE"))
        XCTAssertTrue(rendered.contains("WHAT THE MAIN METRICS MEAN"))
        XCTAssertTrue(rendered.contains("HOW TO MOVE THEM"))
        XCTAssertTrue(rendered.contains("CRISIS MEASURES"))
    }

    func testRenderedAdvisorFitsFrameAndShowsGuidance() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.foreignReservesMonths = 0.9
        sim.state.exchangeRateQoQChange = 0.07
        sim.state.externalDebtGDP = 0.74
        sim.state.currentAccountGDP = -0.052

        let rendered = renderAdvisor(makeAdvisorSnapshot(simulator: sim, topicText: "currency"))

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains("STAFF ADVISOR"))
        XCTAssertTrue(rendered.contains("Requested focus: Currency Defense"))
        XCTAssertTrue(rendered.contains("Most urgent right now:"))
        XCTAssertTrue(rendered.contains("Indicative rate guidance:"))
        XCTAssertTrue(rendered.contains("Recommended levers:"))
    }

    func testRenderedScenarioBriefingFitsFrame() {
        guard let scenario = scenarioDefinition(id: "soft_landing_1966") else {
            return XCTFail("Expected soft_landing_1966 scenario to exist.")
        }

        let rendered = renderScenarioBriefing(makeScenarioBriefingSnapshot(scenario: scenario))

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains("HISTORICAL SCENARIO"))
        XCTAssertTrue(rendered.contains(scenario.title.uppercased()))
        XCTAssertTrue(rendered.contains("Teaching focus:"))
        XCTAssertTrue(rendered.contains("Objectives:"))
    }

    func testRenderedReportDebriefAndTutorialFitFrame() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.inflation = 0.082
        sim.state.expectedInflation = 0.070
        sim.state.outputGap = -0.01
        stepQuarter(sim)
        sim.communicationStance = .hawkish
        stepQuarter(sim)

        let report = renderCampaignReport(makeReportSnapshot(simulator: sim, gameLength: .short))
        let debrief = renderQuarterDebrief(makeDebriefSnapshot(simulator: sim))
        let tutorial = renderTutorial(makeTutorialSnapshot(simulator: sim, mode: .historical, gameLength: .short))

        assertRenderedScreenFits(report)
        assertRenderedScreenFits(debrief)
        assertRenderedScreenFits(tutorial)
        XCTAssertTrue(report.contains("CAMPAIGN REPORT"))
        XCTAssertTrue(debrief.contains("WHY THINGS MOVED"))
        XCTAssertTrue(tutorial.contains("GUIDED TUTORIAL"))
    }

    func testRenderedHistoryAndNewsFitFrame() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.log.addNews("OIL SHOCK: Imported fuel costs are rising fast across the island economy.", quarterLabel: sim.state.quarterLabel)
        stepQuarter(sim)
        sim.log.addNews("CABINET REQUEST: Ministers want immediate relief before approval erodes further.", quarterLabel: sim.state.quarterLabel)
        stepQuarter(sim)

        let history = renderHistory(makeHistorySnapshot(simulator: sim))
        let news = renderNewsLog(makeNewsSnapshot(simulator: sim))

        assertRenderedScreenFits(history)
        assertRenderedScreenFits(news)
        XCTAssertTrue(history.contains("ECONOMIC HISTORY"))
        XCTAssertTrue(history.contains("RECENT QUARTER TABLE"))
        XCTAssertTrue(news.contains("FULL NEWS LOG"))
        XCTAssertTrue(news.contains("OIL SHOCK"))
    }

    func testRenderedStatusAndCrisisFitFrame() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.foreignReservesMonths = 0.8
        sim.state.exchangeRateQoQChange = 0.07
        sim.state.externalDebtGDP = 0.74
        sim.state.publicApproval = 33
        sim.state.politicalPressure = 81

        let status = renderStatus(makeStatusSnapshot(simulator: sim, gameLength: .extended, scenarioID: "debt_crisis_1982"))
        let crisis = renderCrisisOptions(makeCrisisOptionsSnapshot(simulator: sim))

        assertRenderedScreenFits(status)
        assertRenderedScreenFits(crisis)
        XCTAssertTrue(status.contains("EXTENDED ECONOMIC BRIEFING"))
        XCTAssertTrue(status.contains("Scenario:              Debt Crisis"))
        XCTAssertTrue(crisis.contains("CRISIS OPTIONS"))
        XCTAssertTrue(crisis.contains("measure"))
    }

    func testRenderedPreviewFitsFrameAndShowsForecastSections() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.inflation = 0.094
        sim.state.expectedInflation = 0.071
        sim.state.foreignReservesMonths = 1.4
        sim.state.exchangeRateQoQChange = 0.035

        let report = previewNextQuarter(
            of: sim,
            mode: .historical,
            gameLength: .short,
            macroSchedule: [:],
            rateSchedule: [:])
        let estimate = forecastEstimate(for: report, sessionSeed: testSeed)
        let preview = renderPreview(makePreviewSnapshot(estimate: estimate, headerNote: "Hypothetical: rate 11.5"))

        assertRenderedScreenFits(preview)
        XCTAssertTrue(preview.contains("STAFF FORECAST"))
        XCTAssertTrue(preview.contains("Events this quarter"))
        XCTAssertTrue(preview.contains("Indicator"))
        XCTAssertTrue(preview.contains("Hypothetical: rate 11.5"))
    }

    func testPreviewSnapshotIsNonMutatingAndCarriesHypotheticalHeader() {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            sessionSeed: testSeed)
        let originalRate = session.simulator.state.policyRate

        let snapshot = session.makePreviewSnapshot(changes: [.rate(0.115), .controls(0.6)])

        XCTAssertEqual(session.simulator.state.policyRate, originalRate, accuracy: 1e-12)
        XCTAssertEqual(snapshot.headerNote, "Hypothetical: rate 11.50%  |  controls 6/10")
        XCTAssertFalse(snapshot.projections.isEmpty)
        XCTAssertTrue(snapshot.title.contains("STAFF FORECAST"))
    }

    func testRenderedGameOverFitsFrame() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.year = 1982
        sim.state.quarter = 4
        sim.state.inflation = 0.084
        sim.state.unemployment = 0.091
        sim.state.foreignReservesMonths = 2.2
        sim.scoreCard.quartersSimulated = 36
        sim.scoreCard.peakInflation = 0.18
        sim.scoreCard.troughGrowthAnnualized = -0.06
        sim.scoreCard.peakUnemployment = 0.11
        sim.scoreCard.lowestCredibility = 0.31
        sim.scoreCard.lowestReserves = 1.4
        sim.scoreCard.peakPoliticalPressure = 66
        sim.scoreCard.peakPolicyRate = 0.17
        sim.scoreCard.peakReserveRequirement = 0.18
        sim.scoreCard.peakCapitalControls = 0.6
        sim.scoreCard.highInflationQuarters = 7
        sim.scoreCard.recessionQuarters = 4
        sim.scoreCard.highUnemploymentQuarters = 5
        sim.scoreCard.nearOusterQuarters = 1

        let rendered = renderGameOver(makeGameOverSnapshot(outcome: .success, simulator: sim, gameLength: .short))

        assertRenderedScreenFits(rendered)
        XCTAssertTrue(rendered.contains("YOU SURVIVED"))
        XCTAssertTrue(rendered.contains("FINAL STATE"))
        XCTAssertTrue(rendered.contains("SCORECARD"))
    }

    func testAdvisorSnapshotIncludesRequestedFocusAndRecommendations() {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            sessionSeed: testSeed)
        let sim = session.simulator
        sim.state.foreignReservesMonths = 0.9
        sim.state.exchangeRateQoQChange = 0.07
        sim.state.externalDebtGDP = 0.74
        sim.state.currentAccountGDP = -0.052

        let snapshot = session.makeAdvisorSnapshot(topic: "currency")

        XCTAssertEqual(snapshot.requestedFocusLine, "Requested focus: Currency Defense")
        XCTAssertFalse(snapshot.recommendationSection.bullets.isEmpty)
        XCTAssertFalse(snapshot.watchSection.bullets.isEmpty)
        XCTAssertTrue(snapshot.topicSuggestions.contains("advisor currency"))
    }

    func testScenarioAssessmentAppearsInReportAndEndScreen() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.inflation = 0.052
        sim.state.unemployment = 0.071
        sim.state.credibility = 0.78
        sim.state.year = 1968
        sim.state.quarter = 4

        let report = renderCampaignReport(makeReportSnapshot(simulator: sim, gameLength: .short, scenarioID: "soft_landing_1966"))
        let gameOver = renderGameOver(makeGameOverSnapshot(outcome: .success, simulator: sim, gameLength: .short, scenarioID: "soft_landing_1966"))

        assertRenderedScreenFits(report)
        assertRenderedScreenFits(gameOver)
        XCTAssertTrue(report.contains("Scenario assessment:"))
        XCTAssertTrue(gameOver.contains("SCENARIO ASSESSMENT"))
        XCTAssertTrue(gameOver.contains("Lesson focus:"))
        XCTAssertTrue(gameOver.contains("acting early"))
    }

    func testScenarioBriefingAndTutorialSnapshotsCarryTeachingFocus() throws {
        let session = GameSession(
            mode: .historical,
            gameLength: .short,
            difficulty: .governor,
            scenarioID: "soft_landing_1966",
            sessionSeed: testSeed)

        let briefing = try XCTUnwrap(session.makeScenarioBriefingSnapshot())
        let tutorial = session.makeTutorialSnapshot()

        XCTAssertTrue(briefing.title.contains("Soft Landing"))
        XCTAssertFalse(briefing.teachingFocus.isEmpty)
        XCTAssertFalse(briefing.objectives.isEmpty)
        XCTAssertFalse(tutorial.scenarioGoals.isEmpty)
        XCTAssertTrue(tutorial.focus.contains(where: { $0.contains("Soft Landing") }))
    }

    func testPassiveBalanceBotMakesNoPolicyMoves() {
        let sim = EconomicSimulator(seed: testSeed)
        let turn = applyBalanceBotTurn(.passive, to: sim)

        XCTAssertFalse(turn.activeQuarter)
        XCTAssertEqual(turn.policyActions, 0)
        XCTAssertEqual(turn.rateMoveAbs, 0.0, accuracy: 1e-12)
        XCTAssertEqual(turn.controlsMoveAbs, 0.0, accuracy: 1e-12)
        XCTAssertEqual(turn.interventionMonthsAbs, 0.0, accuracy: 1e-12)
        XCTAssertEqual(turn.crisisMeasuresUsed, 0)
    }

    func testFullReactiveBalanceBotActsUnderStress() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.inflation = 0.12
        sim.state.expectedInflation = 0.10
        sim.state.outputGap = -0.03
        sim.state.unemployment = 0.10
        sim.state.foreignReservesMonths = 0.7
        sim.state.exchangeRateQoQChange = 0.06
        sim.state.capitalControls = 0.20

        let turn = applyBalanceBotTurn(.fullReactive, to: sim)

        XCTAssertTrue(turn.activeQuarter)
        XCTAssertGreaterThan(turn.policyActions, 0)
        XCTAssertTrue(turn.rateMoveAbs > 0 || turn.controlsMoveAbs > 0 || turn.interventionMonthsAbs > 0,
                      "Full reactive bot should take at least one stabilizing action under obvious stress.")
        XCTAssertGreaterThan(turn.crisisMeasuresUsed, 0,
                             "Full reactive bot should use a crisis tool when one is available under acute stress.")
        XCTAssertGreaterThan(sim.crisisCooldownQuarters, 0)
    }

    // MARK: - 2. Baseline sanity

    func testBaselineDecadeStaysNumericallyWellBehaved() {
        // Default policy (rate 6%, reserve 12%, controls 0.3), no events.
        // We're not asserting *realism* — only that 40 unperturbed quarters
        // don't explode to NaN, hit the bounds rails, or produce nonsense.
        let sim = EconomicSimulator(seed: testSeed)

        for _ in 0..<40 {
            stepQuarter(sim)
            XCTAssertFalse(sim.state.inflation.isNaN, "inflation went NaN")
            XCTAssertFalse(sim.state.outputGap.isNaN, "outputGap went NaN")
            XCTAssertFalse(sim.state.unemployment.isNaN, "unemployment went NaN")
            XCTAssertFalse(sim.state.exchangeRate.isNaN, "exchangeRate went NaN")
        }

        let s = sim.state
        // Inflation should have stayed moderate without shocks — nowhere near
        // the hyperinflation threshold.
        XCTAssertLessThan(s.inflation, 0.15,
                          "Baseline (no shocks) should not drift into severe inflation.")
        XCTAssertGreaterThan(s.inflation, -0.02,
                             "Baseline should not collapse into persistent deflation.")
        // Output gap should be bounded.
        XCTAssertGreaterThan(s.outputGap, -0.10)
        XCTAssertLessThan(s.outputGap, 0.08)
        // Credibility should stay well above the floor without any shocks.
        XCTAssertGreaterThan(s.credibility, 0.40,
                             "Credibility should not collapse in a shock-free baseline.")
        // Reserves shouldn't vanish under default conditions.
        XCTAssertGreaterThan(s.foreignReservesMonths, 1.0,
                             "Reserves should not be drained in a shock-free baseline.")
    }

    // MARK: - 3. Tight money cools the output gap

    func testRateHikeReducesOutputGapRelativeToBaseline() {
        // Two twin sims, identical seed (so noise draws align), same events (none).
        // The only difference is policy rate: one at 6% (baseline), one at 12%.
        // After 4 quarters, the tight-money run should have a lower output gap.
        let easy = EconomicSimulator(seed: testSeed)
        let tight = EconomicSimulator(seed: testSeed)
        tight.state.policyRate = 0.12  // +6pp above baseline

        for _ in 0..<4 {
            stepQuarter(easy)
            stepQuarter(tight)
        }

        XCTAssertLessThan(tight.state.outputGap, easy.state.outputGap,
                          "A sustained rate hike should cool the output gap vs. baseline.")
        // And by a meaningful margin — the IS response is real, not noise.
        XCTAssertLessThan(tight.state.outputGap, easy.state.outputGap - 0.005,
                          "Rate-hike effect on output gap is smaller than expected (<0.5pp).")
    }

    // MARK: - 4. Oil shock raises inflation

    func testOilShockRaisesInflationRelativeToBaseline() {
        // Twin sims, identical seed. One receives a large oil shock in Q1;
        // the other runs the same quarter with no events.
        let calm = EconomicSimulator(seed: testSeed)
        let shocked = EconomicSimulator(seed: testSeed)

        let shock = EconomicEvent(type: .oilShock(magnitude: 2.0), isScripted: true)

        stepQuarter(calm)
        stepQuarter(shocked, events: [shock])

        XCTAssertGreaterThan(shocked.state.inflation, calm.state.inflation,
                             "Oil shock should raise inflation relative to a calm quarter.")
        // The oil passthrough coefficient is 0.022 per unit pct rise. A magnitude
        // of 2.0 (=200% rise) should yield ~4.4pp of annualised inflation impact
        // from the oil channel alone. We're loose on the exact number (other
        // channels — expectations, output gap — also shift), but we expect at
        // least ~2pp of extra inflation.
        XCTAssertGreaterThan(shocked.state.inflation - calm.state.inflation, 0.02,
                             "Oil shock's inflation impact is smaller than expected.")
        // And the shock should register as stagflationary — output gap lower.
        XCTAssertLessThan(shocked.state.outputGap, calm.state.outputGap,
                          "Oil shock should also depress the output gap.")
    }

    // MARK: - 4b. Current-account persistence actually mean-reverts

    func testCurrentAccountPartiallyMeanRevertsTowardTarget() {
        var params = ModelParameters.default
        params.exchangeRate.noiseStd = 0.0
        params.exchangeRate.currentAccountPressure = 0.0
        params.exchangeRate.uipCoefficient = 0.0
        params.currentAccount.competitiveness = 0.0
        params.currentAccount.absorption = 0.0
        params.currentAccount.partnerSensitivity = 0.0
        params.currentAccount.persistence = 0.78

        let sim = EconomicSimulator(params: params, seed: testSeed)
        sim.state.currentAccountGDP = -0.10

        stepQuarter(sim)

        XCTAssertEqual(sim.state.currentAccountGDP, -0.078, accuracy: 1e-12,
                       "With a zero target flow, persistence should shrink the inherited imbalance.")
    }

    // MARK: - 4c. Save/load commands preserve paths with spaces

    func testSaveLoadCommandsPreserveWholePath() {
        let savePath = "~/Desktop/Solaverde Saves/run 1.json"
        if case .save(let parsedPath) = parseCommand("save \(savePath)") {
            XCTAssertEqual(parsedPath, savePath)
        } else {
            XCTFail("save command should parse into .save")
        }

        if case .save(let parsedPath) = parseCommand("save \"\(savePath)\"") {
            XCTAssertEqual(parsedPath, savePath)
        } else {
            XCTFail("quoted save path should parse into .save")
        }

        let loadPath = "/tmp/Solaverde Saves/archive 1979.json"
        if case .load(let parsedPath) = parseCommand("load \(loadPath)") {
            XCTAssertEqual(parsedPath, loadPath)
        } else {
            XCTFail("load command should parse into .load")
        }

        if case .load(let parsedPath) = parseCommand("load '\(loadPath)'") {
            XCTAssertEqual(parsedPath, loadPath)
        } else {
            XCTFail("quoted load path should parse into .load")
        }

        if case .setCommunication(let stance) = parseCommand("comm hawkish") {
            XCTAssertEqual(stance, .hawkish)
        } else {
            XCTFail("comm command should parse into .setCommunication")
        }

        if case .preview(let changes) = parseCommand("preview rate 12.5 reserve 14 controls 6") {
            XCTAssertEqual(changes, [.rate(0.125), .reserve(0.14), .controls(0.6)])
        } else {
            XCTFail("preview command should parse multiple hypothetical overrides")
        }

        if case .preview(let changes) = parseCommand("what_if rate 12.5") {
            XCTAssertEqual(changes, [.rate(0.125)])
        } else {
            XCTFail("what_if alias should map into preview overrides")
        }

        if case .cabinet = parseCommand("cabinet") {
        } else {
            XCTFail("cabinet command should parse into .cabinet")
        }

        if case .crisis = parseCommand("crisis") {
        } else {
            XCTFail("crisis command should parse into .crisis")
        }

        if case .enactCrisisMeasure(let measure) = parseCommand("measure imf") {
            XCTAssertEqual(measure, .imfProgram)
        } else {
            XCTFail("measure command should parse IMF correctly")
        }

        if case .acceptCabinet = parseCommand("accept") {
        } else {
            XCTFail("accept command should parse into .acceptCabinet")
        }

        if case .rejectCabinet = parseCommand("reject") {
        } else {
            XCTFail("reject command should parse into .rejectCabinet")
        }

        if case .delayCabinet = parseCommand("delay") {
        } else {
            XCTFail("delay command should parse into .delayCabinet")
        }

        if case .news = parseCommand("news") {
        } else {
            XCTFail("news command should parse into .news")
        }

        if case .report = parseCommand("report") {
        } else {
            XCTFail("report command should parse into .report")
        }

        if case .debrief = parseCommand("why") {
        } else {
            XCTFail("why command should parse into .debrief")
        }

        if case .tutorial = parseCommand("tutorial") {
        } else {
            XCTFail("tutorial command should parse into .tutorial")
        }
    }

    func testSessionLogRetainsDeepHistoryAndFullNews() {
        var log = SessionLog()
        for i in 0..<20 {
            var state = EconomicState()
            state.year = 1973 + (i / 4)
            state.quarter = (i % 4) + 1
            state.inflation = 0.03 + Double(i) * 0.001
            state.gdpGrowthQoQ = 0.004 + Double(i) * 0.0001
            state.unemployment = 0.06 + Double(i) * 0.0005
            log.recordQuarter(state)
            log.addNews("Event \(i)", quarterLabel: state.quarterLabel)
        }

        XCTAssertEqual(log.inflationHistory.count, 20)
        XCTAssertEqual(log.gdpGrowthHistory.count, 20)
        XCTAssertEqual(log.unemploymentHistory.count, 20)
        XCTAssertEqual(log.quarterSnapshots.count, 20)
        XCTAssertEqual(log.fullNewsLog.count, 20)
        XCTAssertEqual(log.newsLog.count, 12, "Dashboard news should still stay compact.")
    }

    // MARK: - 5. Communication stance affects credibility and expectations

    func testConsistentHawkishCommunicationBuildsCredibility() {
        let balanced = EconomicSimulator(seed: testSeed)
        let hawkish = EconomicSimulator(seed: testSeed)
        balanced.state.policyRate = 0.11
        hawkish.state.policyRate = 0.11
        hawkish.communicationStance = .hawkish

        stepQuarter(balanced)
        stepQuarter(hawkish)

        XCTAssertGreaterThan(hawkish.state.credibility, balanced.state.credibility + 0.005,
                             "Credible hawkish messaging should improve credibility relative to a balanced statement.")
        XCTAssertLessThan(hawkish.state.expectedInflation, balanced.state.expectedInflation,
                          "Credible hawkish messaging should pull expectations down slightly.")
        XCTAssertEqual(hawkish.communicationStance, .hawkish,
                       "Communication stance should persist until the player changes it.")
    }

    func testInconsistentHawkishCommunicationHurtsCredibility() {
        let balanced = EconomicSimulator(seed: testSeed)
        let hawkish = EconomicSimulator(seed: testSeed)
        balanced.state.policyRate = 0.03
        hawkish.state.policyRate = 0.03
        balanced.state.expectedInflation = 0.07
        hawkish.state.expectedInflation = 0.07
        hawkish.communicationStance = .hawkish

        stepQuarter(balanced)
        stepQuarter(hawkish)

        XCTAssertLessThan(hawkish.state.credibility, balanced.state.credibility - 0.01,
                          "Hawkish messaging without a tight stance should damage credibility.")
        XCTAssertGreaterThan(hawkish.state.expectedInflation, balanced.state.expectedInflation,
                             "Incredible hawkish messaging should nudge expectations up, not down.")
    }

    // MARK: - 5b. Cabinet requests generate and resolve deterministically

    func testCabinetCutRatesRequestCanBeAccepted() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.unemployment = 0.11
        sim.state.outputGap = -0.04
        sim.state.inflation = 0.07

        sim.maybeIssueCabinetRequest()

        XCTAssertEqual(sim.activeCabinetRequest?.type, .cutRates)
        let priorRate = sim.state.policyRate
        let priorPressure = sim.state.politicalPressure
        _ = sim.acceptCabinetRequest()

        XCTAssertNil(sim.activeCabinetRequest)
        XCTAssertLessThan(sim.state.policyRate, priorRate)
        XCTAssertLessThan(sim.state.politicalPressure, priorPressure)
    }

    func testExternalDefenseActionsCreateTemporarySupportCarry() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.applyFXIntervention(months: -0.5)
        XCTAssertGreaterThan(sim.interventionSupportCarry, 0.0)

        sim.setCapitalControls(0.55)
        XCTAssertGreaterThan(sim.controlsReliefCarry, 0.0)

        let interventionCarry = sim.interventionSupportCarry
        let controlsCarry = sim.controlsReliefCarry
        stepQuarter(sim)

        XCTAssertLessThan(sim.interventionSupportCarry, interventionCarry)
        XCTAssertLessThan(sim.controlsReliefCarry, controlsCarry)
    }

    func testAdvanceWithoutResponseTreatsCabinetRequestAsDelay() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.unemployment = 0.11
        sim.state.outputGap = -0.04
        sim.maybeIssueCabinetRequest()

        let priorPressure = sim.state.politicalPressure
        sim.deferCabinetRequestIfNeeded()

        XCTAssertNil(sim.activeCabinetRequest)
        XCTAssertGreaterThan(sim.state.politicalPressure, priorPressure)
    }

    func testCrisisMeasuresUnlockUnderStressAndGoOnCooldown() {
        let sim = EconomicSimulator(seed: testSeed)
        sim.state.foreignReservesMonths = 1.7
        sim.state.exchangeRateQoQChange = 0.06

        let measures = sim.availableCrisisMeasures().map(\.type)
        XCTAssertTrue(measures.contains(.bankHoliday))
        XCTAssertFalse(measures.isEmpty)

        let priorReserves = sim.state.foreignReservesMonths
        let priorControls = sim.state.capitalControls
        let message = sim.enactCrisisMeasure(.bankHoliday)

        XCTAssertTrue(message.contains("Bank holiday"))
        XCTAssertGreaterThanOrEqual(sim.state.foreignReservesMonths, priorReserves)
        XCTAssertGreaterThan(sim.state.capitalControls, priorControls)
        XCTAssertEqual(sim.crisisCooldownQuarters, sim.crisisMeasureCooldown)
        XCTAssertTrue(sim.availableCrisisMeasures().isEmpty,
                      "Measures should be unavailable during cooldown.")
    }

    // MARK: - 6. Preview does not mutate the real simulator

    func testPreviewIsNonMutating() {
        // The preview contract: running `previewNextQuarter` must not advance
        // the real simulator's state, consume its RNG, or append to its log.
        // If this test ever breaks, `preview` and `what_if` silently become
        // destructive — the single worst possible regression for a UX feature
        // whose whole promise is "no commitment."
        let sim = EconomicSimulator(seed: testSeed)

        let stateBefore = sim.state
        let envBefore = sim.environment
        let newsCountBefore = sim.log.newsLog.count
        let inflationHistBefore = sim.log.inflationHistory.count

        let preview = previewNextQuarter(
            of: sim,
            mode: .randomized,
            macroSchedule: [:],
            rateSchedule: [:])

        // Real simulator should be byte-identical on the observable fields.
        XCTAssertEqual(sim.state.inflation, stateBefore.inflation, accuracy: 1e-12)
        XCTAssertEqual(sim.state.outputGap, stateBefore.outputGap, accuracy: 1e-12)
        XCTAssertEqual(sim.state.quarter, stateBefore.quarter)
        XCTAssertEqual(sim.state.year, stateBefore.year)
        XCTAssertEqual(sim.environment.oilPriceIndex, envBefore.oilPriceIndex, accuracy: 1e-12)
        XCTAssertEqual(sim.log.newsLog.count, newsCountBefore,
                       "Preview must not append to the real news log.")
        XCTAssertEqual(sim.log.inflationHistory.count, inflationHistBefore,
                       "Preview must not append to the real chart history.")

        // And the preview report itself should reflect a real simulation (time
        // advanced, something was computed).
        XCTAssertNotEqual(preview.stateAfter.quarter, preview.stateBefore.quarter,
                          "Preview report should reflect time-advancement on the clone.")

        // Now advance the real simulator for real — result should be *identical*
        // to the preview, since the clone's RNG was drawn from the same stream.
        sim.environment.worldInterestRate = worldInterestRate(
            for: sim.state, mode: .randomized, rateSchedule: [:])
        let events = generateEvents(
            for: sim.state, mode: .randomized, macroSchedule: [:], using: &sim.rng)
        sim.simulateQuarter(events: events)

        XCTAssertEqual(sim.state.inflation, preview.stateAfter.inflation, accuracy: 1e-12,
                       "Advance after preview should reproduce the previewed inflation.")
        XCTAssertEqual(sim.state.outputGap, preview.stateAfter.outputGap, accuracy: 1e-12,
                       "Advance after preview should reproduce the previewed output gap.")
    }

    // MARK: - 6b. What-if previews keep the same shock path

    func testWhatIfPreviewAnchorsEventsToCurrentState() {
        func eventKeys(_ report: QuarterReport) -> [String] {
            report.events.map { String(describing: $0.type) }.sorted()
        }

        for seed in 1...2_000 {
            let baseline = EconomicSimulator(seed: UInt64(seed))
            baseline.state.foreignReservesMonths = 3.4
            baseline.state.capitalControls = 0.5

            let baselinePreview = previewNextQuarter(
                of: baseline,
                mode: .randomized,
                macroSchedule: [:],
                rateSchedule: [:])

            let hypothetical = baseline.cloneForPreview()
            hypothetical.state.capitalControls = 0.7

            let unanchored = previewNextQuarter(
                of: hypothetical,
                mode: .randomized,
                macroSchedule: [:],
                rateSchedule: [:])

            guard eventKeys(unanchored) != eventKeys(baselinePreview) else { continue }

            let anchored = previewNextQuarter(
                of: hypothetical,
                mode: .randomized,
                macroSchedule: [:],
                rateSchedule: [:],
                eventSourceState: baseline.state)

            XCTAssertEqual(eventKeys(anchored), eventKeys(baselinePreview),
                           "A what-if preview should preserve the real quarter's event set.")
            XCTAssertNotEqual(eventKeys(unanchored), eventKeys(baselinePreview),
                              "Control case should prove the hypothetical policy can otherwise perturb event eligibility.")
            return
        }

        XCTFail("Failed to find a deterministic seed where policy-gated event eligibility diverged.")
    }

    func testForecastEstimateIsDeterministicButNotPerfect() {
        let sim = EconomicSimulator(seed: testSeed)
        let report = previewNextQuarter(
            of: sim,
            mode: .randomized,
            macroSchedule: [:],
            rateSchedule: [:])

        let estimateA = forecastEstimate(for: report, sessionSeed: testSeed)
        let estimateB = forecastEstimate(for: report, sessionSeed: testSeed)

        XCTAssertEqual(estimateA.estimatedAfter.inflation, estimateB.estimatedAfter.inflation, accuracy: 1e-12)
        XCTAssertEqual(estimateA.estimatedAfter.exchangeRate, estimateB.estimatedAfter.exchangeRate, accuracy: 1e-12)
        XCTAssertNotEqual(estimateA.estimatedAfter.inflation, report.stateAfter.inflation,
                          "Displayed forecast should not be a perfect oracle for inflation.")
    }

    func testExtendedCampaignScoringIsScaledByLength() {
        var card = ScoreCard()
        card.highInflationQuarters = 20
        card.recessionQuarters = 20
        card.lowestReserves = 1.8

        let shortScore = computeScore(outcome: .success, card: card, gameLength: .short).final
        let extendedScore = computeScore(outcome: .success, card: card, gameLength: .extended).final

        XCTAssertGreaterThan(extendedScore, shortScore,
                             "Extended campaigns should not be punished as if 160 quarters were a 36-quarter run.")
    }

    // MARK: - 7. Save → load round-trip is deterministic

    func testSaveLoadRoundTripMatchesUninterruptedContinuation() {
        // Run some quarters, save, then load into a fresh sim and continue.
        // A parallel "control" run continues from the save point without ever
        // touching disk. After N more quarters, both runs must be identical —
        // that's the save/load contract. If it breaks, it means the save is
        // missing something deterministic (RNG state, noise carries, etc.)
        // and players would get silently divergent games after a reload.

        let original = EconomicSimulator(seed: testSeed)
        for _ in 0..<4 { original.simulateQuarter(events: []) }
        original.communicationStance = .dovish
        original.activeCabinetRequest = CabinetRequest(
            type: .tightenControls,
            detail: "Ministers want tighter controls before reserves slip further.")
        original.interventionSupportCarry = 0.014
        original.controlsReliefCarry = 0.021
        original.crisisCooldownQuarters = 3

        // Capture a save at this point.
        let save = GameSave(
            state: original.state,
            environment: original.environment,
            log: original.log,
            scoreCard: original.scoreCard,
            difficulty: .governor,
            communicationStance: original.communicationStance,
            activeCabinetRequest: original.activeCabinetRequest,
            rng: original.rng,
            demandNoiseCarry: original.demandNoiseCarry,
            supplyNoiseCarry: original.supplyNoiseCarry,
            interventionSupportCarry: original.interventionSupportCarry,
            controlsReliefCarry: original.controlsReliefCarry,
            crisisCooldownQuarters: original.crisisCooldownQuarters,
            sessionSeed: testSeed,
            mode: .historical,
            gameLength: .extended,
            scenarioID: "debt_crisis_1982",
            macroSchedule: [:],
            rateSchedule: [:])

        // Round-trip through JSON so we also exercise the encoder / decoder.
        let encoded = try! JSONEncoder().encode(save)
        let decoded = try! JSONDecoder().decode(GameSave.self, from: encoded)

        // Rebuild a sim from the decoded save.
        let reloaded = EconomicSimulator(
            state: decoded.state,
            environment: decoded.environment,
            log: decoded.log,
            scoreCard: decoded.scoreCard,
            params: .default,
            seed: 0)
        reloaded.rng = decoded.rng
        reloaded.demandNoiseCarry = decoded.demandNoiseCarry
        reloaded.supplyNoiseCarry = decoded.supplyNoiseCarry
        reloaded.interventionSupportCarry = decoded.interventionSupportCarry ?? 0.0
        reloaded.controlsReliefCarry = decoded.controlsReliefCarry ?? 0.0
        reloaded.crisisCooldownQuarters = decoded.crisisCooldownQuarters ?? 0
        reloaded.communicationStance = decoded.communicationStance
        reloaded.activeCabinetRequest = decoded.activeCabinetRequest

        // Continue both sims for another 4 quarters with identical events.
        for _ in 0..<4 {
            original.deferCabinetRequestIfNeeded()
            original.simulateQuarter(events: [])
            original.maybeIssueCabinetRequest()
            reloaded.deferCabinetRequestIfNeeded()
            reloaded.simulateQuarter(events: [])
            reloaded.maybeIssueCabinetRequest()
        }

        XCTAssertEqual(decoded.communicationStance, .dovish)
        XCTAssertEqual(decoded.activeCabinetRequest?.type, .tightenControls)
        XCTAssertEqual(decoded.gameLength, .extended)
        XCTAssertEqual(decoded.scenarioID, "debt_crisis_1982")
        XCTAssertEqual(decoded.interventionSupportCarry ?? 0.0, 0.014, accuracy: 1e-12)
        XCTAssertEqual(decoded.controlsReliefCarry ?? 0.0, 0.021, accuracy: 1e-12)
        XCTAssertEqual(decoded.crisisCooldownQuarters ?? 0, 3)
        XCTAssertEqual(reloaded.state.inflation, original.state.inflation, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.outputGap, original.state.outputGap, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.unemployment, original.state.unemployment, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.credibility, original.state.credibility, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.exchangeRate, original.state.exchangeRate, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.foreignReservesMonths, original.state.foreignReservesMonths, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.publicApproval, original.state.publicApproval, accuracy: 1e-12)
        XCTAssertEqual(reloaded.state.politicalPressure, original.state.politicalPressure, accuracy: 1e-12)
    }

    // MARK: - 8. Heavy capital controls carry political and credibility cost

    func testCapitalControlsReduceApprovalAndCredibility() {
        // Twin sims, identical seed. One runs with open capital account,
        // the other clamps capital controls to full lockdown. After a few
        // quarters the locked-down run should show materially lower public
        // approval AND lower credibility — controls are no longer a free
        // lunch. The effect must hold under otherwise-identical conditions.
        let open = EconomicSimulator(seed: testSeed)
        let locked = EconomicSimulator(seed: testSeed)
        open.state.capitalControls = 0.0
        locked.state.capitalControls = 1.0

        for _ in 0..<6 {
            stepQuarter(open)
            stepQuarter(locked)
        }

        XCTAssertLessThan(locked.state.publicApproval, open.state.publicApproval - 5.0,
                          "Full capital controls should cost at least 5pp of public approval.")
        XCTAssertLessThan(locked.state.credibility, open.state.credibility - 0.02,
                          "Full capital controls should erode credibility over time.")
    }

    // MARK: - 9. Sustained low inflation earns a credibility bonus

    func testSustainedLowInflationBoostsCredibility() {
        // Engineer a scenario where inflation stays below the sustained-low
        // threshold for two consecutive quarters. The second quarter should
        // apply the rebuild bonus on top of the calm-increment.
        let sim = EconomicSimulator(seed: testSeed)
        // Push expectations down and inflation to a low starting point so the
        // Phillips-curve baseline output settles under the threshold.
        sim.state.inflation = 0.025
        sim.state.expectedInflation = 0.025
        sim.state.outputGap = 0.0
        sim.state.credibility = 0.50   // room to grow

        stepQuarter(sim)                            // first low quarter (priming)
        let midCredibility = sim.state.credibility
        stepQuarter(sim)                            // second low quarter — bonus fires

        // Inflation must actually have stayed below threshold both quarters
        // for the bonus to have applied — otherwise the test's premise failed.
        XCTAssertLessThan(sim.state.inflation, 0.040,
                          "Test premise broken: inflation drifted above threshold.")
        // Bonus is +0.020 per param; allow headroom for the calm-increment.
        // Key claim: the second quarter's gain exceeds a normal calm bump alone.
        let secondQuarterGain = sim.state.credibility - midCredibility
        XCTAssertGreaterThan(secondQuarterGain, 0.015,
                             "Two consecutive low-inflation quarters should add meaningful credibility.")
    }

    // MARK: - 10. ScoreCard counters and scoring are wired correctly

    func testScoreCardCountersAndScoringRespondToState() {
        // Unit-test the ScoreCard in isolation: feed it crafted states that
        // cross each threshold, verify the counters and extremes land where
        // expected, then verify the score reflects the same picture.
        // Emergent sim behavior has too much parameter sensitivity to make a
        // reliable counter-level test — craft the states directly instead.

        var card = ScoreCard()

        // Helper: craft a state with only the fields that matter to scoring
        // set explicitly, so the three test quarters are fully independent.
        func quarterState(inflation: Double, growthAnn: Double, unemployment: Double,
                          credibility: Double, reserves: Double, pressure: Double) -> EconomicState {
            var s = EconomicState()
            s.inflation = inflation
            s.gdpGrowthQoQ = growthAnn / 4.0
            s.unemployment = unemployment
            s.credibility = credibility
            s.foreignReservesMonths = reserves
            s.politicalPressure = pressure
            return s
        }

        // Q1: calm baseline — nothing should trip.
        card.record(quarterState(inflation: 0.035, growthAnn: 0.036, unemployment: 0.065,
                                 credibility: 0.75, reserves: 4.5, pressure: 30))
        // Q2: stagflation — high inflation, recession, high unemployment, low credibility, low reserves, high pressure.
        card.record(quarterState(inflation: 0.14, growthAnn: -0.024, unemployment: 0.10,
                                 credibility: 0.35, reserves: 1.8, pressure: 80))
        // Q3: severe inflation only — but growth recovered and unemployment back in band.
        card.record(quarterState(inflation: 0.22, growthAnn: 0.010, unemployment: 0.07,
                                 credibility: 0.20, reserves: 2.4, pressure: 50))

        XCTAssertEqual(card.quartersSimulated, 3)
        XCTAssertEqual(card.highInflationQuarters, 2,   // 0.14 and 0.22 both >10%
                       "highInflationQuarters should count 2 (both elevated quarters).")
        XCTAssertEqual(card.severeInflationQuarters, 1,
                       "severeInflationQuarters should count the >20% quarter only.")
        XCTAssertEqual(card.recessionQuarters, 1,
                       "recessionQuarters should count the Q2 recession only.")
        XCTAssertEqual(card.stagflationQuarters, 1,
                       "stagflationQuarters requires both high inflation AND recession (Q2 only).")
        XCTAssertEqual(card.highUnemploymentQuarters, 1,
                       "highUnemploymentQuarters: only Q2 had u>0.09.")
        XCTAssertEqual(card.lowCredibilityQuarters, 2,
                       "lowCredibilityQuarters: credibility 0.35 and 0.20 both <0.40.")
        XCTAssertEqual(card.nearOusterQuarters, 1,
                       "nearOusterQuarters: only Q2 had pressure > 75.")

        XCTAssertEqual(card.peakInflation, 0.22, accuracy: 1e-9)
        XCTAssertEqual(card.lowestCredibility, 0.20, accuracy: 1e-9)
        XCTAssertEqual(card.lowestReserves, 1.8, accuracy: 1e-9)
        XCTAssertEqual(card.peakPoliticalPressure, 80, accuracy: 1e-9)

        // Scoring: against an ongoing-outcome baseline, the deductions should
        // subtract from 100 and land in-bounds. The exact number isn't the
        // point; the wiring is.
        let breakdown = computeScore(outcome: .ongoing, card: card)
        XCTAssertEqual(breakdown.baseline, 100)
        XCTAssertGreaterThanOrEqual(breakdown.final, 0)
        XCTAssertLessThanOrEqual(breakdown.final, 100)
        XCTAssertLessThan(breakdown.final, 100,
                          "A run with stagflation + severe inflation + reserves crisis should not score 100.")
        XCTAssertFalse(breakdown.headline.isEmpty)

        // And a pristine run against the same scoring function should outscore
        // the messy one by a meaningful margin.
        var cleanCard = ScoreCard()
        var cleanState = EconomicState()
        cleanState.inflation = 0.03
        cleanState.unemployment = 0.06
        cleanState.gdpGrowthQoQ = 0.008
        cleanState.credibility = 0.80
        cleanState.foreignReservesMonths = 5.0
        cleanState.politicalPressure = 20
        for _ in 0..<40 { cleanCard.record(cleanState) }
        let cleanBreakdown = computeScore(outcome: .success, card: cleanCard)
        XCTAssertGreaterThan(cleanBreakdown.final, breakdown.final + 30,
                             "A clean success run should easily outscore a rough one.")
    }

    // MARK: - 5. Inflation surprise erodes credibility

    func testInflationSurpriseErodesCredibility() {
        // A big oil shock will push actual inflation well above expected
        // inflation, crossing the surprise threshold and triggering a
        // credibility decrement. The calm twin is our control.
        let calm = EconomicSimulator(seed: testSeed)
        let shocked = EconomicSimulator(seed: testSeed)

        let startingCredibility = shocked.state.credibility
        let shock = EconomicEvent(type: .oilShock(magnitude: 2.5), isScripted: true)

        stepQuarter(calm)
        stepQuarter(shocked, events: [shock])

        XCTAssertLessThan(shocked.state.credibility, startingCredibility,
                          "A large inflation surprise should reduce credibility.")
        XCTAssertLessThan(shocked.state.credibility, calm.state.credibility,
                          "Shocked run should end with lower credibility than calm twin.")
        // The decrement is parameterised at 0.025; allow for some wiggle in case
        // the calm run also shifted credibility slightly.
        XCTAssertLessThan(shocked.state.credibility, startingCredibility - 0.01,
                          "Credibility decrement from a large surprise is smaller than expected.")
    }

    // MARK: - 11. Difficulty presets move the model in the intended direction

    func testDifficultyPresetsShapeBehavior() {
        // Same seed, same oil shock, three different difficulty presets.
        // We assert on two channels whose ordering should hold regardless of
        // higher-order feedbacks:
        //
        //   1. Expectations adapt faster under Volcker (baseAdaptSpeed ×1.3
        //      vs Governor, and double vs Apprentice). Measured right after
        //      the shock quarter while the inflation surprise is fresh.
        //   2. Credibility falls harder under Volcker (larger surpriseDecrement,
        //      larger highInflationDecrement, smaller calmIncrement).
        //
        // Note: we deliberately don't assert on inflation *levels* after many
        // quarters. Volcker has a steeper Phillips slope, which amplifies
        // inflation *and* accelerates disinflation once the post-shock output
        // gap turns negative — the two effects can flip headline inflation
        // ordering mid-run. That's a feature of the model, not a bug in the
        // presets. The expectations & credibility channels are what the
        // difficulty label is fundamentally about.

        func runShock(_ d: Difficulty, quarters: Int) -> EconomicSimulator {
            let sim = EconomicSimulator(params: ModelParameters.preset(d),
                                        difficulty: d, seed: testSeed)
            let shock = EconomicEvent(type: .oilShock(magnitude: 1.8),
                                      isScripted: false)
            sim.simulateQuarter(events: [shock])
            for _ in 0..<(quarters - 1) { sim.simulateQuarter(events: []) }
            return sim
        }

        // Measure 2 quarters post-shock — long enough for expectations to
        // have moved, short enough that Phillips-curve disinflation hasn't
        // inverted the ordering.
        let apprentice2 = runShock(.apprentice, quarters: 2)
        let governor2   = runShock(.governor,   quarters: 2)
        let volcker2    = runShock(.volcker,    quarters: 2)

        // Expectations de-anchor faster under harsher presets.
        XCTAssertGreaterThan(volcker2.state.expectedInflation,
                             apprentice2.state.expectedInflation,
                             "Volcker should de-anchor expectations faster than Apprentice.")
        XCTAssertGreaterThan(volcker2.state.expectedInflation,
                             governor2.state.expectedInflation,
                             "Volcker should de-anchor expectations faster than Governor.")
        XCTAssertLessThan(apprentice2.state.expectedInflation,
                          governor2.state.expectedInflation,
                          "Apprentice should hold expectations tighter than Governor.")

        // Credibility falls harder under harsher presets.
        XCTAssertLessThan(volcker2.state.credibility,
                          apprentice2.state.credibility,
                          "Volcker should lose credibility faster than Apprentice under same shock.")
    }
}
