import Foundation

@main
enum IntegrationTestRunner {
    @MainActor
    static func main() async throws {
        var suite = TestSuite()
        let root = try TestFiles.temporaryDirectory(named: "integration")
        defer { try? FileManager.default.removeItem(at: root) }

        let npmCache = root.appendingPathComponent(".npm/_cacache/content")
        try TestFiles.createFile(at: npmCache, bytes: 128)
        let staleLog = root.appendingPathComponent("Library/Logs/Demo/old.log")
        let freshLog = root.appendingPathComponent("Library/Logs/Demo/fresh.log")
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        try TestFiles.createFile(at: staleLog, bytes: 1_048_576, modified: now.addingTimeInterval(-9 * 86_400))
        try TestFiles.createFile(at: freshLog, bytes: 1_048_576, modified: now.addingTimeInterval(-1 * 86_400))

        let scanned = CleanupScanner(homeDirectory: root, now: now).scanGeneric()
        suite.expect(scanned.contains { $0.url.path.hasPrefix(root.appendingPathComponent(".npm/_cacache").path) }, "Known npm cache should be discovered")
        suite.expect(scanned.contains { $0.url.lastPathComponent == staleLog.lastPathComponent }, "Large logs older than seven days should be discovered")
        suite.expect(!scanned.contains { $0.url.lastPathComponent == freshLog.lastPathComponent }, "Fresh logs should be preserved")

        let deletable = root.appendingPathComponent(".cache/demo/cache.bin")
        try TestFiles.createFile(at: deletable, bytes: 256)
        let selected = CleanupCandidate(url: deletable, category: .packageCache, explanation: "fixture", size: 256)
        let executor = CleanupExecutor(homeDirectory: root)
        let result = await executor.execute(candidates: [selected], mode: .generic) { _, _, _ in }
        suite.expect(result.failures.isEmpty, "Allowlisted generic cache deletion should succeed")
        suite.expect(!FileManager.default.fileExists(atPath: deletable.path), "Selected generic cache should be removed")
        suite.expect(result.freedBytes == 256, "Freed-byte result should equal the scanned candidate size")

        let preserved = root.appendingPathComponent(".cache/demo/preserved.bin")
        try TestFiles.createFile(at: preserved, bytes: 64)
        var unselected = CleanupCandidate(url: preserved, category: .packageCache, explanation: "fixture", size: 64)
        unselected.isSelected = false
        _ = await executor.execute(candidates: [unselected], mode: .generic) { _, _, _ in }
        suite.expect(FileManager.default.fileExists(atPath: preserved.path), "Unselected candidates must be preserved")

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("CleanSweepUnsafe-\(UUID().uuidString)")
        try TestFiles.createFile(at: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        let unsafe = CleanupCandidate(url: outside, category: .packageCache, explanation: "fixture", size: 64)
        let unsafeResult = await executor.execute(candidates: [unsafe], mode: .generic) { _, _, _ in }
        suite.expect(!unsafeResult.failures.isEmpty, "Paths outside the injected home allowlist must fail")
        suite.expect(FileManager.default.fileExists(atPath: outside.path), "Rejected unsafe paths must remain untouched")

        let app = root.appendingPathComponent("Applications/Demo.app")
        try TestFiles.createApplication(at: app, identifier: "com.example.demo", name: "Demo")
        let support = root.appendingPathComponent("Library/Caches/com.example.demo/cache")
        try TestFiles.createFile(at: support)
        let appCandidates = try CleanupScanner(homeDirectory: root).scanApplication(app)
        suite.expect(appCandidates.contains { $0.category == .application && $0.url.lastPathComponent == app.lastPathComponent }, "Application bundle should be included")
        suite.expect(appCandidates.contains { $0.url.path == root.appendingPathComponent("Library/Caches/com.example.demo").path }, "Exact bundle-associated cache should be included")

        suite.finish(layer: "Integration tests")
    }
}
