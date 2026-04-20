import XCTest
@testable import CentralBankerCore

// Keep the compiled-in `.fallback` config structs byte-for-byte in sync with
// the JSON files shipped under `Config/`. The fallback is what players get
// when their JSON edits fail to decode (see `GameConfig.swift`'s loud
// `loadConfig`) — if the two drift, a player who removes their JSON gets a
// silently different game from the one we shipped.
//
// The test re-encodes each decoded JSON and the paired `.fallback` with a
// canonicalizing encoder (sortedKeys) and compares the resulting bytes. The
// error message on mismatch shows both encodings so the drift is easy to spot
// without a debugger.

final class ConfigSyncTests: XCTestCase {

    // Locate the repo root from this test file's path so the test works
    // regardless of where `swift test` is invoked from.
    private func configURL(_ fileName: String) -> URL {
        let here = URL(fileURLWithPath: #filePath)
        // Tests/CentralBankerTests/ConfigSyncTests.swift -> repo root
        let repoRoot = here.deletingLastPathComponent()
                           .deletingLastPathComponent()
                           .deletingLastPathComponent()
        return repoRoot.appendingPathComponent("Config").appendingPathComponent(fileName)
    }

    private func canonicalJSON<T: Encodable>(_ value: T) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try enc.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func assertInSync<T: Codable>(
        _ fileName: String,
        fallback: T,
        _ type: T.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let url = configURL(fileName)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(T.self, from: data)

        let fromJSON = try canonicalJSON(decoded)
        let fromFallback = try canonicalJSON(fallback)

        if fromJSON != fromFallback {
            XCTFail(
                """
                \(fileName) and its compiled `.fallback` have drifted. Update
                whichever is stale so loud-fallback players keep the shipped
                balance.

                --- from JSON (\(url.path)) ---
                \(fromJSON)

                --- from fallback ---
                \(fromFallback)
                """,
                file: file,
                line: line
            )
        }
    }

    func testGameTuningJSONMatchesFallback() throws {
        try assertInSync("game_tuning.json",
                         fallback: GameTuningConfig.fallback,
                         GameTuningConfig.self)
    }

    func testHistoricalShortJSONMatchesFallback() throws {
        try assertInSync("historical_short.json",
                         fallback: HistoricalTrackConfig.shortFallback,
                         HistoricalTrackConfig.self)
    }

    func testHistoricalExtendedJSONMatchesFallback() throws {
        try assertInSync("historical_extended.json",
                         fallback: HistoricalTrackConfig.extendedFallback,
                         HistoricalTrackConfig.self)
    }

    func testScenariosJSONMatchesFallback() throws {
        try assertInSync("scenarios.json",
                         fallback: ScenarioCatalogConfig.fallback,
                         ScenarioCatalogConfig.self)
    }
}
