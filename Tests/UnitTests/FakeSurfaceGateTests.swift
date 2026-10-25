import XCTest

// #419: fake-surface gate — fails when a function named run*/test* in production code
// simulates work with Task.sleep. Timeout watchdogs (sleep + terminate/waitUntilExit on a
// real Process) are the legit pattern and are exempted. Catches the exact pattern of the
// removed WorkflowCanvasView.runTest / ExternalIntegrationManager.testConnection fakes.
final class FakeSurfaceGateTests: XCTestCase {

    // Scan root derived from #filePath: .../fusion-studio/Tests/UnitTests/<this file>
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UnitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // fusion-studio
            .appendingPathComponent("FusionStudio")
    }

    private func swiftFiles() throws -> [URL] {
        let fm = FileManager.default
        var files: [URL] = []
        if let enumerator = fm.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                files.append(url)
            }
        }
        return files
    }

    // Extract the brace-balanced body of each func whose base name starts with run/test,
    // flag Task.sleep inside unless the body also drives a real Process watchdog.
    private func fakeSleepHits(in text: String) -> [(line: Int, name: String)] {
        var hits: [(Int, String)] = []
        let pattern = try! NSRegularExpression(pattern: #"func\s+(run|test)\w*\s*\("#)
        let ns = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            var i = m.range.location + m.range.length
            var depth = 0
            var started = false
            while i < ns.length {
                let c = ns.character(at: i)
                if c == UInt16(UnicodeScalar("{").value) { depth += 1; started = true }
                if c == UInt16(UnicodeScalar("}").value) {
                    depth -= 1
                    if started && depth == 0 { break }
                }
                i += 1
            }
            guard started else { continue }
            let body = ns.substring(with: NSRange(location: m.range.location, length: i - m.range.location))
            guard body.contains("Task.sleep") else { continue }
            // Watchdog exemption: sleep guarding a real external process run.
            if body.contains("terminate()") || body.contains("waitUntilExit") { continue }
            let name = ns.substring(with: m.range)
            let line = ns.substring(to: m.range.location).components(separatedBy: .newlines).count
            hits.append((line, name))
        }
        return hits
    }

    func testNoTaskSleepFakeInRunTestFunctions() throws {
        var violations: [String] = []
        for file in try swiftFiles() {
            let text = try String(contentsOf: file, encoding: .utf8)
            for hit in fakeSleepHits(in: text) {
                violations.append("\(file.lastPathComponent):\(hit.line) \(hit.name)")
            }
        }
        XCTAssertTrue(violations.isEmpty,
                      "Fake surfaces (#419): run*/test* functions simulating with Task.sleep:\n"
                      + violations.joined(separator: "\n"))
    }

    // Acceptance #1 of #419: the removed canvas fake must stay gone (comments included).
    // RAGSearchConfigView.runTest is REAL (client.search) and stays.
    func testCanvasFakeRunTestGone() throws {
        let file = sourcesRoot.appendingPathComponent("Components/WorkflowCanvasView.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(text.contains("runTest"), "canvas fake runTest resurfaced")
        XCTAssertFalse(text.contains("Task.sleep(nanoseconds: 800_000_000)"),
                       "canvas fake simulation sleep resurfaced")
    }
}
