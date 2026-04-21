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

private func severityColor(_ severity: SeverityLevel) -> String {
    switch severity {
    case .good: return A.bGreen
    case .warning: return A.bYellow
    case .danger: return A.bRed
    case .neutral: return A.dim
    }
}

private func actionColor(_ availability: ActionAvailability) -> String {
    switch availability {
    case .available:
        return A.bold + A.bCyan
    case .recommended:
        return A.bold + A.bYellow
    case .dormant, .locked:
        return A.dim
    case .cooldown:
        return A.bold + A.bYellow
    }
}

private func trendGlyph(_ trend: TrendDirection?) -> String {
    switch trend {
    case .up: return "↑"
    case .down: return "↓"
    case .flat: return "→"
    case .none: return ""
    }
}

private func renderMetric(_ metric: MetricDescriptor) -> String {
    let color = severityColor(metric.severity)
    switch metric.displayStyle {
    case .plain:
        var value = color + metric.primaryValue + A.reset
        if let note = metric.note, !note.isEmpty {
            value += " " + metricNoteText(note, for: metric)
        }
        if let deltaText = metric.deltaText, !deltaText.isEmpty {
            value += " " + A.dim + deltaText + A.reset
        }
        let trend = trendGlyph(metric.trend)
        if !trend.isEmpty {
            value += " " + trend
        }
        return "  " + pad(metric.label + ":", to: 16) + value
    case .bar(let maxValue):
        let fillColor = severityColor(metric.severity)
        let chart = bar(metric.numericValue ?? 0.0, maxVal: maxValue, color: fillColor)
        var value = chart + " " + color + metric.primaryValue + A.reset
        let trend = trendGlyph(metric.trend)
        if !trend.isEmpty {
            value += " " + trend
        }
        return "  " + pad(metric.label + ":", to: 16) + value
    }
}

private func metricNoteText(_ note: String, for metric: MetricDescriptor) -> String {
    switch metric.id {
    case "policy-rate", "reserve-requirement":
        return A.dim + A.green + note + A.reset
    default:
        return note
    }
}

private func formattedActionTokens(from section: ActionSectionDescriptor) -> [String] {
    if section.group == .crisis {
        let menuActions = section.actions.filter { $0.label != "measure" }
        let measureActions = section.actions.filter { $0.label == "measure" }
        var tokens = menuActions.map { action in
            actionColor(action.availability) + action.label + (action.argumentHint.map { " \($0)" } ?? "") + A.reset
        }
        if !measureActions.isEmpty {
            let availability = measureActions.contains(where: { $0.availability == .recommended }) ? ActionAvailability.recommended : (measureActions.first?.availability ?? .dormant)
            let hint = measureActions.map { $0.argumentHint ?? "" }.joined(separator: "|")
            tokens.append(actionColor(availability) + "measure " + hint + A.reset)
        }
        return tokens
    }
    return section.actions.map { action in
        actionColor(action.availability) + action.label + (action.argumentHint.map { " \($0)" } ?? "") + A.reset
    }
}

func renderDashboard(_ snapshot: DashboardSnapshot) -> String {
    var lines: [String] = []

    // Title bar
    lines.append(hline(TL, HH, TR))
    let title = A.bold + snapshot.title + A.reset
    let titlePadded = pad(title, to: IW - 2)
    lines.append(VV + " " + titlePadded + " " + VV)
    let dateSection = pad("  " + A.bold + A.cyan + snapshot.subtitle + A.reset, to: IW - 2)
    lines.append(VV + " " + dateSection + " " + VV)
    lines.append(hline(ML, HH, MR))

    for section in snapshot.metricSections {
        lines.append(sheader("  \(section.leftHeading)", "  \(section.rightHeading)"))
        lines.append(crow(pad("", to: LC), pad("", to: RC)))
        for row in section.rows {
            lines.append(crow(
                row.left.map(renderMetric) ?? pad("", to: LC),
                row.right.map(renderMetric) ?? pad("", to: RC)
            ))
        }
        if section.leftHeading != snapshot.metricSections.last?.leftHeading {
            lines.append(hline(ML, HH, MR))
        }
    }

    for advisory in snapshot.advisorySections {
        for row in advisory.rows {
            lines.append(frow(A.dim + "  " + row + A.reset))
        }
        for bullet in advisory.bullets {
            lines.append(frow(A.dim + "  • " + bullet + A.reset))
        }
    }

    // News section
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  RECENT EVENTS & ECONOMIC ANALYSIS" + A.reset))
    lines.append(frow(""))

    let newsToShow = min(5, snapshot.recentNews.count)
    if newsToShow == 0 {
        lines.append(frow("  " + A.dim + "No events recorded yet." + A.reset))
    } else {
        for i in 0..<newsToShow {
            let entry = snapshot.recentNews[i]
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
    lines.append(frow(A.dim + "  " + snapshot.footerLegend + A.reset))
    for section in snapshot.actionSections {
        lines.append(frow("  " + A.bold + section.title + ":" + A.reset + " " + formattedActionTokens(from: section).joined(separator: " ")))
    }
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + "  Governor > " + A.reset))
    lines.append(hline(BL, HH, BR))

    return renderScreen(lines)
}

