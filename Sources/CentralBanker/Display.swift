import Foundation

// ANSI escape codes
enum A {
    static let reset    = "\u{001B}[0m"
    static let bold     = "\u{001B}[1m"
    static let dim      = "\u{001B}[2m"
    static let red      = "\u{001B}[31m"
    static let green    = "\u{001B}[32m"
    static let yellow   = "\u{001B}[33m"
    static let cyan     = "\u{001B}[36m"
    static let white    = "\u{001B}[37m"
    static let bRed     = "\u{001B}[91m"
    static let bGreen   = "\u{001B}[92m"
    static let bYellow  = "\u{001B}[93m"
    static let bCyan    = "\u{001B}[96m"
    static let clearScreen = "\u{001B}[2J\u{001B}[H"
}

// Strip ANSI codes for accurate visual-length calculations
private func vlen(_ s: String) -> Int {
    var result = 0
    var inEscape = false
    for c in s {
        if c == "\u{001B}" { inEscape = true; continue }
        if inEscape {
            if c == "m" { inEscape = false }
            continue
        }
        result += 1
    }
    return result
}

// Truncate a string to a given visual width while preserving ANSI escape
// sequences so colored content cannot break the frame layout.
private func truncateVisual(_ s: String, to width: Int) -> String {
    guard width > 0 else { return "" }
    if vlen(s) <= width { return s }

    var result = ""
    var visualCount = 0
    var inEscape = false

    for c in s {
        if c == "\u{001B}" {
            inEscape = true
            result.append(c)
            continue
        }
        if inEscape {
            result.append(c)
            if c == "m" { inEscape = false }
            continue
        }
        if visualCount >= width { break }
        result.append(c)
        visualCount += 1
    }

    if s.contains("\u{001B}") {
        result += A.reset
    }
    return result
}

// Pad a string (which may contain ANSI codes) to a given visual width
private func pad(_ s: String, to width: Int, char: Character = " ") -> String {
    let v = vlen(s)
    if v > width { return truncateVisual(s, to: width) }
    if v == width { return s }
    return s + String(repeating: char, count: width - v)
}

// ─── Layout constants ───────────────────────────────────────────────────────
private let W = 82          // total width
private let IW = 80         // inner width (between outer borders)
private let LC = 37         // left cell content width (after padding strip)
private let RC = 38         // right cell content width

let displayFrameWidth = W

// Box-drawing characters
private let TL = "╔"; private let TR = "╗"
private let BL = "╚"; private let BR = "╝"
private let HH = "═"; private let VV = "║"
private let ML = "╠"; private let MR = "╣"
private let MLC = "╠"; private let MRC = "╣"
private let TM = "╦"; private let BM = "╩"; private let XX = "╬"
private let LT = "╠"; private let RT = "╣"
private let CV = "│"        // inner vertical divider (thin)
private let CH = "─"        // inner horizontal (thin)

private func hline(_ left: String, _ fill: String, _ right: String) -> String {
    left + String(repeating: fill, count: IW) + right
}

// Full-width content row
private func frow(_ content: String) -> String {
    VV + " " + pad(content, to: IW - 2) + " " + VV
}

// Two-column content row
// left and right are pre-colored strings; visual widths must be LC and RC
private func crow(_ left: String, _ right: String) -> String {
    let l = pad(left, to: LC)
    let r = pad(right, to: RC)
    return VV + " " + l + " " + CV + " " + r + " " + VV
}

// Section header (two columns)
private func sheader(_ left: String, _ right: String) -> String {
    let l = A.bold + A.cyan + pad(left, to: LC) + A.reset
    let r = A.bold + A.cyan + pad(right, to: RC) + A.reset
    return crow(l, r)
}

// ─── Formatters ─────────────────────────────────────────────────────────────

private func pct(_ v: Double, decimals: Int = 1) -> String {
    String(format: "%.\(decimals)f%%", v * 100)
}

private func signed(_ v: Double, decimals: Int = 1) -> String {
    String(format: "%+.\(decimals)f%%", v * 100)
}

// Colorize a value: green if good, yellow if warning, red if bad
// direction: +1 = higher is better, -1 = lower is better
private func colored(_ str: String, value: Double, lo: Double, hi: Double, direction: Int = 1) -> String {
    let normalized = direction == 1 ? value : -value
    let loN = direction == 1 ? lo : -hi
    let hiN = direction == 1 ? hi : -lo
    if normalized >= hiN { return A.bGreen + str + A.reset }
    if normalized <= loN { return A.bRed + str + A.reset }
    return A.bYellow + str + A.reset
}

private func coloredPct(_ v: Double, lo: Double, hi: Double, direction: Int = 1, decimals: Int = 1) -> String {
    colored(pct(v, decimals: decimals), value: v, lo: lo, hi: hi, direction: direction)
}

// ASCII bar chart: e.g. [████░░░░░░] 45%
private func bar(_ value: Double, maxVal: Double = 1.0, width: Int = 10, color: String = A.green) -> String {
    let ratio = min(1.0, Swift.max(0, value / maxVal))
    let filled = Int(ratio * Double(width))
    let empty = width - filled
    return "[" + color + String(repeating: "█", count: filled) + A.dim + String(repeating: "░", count: empty) + A.reset + "]"
}

// Trend arrow based on recent history
private func trend(_ history: [Double]) -> String {
    guard history.count >= 2 else { return " " }
    let delta = history.last! - history[history.count - 2]
    if abs(delta) < 0.001 { return "→" }
    return delta > 0 ? "↑" : "↓"
}

private func sampledHistory(_ history: [Double], limit: Int) -> [Double] {
    guard history.count > limit, limit > 1 else { return history }
    let denom = Double(limit - 1)
    return (0..<limit).map { idx in
        let source = Int((Double(history.count - 1) * Double(idx) / denom).rounded())
        return history[source]
    }
}

private func wrappedRows(_ text: String, indent: String = "  ", width: Int = IW - 4) -> [String] {
    guard !text.isEmpty else { return [indent] }
    var rows: [String] = []
    var current = indent
    let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

    for word in words {
        let candidate = current == indent ? indent + word : current + " " + word
        if vlen(candidate) <= width {
            current = candidate
        } else {
            rows.append(current)
            current = indent + word
        }
    }
    rows.append(current)
    return rows
}

func displayVisualWidth(_ s: String) -> Int { vlen(s) }

private func renderScreen(_ lines: [String],
                          prompt: String? = nil,
                          clearScreen: Bool = true) -> String {
    var output = clearScreen ? A.clearScreen : ""
    output += lines.joined(separator: "\n")
    if let prompt {
        output += "\n\n" + prompt
    }
    return output
}

// ─── Main display function ────────────────────────────────────────────────

