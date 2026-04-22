import Foundation

enum Command {
    case setRate(Double)
    case setReserve(Double)
    case setControls(Double)
    case intervene(Double)
    case setCommunication(CommunicationStance)
    case cabinet
    case crisis
    case enactCrisisMeasure(CrisisMeasureType)
    case acceptCabinet
    case rejectCabinet
    case delayCabinet
    case advance
    case preview([PolicyChange])         // dry-run next quarter under current or hypothetical policy
    case history
    case news
    case report
    case debrief
    case tutorial
    case advisor(String?)
    case status
    case save(String?)        // optional explicit path
    case load(String?)
    case help
    case quit
    case invalid(String)
}

enum PolicyChange: Equatable {
    case rate(Double)       // fractional (e.g. 0.125 for 12.5%)
    case reserve(Double)    // fractional
    case controls(Double)   // 0...1
}

extension PolicyChange {
    var summaryLabel: String {
        switch self {
        case .rate(let value):
            return String(format: "rate %.2f%%", value * 100)
        case .reserve(let value):
            return String(format: "reserve %.1f%%", value * 100)
        case .controls(let value):
            return String(format: "controls %.0f/10", value * 10)
        }
    }
}

func parseCommand(_ input: String) -> Command {
    // Tokenize with simple quote support so commands like
    // `save "~/Desktop/Solaverde Saves/run 1.json"` work naturally.
    let rawParts = tokenizeCommand(input)
    let parts = rawParts.map { $0.lowercased() }
    let trailingArgument = rawParts.dropFirst().joined(separator: " ")

    guard !parts.isEmpty else { return .invalid("") }

    switch parts[0] {
    case "advance", "next", "n", "a":
        return .advance

    case "rate":
        guard parts.count >= 2, let val = Double(parts[1]) else {
            return .invalid("rate requires a numeric argument, e.g. rate 8.5 (sets rate to 8.5%)")
        }
        guard val >= 0.0 && val <= 50.0 else {
            return .invalid("rate must be between 0 and 50 (percent)")
        }
        return .setRate(val / 100.0)

    case "reserve":
        guard parts.count >= 2, let val = Double(parts[1]) else {
            return .invalid("reserve requires a numeric argument, e.g. reserve 15 (sets to 15%)")
        }
        guard val >= 0.0 && val <= 50.0 else {
            return .invalid("reserve requirement must be between 0 and 50 (percent)")
        }
        return .setReserve(val / 100.0)

    case "controls":
        guard parts.count >= 2, let val = Double(parts[1]) else {
            return .invalid("controls requires a value 0–10, e.g. controls 5")
        }
        guard val >= 0 && val <= 10 else {
            return .invalid("controls must be between 0 (no controls) and 10 (full controls)")
        }
        return .setControls(val / 10.0)

    case "intervene":
        guard parts.count >= 2, let val = Double(parts[1]) else {
            return .invalid("intervene requires a signed number, e.g. intervene -1.0 or intervene +0.5")
        }
        guard abs(val) <= 3.0 else {
            return .invalid("intervention cannot exceed 3.0 months of reserves in a single quarter")
        }
        return .intervene(val)

    case "comm", "communication":
        guard parts.count >= 2 else {
            return .invalid("comm requires hawkish, balanced, dovish, or opaque")
        }
        switch parts[1] {
        case "hawkish", "hawk", "h":
            return .setCommunication(.hawkish)
        case "balanced", "balance", "bal", "b":
            return .setCommunication(.balanced)
        case "dovish", "dove", "dov", "d":
            return .setCommunication(.dovish)
        case "opaque", "opaq", "op", "o":
            return .setCommunication(.opaque)
        default:
            return .invalid("comm must be hawkish, balanced, dovish, or opaque")
        }

    case "cabinet", "cab":
        return .cabinet

    case "crisis", "emergency", "emerg":
        return .crisis

    case "measure":
        guard parts.count >= 2 else {
            return .invalid("measure requires imf, holiday, or liquidity")
        }
        switch parts[1] {
        case "imf", "fund":
            return .enactCrisisMeasure(.imfProgram)
        case "holiday", "bank_holiday", "bankholiday", "bank":
            return .enactCrisisMeasure(.bankHoliday)
        case "liquidity", "lending", "window":
            return .enactCrisisMeasure(.emergencyLiquidity)
        default:
            return .invalid("measure must be imf, holiday, or liquidity")
        }

    case "accept":
        return .acceptCabinet

    case "reject":
        return .rejectCabinet

    case "delay":
        return .delayCabinet

    case "preview", "p", "what_if", "whatif", "if", "w":
        if parts.count == 1 {
            return .preview([])
        }
        let argumentParts = Array(parts.dropFirst())
        var changes: [PolicyChange] = []
        var idx = 0
        while idx < argumentParts.count {
            guard idx + 1 < argumentParts.count else {
                return .invalid("preview overrides must come in lever/value pairs, e.g. preview rate 12.5 controls 6")
            }
            let lever = argumentParts[idx]
            let valueText = argumentParts[idx + 1]
            guard let value = Double(valueText) else {
                return .invalid("preview value must be numeric, e.g. preview rate 12.5")
            }
            switch lever {
            case "rate":
                guard value >= 0.0 && value <= 50.0 else {
                    return .invalid("rate must be between 0 and 50 (percent)")
                }
                changes.append(.rate(value / 100.0))
            case "reserve":
                guard value >= 0.0 && value <= 50.0 else {
                    return .invalid("reserve must be between 0 and 50 (percent)")
                }
                changes.append(.reserve(value / 100.0))
            case "controls":
                guard value >= 0.0 && value <= 10.0 else {
                    return .invalid("controls must be between 0 and 10")
                }
                changes.append(.controls(value / 10.0))
            default:
                return .invalid("preview lever must be rate, reserve, or controls")
            }
            idx += 2
        }
        return .preview(changes)

    case "save":
        return .save(trailingArgument.isEmpty ? nil : trailingArgument)

    case "load":
        return .load(trailingArgument.isEmpty ? nil : trailingArgument)

    case "history", "hist", "h":
        return .history

    case "news", "log":
        return .news

    case "report", "summary":
        return .report

    case "why", "debrief", "brief":
        return .debrief

    case "tutorial", "guide", "lesson":
        return .tutorial

    case "advisor", "adviser", "advise":
        return .advisor(trailingArgument.isEmpty ? nil : trailingArgument)

    case "status", "st":
        return .status

    case "help", "?":
        return .help

    case "quit", "exit", "q":
        return .quit

    default:
        return .invalid("Unknown command '\(parts[0])'. Type 'help' for available commands.")
    }
}

