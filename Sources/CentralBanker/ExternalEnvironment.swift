import Foundation

// Exogenous inputs that drive the domestic economy: global interest rates,
// inflation at trading partners, partner growth, oil and commodity prices,
// and the terms of trade. The player has no direct control over these —
// events (oil shocks, partner recessions, commodity booms) and, in
// historical mode, the scripted world-rate path are what move them.
//
// Pulled out of `EconomicState` so that:
//   • the simulator can clearly distinguish "what we chose" from "what the
//     world did to us";
//   • future save/load can serialise environment state independently;
//   • tests can stub in an `ExternalEnvironment` to replay a specific path
//     without reconstructing a whole economic state.
struct ExternalEnvironment: Codable {
    var worldInterestRate: Double = 0.060
    var worldInflation: Double = 0.055
    var tradingPartnerGrowth: Double = 0.035
    var oilPriceIndex: Double = 100.0
    var commodityPriceIndex: Double = 100.0
    var termsOfTrade: Double = 1.0
}