func renderDashboard(_ simulator: EconomicSimulator) -> String {
    let s = simulator.state
    let env = simulator.environment
    let log = simulator.log
    let crisisMeasures = simulator.availableCrisisMeasures()
    let hasCabinetRequest = simulator.activeCabinetRequest != nil
    let crisisMenuRelevant = !crisisMeasures.isEmpty || simulator.crisisCooldownQuarters > 0
    var lines: [String] = []

    enum FooterCommandState {
        case always
        case urgent
        case dormant
    }

    func footerCommand(_ label: String, _ state: FooterCommandState) -> String {
        switch state {
        case .always:
            return A.bold + A.bCyan + label + A.reset
        case .urgent:
            return A.bold + A.bYellow + label + A.reset
        case .dormant:
            return A.dim + label + A.reset
        }
    }

    // Title bar
    lines.append(hline(TL, HH, TR))
    let title = A.bold + "CENTRAL BANK OF SOLAVERDE — GOVERNOR'S DASHBOARD" + A.reset
    let titlePadded = pad(title, to: IW - 2)
    lines.append(VV + " " + titlePadded + " " + VV)
    let dateLine = A.bold + A.cyan + s.quarterLabel + A.reset
    let diffLabel = A.dim + "  |  " + simulator.difficulty.displayName + A.reset
    let dateSection = pad("  Solan Dollar (SLD)  |  " + dateLine + diffLabel, to: IW - 2)
    lines.append(VV + " " + dateSection + " " + VV)
    lines.append(hline(ML, HH, MR))

    // Section: Real Economy | Monetary Conditions
    lines.append(sheader("  REAL ECONOMY", "  MONETARY CONDITIONS"))
    lines.append(crow(pad("", to: LC), pad("", to: RC)))

    // GDP Growth
    let gdpVal = s.annualizedGDPGrowth
    let gdpStr = coloredPct(gdpVal, lo: -0.01, hi: 0.025, direction: 1) + " ann " + trend(log.gdpGrowthHistory)
    let gdpRow = "  GDP Growth:      " + gdpStr
    let rateStr = "  Policy Rate:    " + A.bold + pct(s.policyRate) + A.reset
    lines.append(crow(gdpRow, rateStr))

    // Output gap | Reserve Requirement
    let gapColor = abs(s.outputGap) < 0.01 ? A.bGreen : (abs(s.outputGap) < 0.03 ? A.bYellow : A.bRed)
    let gapDeltaStr = s.outputGapDelta == 0 ? "" : A.dim + String(format: " %+.1fpp", s.outputGapDelta * 100) + A.reset
    let gapStr = "  Output Gap:     " + gapColor + String(format: "%+.1f%%", s.outputGap * 100) + A.reset + gapDeltaStr
    let rrStr = "  Reserve Req:    " + pct(s.reserveRequirement)
    lines.append(crow(gapStr, rrStr))

    // Unemployment | Inflation Surprise
    let uStr = "  Unemployment:   " + coloredPct(s.unemployment, lo: 0.05, hi: 0.09, direction: -1) + " " + trend(log.unemploymentHistory)
    let surprise = s.inflation - s.expectedInflation
    let surpriseColor = surprise > 0.005 ? A.bRed : (surprise < -0.005 ? A.bGreen : A.bYellow)
    let surpriseStr = "  Infl. Surprise: " + surpriseColor + String(format: "%+.1fpp", surprise * 100) + A.reset
    lines.append(crow(uStr, surpriseStr))

    // Inflation | Expected Inflation
    let infColor = s.inflation < 0.05 ? A.bGreen : (s.inflation < 0.10 ? A.bYellow : A.bRed)
    let infDeltaStr = s.inflationDelta == 0 ? "" : A.dim + String(format: " %+.1fpp", s.inflationDelta * 100) + A.reset
    let infStr = "  Inflation:      " + infColor + pct(s.inflation) + A.reset + infDeltaStr + " " + trend(log.inflationHistory)
    let expDeltaStr = s.expectedInflationDelta == 0 ? "" : A.dim + String(format: " %+.1fpp", s.expectedInflationDelta * 100) + A.reset
    let expStr = "  Exp. Inflation: " + coloredPct(s.expectedInflation, lo: 0.02, hi: 0.08, direction: -1) + expDeltaStr
    lines.append(crow(infStr, expStr))

    // Core inflation | Real interest rate
    let coreStr = "  Core Inflation: " + pct(s.coreInflation)
    let rrealVal = s.realInterestRate
    let rrealColor = rrealVal > 0.005 ? A.bGreen : (rrealVal > -0.02 ? A.bYellow : A.bRed)
    let rrealStr = "  Real Rate:      " + rrealColor + signed(rrealVal) + A.reset
    lines.append(crow(coreStr, rrealStr))

    // Credibility bar
    let credColor = s.credibility > 0.6 ? A.bGreen : (s.credibility > 0.35 ? A.bYellow : A.bRed)
    let credBar = bar(s.credibility, color: credColor)
    let credStr = "  CB Credibility: " + credBar + " " + credColor + String(format: "%.0f%%", s.credibility * 100) + A.reset
    lines.append(crow(pad("", to: LC), credStr))

    let commColor: String
    switch simulator.communicationStance {
    case .hawkish: commColor = A.bCyan
    case .balanced: commColor = A.bGreen
    case .dovish: commColor = A.bYellow
    case .opaque: commColor = A.bRed
    }
    let commStr = "  Comm Stance:   " + commColor + simulator.communicationStance.dashboardLabel + A.reset
    lines.append(crow(pad("", to: LC), commStr))

    let cabinetStr: String
    if let request = simulator.activeCabinetRequest {
        cabinetStr = "  Cabinet Ask:   " + A.bYellow + request.title.uppercased() + A.reset
    } else {
        cabinetStr = "  Cabinet Ask:   " + A.dim + "NONE" + A.reset
    }
    lines.append(crow(pad("", to: LC), cabinetStr))

    let crisisColor: String
    if simulator.crisisCooldownQuarters > 0 {
        crisisColor = A.bYellow
    } else if crisisMeasures.isEmpty {
        crisisColor = A.dim
    } else {
        crisisColor = A.bRed
    }
    let crisisStr = "  Crisis Tools:  " + crisisColor + simulator.crisisStatusText() + A.reset
    lines.append(crow(pad("", to: LC), crisisStr))

    // Two-line advisor strip. Keep each line short and stable so the dashboard
    // never overruns the frame on narrower terminals.
    let cp = simulator.params.credibility
    let credHint = String(format: "  Credibility: misses above +%.1fpp hurt; calm sub-%.1f%% inflation rebuilds.",
                          cp.surpriseThreshold * 100, cp.calmInflationCeiling * 100)
    let advisory: String
    if simulator.activeCabinetRequest != nil {
        advisory = "  Cabinet pending. Use cabinet, accept, reject, or delay."
    } else if !crisisMeasures.isEmpty {
        advisory = "  Crisis tools available. Use crisis, then measure <name>."
    } else if simulator.crisisCooldownQuarters > 0 {
        advisory = "  Crisis tools cooling down. Use the runway to stabilize the economy."
    } else if simulator.communicationStance == .hawkish && !simulator.isHawkishCommunicationConsistent(state: s) {
        advisory = "  Warning: hawkish guidance is not matched by current policy."
    } else if simulator.communicationStance != .balanced {
        advisory = "  Communication stance stays active until you change it."
    } else {
        advisory = "  Tip: use preview with overrides before advance when conditions feel unstable."
    }
    lines.append(frow(A.dim + credHint + A.reset))
    lines.append(frow(A.dim + advisory + A.reset))

    // Separator
    lines.append(hline(ML, HH, MR))

    // Section: External Sector | Reserves & Risk
    lines.append(sheader("  EXTERNAL SECTOR", "  RESERVES & RISK"))
    lines.append(crow(pad("", to: LC), pad("", to: RC)))

    // Exchange Rate | Foreign Reserves
    let erChange = s.exchangeRateQoQChange
    let erChangeStr = erChange >= 0 ? A.bRed + String(format: "+%.2f%%", erChange * 100) + A.reset
                                    : A.bGreen + String(format: "%.2f%%", erChange * 100) + A.reset
    let erStr = "  Exch. Rate:  " + A.bold + String(format: "%.3f", s.exchangeRate) + " SLD/USD" + A.reset + " (" + erChangeStr + ")"
    let resColor = s.foreignReservesMonths > 4.0 ? A.bGreen : (s.foreignReservesMonths > 2.5 ? A.bYellow : A.bRed)
    let resBar = bar(s.foreignReservesMonths, maxVal: 6.0, color: resColor)
    let resStr = "  FX Reserves: " + resBar + " " + resColor + String(format: "%.1f", s.foreignReservesMonths) + " mo" + A.reset
    lines.append(crow(erStr, resStr))

    // Current Account | Political Pressure
    let caColor = s.currentAccountGDP > -0.02 ? A.bGreen : (s.currentAccountGDP > -0.05 ? A.bYellow : A.bRed)
    let caStr = "  Current Acct: " + caColor + String(format: "%+.1f%%", s.currentAccountGDP * 100) + " GDP" + A.reset
    // Political pressure — shown as current / ouster-threshold so the player
    // can see how much runway they actually have. Bar scales against threshold
    // (not 100) so "bar full" and "game over" align visually.
    let ousterThreshold = simulator.params.outcomes.politicalOusterPressure
    let polColor = s.politicalPressure < ousterThreshold * 0.4 ? A.bGreen
                 : (s.politicalPressure < ousterThreshold * 0.75 ? A.bYellow : A.bRed)
    let polBar = bar(s.politicalPressure, maxVal: ousterThreshold, width: 8, color: polColor)
    let polStr = "  Pol. Pressure:" + polBar + " " + polColor
               + String(format: "%.0f/%.0f", s.politicalPressure, ousterThreshold) + A.reset
    lines.append(crow(caStr, polStr))

    // Capital Account | Public Approval
    let kaColor = s.capitalAccountGDP >= 0 ? A.bGreen : A.bRed
    let kaStr = "  Capital Acct:  " + kaColor + String(format: "%+.1f%%", s.capitalAccountGDP * 100) + " GDP" + A.reset
    let appColor = s.publicApproval > 55 ? A.bGreen : (s.publicApproval > 35 ? A.bYellow : A.bRed)
    let appBar = bar(s.publicApproval, maxVal: 100, width: 8, color: appColor)
    let appStr = "  CB Approval:  " + appBar + " " + appColor + String(format: "%.0f%%", s.publicApproval) + A.reset
    lines.append(crow(kaStr, appStr))

    // Capital Controls | Oil Price
    let ctrlLabel: String
    switch s.capitalControls {
    case 0.0..<0.20: ctrlLabel = A.bYellow + "MINIMAL" + A.reset
    case 0.20..<0.45: ctrlLabel = A.bYellow + "MODERATE" + A.reset
    case 0.45..<0.70: ctrlLabel = A.bYellow + "SUBSTANTIAL" + A.reset
    default: ctrlLabel = A.bRed + "COMPREHENSIVE" + A.reset
    }
    let ctrlStr = "  Cap. Controls: " + ctrlLabel + String(format: " (%.0f%%)", s.capitalControls * 100)
    let oilColor = env.oilPriceIndex < 200 ? A.bGreen : (env.oilPriceIndex < 350 ? A.bYellow : A.bRed)
    let oilStr = "  Oil Idx:  " + oilColor + String(format: "%.0f", env.oilPriceIndex) + A.reset + "  World Rate: " + pct(env.worldInterestRate)
    lines.append(crow(ctrlStr, oilStr))

    // External Debt | Fiscal Balance
    let debtStr = "  Ext. Debt:     " + String(format: "%.1f%%", s.externalDebtGDP * 100) + " GDP"
    let fiscColor = s.fiscalBalanceGDP > -0.03 ? A.bGreen : (s.fiscalBalanceGDP > -0.06 ? A.bYellow : A.bRed)
    let fiscStr = "  Fiscal Bal:    " + fiscColor + String(format: "%+.1f%%", s.fiscalBalanceGDP * 100) + " GDP" + A.reset
    lines.append(crow(debtStr, fiscStr))

    // News section
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  RECENT EVENTS & ECONOMIC ANALYSIS" + A.reset))
    lines.append(frow(""))

    let newsToShow = min(5, log.newsLog.count)
    if newsToShow == 0 {
        lines.append(frow("  " + A.dim + "No events recorded yet." + A.reset))
    } else {
        for i in 0..<newsToShow {
            let entry = log.newsLog[i]
            // First entry is most recent — highlight it
            let formatted = i == 0
                ? "  " + A.white + entry + A.reset
                : "  " + A.dim + entry + A.reset
            // Wrap if too long
            let maxLen = IW - 4
            if vlen(entry) + 2 <= maxLen {
                lines.append(frow(formatted))
            } else {
                // Simple truncation with ellipsis
                let truncated = String(entry.prefix(maxLen - 3)) + "..."
                let display = i == 0
                    ? "  " + A.white + truncated + A.reset
                    : "  " + A.dim + truncated + A.reset
                lines.append(frow(display))
            }
        }
    }

    // Commands. Group by job so the footer reads like a control panel instead
    // of a flat token list. Bright yellow means "relevant right now", cyan is
    // generally available, and dim is currently dormant.
    lines.append(hline(ML, HH, MR))
    let crisisMeasureHint: String = {
        if !crisisMeasures.isEmpty {
            return "measure " + crisisMeasures.map(\.type.commandName).joined(separator: "|")
        }
        if simulator.crisisCooldownQuarters > 0 {
            return "measure <cooldown>"
        }
        return "measure <locked>"
    }()

    lines.append(frow(A.dim + "  Yellow = relevant now. Cyan = generally available. Dim = dormant." + A.reset))
    lines.append(frow("  " + A.bold + "POLICY:" + A.reset + " "
        + footerCommand("rate <x.x>", .always) + " "
        + footerCommand("reserve <x>", .always) + " "
        + footerCommand("controls <0-10>", .always) + " "
        + footerCommand("intervene <±x.x>", .always)))
    lines.append(frow("  " + A.bold + "NEXT:" + A.reset + " "
        + footerCommand("preview (p) [overrides]", .always) + " "
        + footerCommand("advance (n)", .always) + "  "
        + A.bold + "COMM:" + A.reset + " "
        + footerCommand("comm <stance>", .always)))
    lines.append(frow("  " + A.bold + "CABINET:" + A.reset + " "
        + footerCommand("cabinet", hasCabinetRequest ? .urgent : .dormant) + " "
        + footerCommand("accept", hasCabinetRequest ? .urgent : .dormant) + " "
        + footerCommand("reject", hasCabinetRequest ? .urgent : .dormant) + " "
        + footerCommand("delay", hasCabinetRequest ? .urgent : .dormant)))
    lines.append(frow("  " + A.bold + "CRISIS:" + A.reset + " "
        + footerCommand("crisis", crisisMenuRelevant ? .urgent : .dormant) + " "
        + footerCommand(crisisMeasureHint, !crisisMeasures.isEmpty ? .urgent : .dormant)))
    lines.append(frow("  " + A.bold + "INFO:" + A.reset + " "
        + footerCommand("status", .always) + " "
        + footerCommand("history", .always) + " "
        + footerCommand("news", .always) + " "
        + footerCommand("report", .always) + " "
        + footerCommand("why", .always) + " "
        + footerCommand("advisor [topic]", .always) + " "
        + footerCommand("tutorial", .always) + " "
        + footerCommand("help", .always)))
    lines.append(frow("  " + A.bold + "FILES:" + A.reset + " "
        + footerCommand("save", .always) + " "
        + footerCommand("load", .always) + " "
        + footerCommand("quit", .always)))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + "  Governor > " + A.reset))
    lines.append(hline(BL, HH, BR))

    return renderScreen(lines)
}

