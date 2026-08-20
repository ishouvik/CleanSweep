import AppKit
import Foundation

struct CleanupExecutor {
    typealias ProgressHandler = @MainActor (_ completed: Int, _ total: Int, _ currentPath: String) -> Void
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(fileManager: FileManager = .default, homeDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
    }

    func execute(
        candidates: [CleanupCandidate],
        mode: CleanupMode,
        progress: @escaping ProgressHandler
    ) async -> CleanupResult {
        let selected = candidates.filter(\.isSelected)
        var failures: [CleanupFailure] = []
        var freed: Int64 = 0
        var trashed: Int64 = 0
        var processed = 0

        for (index, candidate) in selected.enumerated() {
            if Task.isCancelled {
                return CleanupResult(
                    processedCount: processed,
                    freedBytes: freed,
                    movedToTrashBytes: trashed,
                    failures: failures,
                    cancelled: true
                )
            }

            await progress(index, selected.count, candidate.url.path)

            guard isSafe(candidate.url, mode: mode) else {
                failures.append(CleanupFailure(path: candidate.url.path, message: "Safety validation rejected this path."))
                continue
            }

            guard fileManager.fileExists(atPath: candidate.url.path) else {
                failures.append(CleanupFailure(path: candidate.url.path, message: "The item disappeared after scanning."))
                continue
            }

            do {
                if mode == .uninstall {
                    if candidate.category == .application {
                        try await requestGracefulTermination(of: candidate.url)
                    }
                    var resultingURL: NSURL?
                    try fileManager.trashItem(at: candidate.url, resultingItemURL: &resultingURL)
                    trashed += candidate.size
                } else {
                    try fileManager.removeItem(at: candidate.url)
                    freed += candidate.size
                }
                processed += 1
            } catch {
                failures.append(CleanupFailure(path: candidate.url.path, message: error.localizedDescription))
            }
        }

        await progress(selected.count, selected.count, "Complete")
        return CleanupResult(
            processedCount: processed,
            freedBytes: freed,
            movedToTrashBytes: trashed,
            failures: failures,
            cancelled: false
        )
    }

    private func requestGracefulTermination(of applicationURL: URL) async throws {
        guard let identifier = Bundle(url: applicationURL)?.bundleIdentifier else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        guard !running.isEmpty else { return }

        running.forEach { $0.terminate() }
        for _ in 0..<30 {
            if NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty { return }
            try await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { throw CancellationError() }
        }
        throw ExecutionError.applicationStillRunning(identifier)
    }

    private func isSafe(_ url: URL, mode: CleanupMode) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let path = resolved.path
        let home = homeDirectory.standardizedFileURL.path

        guard path != "/", path != home, !path.isEmpty else { return false }
        guard !path.hasPrefix("/System/") else { return false }

        if mode == .generic {
            return path.hasPrefix(home + "/.npm/")
                || path.hasPrefix(home + "/.cache/")
                || path.hasPrefix(home + "/Library/Caches/")
                || path.hasPrefix(home + "/Library/Logs/")
                || path.hasPrefix(home + "/Library/Google/GoogleUpdater/")
                || path.hasPrefix(home + "/.vscode/extensions/")
        }

        return path.hasPrefix("/Applications/")
            || path.hasPrefix(home + "/Applications/")
            || path.hasPrefix(home + "/Library/")
    }
}

enum ExecutionError: LocalizedError {
    case applicationStillRunning(String)

    var errorDescription: String? {
        switch self {
        case let .applicationStillRunning(identifier):
            "The application \(identifier) did not quit after a graceful termination request. Quit it manually and retry."
        }
    }
}
