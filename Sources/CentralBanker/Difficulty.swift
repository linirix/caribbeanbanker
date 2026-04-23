import Foundation

// Difficulty presets alter `ModelParameters` — the structural coefficients
// of the simulator — rather than adding ad-hoc multipliers. This keeps the
// model pure: every preset is a valid, self-consistent set of parameters
// that the sim treats identically. A run at a given difficulty is
// indistinguishable from a run where the defaults happen to match.
//
// Only the difficulty label is persisted in saves (not the params struct
// itself), so a future balance pass tweaks the coefficient values while
// preserving player intent. Saved as the *name*, loaded by *preset lookup*.
package enum Difficulty: String, Codable, CaseIterable {
    case apprentice
    case governor
    case volcker

    package var displayName: String {
        GameConfigs.difficulty(self).displayName
    }

    // A one-line capsule suitable for the selector screen.
    package var tagline: String {
        GameConfigs.difficulty(self).tagline
    }
}

extension ModelParameters {
    // Named preset accessor. Defaults on each field are the Governor settings;
    // the other presets diverge from those by overriding selected fields.
    package static func preset(_ d: Difficulty) -> ModelParameters {
        GameConfigs.difficulty(d).applied(to: .default)
    }
}