func drawDashboard(_ simulator: EconomicSimulator) {
    print(renderDashboard(simulator))
}

// Compact projection box for `preview`. Shows the staff estimate for the next
// quarter, including slight deterministic forecast error so previews remain
// informative without becoming a perfect oracle.
// Intentionally smaller than the dashboard: previews are a conversation,
// not a screen take-over.
func renderPreview(_ estimate: ForecastEstimate, headerNote: String? = nil) -> String {
    let report = estimate.report
    let before = report.stateBefore
    let after = estimate.estimatedAfter
    var lines: [String] = []

    lines.append("")
    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  STAFF FORECAST — " + after.quarterLabel + A.reset
                      + A.dim + "   (dry run, no state changed)" + A.reset))
    if let note = headerNote {
        lines.append(frow(A.bYellow + "  " + note + A.reset))
    }
    lines.append(frow(A.dim + "  Forecasts are approximate. Realized data may differ modestly next quarter." + A.reset))
    lines.append(hline(ML, HH, MR))

    // Events section
    if report.events.isEmpty {
        lines.append(frow(A.dim + "  Events this quarter: (none)" + A.reset))
    } else {
        lines.append(frow(A.bold + "  Events this quarter:" + A.reset))
        for n in report.news where isEventHeadline(n) {
            lines.append(frow("  • " + n))
        }
    }
    lines.append(hline(ML, HH, MR))

    // Projected deltas — one row per indicator
    lines.append(frow(A.bold + "  Indicator              Before      Forecast       Δ" + A.reset))
    lines.append(previewRow("Inflation",        before.inflation,           after.inflation,           style: .pct))
    lines.append(previewRow("Expected infl.",   before.expectedInflation,   after.expectedInflation,   style: .pct))
    lines.append(previewRow("Output gap",       before.outputGap,           after.outputGap,           style: .ppSigned))
    lines.append(previewRow("GDP growth (ann)", before.annualizedGDPGrowth, after.annualizedGDPGrowth, style: .ppSigned))
    lines.append(previewRow("Unemployment",     before.unemployment,        after.unemployment,        style: .pct))
    lines.append(previewRow("Credibility",      before.credibility,         after.credibility,         style: .ratio))
    lines.append(previewRow("Reserves (mo)",    before.foreignReservesMonths, after.foreignReservesMonths, style: .months))
    lines.append(previewRow("Exchange rate",    before.exchangeRate,        after.exchangeRate,        style: .fx))
    lines.append(previewRow("Political press.", before.politicalPressure,   after.politicalPressure,   style: .score))
    lines.append(previewRow("Public approval",  before.publicApproval,      after.publicApproval,      style: .score))

    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.dim + "  Press any key to return to dashboard — no changes have been applied." + A.reset))
    lines.append(hline(BL, HH, BR))

    return renderScreen(lines, clearScreen: false)
}

func drawPreview(_ estimate: ForecastEstimate, headerNote: String? = nil) {
    print(renderPreview(estimate, headerNote: headerNote))
}

// Format styles for preview rows
private enum PreviewStyle { case pct, ppSigned, ratio, months, fx, score }

private func previewRow(_ label: String, _ b: Double, _ a: Double, style: PreviewStyle) -> String {
    let delta = a - b
    let bStr: String
    let aStr: String
    let dStr: String
    switch style {
    case .pct:
        bStr = String(format: "%.2f%%", b * 100)
        aStr = String(format: "%.2f%%", a * 100)
        dStr = String(format: "%+.2fpp", delta * 100)
    case .ppSigned:
        bStr = String(format: "%+.2f%%", b * 100)
        aStr = String(format: "%+.2f%%", a * 100)
        dStr = String(format: "%+.2fpp", delta * 100)
    case .ratio:
        bStr = String(format: "%.2f", b)
        aStr = String(format: "%.2f", a)
        dStr = String(format: "%+.3f", delta)
    case .months:
        bStr = String(format: "%.2f", b)
        aStr = String(format: "%.2f", a)
        dStr = String(format: "%+.2f", delta)
    case .fx:
        bStr = String(format: "%.3f", b)
        aStr = String(format: "%.3f", a)
        dStr = String(format: "%+.3f", delta)
    case .score:
        bStr = String(format: "%.1f", b)
        aStr = String(format: "%.1f", a)
        dStr = String(format: "%+.1f", delta)
    }
    // Color the delta by sign for indicators where direction matters. We keep
    // this neutral for now — player context determines "good" vs "bad".
    let dColored: String
    if abs(delta) < 1e-9 {
        dColored = A.dim + dStr + A.reset
    } else if delta > 0 {
        dColored = A.bYellow + dStr + A.reset
    } else {
        dColored = A.bCyan + dStr + A.reset
    }
    let body = "  " + pad(label, to: 22) + pad(bStr, to: 14) + pad(aStr, to: 14) + dColored
    return frow(body)
}