func drawDashboard(_ snapshot: DashboardSnapshot) {
    print(renderDashboard(snapshot))
}

// Compact projection box for `preview`. Shows the staff estimate for the next
// quarter, including slight deterministic forecast error so previews remain
// informative without becoming a perfect oracle.
// Intentionally smaller than the dashboard: previews are a conversation,
// not a screen take-over.
func renderPreview(_ snapshot: PreviewSnapshot) -> String {
    var lines: [String] = []

    lines.append("")
    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset
                      + A.dim + "   " + snapshot.subtitle + A.reset))
    if let note = snapshot.headerNote {
        lines.append(frow(A.bYellow + "  " + note + A.reset))
    }
    lines.append(frow(A.dim + "  " + snapshot.explanation + A.reset))
    lines.append(hline(ML, HH, MR))

    // Events section
    if snapshot.eventHeadlines.isEmpty {
        lines.append(frow(A.dim + "  Events this quarter: (none)" + A.reset))
    } else {
        lines.append(frow(A.bold + "  Events this quarter:" + A.reset))
        for n in snapshot.eventHeadlines {
            lines.append(frow("  • " + n))
        }
    }
    lines.append(hline(ML, HH, MR))

    // Projected deltas — one row per indicator
    lines.append(frow(A.bold + "  Indicator              Before      Forecast       Δ" + A.reset))
    for projection in snapshot.projections {
        lines.append(previewRow(projection))
    }

    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.dim + "  " + snapshot.footerNote + A.reset))
    lines.append(hline(BL, HH, BR))

    return renderScreen(lines, clearScreen: false)
}

func drawPreview(_ snapshot: PreviewSnapshot) {
    print(renderPreview(snapshot))
}

private func previewRow(_ projection: ComparisonDescriptor) -> String {
    let dColored: String
    switch projection.severity {
    case .good:
        dColored = A.bCyan + projection.deltaText + A.reset
    case .warning:
        dColored = A.bYellow + projection.deltaText + A.reset
    case .danger:
        dColored = A.bRed + projection.deltaText + A.reset
    case .neutral:
        dColored = A.dim + projection.deltaText + A.reset
    }
    let body = "  "
        + pad(projection.label, to: 22)
        + pad(projection.beforeValue, to: 14)
        + pad(projection.afterValue, to: 14)
        + dColored
    return frow(body)
}

private func sectionHeadingRow(_ title: String) -> String {
    frow(A.bold + A.cyan + "  " + title + A.reset)
}

private func emphasizedText(_ text: String, severity: SeverityLevel) -> String {
    severityColor(severity) + A.bold + text + A.reset
}

private func metricSummaryText(_ metric: MetricDescriptor) -> String {
    let color = severityColor(metric.severity)
    switch metric.displayStyle {
    case .plain:
        var value = color + metric.primaryValue + A.reset
        if let note = metric.note, !note.isEmpty {
            value += " " + note
        }
        if let deltaText = metric.deltaText, !deltaText.isEmpty {
            value += " " + A.dim + deltaText + A.reset
        }
        let trend = trendGlyph(metric.trend)
        if !trend.isEmpty {
            value += " " + trend
        }
        return value
    case .bar(let maxValue):
        return bar(metric.numericValue ?? 0.0, maxVal: maxValue, color: color) + " " + color + metric.primaryValue + A.reset
    }
}

private func appendWrappedText(_ lines: inout [String], _ text: String, indent: String = "  ") {
    for row in wrappedRows(text, indent: indent) {
        lines.append(frow(row))
    }
}

