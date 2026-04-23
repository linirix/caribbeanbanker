import Foundation

package enum CrisisMeasureType: String, Codable, CaseIterable {
    case imfProgram
    case bankHoliday
    case emergencyLiquidity

    package var title: String {
        switch self {
        case .imfProgram:
            return "IMF Program"
        case .bankHoliday:
            return "Bank Holiday"
        case .emergencyLiquidity:
            return "Emergency Liquidity Window"
        }
    }

    package var commandName: String {
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

package struct CrisisMeasure: Equatable {
    package let type: CrisisMeasureType
    package let detail: String
    package let tradeoff: String
}

extension EconomicSimulator {
    package var crisisMeasureCooldown: Int { GameConfigs.tuning.crisis.cooldownQuarters }

    package func availableCrisisMeasures() -> [CrisisMeasure] {
        guard crisisCooldownQuarters == 0 else { return [] }

        return CrisisMeasureType.allCases.compactMap { type in
            let config = GameConfigs.crisisMeasure(type)
            guard config.availability.matches(state) else { return nil }
            return CrisisMeasure(type: type, detail: config.detail, tradeoff: config.tradeoff)
        }
    }

    package func crisisStatusText() -> String {
        if crisisCooldownQuarters > 0 {
            return "COOLDOWN \(crisisCooldownQuarters)Q"
        }
        return availableCrisisMeasures().isEmpty ? "NONE" : "AVAILABLE"
    }

    package func describeCrisisMeasures() -> String {
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

    package func enactCrisisMeasure(_ type: CrisisMeasureType) -> String {
        if crisisCooldownQuarters > 0 {
            return "Crisis measures unavailable for \(crisisCooldownQuarters) more quarters."
        }

        guard availableCrisisMeasures().contains(where: { $0.type == type }) else {
            return "\(type.title) is not currently available."
        }

        let config = GameConfigs.crisisMeasure(type)
        crisisCooldownQuarters = GameConfigs.tuning.crisis.cooldownQuarters
        scoreCard.recordCrisisMeasure(type)
        applyConfiguredEffects(config.effects)
        log.addNews(config.newsLine, quarterLabel: state.quarterLabel)
        return config.resultMessage
    }
}
