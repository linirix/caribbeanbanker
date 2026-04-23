import Foundation

// What happened in one simulated quarter.
//
// `simulateQuarter` builds and returns one of these. Consumers can use it for:
//   • Display (render `news` directly; diff `stateBefore` vs `stateAfter`).
//   • Preview / what-if (run a quarter, inspect the report, discard).
//   • Replay and tests (the report is a complete, self-contained record of
//     the quarter's outputs — no hidden mutation of any caller-visible state).
//
// The simulator still applies the report to its internal state as a side
// effect (for ergonomics), but external code is free to treat the report as
// the authoritative description of the quarter and ignore `simulator.state`.
package struct QuarterReport {
    package let stateBefore: EconomicState
    package let stateAfter: EconomicState
    package let environmentBefore: ExternalEnvironment
    package let environmentAfter: ExternalEnvironment
    package let events: [EconomicEvent]
    // News items generated this quarter, in emission order:
    // event descriptions first, then reserve alarms, then macro commentary.
    package let news: [String]
}
