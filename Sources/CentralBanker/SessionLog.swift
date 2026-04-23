import Foundation

package struct QuarterSnapshot: Codable {
    package let quarterLabel: String
    package let inflation: Double
    package let annualizedGDPGrowth: Double
    package let unemployment: Double
    package let foreignReservesMonths: Double
    package let policyRate: Double
    package let capitalControls: Double
    package let exchangeRate: Double
    package let credibility: Double
    package let publicApproval: Double
    package let politicalPressure: Double
}

// The view-ish side-stream of the simulation: narrative news lines for the
// dashboard and retained history buffers for charts and post-run analysis.
//
// Kept separate from `EconomicState` so that:
//   • save/load serialises raw numbers, not ANSI-formatted news strings;
//   • previews / what-if runs can discard this without rewinding state;
//   • `EconomicState` stays a pure numeric model, easy to diff and test.
package struct SessionLog: Codable {
    package var newsLog: [String] = []
    package var fullNewsLog: [String] = []
    package var inflationHistory: [Double] = []
    package var gdpGrowthHistory: [Double] = []
    package var unemploymentHistory: [Double] = []
    package var quarterSnapshots: [QuarterSnapshot] = []

    // Dashboard-only cap. The full log is retained separately.
    private static let newsCap = 12

    // Prepend a news line, labeled with the quarter it was emitted in.
    // The caller supplies the label because `SessionLog` deliberately does
    // not know about time — that lives on `EconomicState`.
    package mutating func addNews(_ msg: String, quarterLabel: String) {
        let entry = "[\(quarterLabel)] \(msg)"
        newsLog.insert(entry, at: 0)
        if newsLog.count > SessionLog.newsCap { newsLog.removeLast() }
        fullNewsLog.insert(entry, at: 0)
    }

    // Snapshot the end-of-quarter values into the rolling history. Called
    // by the simulator immediately before it advances time.
    package mutating func recordQuarter(_ s: EconomicState) {
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
