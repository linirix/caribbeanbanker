import Foundation

// Seeded, deterministic RNG used by the simulator and event scheduler.
// Algorithm: splitmix64 — small, fast, well-distributed, stdlib-free.
//
// Threading this through as an explicit `inout` parameter (rather than
// relying on the global RNG) gives us:
//   • reproducible runs from a known seed, for testing and debugging
//   • shareable scenarios ("try seed 12345, it's brutal")
//   • the ability to add a future --seed CLI flag without rework.
package struct SeededRandomGenerator: RandomNumberGenerator, Codable {
    private var state: UInt64

    package init(seed: UInt64) {
        // Avoid the degenerate all-zero state; splitmix64 handles it fine
        // but a tiny nudge keeps early outputs well-mixed.
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    package mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// Generate a seed from the system RNG. Used when the player hasn't
// supplied one explicitly.
package func freshSeed() -> UInt64 {
    UInt64.random(in: .min ... .max)
}
