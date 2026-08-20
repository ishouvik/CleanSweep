import Foundation

@main
enum UnitTestRunner {
    static func main() throws {
        var suite = TestSuite()

        suite.expect(!ByteFormatting.string(-10).contains("-"), "Negative byte values must be clamped to zero")

        let candidate = CleanupCandidate(
            url: URL(fileURLWithPath: "/tmp/candidate"),
            category: .packageCache,
            explanation: "fixture",
            size: 10
        )
        suite.expect(candidate.isSelected, "Candidates should default to selected")
        suite.expect(candidate.displayName == "candidate", "Candidate display name should use the final path component")

        let scanner = CleanupScanner()
        suite.expectThrows("System applications must be rejected") {
            _ = try scanner.scanApplication(URL(fileURLWithPath: "/System/Applications/Finder.app"))
        }

        let root = try TestFiles.temporaryDirectory(named: "unit")
        defer { try? FileManager.default.removeItem(at: root) }
        let fakeApp = root.appendingPathComponent("Invalid.app")
        try FileManager.default.createDirectory(at: fakeApp, withIntermediateDirectories: true)
        suite.expectThrows("Bundles without identifiers must be rejected") {
            _ = try scanner.scanApplication(fakeApp)
        }

        let extensions = root.appendingPathComponent(".vscode/extensions")
        let old = try TestFiles.createExtension(at: extensions, publisher: "example", name: "tool", version: "1.2.9")
        let current = try TestFiles.createExtension(at: extensions, publisher: "example", name: "tool", version: "1.10.0")
        let extensionCandidates = CleanupScanner(homeDirectory: root).scanGeneric()
        suite.expect(extensionCandidates.contains { $0.url.lastPathComponent == old.lastPathComponent }, "Numeric version ordering should select the obsolete extension")
        suite.expect(!extensionCandidates.contains { $0.url.lastPathComponent == current.lastPathComponent }, "The newest extension version must be preserved")

        suite.finish(layer: "Unit tests")
    }
}
