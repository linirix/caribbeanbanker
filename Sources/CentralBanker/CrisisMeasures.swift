import Foundation

enum CrisisMeasureType: String, Codable, CaseIterable {
    case imfProgram
    case bankHoliday
    case emergencyLiquidity

    var title: String {
        switch self {
        case .imfProgram:
            return "IMF Program"
        case .bankHoliday:
            return "Bank Holiday"
        case .emergencyLiquidity:
            return "Emergency Liquidity Window"
        }
    }

    var commandName: String {
        switch self {
        case .imfProgram:
            return "imf"
        case .bankHoliday:
            return "holiday"
        case .emergencyLiquidity:
            return "liquidity"
        }
    }
}

struct CrisisMeasure: Equatable {
    let type: CrisisMeasureType
    let detail: String
    let tradeoff: String
}

extension EconomicSimulator {
    var crisisMeasureCooldown: Int { GameConfigs.tuning.crisis.cooldownQuarters }

    func availableCrisisMeasures() -> [CrisisMeasure] {
        guard crisisCooldownQuarters == 0 else { return [] }

        return CrisisMeasureType.allCases.compactMap { type in
            let config = GameConfigs.crisisMeasure(type)
            guard config.availability.matches(state) else { return nil }
            return CrisisMeasure(type: type, detail: config.detail, tradeoff: config.tradeoff)
        }
    }

    func crisisStatusText() -> String {
        if crisisCooldownQuarters > 0 {
            return "COOLDOWN \(crisisCooldownQuarters)Q"
        }
        return availableCrisisMeasures().isEmpty ? "NONE" : "AVAILABLE"
    }

    func describeCrisisMeasures() -> String {
        if crisisCooldownQuarters > 0 {
            return "Crisis tools are cooling down for \(crisisCooldownQuarters) more quarters."
        }

        let measures = availableCrisisMeasures()
        guard !measures.isEmpty else {
            return "No crisis measures available. They unlock only under severe external or domestic stress."
        }

        return measures.map {
            "\($0.type.commandName): \($0.type.title) — \($0.detail) \($0.tradeoff)"
        }.joined(separator: "  |  ")
    }

    func enactCrisisMeasure(_ type: CrisisMeasureType) -> String {
        if crisisCooldownQuarters > 0 {
            return "Crisis measures unavailable for \(crisisCooldownQuarters) more quarters."
        }

        guard availableCrisisMeasures().contains(where: { $0.type == type }) else {
            return "\(type.title) is not currently available."
        }

        let config = GameConfigs.crisisMeasure(type)
        crisisCooldownQuarters = GameConfigs.tuning.crisis.cooldownQuarters
        applyConfiguredEffects(config.effects)
        log.addNews(config.newsLine, quarterLabel: state.quarterLabel)
        return config.resultMessage
    }
}
