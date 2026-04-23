import Foundation

package enum GameLength: String, Codable, CaseIterable {
    case short
    case extended

    package var displayName: String {
        switch self {
        case .short: return "Short"
        case .extended: return "Extended"
        }
    }

    package var rangeLabel: String {
        switch self {
        case .short: return "1973–1982"
        case .extended: return "1960–2000"
        }
    }

    package var startYear: Int {
        switch self {
        case .short: return 1973
        case .extended: return 1960
        }
    }

    package var successYear: Int {
        switch self {
        case .short: return 1982
        case .extended: return 2000
        }
    }

    package var totalQuarters: Int {
        (successYear - startYear) * 4
    }

    package var scorePenaltyScale: Double {
        Double(GameLength.short.totalQuarters) / Double(totalQuarters)
    }

    package var startDateLabel: String {
        "January \(startYear)"
    }

    package var survivalTargetLabel: String {
        "\(successYear)"
    }

    package var baseIndexLabel: String {
        "Q1 \(startYear)"
    }

    package var selectorDescription: String {
        switch self {
        case .short:
            return "36 quarters. The focused 1973–1982 crisis arc."
        case .extended:
            return "160 quarters. A full 1960–2000 central-banking career."
        }
    }
}

extension ModelParameters {
    package func configured(for gameLength: GameLength) -> ModelParameters {
        var adjusted = self
        adjusted.outcomes.successYear = gameLength.successYear
        if let tuning = GameConfigs.lengthAdjustments(for: gameLength) {
            adjusted.exchangeRate.uipCoefficient *= tuning.exchangeRateUIPMultiplier
            adjusted.exchangeRate.currentAccountPressure *= tuning.exchangeRateCurrentAccountPressureMultiplier
            adjusted.capitalAccount.interestSensitivity *= tuning.capitalAccountInterestSensitivityMultiplier
            adjusted.capitalAccount.expectationsSensitivity *= tuning.capitalAccountExpectationsSensitivityMultiplier
            adjusted.currentAccount.absorption *= tuning.currentAccountAbsorptionMultiplier
            adjusted.currentAccount.partnerSensitivity *= tuning.currentAccountPartnerSensitivityMultiplier
            adjusted.reserves.criticalMonths = tuning.reservesCriticalMonths
            adjusted.reserves.warningMonths = tuning.reservesWarningMonths
            adjusted.outcomes.currencyCrisisReserves = tuning.outcomesCurrencyCrisisReserves
        }
        return adjusted
    }
}