// Heuristic: the simulator emits event headlines in UPPERCASE-prefixed form
// ("OIL SHOCK:", "SPECULATIVE ATTACK:", "IMF ARTICLE IV:"). Commentary is
// sentence-case. This separates "things that happened to you" from
// "things about how you're doing", which is what a preview wants.
private func isEventHeadline(_ s: String) -> Bool {
    guard let colonIdx = s.firstIndex(of: ":") else { return false }
    let prefix = s[..<colonIdx]
    // At least 3 chars and all uppercase letters / spaces
    let ok = prefix.count >= 3 && prefix.allSatisfy { $0.isUppercase || $0 == " " || $0 == "-" }
    return ok
}

private struct ScenarioAssessmentSummary {
    let heading: String
    let headingColor: String
    let overview: String
    let focus: [String]
    let missedObjectives: [String]
}

private func scenarioAssessmentSummary(for scenario: ScenarioDefinition,
                                       goalStatuses: [ScenarioGoalStatus],
                                       outcome: GameOutcome) -> ScenarioAssessmentSummary {
    let metCount = goalStatuses.filter(\.met).count
    let totalGoals = max(goalStatuses.count, 1)
    let ratio = Double(metCount) / Double(totalGoals)
    let missed = goalStatuses.filter { !$0.met }.map(\.description)

    let heading: String
    let headingColor: String
    let overview: String

    switch outcome {
    case .success where metCount == goalStatuses.count:
        heading = "LESSON MASTERED"
        headingColor = A.bGreen
        overview = "You met the scenario's objectives and handled its core tradeoff with discipline."
    case .success where ratio >= 0.67:
        heading = "STRONG BUT IMPERFECT"
        headingColor = A.bYellow
        overview = "You held the system together and learned most of the lesson, but one weak flank remained."
    case .success where ratio > 0.0:
        heading = "PARTIAL COMMAND"
        headingColor = A.bYellow
        overview = "You solved part of the scenario, but the underlying policy lesson was only partly absorbed."
    case .ongoing where ratio > 0.0:
        heading = "PARTIAL COMMAND"
        headingColor = A.bYellow
        overview = "You solved part of the scenario, but the underlying policy lesson was only partly absorbed."
    default:
        heading = "LESSON MISSED"
        headingColor = A.bRed
        overview = "The run failed to secure the scenario's central tradeoff before the crisis or politics closed in."
    }

    return ScenarioAssessmentSummary(
        heading: heading,
        headingColor: headingColor,
        overview: overview,
        focus: scenario.teachingFocus,
        missedObjectives: missed
    )
}

func renderGameOver(_ outcome: GameOutcome, _ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) -> String {
    let s = simulator.state
    let card = simulator.scoreCard
    let score = computeScore(outcome: outcome, card: card, gameLength: gameLength)
    let scenario = scenarioDefinition(id: scenarioID)
    let goalStatuses = evaluateScenarioGoals(scenarioID: scenarioID, state: s)
    var lines: [String] = [""]

    lines.append(hline(TL, HH, TR))
    switch outcome {
    case .currencyCrisis:
        lines.append(frow(A.bRed + A.bold + "  CURRENCY CRISIS — GAME OVER" + A.reset))
        lines.append(frow(""))
        lines.append(frow("  The Solan Dollar has collapsed. Foreign reserves exhausted;"))
        lines.append(frow("  the SLD enters freefall. The IMF imposes emergency conditionality."))
        lines.append(frow("  You are dismissed as Governor. Solaverde faces a decade of austerity."))
    case .hyperinflation:
        lines.append(frow(A.bRed + A.bold + "  HYPERINFLATION — GAME OVER" + A.reset))
        lines.append(frow(""))
        lines.append(frow("  Inflation has spiralled beyond control. Prices doubling quarterly."))
        lines.append(frow("  The public has lost all confidence in the Solan Dollar."))
        lines.append(frow("  Currency reform and dollarisation forced upon the government."))
    case .depression:
        lines.append(frow(A.bRed + A.bold + "  ECONOMIC DEPRESSION — GAME OVER" + A.reset))
        lines.append(frow(""))
        lines.append(frow("  The economy has collapsed into severe depression. Mass unemployment."))
        lines.append(frow("  Social unrest and political chaos force your resignation."))
        lines.append(frow("  Solaverde appeals for emergency international assistance."))
    case .politicalOuster:
        lines.append(frow(A.bRed + A.bold + "  POLITICAL OUSTER — GAME OVER" + A.reset))
        lines.append(frow(""))
        lines.append(frow("  Political pressure has become overwhelming. The Cabinet has voted"))
        lines.append(frow("  to remove you as Governor. Central bank independence is abolished."))
        lines.append(frow("  Your replacement immediately cuts rates to win the next election."))
    case .success:
        lines.append(frow(A.bGreen + A.bold + "  YOU SURVIVED — CONGRATULATIONS, GOVERNOR" + A.reset))
        lines.append(frow(""))
        if let scenario {
            let met = goalStatuses.filter(\.met).count
            lines.append(frow("  Scenario completed: " + A.bold + scenario.title + A.reset))
            lines.append(frow("  Objective results: \(met)/\(goalStatuses.count) met."))
        } else {
            switch gameLength {
            case .short:
                lines.append(frow("  You have guided Solaverde through one of the most turbulent decades"))
                lines.append(frow("  in monetary history. The 1970s tested every central banker on earth."))
                lines.append(frow("  Solaverde enters the 1980s battered but intact."))
            case .extended:
                lines.append(frow("  You have completed a forty-year central-banking career without"))
                lines.append(frow("  losing the currency, the economy, or your office. Few governors"))
                lines.append(frow("  survive Bretton Woods, stagflation, debt crises, and the 1990s intact."))
            }
        }
    case .ongoing:
        break
    }

    // ─── Final state ────────────────────────────────────────────────────
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + String(format: "  FINAL STATE — %@", s.quarterLabel) + A.reset))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Inflation: %.1f%%   Unemployment: %.1f%%   Reserves: %.1f months",
        s.inflation * 100, s.unemployment * 100, s.foreignReservesMonths)))
    lines.append(frow(String(format: "  GDP Growth: %+.1f%%   Credibility: %.0f%%   Approval: %.0f%%",
        s.annualizedGDPGrowth * 100, s.credibility * 100, s.publicApproval)))

    if !goalStatuses.isEmpty {
        lines.append(hline(ML, HH, MR))
        lines.append(frow(A.bold + A.cyan + "  SCENARIO OBJECTIVES" + A.reset))
        lines.append(frow(""))
        for goal in goalStatuses {
            let marker = goal.met ? A.bGreen + "✓" + A.reset : A.bRed + "✗" + A.reset
            lines.append(frow("  \(marker) \(goal.description)"))
        }
    }

    if let scenario {
        let assessment = scenarioAssessmentSummary(for: scenario, goalStatuses: goalStatuses, outcome: outcome)
        lines.append(hline(ML, HH, MR))
        lines.append(frow(A.bold + A.cyan + "  SCENARIO ASSESSMENT" + A.reset))
        lines.append(frow(""))
        lines.append(frow("  " + assessment.headingColor + A.bold + assessment.heading + A.reset))
        for row in wrappedRows(assessment.overview) {
            lines.append(frow(row))
        }
        if !assessment.focus.isEmpty {
            lines.append(frow(""))
            lines.append(frow(A.bold + "  Lesson focus:" + A.reset))
            for note in assessment.focus {
                for row in wrappedRows(note, indent: "    • ") {
                    lines.append(frow(row))
                }
            }
        }
        if !assessment.missedObjectives.isEmpty {
            lines.append(frow(""))
            lines.append(frow(A.bold + "  What remained unresolved:" + A.reset))
            for note in assessment.missedObjectives.prefix(2) {
                for row in wrappedRows(note, indent: "    • ") {
                    lines.append(frow(row))
                }
            }
        }
    }

    // ─── Decade in review ──────────────────────────────────────────────
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  CAMPAIGN REVIEW" + A.reset
               + A.dim + String(format: "   (%d quarters simulated)", card.quartersSimulated) + A.reset))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Quarters with inflation >10%%:     %d", card.highInflationQuarters)))
    if card.severeInflationQuarters > 0 {
        lines.append(frow(String(format: "  Quarters with inflation >20%%:     %d   %@",
                          card.severeInflationQuarters,
                          A.dim + "(severe)" + A.reset)))
    }
    lines.append(frow(String(format: "  Quarters in recession:            %d", card.recessionQuarters)))
    if card.stagflationQuarters > 0 {
        lines.append(frow(String(format: "  Quarters of stagflation:          %d   %@",
                          card.stagflationQuarters,
                          A.dim + "(the hardest kind)" + A.reset)))
    }
    lines.append(frow(String(format: "  Quarters with unemployment >9%%:   %d", card.highUnemploymentQuarters)))
    lines.append(frow(String(format: "  Quarters near political ouster:   %d", card.nearOusterQuarters)))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Extremes reached:" + A.reset))
    lines.append(frow(String(format: "    Peak inflation                  %.1f%%", card.peakInflation * 100)))
    lines.append(frow(String(format: "    Trough GDP growth (annualised)  %+.1f%%", card.troughGrowthAnnualized * 100)))
    lines.append(frow(String(format: "    Peak unemployment               %.1f%%", card.peakUnemployment * 100)))
    lines.append(frow(String(format: "    Credibility trough              %.0f%%", card.lowestCredibility * 100)))
    lines.append(frow(String(format: "    Reserves low-water mark         %.1f months", card.lowestReserves)))
    lines.append(frow(String(format: "    Peak political pressure         %.0f / 92", card.peakPoliticalPressure)))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Policy reached for:" + A.reset))
    lines.append(frow(String(format: "    Peak policy rate                %.1f%%", card.peakPolicyRate * 100)))
    lines.append(frow(String(format: "    Peak reserve requirement        %.1f%%", card.peakReserveRequirement * 100)))
    lines.append(frow(String(format: "    Peak capital controls           %.0f / 10", card.peakCapitalControls * 10)))

    // ─── Scorecard ──────────────────────────────────────────────────────
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  SCORECARD" + A.reset))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Starting baseline:                          %+3d", score.baseline)))
    for item in score.items {
        let color = item.points < 0 ? A.bRed : A.bGreen
        let labelPadded = pad("    " + item.label, to: 44)
        let pts = String(format: "%+3d", item.points)
        lines.append(frow(labelPadded + color + pts + A.reset))
    }
    lines.append(frow(""))
    let finalColor = score.final >= 75 ? A.bGreen
                   : (score.final >= 45 ? A.bYellow : A.bRed)
    let finalLine = String(format: "  FINAL SCORE:                                %@%3d / 100%@",
                           finalColor + A.bold, score.final, A.reset)
    lines.append(frow(finalLine))
    lines.append(frow("  " + finalColor + A.bold + score.headline + A.reset))

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to exit...")
}

