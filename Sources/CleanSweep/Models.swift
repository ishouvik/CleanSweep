import Foundation

enum CleanupMode: String, CaseIterable, Identifiable {
    case generic = "Clean Caches"
    case uninstall = "Uninstall App"

    var id: String { rawValue }
}

enum CandidateCategory: String, Codable, CaseIterable {
    case packageCache = "Package cache"
    case temporaryDownload = "Temporary download"
    case updater = "Updater residue"
    case staleLog = "Stale log"
    case oldExtension = "Obsolete VS Code extension"
    case application = "Application"
    case associatedFile = "Associated application file"

    var systemImage: String {
        switch self {
        case .packageCache: "shippingbox"
        case .temporaryDownload: "arrow.down.circle"
        case .updater: "arrow.triangle.2.circlepath"
        case .staleLog: "doc.text"
        case .oldExtension: "puzzlepiece.extension"
        case .application: "app"
        case .associatedFile: "folder.badge.minus"
        }
    }
}

struct CleanupCandidate: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let category: CandidateCategory
    let explanation: String
    let size: Int64
    var isSelected: Bool

    init(
        url: URL,
        category: CandidateCategory,
        explanation: String,
        size: Int64,
        isSelected: Bool = true
    ) {
        self.id = UUID()
        self.url = url
        self.category = category
        self.explanation = explanation
        self.size = size
        self.isSelected = isSelected
    }

    var displayName: String { url.lastPathComponent }
}

struct CleanupFailure: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let message: String
}

struct CleanupResult {
    let processedCount: Int
    let freedBytes: Int64
    let movedToTrashBytes: Int64
    let failures: [CleanupFailure]
    let cancelled: Bool
}

enum ScanState: Equatable {
    case idle
    case scanning
    case ready
    case failed(String)
}

enum ExecutionState {
    case idle
    case confirming
    case running
    case finished(CleanupResult)
}

enum ByteFormatting {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