private func appendInfoSection(_ lines: inout [String], section: InfoSection, bulletIndent: String = "    • ") {
    lines.append(frow(""))
    lines.append(frow(A.bold + "  " + section.heading + ":" + A.reset))
    for row in section.rows {
        appendWrappedText(&lines, row, indent: "    ")
    }
    for bullet in section.bullets {
        appendWrappedText(&lines, bullet, indent: bulletIndent)
    }
    if let emphasis = section.emphasis, !emphasis.isEmpty {
        appendWrappedText(&lines, emphasis, indent: "    ")
    }
}

private func appendMetricList(_ lines: inout [String],
                              title: String,
                              metrics: [MetricDescriptor],
                              labelWidth: Int = 22,
                              indent: String = "    ") {
    lines.append(frow(""))
    lines.append(frow(A.bold + "  " + title + ":" + A.reset))
    for metric in metrics {
        let row = indent + pad(metric.label, to: labelWidth) + metricSummaryText(metric)
        lines.append(frow(row))
    }
}

private func appendRecentQuarterRows(_ lines: inout [String], rows: [RecentQuarterSnapshot], limit: Int? = nil) {
    let rowsToShow = limit.map { Array(rows.prefix($0)) } ?? rows
    if rowsToShow.isEmpty {
        lines.append(frow("    " + A.dim + "No completed quarters yet." + A.reset))
        return
    }

    for row in rowsToShow {
        let rendered = "    "
            + pad(row.quarterLabel, to: 10)
            + "CPI " + row.inflation
            + " | GDP " + row.growth
            + " | Rsv " + row.reserves
            + " | Rate " + row.rate
        lines.append(frow(rendered))
    }
}

private func appendScenarioGoalRows(_ lines: inout [String],
                                    goals: [ScenarioGoalDescriptor],
                                    heading: String,
                                    unmetMarker: String = "✗") {
    guard !goals.isEmpty else { return }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  " + heading + ":" + A.reset))
    for goal in goals {
        let marker = goal.met ? A.bGreen + "✓" + A.reset : A.bRed + unmetMarker + A.reset
        appendWrappedText(&lines, goal.description, indent: "    \(marker) ")
    }
}

private func appendScenarioAssessment(_ lines: inout [String], assessment: ScenarioAssessmentSnapshot) {
    lines.append(frow(""))
    lines.append(frow(A.bold + "  SCENARIO ASSESSMENT:" + A.reset))
    lines.append(frow("  " + emphasizedText(assessment.heading, severity: assessment.severity)))
    appendWrappedText(&lines, assessment.overview, indent: "    ")
    if !assessment.focus.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Lesson focus:" + A.reset))
        for item in assessment.focus {
            appendWrappedText(&lines, item, indent: "    • ")
        }
    }
    if !assessment.missedObjectives.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  What remained unresolved:" + A.reset))
        for item in assessment.missedObjectives.prefix(2) {
            appendWrappedText(&lines, item, indent: "    • ")
        }
    }
}

private func historyChartRow(_ chart: HistoryChartSnapshot) -> String {
    let chartWidth = max(12, min(44, IW - 33))
    let sampled = sampledHistory(chart.values, limit: chartWidth)
    var rendered = "  " + pad(chart.label, to: 20) + " "
    for value in sampled {
        let ratio = min(1.0, max(0.0, abs(value) / chart.scale))
        let glyph = ratio > 0.66 ? "▇" : (ratio > 0.33 ? "▄" : "▁")
        let color: String
        if let threshold = chart.positiveThreshold {
            color = value > threshold ? A.bGreen : (value > chart.warningRange.lowerBound ? A.bYellow : A.bRed)
        } else {
            color = chart.goodRange.contains(value) ? A.bGreen : (chart.warningRange.contains(value) ? A.bYellow : A.bRed)
        }
        rendered += color + glyph + A.reset
    }
    rendered += "  " + chart.latestValue
    return rendered
}

