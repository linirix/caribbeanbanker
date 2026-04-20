import Foundation

struct QuarterSnapshot: Codable {
    let quarterLabel: String
    let inflation: Double
    let annualizedGDPGrowth: Double
    let unemployment: Double
    let foreignReservesMonths: Double
    let policyRate: Double
    let capitalControls: Double
    let exchangeRate: Double
    let credibility: Double
    let publicApproval: Double
    let politicalPressure: Double
}

// The view-ish side-stream of the simulation: narrative news lines for the
// dashboard and retained history buffers for charts and post-run analysis.
//
// Kept separate from `EconomicState` so that:
//   • save/load serialises raw numbers, not ANSI-formatted news strings;
//   • previews / what-if runs can discard this without rewinding state;
//   • `EconomicState` stays a pure numeric model, easy to diff and test.
struct SessionLog: Codable {
    var newsLog: [String] = []
    var fullNewsLog: [String] = []
    var inflationHistory: [Double] = []
    var gdpGrowthHistory: [Double] = []
    var unemploymentHistory: [Double] = []
    var quarterSnapshots: [QuarterSnapshot] = []

    // Dashboard-only cap. The full log is retained separately.
    private static let newsCap = 12

    // Prepend a news line, labeled with the quarter it was emitted in.
    // The caller supplies the label because `SessionLog` deliberately does
    // not know about time — that lives on `EconomicState`.
    mutating func addNews(_ msg: String, quarterLabel: String) {
        let entry = "[\(quarterLabel)] \(msg)"
        newsLog.insert(entry, at: 0)
        if newsLog.count > SessionLog.newsCap { newsLog.removeLast() }
        fullNewsLog.insert(entry, at: 0)
    }

    // Snapshot the end-of-quarter values into the rolling history. Called
    // by the simulator immediately before it advances time.
    mutating func recordQuarter(_ s: EconomicState) {
        inflationHistory.append(s.inflation)
        gdpGrowthHistory.append(s.annualizedGDPGrowth)
        unemploymentHistory.append(s.unemployment)
        quarterSnapshots.append(QuarterSnapshot(
            quarterLabel: s.quarterLabel,
            inflation: s.inflation,
            annualizedGDPGrowth: s.annualizedGDPGrowth,
            unemployment: s.unemployment,
            foreignReservesMonths: s.foreignReservesMonths,
            policyRate: s.policyRate,
            capitalControls: s.capitalControls,
            exchangeRate: s.exchangeRate,
            credibility: s.credibility,
            publicApproval: s.publicApproval,
            politicalPressure: s.politicalPressure))
    }
}