func drawGameOver(_ outcome: GameOutcome, _ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) {
    print(renderGameOver(outcome, simulator, gameLength: gameLength, scenarioID: scenarioID))
}

func renderHelp(gameLength: GameLength, scenarioID: String? = nil) -> String {
    func wrapPlain(_ text: String, width: Int) -> [String] {
        guard !text.isEmpty else { return [""] }
        var lines: [String] = []
        var current = ""

        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let token = String(word)
            let candidate = current.isEmpty ? token : current + " " + token
            if candidate.count <= width {
                current = candidate
            } else {
                if !current.isEmpty {
                    lines.append(current)
                    current = token
                } else {
                    lines.append(String(token.prefix(width)))
                }
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    var lines: [String] = []

    func helpSection(_ title: String) {
        lines.append(hline(ML, HH, MR))
        lines.append(frow(A.bold + A.cyan + "  " + title + A.reset))
        lines.append(hline(ML, HH, MR))
    }

    func helpParagraph(_ text: String, indent: String = "  ") {
        let wrapped = wrapPlain(text, width: IW - 2 - indent.count)
        for line in wrapped {
            lines.append(frow(indent + line))
        }
    }

    func helpCommand(_ name: String, details: [String]) {
        lines.append(frow("  " + A.bold + A.bYellow + name + A.reset))
        for detail in details {
            helpParagraph(detail, indent: "    ")
        }
    }

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  HELP & REFERENCE" + A.reset))
    lines.append(frow(A.dim + "  Commands, metric definitions, and strategy notes." + A.reset))

    helpSection("CORE COMMANDS")
    helpCommand("rate <value>", details: [
        "Set the policy or discount rate. Example: rate 8.5 sets the rate to 8.5%."
    ])
    helpCommand("reserve <value>", details: [
        "Set the reserve requirement. Example: reserve 15 sets the requirement to 15%."
    ])
    helpCommand("controls <0-10>", details: [
        "Set the capital-control level. 0 means mostly open; 10 means near-total closure."
    ])
    helpCommand("intervene <±value>", details: [
        "FX intervention in months of reserves.",
        "Positive means buy reserves and weaken SLD.",
        "Negative means spend reserves to defend SLD."
    ])
    helpCommand("comm <stance>", details: [
        "Set the communication stance until you change it.",
        "Available stances: hawkish, balanced, dovish, opaque."
    ])
    helpCommand("advance", details: [
        "Advance one quarter and run the simulation. Aliases: next, n."
    ])
    helpCommand("preview", details: [
        "Dry-run the next quarter under current policy.",
        "You can also test hypothetical overrides, for example:",
        "preview rate 12.5",
        "preview reserve 15 controls 6",
        "No state changes. Forecasts are informative, not exact."
    ])

    helpSection("POLITICS & CRISIS")
    helpCommand("cabinet", details: [
        "Show the active cabinet demand for this quarter."
    ])
    helpCommand("accept / reject / delay", details: [
        "Respond to the current cabinet demand."
    ])
    helpCommand("crisis", details: [
        "Show emergency measures unlocked by severe stress."
    ])
    helpCommand("measure <name>", details: [
        "Use an emergency tool when available.",
        "Available names: imf, holiday, liquidity."
    ])

    helpSection("INFORMATION & FILES")
    helpCommand("status", details: [
        "Show the extended economic report."
    ])
    helpCommand("history", details: [
        "Show whole-run trend charts plus a recent-quarter table."
    ])
    helpCommand("news", details: [
        "Show the full retained news log for the run."
    ])
    helpCommand("report", details: [
        "Show a campaign summary with averages and extremes."
    ])
    helpCommand("why", details: [
        "Show a plain-language debrief of the last completed quarter.",
        "Useful when you know what moved but not why it moved."
    ])
    helpCommand("advisor [topic]", details: [
        "Show staff advice on the most urgent current problem, plus lever suggestions.",
        "You can also ask for a focus explicitly, for example: advisor currency, advisor inflation, advisor debt, advisor growth, or advisor balance of payments."
    ])
    helpCommand("tutorial", details: [
        "Show a guided opening briefing with concrete advice for the current stage of the run."
    ])
    helpCommand("save [path]", details: [
        "Save the current session. Default path: ./solaverde.save.json."
    ])
    helpCommand("load [path]", details: [
        "Load a saved session. Default path: ./solaverde.save.json."
    ])
    helpCommand("help / quit", details: [
        "Show this screen or exit the game."
    ])
    helpParagraph("CLI flags: --seed <uint64>, --mode <h|r>, --length <s|e>, and --difficulty <a|g|v> skip the startup menus.", indent: "  " + A.dim)
    lines.append(frow(""))

    helpSection("WHAT THE MAIN METRICS MEAN")
    helpCommand("Inflation / Exp. Inflation", details: [
        "Current price growth, and what households and firms expect next.",
        "Once expectations rise, inflation gets harder to bring down."
    ])
    helpCommand("Output Gap / GDP Growth", details: [
        "How hot or weak the economy is relative to trend.",
        "A negative gap means slack and recession pressure."
    ])
    helpCommand("Current Account", details: [
        "Trade, services, and income flow with the rest of the world.",
        "Negative means the country is spending more abroad than it earns.",
        "Persistent deficits build external debt."
    ])
    helpCommand("Capital Account", details: [
        "Net private money moving in or out.",
        "Positive means inflows and easier external financing.",
        "Negative means capital flight or weak investor appetite."
    ])
    helpCommand("FX Reserves", details: [
        "Months of imports the central bank can cover with foreign currency.",
        "This is your main crisis buffer."
    ])
    helpCommand("Exchange Rate", details: [
        "SLD per USD.",
        "A higher number means a weaker Solan Dollar.",
        "A lower number means a stronger Solan Dollar."
    ])
    helpCommand("External Debt", details: [
        "Stock of obligations owed abroad.",
        "In this model it rises mainly when current-account deficits persist and falls only through sustained surpluses."
    ])
    helpCommand("Credibility", details: [
        "Markets' belief that you will control inflation.",
        "Low credibility de-anchors expectations."
    ])
    helpCommand("Political Pressure / Approval", details: [
        "Cabinet heat and public tolerance.",
        "High inflation, high unemployment, and recession all work against you."
    ])

    helpSection("HOW TO MOVE THEM")
    helpCommand("To lower inflation", details: [
        "Raise the policy rate and keep policy tight long enough for expectations to cool.",
        "Hawkish communication helps only if policy is truly tight."
    ])
    helpCommand("To support growth or lower unemployment", details: [
        "Cut rates or avoid overtightening.",
        "This usually risks more inflation or FX pressure, especially when credibility is weak."
    ])
    helpCommand("To strengthen the currency", details: [
        "Raise rates, tighten controls, or spend reserves with intervene -x to defend SLD.",
        "Reserve defense can stabilize FX, but it is costly."
    ])
    helpCommand("To rebuild reserves", details: [
        "Improve the balance of payments through a better current account and stronger capital inflows.",
        "You can also use intervene +x to buy reserves and weaken SLD."
    ])
    helpCommand("To improve the current account", details: [
        "A weaker currency and softer domestic demand usually help.",
        "Overheated growth and real appreciation usually hurt."
    ])
    helpCommand("To improve the capital account", details: [
        "Higher rates and calmer FX tend to attract inflows.",
        "Expected depreciation pushes money out.",
        "Controls can slow outflows but may also deter new capital."
    ])
    helpCommand("To lower external debt", details: [
        "Run smaller current-account deficits or, better, sustained surpluses.",
        "Defending the currency with reserves alone does not pay debt down."
    ])
    helpCommand("To rebuild credibility", details: [
        "Avoid upside inflation surprises.",
        "Keep inflation calm for several quarters.",
        "Do not use hawkish language without backing it up in policy."
    ])
    helpCommand("To relieve political pressure", details: [
        "Reduce inflation and job pain.",
        "Dovish communication or accepting cabinet demands can buy time, but often at a later economic cost."
    ])
    helpCommand("Reserve requirement", details: [
        "This is a secondary tightening tool.",
        "Raising it leans against credit growth; lowering it eases conditions.",
        "The policy rate remains the main lever."
    ])

    helpSection("CRISIS MEASURES")
    helpParagraph("These tools appear only under real stress and then go on cooldown. They are meant to create hard choices, not routine quarter-by-quarter play.")
    helpCommand("measure imf", details: [
        "Rebuilds reserves and external confidence, but hurts growth, approval, and adds debt."
    ])
    helpCommand("measure holiday", details: [
        "Stops a bank-run dynamic quickly, usually with tighter controls, but damages confidence."
    ])
    helpCommand("measure liquidity", details: [
        "Supports banks and activity in recession, but risks higher inflation and weaker credibility."
    ])

    helpSection("MODEL NOTES")
    helpParagraph("Difficulty changes structural coefficients like Phillips-curve sensitivity, expectations adaptation, credibility costs, and political reactivity.")
    helpParagraph("Apprentice softens punishing channels; Volcker sharpens them. Win and lose thresholds stay the same.")
    print(frow(""))
    helpParagraph("The model uses expectations-augmented Phillips-curve dynamics. Once inflation expectations de-anchor, bringing them back requires sustained tight policy and a credibility cost.")
    helpParagraph("Communication matters: hawkish messaging helps only when policy is actually tight; otherwise it backfires and damages credibility.")
    helpParagraph("The Mundell-Fleming trilemma applies: with open capital markets you cannot simultaneously fix the exchange rate and set domestic rates freely.")
    helpParagraph("Capital controls buy more monetary independence, but signal weakness to international markets and investors.")
    print(frow(""))
    switch gameLength {
    case .short:
        helpParagraph("Surviving to 1982 requires navigating two oil shocks, plus the sharp global rate spike of 1979–1981.")
    case .extended:
        helpParagraph("The extended campaign runs from 1960 to 2000: Bretton Woods calm, the 1970s shocks, the 1980s debt era, and 1990s capital volatility.")
    }
    if let scenario = scenarioDefinition(id: scenarioID) {
        lines.append(frow(""))
        helpParagraph("Active scenario: \(scenario.title) (\(scenario.rangeLabel)). Scenario goals appear in report and on the end screen.")
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawHelp(gameLength: GameLength, scenarioID: String? = nil) {
    print(renderHelp(gameLength: gameLength, scenarioID: scenarioID))
}

func renderCrisisOptions(_ simulator: EconomicSimulator) -> String {
    let measures = simulator.availableCrisisMeasures()
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  CRISIS OPTIONS" + A.reset))
    lines.append(hline(ML, HH, MR))

    if simulator.crisisCooldownQuarters > 0 {
        lines.append(frow("  Crisis tools are cooling down for \(simulator.crisisCooldownQuarters) more quarters."))
        lines.append(frow("  Stabilize the economy with your normal policy tools until they reopen."))
    } else if measures.isEmpty {
        lines.append(frow("  No emergency measures are currently unlocked."))
        lines.append(frow("  They appear only under severe external or domestic stress."))
    } else {
        lines.append(frow("  Available now. You may enact one with " + A.bold + "measure <name>" + A.reset + "."))
        lines.append(frow("  After use, crisis tools go on a four-quarter cooldown."))
        lines.append(frow(""))
        for measure in measures {
            lines.append(frow("  " + A.bold + "measure \(measure.type.commandName)" + A.reset + " — " + measure.type.title))
            lines.append(frow("    " + measure.detail))
            lines.append(frow("    Tradeoff: " + measure.tradeoff))
            lines.append(frow(""))
        }
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawCrisisOptions(_ simulator: EconomicSimulator) {
    print(renderCrisisOptions(simulator))
}

func renderHistory(_ simulator: EconomicSimulator) -> String {
    let log = simulator.log
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  ECONOMIC HISTORY — TREND CHARTS" + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(""))

    let chartWidth = max(12, min(44, IW - 33))

    func miniChart(_ label: String, _ history: [Double], scale: Double, good: Range<Double>, warn: Range<Double>) -> String {
        let sampled = sampledHistory(history, limit: chartWidth)
        var chart = "  " + pad(label, to: 20) + " "
        for v in sampled {
            let ratio = min(1.0, max(0, v / scale))
            let bar = ratio > 0.66 ? "▇" : (ratio > 0.33 ? "▄" : "▁")
            let color = good.contains(v) ? A.bGreen : (warn.contains(v) ? A.bYellow : A.bRed)
            chart += color + bar + A.reset
        }
        if let last = history.last {
            chart += "  " + String(format: "%.1f%%", last * 100)
        }
        return chart
    }

    if log.inflationHistory.isEmpty {
        lines.append(frow("  " + A.dim + "No history yet — advance some quarters first." + A.reset))
    } else {
        lines.append(frow(miniChart("CPI Inflation", log.inflationHistory, scale: 0.25,
            good: 0.0..<0.05, warn: 0.05..<0.10)))
        lines.append(frow(miniChart("Unemployment", log.unemploymentHistory, scale: 0.20,
            good: 0.0..<0.07, warn: 0.07..<0.10)))
        let sampledGrowth = sampledHistory(log.gdpGrowthHistory, limit: chartWidth)
        lines.append(frow("  GDP Growth (ann)       " + sampledGrowth.map { v -> String in
            let color = v > 0.02 ? A.bGreen : (v > -0.01 ? A.bYellow : A.bRed)
            return color + (v > 0.02 ? "▇" : (v > 0 ? "▄" : "▁")) + A.reset
        }.joined() + (log.gdpGrowthHistory.last.map { "  " + String(format: "%+.1f%%", $0 * 100) } ?? "")))
    }
    lines.append(frow(""))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  RECENT QUARTER TABLE" + A.reset))
    lines.append(frow(A.bold + "  Quarter     CPI     GDP Ann   Unemp   Reserves   Rate   Pressure" + A.reset))
    if log.quarterSnapshots.isEmpty {
        lines.append(frow("  " + A.dim + "No completed quarters yet." + A.reset))
    } else {
        for snap in log.quarterSnapshots.suffix(12).reversed() {
            let row = "  "
                + pad(snap.quarterLabel, to: 10)
                + pad(String(format: "%5.1f%%", snap.inflation * 100), to: 9)
                + pad(String(format: "%+6.1f%%", snap.annualizedGDPGrowth * 100), to: 11)
                + pad(String(format: "%5.1f%%", snap.unemployment * 100), to: 9)
                + pad(String(format: "%5.1f mo", snap.foreignReservesMonths), to: 12)
                + pad(String(format: "%4.1f%%", snap.policyRate * 100), to: 8)
                + String(format: "%5.0f", snap.politicalPressure)
            lines.append(frow(row))
        }
    }
    lines.append(frow(""))
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawHistory(_ simulator: EconomicSimulator) {
    print(renderHistory(simulator))
}

func renderNewsLog(_ simulator: EconomicSimulator) -> String {
    let entries = simulator.log.fullNewsLog
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  FULL NEWS LOG" + A.reset))
    lines.append(hline(ML, HH, MR))
    if entries.isEmpty {
        lines.append(frow("  " + A.dim + "No news yet — advance some quarters first." + A.reset))
    } else {
        for entry in entries {
            for row in wrappedRows(entry) {
                lines.append(frow(row))
            }
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawNewsLog(_ simulator: EconomicSimulator) {
    print(renderNewsLog(simulator))
}

func renderCampaignReport(_ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) -> String {
    let snaps = simulator.log.quarterSnapshots
    let card = simulator.scoreCard
    let liveOutcome: GameOutcome = isCampaignComplete(state: simulator.state, gameLength: gameLength, scenarioID: scenarioID) ? .success : simulator.checkOutcome()
    let score = computeScore(outcome: liveOutcome, card: card, gameLength: gameLength)
    let avgInflation = snaps.isEmpty ? 0.0 : snaps.map(\.inflation).reduce(0, +) / Double(snaps.count)
    let avgGrowth = snaps.isEmpty ? 0.0 : snaps.map(\.annualizedGDPGrowth).reduce(0, +) / Double(snaps.count)
    let avgUnemployment = snaps.isEmpty ? 0.0 : snaps.map(\.unemployment).reduce(0, +) / Double(snaps.count)
    let avgReserves = snaps.isEmpty ? 0.0 : snaps.map(\.foreignReservesMonths).reduce(0, +) / Double(snaps.count)
    let avgRate = snaps.isEmpty ? 0.0 : snaps.map(\.policyRate).reduce(0, +) / Double(snaps.count)
    let scenario = scenarioDefinition(id: scenarioID)
    let goalStatuses = evaluateScenarioGoals(scenarioID: scenarioID, state: simulator.state)

    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  CAMPAIGN REPORT — " + campaignRangeLabel(gameLength: gameLength, scenarioID: scenarioID) + A.reset))
    lines.append(hline(ML, HH, MR))
    if let scenario {
        lines.append(frow("  Scenario: \(scenario.title)"))
    }
    lines.append(frow(String(format: "  Quarters completed: %d   Current quarter: %@", card.quartersSimulated, simulator.state.quarterLabel)))
    lines.append(frow(String(format: "  Indicative score if ended now: %d / 100   %@", score.final, score.headline)))
    if !goalStatuses.isEmpty {
        lines.append(frow(String(format: "  Scenario objectives met: %d / %d", goalStatuses.filter(\.met).count, goalStatuses.count)))
    }
    if let scenario {
        let assessment = scenarioAssessmentSummary(for: scenario, goalStatuses: goalStatuses, outcome: liveOutcome)
        lines.append(frow("  Scenario assessment: \(assessment.heading)"))
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Run averages:" + A.reset))
    lines.append(frow(String(format: "    CPI inflation         %.2f%%", avgInflation * 100)))
    lines.append(frow(String(format: "    GDP growth (ann.)     %+.2f%%", avgGrowth * 100)))
    lines.append(frow(String(format: "    Unemployment          %.2f%%", avgUnemployment * 100)))
    lines.append(frow(String(format: "    FX reserves           %.2f months", avgReserves)))
    lines.append(frow(String(format: "    Policy rate           %.2f%%", avgRate * 100)))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Run extremes:" + A.reset))
    lines.append(frow(String(format: "    Peak inflation        %.1f%%", card.peakInflation * 100)))
    lines.append(frow(String(format: "    Growth trough         %+.1f%%", card.troughGrowthAnnualized * 100)))
    lines.append(frow(String(format: "    Unemployment peak     %.1f%%", card.peakUnemployment * 100)))
    lines.append(frow(String(format: "    Reserve low           %.1f months", card.lowestReserves)))
    lines.append(frow(String(format: "    Credibility trough    %.0f%%", card.lowestCredibility * 100)))
    lines.append(frow(String(format: "    Political pressure    %.0f", card.peakPoliticalPressure)))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Most recent quarters:" + A.reset))
    if snaps.isEmpty {
        lines.append(frow("    " + A.dim + "No completed quarters yet." + A.reset))
    } else {
        for snap in snaps.suffix(6).reversed() {
            let row = "    "
                + pad(snap.quarterLabel, to: 10)
                + "CPI " + String(format: "%5.1f%%", snap.inflation * 100)
                + " | GDP " + String(format: "%+4.1f%%", snap.annualizedGDPGrowth * 100)
                + " | Rsv " + String(format: "%.1f", snap.foreignReservesMonths)
                + " | Rate " + String(format: "%.1f%%", snap.policyRate * 100)
            lines.append(frow(row))
        }
    }
    if !goalStatuses.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Scenario objectives:" + A.reset))
        for goal in goalStatuses {
            let marker = goal.met ? A.bGreen + "✓" + A.reset : A.bRed + "✗" + A.reset
            lines.append(frow("    \(marker) \(goal.description)"))
        }
        if let scenario {
            let assessment = scenarioAssessmentSummary(for: scenario, goalStatuses: goalStatuses, outcome: liveOutcome)
            lines.append(frow(""))
            lines.append(frow(A.bold + "  Scenario assessment:" + A.reset))
            for row in wrappedRows(assessment.overview, indent: "    ") {
                lines.append(frow(row))
            }
            if !assessment.missedObjectives.isEmpty {
                for row in wrappedRows("Still unresolved: " + assessment.missedObjectives[0], indent: "    ") {
                    lines.append(frow(row))
                }
            }
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawCampaignReport(_ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) {
    print(renderCampaignReport(simulator, gameLength: gameLength, scenarioID: scenarioID))
}

func renderQuarterDebrief(_ simulator: EconomicSimulator) -> String {
    let snaps = simulator.log.quarterSnapshots
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  WHY THINGS MOVED" + A.reset))
    lines.append(hline(ML, HH, MR))

    guard let last = snaps.last else {
        lines.append(frow("  " + A.dim + "No completed quarter yet — advance once to get a debrief." + A.reset))
        lines.append(hline(BL, HH, BR))
        return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
    }

    let previous = snaps.dropLast().last
    let quarterEntries = Array(simulator.log.fullNewsLog
        .filter { $0.hasPrefix("[\(last.quarterLabel)]") }
        .prefix(8))
        .reversed()
    let s = simulator.state
    let inflationMove = s.inflationDelta * 100
    let expectedMove = s.expectedInflationDelta * 100
    let gapMove = s.outputGapDelta * 100
    let reservesMove = previous.map { last.foreignReservesMonths - $0.foreignReservesMonths } ?? 0.0
    let approvalMove = previous.map { last.publicApproval - $0.publicApproval } ?? 0.0
    let pressureMove = previous.map { last.politicalPressure - $0.politicalPressure } ?? 0.0
    let growthMoveText = previous.map {
        String(format: "%+.1fpp", last.annualizedGDPGrowth * 100 - $0.annualizedGDPGrowth * 100)
    } ?? "n/a"

    lines.append(frow("  Last completed quarter: " + A.bold + last.quarterLabel + A.reset))
    lines.append(frow("  This brief explains the moves that carried into \(simulator.state.quarterLabel)."))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Main moves:" + A.reset))
    lines.append(frow(String(format: "    Inflation            %+.1fpp", inflationMove)))
    lines.append(frow(String(format: "    Expected inflation   %+.1fpp", expectedMove)))
    lines.append(frow(String(format: "    Output gap           %+.1fpp", gapMove)))
    lines.append(frow("    GDP growth (ann.)    \(growthMoveText)"))
    lines.append(frow(String(format: "    Reserves             %+.1f months", reservesMove)))
    lines.append(frow(String(format: "    Approval             %+.1f", approvalMove)))
    lines.append(frow(String(format: "    Political pressure   %+.1f", pressureMove)))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Interpretation:" + A.reset))

    var interpretations: [String] = []
    if inflationMove > 0.3 {
        if s.exchangeRateQoQChange > 0.02 {
            interpretations.append("Inflation rose because the Solan Dollar weakened and imported prices passed through.")
        } else if quarterEntries.contains(where: { $0.contains("OIL SHOCK") || $0.contains("AGRICULTURAL CRISIS") || $0.contains("GENERAL STRIKE") }) {
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
        } else if quarterEntries.contains(where: { $0.contains("EXTERNAL DOWNTURN") || $0.contains("TOURISM COLLAPSE") || $0.contains("CREDIT CRUNCH") }) {
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
        if quarterEntries.contains(where: { $0.contains("SPECULATIVE ATTACK") || $0.contains("CAPITAL FLIGHT") }) {
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

    if quarterEntries.contains(where: { $0.contains("COMMUNICATION: Hawkish rhetoric rings hollow") }) {
        interpretations.append("Your communication stance backfired because markets saw a mismatch between rhetoric and policy.")
    } else if quarterEntries.contains(where: { $0.contains("COMMUNICATION: Hawkish anti-inflation guidance reinforced") }) {
        interpretations.append("Communication helped because your anti-inflation message was backed by actual policy restraint.")
    }

    for line in interpretations.prefix(5) {
        for row in wrappedRows(line, indent: "    ") {
            lines.append(frow(row))
        }
    }

    if !quarterEntries.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Quarter headlines:" + A.reset))
        for entry in quarterEntries {
            for row in wrappedRows(entry, indent: "    ") {
                lines.append(frow(row))
            }
        }
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawQuarterDebrief(_ simulator: EconomicSimulator) {
    print(renderQuarterDebrief(simulator))
}

func renderAdvisor(_ simulator: EconomicSimulator, topic: String? = nil) -> String {
    let brief = advisorBrief(for: simulator, topicText: topic)
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  STAFF ADVISOR — " + brief.focusTitle.uppercased() + A.reset))
    lines.append(hline(ML, HH, MR))

    if let topic, !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        if brief.requestedTopicRecognized {
            lines.append(frow("  Requested focus: \(brief.requestedTopic.title)"))
        } else {
            lines.append(frow("  Requested focus: " + A.bYellow + topic + A.reset + "  " + A.dim + "(not recognized; showing general triage)" + A.reset))
        }
        lines.append(frow(""))
    }

    lines.append(frow(A.bold + "  Most urgent right now:" + A.reset))
    for row in wrappedRows(brief.urgentHeadline, indent: "    ") {
        lines.append(frow(row))
    }
    for row in wrappedRows(brief.urgentDetail, indent: "    ") {
        lines.append(frow(row))
    }

    lines.append(frow(""))
    lines.append(frow(A.bold + "  Indicative rate guidance:" + A.reset))
    for row in wrappedRows(brief.rateHeadline, indent: "    ") {
        lines.append(frow(row))
    }
    for row in wrappedRows(brief.rateDetail, indent: "    ") {
        lines.append(frow(row))
    }

    lines.append(frow(""))
    lines.append(frow(A.bold + "  Recommended levers:" + A.reset))
    for line in brief.recommendations {
        for row in wrappedRows(line, indent: "    • ") {
            lines.append(frow(row))
        }
    }

    lines.append(frow(""))
    lines.append(frow(A.bold + "  Watch closely:" + A.reset))
    for line in brief.watchItems {
        for row in wrappedRows(line, indent: "    • ") {
            lines.append(frow(row))
        }
    }

    lines.append(frow(""))
    lines.append(frow(A.bold + "  Try topics:" + A.reset))
    lines.append(frow("    advisor inflation   advisor growth   advisor currency"))
    lines.append(frow("    advisor reserves    advisor balance of payments"))
    lines.append(frow("    advisor debt        advisor credibility   advisor crisis"))

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawAdvisor(_ simulator: EconomicSimulator, topic: String? = nil) {
    print(renderAdvisor(simulator, topic: topic))
}

func renderTutorial(_ simulator: EconomicSimulator, mode: GameMode, gameLength: GameLength, scenarioID: String? = nil) -> String {
    let s = simulator.state
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

    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  GUIDED TUTORIAL — " + stageTitle + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow("  Quarter: \(s.quarterLabel)   Completed: \(card.quartersSimulated)"))
    lines.append(frow(""))
    lines.append(frow(A.bold + "  What to focus on now:" + A.reset))
    for line in focus {
        for row in wrappedRows(line, indent: "    ") {
            lines.append(frow(row))
        }
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Suggested experiments:" + A.reset))
    for line in experiments {
        for row in wrappedRows(line, indent: "    ") {
            lines.append(frow(row))
        }
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  What success looks like:" + A.reset))
    for line in success {
        for row in wrappedRows(line, indent: "    ") {
            lines.append(frow(row))
        }
    }
    if !goalStatuses.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Current scenario goals:" + A.reset))
        for goal in goalStatuses {
            let marker = goal.met ? A.bGreen + "✓" + A.reset : A.bYellow + "•" + A.reset
            for row in wrappedRows(goal.description, indent: "    \(marker) ") {
                lines.append(frow(row))
            }
        }
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Good companion commands:" + A.reset))
    lines.append(frow("    preview   why   advisor   history   report   help"))
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawTutorial(_ simulator: EconomicSimulator, mode: GameMode, gameLength: GameLength, scenarioID: String? = nil) {
    print(renderTutorial(simulator, mode: mode, gameLength: gameLength, scenarioID: scenarioID))
}

func renderStatus(_ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) -> String {
    let s = simulator.state
    let env = simulator.environment
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  EXTENDED ECONOMIC BRIEFING — " + s.quarterLabel + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(""))
    if let scenario = scenarioDefinition(id: scenarioID) {
        lines.append(frow("  Scenario:              \(scenario.title)"))
        lines.append(frow("  Scenario Range:        \(scenario.rangeLabel)"))
        lines.append(frow(""))
    }
    lines.append(frow(String(format: "  Real GDP Index:        %.2f   (base 100 = %@)", s.realGDP, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID))))
    lines.append(frow(String(format: "  Potential GDP Index:   %.2f", s.potentialGDP)))
    lines.append(frow(String(format: "  Output Gap:            %+.2f%%", s.outputGap * 100)))
    lines.append(frow(""))
    lines.append(frow(String(format: "  CPI Price Level:       %.2f   (base 100 = %@)", s.priceLevel, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID))))
    lines.append(frow(String(format: "  CPI Inflation:         %.2f%%  ann.", s.inflation * 100)))
    lines.append(frow(String(format: "  Core Inflation:        %.2f%%  ann.", s.coreInflation * 100)))
    lines.append(frow(String(format: "  Expected Inflation:    %.2f%%  ann.", s.expectedInflation * 100)))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Policy Rate:           %.2f%%", s.policyRate * 100)))
    lines.append(frow("  Communication Stance:  " + simulator.communicationStance.displayName))
    lines.append(frow("  Cabinet Request:       " + (simulator.activeCabinetRequest?.title ?? "None")))
    lines.append(frow(String(format: "  Real Interest Rate:    %+.2f%%", s.realInterestRate * 100)))
    lines.append(frow(String(format: "  Reserve Requirement:   %.1f%%", s.reserveRequirement * 100)))
    lines.append(frow(String(format: "  M2 Growth:             %.2f%%  ann.", s.m2Growth * 100)))
    lines.append(frow(String(format: "  Bank Credit Growth:    %.2f%%  ann.", s.bankCreditGrowth * 100)))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Exchange Rate:         %.4f SLD/USD", s.exchangeRate)))
    lines.append(frow(String(format: "  Qtrly ER Change:       %+.2f%%  (+ = depreciation)", s.exchangeRateQoQChange * 100)))
    lines.append(frow(String(format: "  Current Account:       %+.2f%% GDP", s.currentAccountGDP * 100)))
    lines.append(frow(String(format: "  Capital Account:       %+.2f%% GDP", s.capitalAccountGDP * 100)))
    lines.append(frow(String(format: "  FX Reserves:           %.2f months of imports", s.foreignReservesMonths)))
    lines.append(frow(String(format: "  Capital Controls:      %.0f%% (0=open, 100=closed)", s.capitalControls * 100)))
    lines.append(frow(String(format: "  External Debt/GDP:     %.1f%%", s.externalDebtGDP * 100)))
    lines.append(frow(""))
    lines.append(frow(String(format: "  Government Debt/GDP:   %.1f%%", s.governmentDebtGDP * 100)))
    lines.append(frow(String(format: "  Fiscal Balance/GDP:    %+.2f%%", s.fiscalBalanceGDP * 100)))
    lines.append(frow(""))
    lines.append(frow(String(format: "  World Interest Rate:   %.2f%%", env.worldInterestRate * 100)))
    lines.append(frow(String(format: "  World Inflation:       %.2f%%", env.worldInflation * 100)))
    lines.append(frow(String(format: "  Trading Partner Grow:  %.2f%%  ann.", env.tradingPartnerGrowth * 100)))
    lines.append(frow(String(format: "  Oil Price Index:       %.0f   (base 100 = %@)", env.oilPriceIndex, campaignBaseIndexLabel(gameLength: gameLength, scenarioID: scenarioID))))
    lines.append(frow(""))
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func drawStatus(_ simulator: EconomicSimulator, gameLength: GameLength, scenarioID: String? = nil) {
    print(renderStatus(simulator, gameLength: gameLength, scenarioID: scenarioID))
}

func renderScenarioBriefing(_ scenario: ScenarioDefinition) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  HISTORICAL SCENARIO — " + scenario.title.uppercased() + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow("  " + scenario.rangeLabel))
    lines.append(frow(""))
    for row in wrappedRows(scenario.briefing) {
        lines.append(frow(row))
    }
    if !scenario.teachingFocus.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Teaching focus:" + A.reset))
        for note in scenario.teachingFocus {
            for row in wrappedRows(note, indent: "    • ") {
                lines.append(frow(row))
            }
        }
    }
    if !scenario.goals.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Objectives:" + A.reset))
        for goal in scenario.goals {
            for row in wrappedRows(goal.description, indent: "    • ") {
                lines.append(frow(row))
            }
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to start the scenario...")
}

func drawScenarioBriefing(_ scenario: ScenarioDefinition) {
    print(renderScenarioBriefing(scenario))
}

// Re-expose the full-width row and hline helpers for main.swift
func fullRow(_ content: String) -> String { frow(content) }
func horizLine(_ l: String, _ f: String, _ r: String) -> String { hline(l, f, r) }
