import AppKit
import Foundation

@MainActor
final class CleanSweepViewModel: ObservableObject {
    @Published var mode: CleanupMode = .generic
    @Published var candidates: [CleanupCandidate] = []
    @Published var scanState: ScanState = .idle
    @Published var executionState: ExecutionState = .idle
    @Published var progress: Double = 0
    @Published var progressText = ""
    @Published var selectedApplication: URL?
    @Published var showConfirmation = false

    private let executor = CleanupExecutor()
    private var executionTask: Task<Void, Never>?

    var selectedCandidates: [CleanupCandidate] { candidates.filter(\.isSelected) }
    var selectedBytes: Int64 { selectedCandidates.reduce(0) { $0 + $1.size } }
    var canExecute: Bool { scanState == .ready && !selectedCandidates.isEmpty }

    var dangerText: String {
        switch mode {
        case .generic:
            "Selected caches and logs will be permanently deleted. They are expected to be regenerable, but downloads may recur, tools may start more slowly once, and deleted logs cannot be recovered."
        case .uninstall:
            "The selected application and exact bundle-associated files will be moved to Trash. Application settings and sessions may be lost. Files protected by macOS may fail and will be reported; CleanSweep never bypasses system protections."
        }
    }

    func resetForMode() {
        executionTask?.cancel()
        candidates = []
        selectedApplication = nil
        scanState = .idle
        executionState = .idle
        progress = 0
        progressText = ""
    }

    func scanGeneric() {
        scanState = .scanning
        executionState = .idle
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                CleanupScanner().scanGeneric()
            }.value
            candidates = found
            scanState = .ready
        }
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to uninstall"
        panel.prompt = "Scan Application"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            scan(application: url)
        }
    }

    func scan(application url: URL) {
        selectedApplication = url
        scanState = .scanning
        executionState = .idle
        Task {
            do {
                let found = try await Task.detached(priority: .userInitiated) {
                    try CleanupScanner().scanApplication(url)
                }.value
                candidates = found
                scanState = .ready
            } catch {
                candidates = []
                scanState = .failed(error.localizedDescription)
            }
        }
    }

    func toggle(_ candidate: CleanupCandidate) {
        guard let index = candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        candidates[index].isSelected.toggle()
    }

    func setAll(_ selected: Bool) {
        for index in candidates.indices { candidates[index].isSelected = selected }
    }

    func requestConfirmation() {
        guard canExecute else { return }
        showConfirmation = true
        executionState = .confirming
    }

    func cancelConfirmation() {
        showConfirmation = false
        executionState = .idle
    }

    func confirmAndExecute() {
        showConfirmation = false
        executionState = .running
        progress = 0
        progressText = "Starting…"
        let snapshot = selectedCandidates
        let selectedMode = mode

        executionTask = Task {
            let result = await executor.execute(candidates: snapshot, mode: selectedMode) { completed, total, current in
                self.progress = total == 0 ? 0 : Double(completed) / Double(total)
                self.progressText = current
            }
            executionState = .finished(result)
            progress = 1
            candidates.removeAll { candidate in
                snapshot.contains(where: { $0.id == candidate.id })
                    && !result.failures.contains(where: { $0.path == candidate.url.path })
            }
        }
    }

    func cancelExecution() {
        executionTask?.cancel()
    }
}
