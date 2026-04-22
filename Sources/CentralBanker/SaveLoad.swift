import Foundation

// Save / load support.
//
// Design goals:
//   • A loaded game must continue *identically* to one that wasn't saved.
//     That means the save must include the RNG state and the AR(1) noise
//     carries, not just the visible numbers.
//   • Saves are human-readable JSON. The sim is pedagogical — players should
//     be able to peek at their save file, and future-me should be able to
//     diff two saves by hand.
//   • Model parameters are *not* saved. Defaults are restored on load, so a
//     future balance tweak applies retroactively. The `difficulty` tag (added
//     in v3) selects which preset to rehydrate on load, so a retroactive
//     balance tweak lands on whichever difficulty the save was played at.
//
// File format is JSON wrapping a single `GameSave` struct. A `version` field
// guards future schema changes; bump it when the wire format changes.

struct GameSave: Codable {
    // v2 added `scoreCard`. v3 added `difficulty` (the label, not the
    // coefficient struct — presets are rehydrated on load so a future
    // balance pass applies retroactively). v4 adds `communicationStance`
    // and the optional `activeCabinetRequest`. v5 adds `gameLength`.
    // v6 adds short-lived external-defense carry state. v7 adds crisis-tool cooldown.
    // v8 adds an optional historical-scenario identifier.
    static let currentVersion = 8
    var version: Int = GameSave.currentVersion

    // The four sim containers.
    var state: EconomicState
    var environment: ExternalEnvironment
    var log: SessionLog
    var scoreCard: ScoreCard

    // Difficulty label, not the parameter struct. See header note.
    var difficulty: Difficulty
    var communicationStance: CommunicationStance
    var activeCabinetRequest: CabinetRequest? = nil

    // Full RNG state. Without this, advancing after load would draw different
    // noise than an un-saved continuation would have.
    var rng: SeededRandomGenerator
    var demandNoiseCarry: Double
    var supplyNoiseCarry: Double
    var interventionSupportCarry: Double? = nil
    var controlsReliefCarry: Double? = nil
    var crisisCooldownQuarters: Int? = nil

    // Session-level context: lets us print the seed and drive mode-dependent
    // schedules after load.
    var sessionSeed: UInt64
    var mode: GameMode
    var gameLength: GameLength? = nil
    var scenarioID: String? = nil

    // Pre-generated schedules (non-empty only in randomized mode).
    var macroSchedule: [Int: [EventType]]
    var rateSchedule: [Int: Double]
}

// Disk helpers. The file lives next to the executable by default; pass an
// explicit path to override. We resolve `~` expansions so players can use
// `save ~/Desktop/solaverde.json`.

enum SaveLoadError: Error, CustomStringConvertible {
    case ioFailure(String)
    case decodeFailure(String)
    case versionMismatch(found: Int, supported: String)

    var description: String {
        switch self {
        case .ioFailure(let s):         return "I/O error: \(s)"
        case .decodeFailure(let s):     return "Save file unreadable: \(s)"
        case .versionMismatch(let f, let supported):
            return "Save version \(f) is incompatible with this build (supported: \(supported))."
        }
    }
}

private let defaultSavePath = "solaverde.save.json"

private func expandPath(_ p: String) -> String {
    (p as NSString).expandingTildeInPath
}

// Serialize a save payload to JSON on disk. Atomic write so a crash
// mid-save doesn't corrupt an existing file.
func writeSave(_ save: GameSave, to path: String? = nil) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data: Data
    do {
        data = try encoder.encode(save)
    } catch {
        throw SaveLoadError.ioFailure("encode failed: \(error)")
    }
    let url = URL(fileURLWithPath: expandPath(path ?? defaultSavePath))
    do {
        try data.write(to: url, options: .atomic)
    } catch {
        throw SaveLoadError.ioFailure(error.localizedDescription)
    }
}

// Read and decode a save payload from disk.
func readSave(from path: String? = nil) throws -> GameSave {
    let url = URL(fileURLWithPath: expandPath(path ?? defaultSavePath))
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        throw SaveLoadError.ioFailure(error.localizedDescription)
    }
    let save: GameSave
    do {
        save = try JSONDecoder().decode(GameSave.self, from: data)
    } catch {
        throw SaveLoadError.decodeFailure("\(error)")
    }
    guard (4...GameSave.currentVersion).contains(save.version) else {
        throw SaveLoadError.versionMismatch(found: save.version,
                                            supported: "4...\(GameSave.currentVersion)")
    }
    return migrate(save)
}

private func migrate(_ save: GameSave) -> GameSave {
    // Keep the migration hook in place even while all supported formats decode
    // directly. When a future schema change needs a real transform, the call
    // site is already centralized here instead of being spread across readers.
    save
}

// Resolved save path (for display purposes — "Saved to /abs/path/..." msg).
func resolvedSavePath(_ path: String? = nil) -> String {
    URL(fileURLWithPath: expandPath(path ?? defaultSavePath)).path
}
