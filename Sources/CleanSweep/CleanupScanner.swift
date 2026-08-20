import AppKit
import Foundation

struct CleanupScanner {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let now: Date

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        now: Date = Date()
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.now = now
    }

    func scanGeneric() -> [CleanupCandidate] {
        let home = homeDirectory
        var candidates: [CleanupCandidate] = []

        let knownPaths: [(String, CandidateCategory, String)] = [
            (".npm/_cacache", .packageCache, "npm's regenerable package-content cache."),
            (".npm/_npx", .temporaryDownload, "Temporary packages downloaded by npx."),
            (".cache/sentry-cli", .packageCache, "Regenerable Sentry CLI cache."),
            (".cache/uv", .packageCache, "Regenerable uv package cache."),
            (".cache/huggingface", .packageCache, "Downloaded Hugging Face cache; models may need to be downloaded again."),
            ("Library/Caches/Homebrew", .packageCache, "Homebrew downloads and build cache; formulae stay installed."),
            ("Library/Caches/com.microsoft.VSCode.ShipIt", .updater, "Downloaded VS Code updater residue."),
            ("Library/Caches/com.google.Keystone", .updater, "Legacy Google updater cache."),
            ("Library/Google/GoogleUpdater", .updater, "Google Updater data; Google software may recreate it."),
            ("Library/Caches/com.microsoft.teams2", .packageCache, "Microsoft Teams cache; Teams may start more slowly once."),
        ]

        for (relativePath, category, explanation) in knownPaths {
            let url = home.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: url.path) {
                candidates.append(candidate(url: url, category: category, explanation: explanation))
            }
        }

        candidates.append(contentsOf: staleLogs(in: home.appendingPathComponent("Library/Logs")))
        candidates.append(contentsOf: obsoleteVSCodeExtensions(in: home.appendingPathComponent(".vscode/extensions")))

        return deduplicated(candidates).sorted {
            if $0.size == $1.size { return $0.url.path < $1.url.path }
            return $0.size > $1.size
        }
    }

    func scanApplication(_ applicationURL: URL) throws -> [CleanupCandidate] {
        let resolved = applicationURL.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.pathExtension.lowercased() == "app" else {
            throw ScanError.notApplication
        }
        guard fileManager.fileExists(atPath: resolved.path) else {
            throw ScanError.missingApplication
        }
        guard !resolved.path.hasPrefix("/System/") else {
            throw ScanError.protectedSystemApplication
        }

        guard let bundle = Bundle(url: resolved), let identifier = bundle.bundleIdentifier, !identifier.isEmpty else {
            throw ScanError.missingBundleIdentifier
        }

        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? resolved.deletingPathExtension().lastPathComponent
        let home = homeDirectory

        var candidates = [candidate(
            url: resolved,
            category: .application,
            explanation: "The (name) application bundle. It will be moved to Trash, not permanently erased."
        )]

        // Exact bundle-identifier and exact application-name matches only. This intentionally
        // avoids fuzzy searches that could select another application's or the user's files.
        let exactRelativePaths = [
            "Library/Application Support/\(name)",
            "Library/Application Support/\(identifier)",
            "Library/Caches/\(identifier)",
            "Library/Caches/\(name)",
            "Library/Preferences/\(identifier).plist",
            "Library/Preferences/\(identifier).private.plist",
            "Library/Saved Application State/\(identifier).savedState",
            "Library/Logs/\(name)",
            "Library/Logs/\(identifier)",
            "Library/WebKit/\(identifier)",
            "Library/HTTPStorages/\(identifier)",
            "Library/HTTPStorages/\(identifier).binarycookies",
            "Library/Cookies/\(identifier).binarycookies",
            "Library/Containers/\(identifier)",
            "Library/Application Scripts/\(identifier)",
            "Library/Group Containers/\(identifier)",
            "Library/LaunchAgents/\(identifier).plist",
        ]

        for relativePath in exactRelativePaths {
            let url = home.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: url.path) {
                candidates.append(candidate(
                    url: url,
                    category: .associatedFile,
                    explanation: "Exact support-file match for bundle identifier (identifier) or application name (name)."
                ))
            }
        }

        return deduplicated(candidates).sorted { lhs, rhs in
            if lhs.category == .application { return true }
            if rhs.category == .application { return false }
            return lhs.url.path < rhs.url.path
        }
    }

    private func staleLogs(in root: URL) -> [CleanupCandidate] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        var results: [CleanupCandidate] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  Int64(values.fileSize ?? 0) >= 1_048_576,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            results.append(candidate(
                url: url,
                category: .staleLog,
                explanation: "Log file larger than 1 MB and not modified for at least seven days."
            ))
        }
        return results
    }

    private func obsoleteVSCodeExtensions(in root: URL) -> [CleanupCandidate] {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        struct ExtensionVersion {
            let identifier: String
            let version: String
            let url: URL
        }

        var grouped: [String: [ExtensionVersion]] = [:]
        for url in directories {
            let manifest = url.appendingPathComponent("package.json")
            guard let data = try? Data(contentsOf: manifest),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let publisher = object["publisher"] as? String,
                  let name = object["name"] as? String,
                  let version = object["version"] as? String else { continue }
            let identifier = "\(publisher).\(name)".lowercased()
            grouped[identifier, default: []].append(ExtensionVersion(identifier: identifier, version: version, url: url))
        }

        var results: [CleanupCandidate] = []
        for versions in grouped.values where versions.count > 1 {
            let ordered = versions.sorted { compareVersions($0.version, $1.version) == .orderedDescending }
            for old in ordered.dropFirst() {
                results.append(candidate(
                    url: old.url,
                    category: .oldExtension,
                    explanation: "Version \(old.version) of \(old.identifier) is superseded by \(ordered[0].version)."
                ))
            }
        }
        return results
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = numericComponents(lhs)
        let right = numericComponents(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return lhs.compare(rhs, options: .caseInsensitive)
    }

    private func numericComponents(_ version: String) -> [Int] {
        version.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    private func candidate(url: URL, category: CandidateCategory, explanation: String) -> CleanupCandidate {
        CleanupCandidate(url: url, category: category, explanation: explanation, size: allocatedSize(of: url))
    }

    private func allocatedSize(of url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
               values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private func deduplicated(_ candidates: [CleanupCandidate]) -> [CleanupCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.url.standardizedFileURL.path).inserted }
    }
}

enum ScanError: LocalizedError {
    case notApplication
    case missingApplication
    case protectedSystemApplication
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .notApplication: "Drop a macOS .app bundle."
        case .missingApplication: "The selected application no longer exists."
        case .protectedSystemApplication: "CleanSweep will not remove applications protected by macOS under /System."
        case .missingBundleIdentifier: "The application has no readable bundle identifier, so associated files cannot be matched safely."
        }
    }
}