func renderGameOver(_ snapshot: GameOverSnapshot) -> String {
    var lines: [String] = [""]

    lines.append(hline(TL, HH, TR))
    lines.append(frow(emphasizedText("  " + snapshot.title, severity: snapshot.scenarioAssessment?.severity ?? .good)))
    lines.append(frow(""))
    for row in snapshot.introduction {
        appendWrappedText(&lines, row)
    }

    lines.append(hline(ML, HH, MR))
    lines.append(sectionHeadingRow(snapshot.finalStateSection.heading))
    for row in snapshot.finalStateSection.rows {
        appendWrappedText(&lines, row)
    }

    appendScenarioGoalRows(&lines, goals: snapshot.scenarioGoals, heading: "SCENARIO OBJECTIVES")
    if let assessment = snapshot.scenarioAssessment {
        appendScenarioAssessment(&lines, assessment: assessment)
    }

    lines.append(hline(ML, HH, MR))
    lines.append(sectionHeadingRow(snapshot.reviewSection.heading))
    for row in snapshot.reviewSection.rows {
        appendWrappedText(&lines, row)
    }

    lines.append(hline(ML, HH, MR))
    lines.append(sectionHeadingRow(snapshot.scoreSection.heading))
    for row in snapshot.scoreSection.rows {
        appendWrappedText(&lines, row)
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to exit...")
}

func renderHelp(_ snapshot: HelpSnapshot) -> String {
    var lines: [String] = []
    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(frow(A.dim + "  " + snapshot.subtitle + A.reset))

    for section in snapshot.sections {
        lines.append(hline(ML, HH, MR))
        lines.append(sectionHeadingRow(section.heading))
        for command in section.commands {
            lines.append(frow("  " + A.bold + A.bYellow + command.command + A.reset))
            for detail in command.details {
                appendWrappedText(&lines, detail, indent: "    ")
            }
        }
        for paragraph in section.paragraphs {
            appendWrappedText(&lines, paragraph, indent: "  ")
        }
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderCrisisOptions(_ snapshot: CrisisOptionsSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    for row in snapshot.summaryRows {
        appendWrappedText(&lines, row)
    }
    if !snapshot.measures.isEmpty {
        lines.append(frow(""))
        for measure in snapshot.measures {
            lines.append(frow("  " + A.bold + "measure \(measure.type.commandName)" + A.reset + " — " + measure.type.title))
            appendWrappedText(&lines, measure.detail, indent: "    ")
            appendWrappedText(&lines, "Tradeoff: " + measure.tradeoff, indent: "    ")
            lines.append(frow(""))
        }
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderHistory(_ snapshot: HistorySnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(""))

    if let emptyState = snapshot.emptyState {
        lines.append(frow("  " + A.dim + emptyState + A.reset))
    } else {
        for chart in snapshot.charts {
            lines.append(frow(historyChartRow(chart)))
        }
    }
    lines.append(frow(""))
    lines.append(hline(ML, HH, MR))
    lines.append(frow(A.bold + A.cyan + "  RECENT QUARTER TABLE" + A.reset))
    lines.append(frow(A.bold + "  Quarter     CPI     GDP Ann   Unemp   Reserves   Rate   Pressure" + A.reset))
    appendRecentQuarterRows(&lines, rows: snapshot.recentQuarters, limit: 12)
    lines.append(frow(""))
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderNewsLog(_ snapshot: NewsSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    if let emptyState = snapshot.emptyState {
        lines.append(frow("  " + A.dim + emptyState + A.reset))
    } else {
        for entry in snapshot.entries {
            appendWrappedText(&lines, entry)
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderCampaignReport(_ snapshot: ReportSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    for row in snapshot.summarySection.rows {
        appendWrappedText(&lines, row)
    }
    appendMetricList(&lines, title: "Run averages", metrics: snapshot.averages)
    appendMetricList(&lines, title: "Run extremes", metrics: snapshot.extremes)
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Most recent quarters:" + A.reset))
    appendRecentQuarterRows(&lines, rows: snapshot.recentQuarters, limit: 6)
    appendScenarioGoalRows(&lines, goals: snapshot.scenarioGoals, heading: "Scenario objectives")
    if let assessment = snapshot.scenarioAssessment {
        appendScenarioAssessment(&lines, assessment: assessment)
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderQuarterDebrief(_ snapshot: DebriefSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    if snapshot.mainMoves.isEmpty && snapshot.interpretations.isEmpty && snapshot.headlines.isEmpty {
        for row in snapshot.summaryRows {
            appendWrappedText(&lines, row)
        }
    } else {
        for row in snapshot.summaryRows {
            appendWrappedText(&lines, row)
        }
        appendMetricList(&lines, title: "Main moves", metrics: snapshot.mainMoves)
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Interpretation:" + A.reset))
        for line in snapshot.interpretations {
            appendWrappedText(&lines, line, indent: "    ")
        }
        if !snapshot.headlines.isEmpty {
            lines.append(frow(""))
            lines.append(frow(A.bold + "  Quarter headlines:" + A.reset))
            for headline in snapshot.headlines {
                appendWrappedText(&lines, headline, indent: "    ")
            }
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderAdvisor(_ snapshot: AdvisorSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))

    if let requestedFocusLine = snapshot.requestedFocusLine {
        appendWrappedText(&lines, requestedFocusLine)
        lines.append(frow(""))
    }

    appendInfoSection(&lines, section: snapshot.urgentSection, bulletIndent: "    ")
    appendInfoSection(&lines, section: snapshot.rateSection, bulletIndent: "    ")
    appendInfoSection(&lines, section: snapshot.recommendationSection)
    appendInfoSection(&lines, section: snapshot.watchSection)

    lines.append(frow(""))
    lines.append(frow(A.bold + "  Try topics:" + A.reset))
    for chunk in stride(from: 0, to: snapshot.topicSuggestions.count, by: 3) {
        let row = snapshot.topicSuggestions[chunk..<min(chunk + 3, snapshot.topicSuggestions.count)].joined(separator: "   ")
        lines.append(frow("    " + row))
    }

    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderTutorial(_ snapshot: TutorialSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + " — " + snapshot.stageTitle + A.reset))
    lines.append(hline(ML, HH, MR))
    appendWrappedText(&lines, "Quarter: \(snapshot.context.quarterLabel)   Range: \(snapshot.context.campaignRange)")
    lines.append(frow(""))
    lines.append(frow(A.bold + "  What to focus on now:" + A.reset))
    for line in snapshot.focus {
        appendWrappedText(&lines, line, indent: "    ")
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Suggested experiments:" + A.reset))
    for line in snapshot.experiments {
        appendWrappedText(&lines, line, indent: "    ")
    }
    lines.append(frow(""))
    lines.append(frow(A.bold + "  What success looks like:" + A.reset))
    for line in snapshot.success {
        appendWrappedText(&lines, line, indent: "    ")
    }
    appendScenarioGoalRows(&lines, goals: snapshot.scenarioGoals, heading: "Current scenario goals", unmetMarker: "•")
    lines.append(frow(""))
    lines.append(frow(A.bold + "  Good companion commands:" + A.reset))
    lines.append(frow("    " + snapshot.companionActions.map(\.label).joined(separator: "   ")))
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderStatus(_ snapshot: StatusSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  " + snapshot.title + A.reset))
    lines.append(hline(ML, HH, MR))
    for section in snapshot.sections {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  " + section.heading + ":" + A.reset))
        for row in section.rows {
            if let colon = row.firstIndex(of: ":") {
                let label = String(row[...colon])
                let value = row[row.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                lines.append(frow("    " + pad(label, to: 23) + value))
            } else {
                appendWrappedText(&lines, row, indent: "    ")
            }
        }
        for bullet in section.bullets {
            appendWrappedText(&lines, bullet, indent: "    • ")
        }
        if let emphasis = section.emphasis, !emphasis.isEmpty {
            appendWrappedText(&lines, emphasis, indent: "    ")
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to return to dashboard...")
}

func renderScenarioBriefing(_ snapshot: ScenarioBriefingSnapshot) -> String {
    var lines: [String] = []

    lines.append(hline(TL, HH, TR))
    lines.append(frow(A.bold + A.cyan + "  HISTORICAL SCENARIO — " + snapshot.title.uppercased() + A.reset))
    lines.append(hline(ML, HH, MR))
    lines.append(frow("  " + snapshot.rangeLabel))
    lines.append(frow(""))
    appendWrappedText(&lines, snapshot.briefing)
    if !snapshot.teachingFocus.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Teaching focus:" + A.reset))
        for note in snapshot.teachingFocus {
            appendWrappedText(&lines, note, indent: "    • ")
        }
    }
    if !snapshot.objectives.isEmpty {
        lines.append(frow(""))
        lines.append(frow(A.bold + "  Objectives:" + A.reset))
        for goal in snapshot.objectives {
            appendWrappedText(&lines, goal, indent: "    • ")
        }
    }
    lines.append(hline(BL, HH, BR))
    return renderScreen(lines, prompt: "  Press any key to start the scenario...")
}

// Re-expose the full-width row and hline helpers for main.swift
func fullRow(_ content: String) -> String { frow(content) }
func horizLine(_ l: String, _ f: String, _ r: String) -> String { hline(l, f, r) }