private func tokenizeCommand(_ input: String) -> [String] {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var tokens: [String] = []
    var current = ""
    var quote: Character? = nil

    for ch in trimmed {
        if let activeQuote = quote {
            if ch == activeQuote {
                quote = nil
            } else {
                current.append(ch)
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            quote = ch
            continue
        }

        if ch.isWhitespace {
            if !current.isEmpty {
                tokens.append(current)
                current.removeAll(keepingCapacity: true)
            }
            continue
        }

        current.append(ch)
    }

    if !current.isEmpty {
        tokens.append(current)
    }

    return tokens
}

// Apply a command to the simulator, returning a confirmation message
func applyCommand(_ cmd: Command, simulator: EconomicSimulator) -> String? {
    switch cmd {
    case .setRate(let r):
        let old = simulator.state.policyRate
        simulator.state.policyRate = r
        let direction = r > old ? "raised" : "lowered"
        return String(format: "Policy rate %@ from %.2f%% to %.2f%%.", direction, old * 100, r * 100)

    case .setReserve(let r):
        let old = simulator.state.reserveRequirement
        simulator.state.reserveRequirement = r
        let direction = r > old ? "raised" : "lowered"
        return String(format: "Reserve requirement %@ from %.1f%% to %.1f%%.", direction, old * 100, r * 100)

    case .setControls(let c):
        let old = simulator.state.capitalControls
        simulator.setCapitalControls(c)
        let labels = ["NONE", "MINIMAL", "LIGHT", "MODERATE", "SUBSTANTIAL",
                      "STRICT", "STRICT", "COMPREHENSIVE", "COMPREHENSIVE", "NEAR-TOTAL", "TOTAL"]
        let idx = min(10, Int(c * 10))
        let direction = c > old ? "tightened" : "eased"
        return String(format: "Capital controls %@ to level %d (%@).", direction, idx, labels[idx])

    case .intervene(let months):
        let oldRate = simulator.state.exchangeRate
        let oldReserves = simulator.state.foreignReservesMonths
        let oldSupportCarry = simulator.interventionSupportCarry
        simulator.applyFXIntervention(months: months)
        let newRate = simulator.state.exchangeRate
        let newReserves = simulator.state.foreignReservesMonths
        let oldDisplayedRate = displayedExchangeRate(oldRate)
        let newDisplayedRate = displayedExchangeRate(newRate)
        let fxDirection: String
        if newRate < oldRate - 0.0005 {
            fxDirection = "SLD strengthened"
        } else if newRate > oldRate + 0.0005 {
            fxDirection = "SLD weakened"
        } else {
            fxDirection = "SLD was little changed"
        }

        if months > 0 {
            return String(
                format: "Bought %.2f months of FX reserves and sold SLD. Reserves: %.2f -> %.2f mo. Rate: %.3f -> %.3f USD/SLD (%@).",
                months,
                oldReserves,
                newReserves,
                oldDisplayedRate,
                newDisplayedRate,
                fxDirection
            )
        } else {
            let supportText = simulator.interventionSupportCarry > oldSupportCarry
                ? " Temporary defense support has been added for the next quarter."
                : ""
            return String(
                format: "Sold %.2f months of FX reserves and bought SLD. Reserves: %.2f -> %.2f mo. Rate: %.3f -> %.3f USD/SLD (%@).%@",
                -months,
                oldReserves,
                newReserves,
                oldDisplayedRate,
                newDisplayedRate,
                fxDirection,
                supportText
            )
        }

    case .setCommunication(let stance):
        simulator.communicationStance = stance
        return "Communication stance set to \(stance.displayName.uppercased())."

    case .cabinet:
        return simulator.describeCabinetRequest()

    case .enactCrisisMeasure(let measure):
        return simulator.enactCrisisMeasure(measure)

    case .acceptCabinet:
        return simulator.acceptCabinetRequest()

    case .rejectCabinet:
        return simulator.rejectCabinetRequest()

    case .delayCabinet:
        return simulator.delayCabinetRequest()

    default:
        return nil
    }
}
