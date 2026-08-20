import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = CleanSweepViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceModeRaw = MThemeMode.system.rawValue

    private var appearanceMode: Binding<MThemeMode> {
        Binding(
            get: { MThemeMode(rawValue: appearanceModeRaw) ?? .system },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            appBar
            ScrollView {
                VStack(alignment: .leading, spacing: MTheme.Spacing.xl) {
                    MModeSelector(selection: $model.mode)
                        .onChange(of: model.mode) { _, _ in model.resetForMode() }
                    if model.mode == .generic { genericScanCard } else { applicationDropCard }
                    dangerBanner
                    scanStatus
                    candidateSection
                    executionStatus
                }
                .padding(MTheme.Spacing.xl)
            }
            .background(MTheme.ColorToken.surface)
            actionBar
        }
        .frame(minWidth: 860, minHeight: 700)
        .preferredColorScheme(appearanceMode.wrappedValue.colorScheme)
        .tint(appearanceMode.wrappedValue == .tinted ? Color.accentColor : Color.primary)
        .onAppear { AdaptiveAppIcon.apply(mode: appearanceMode.wrappedValue, colorScheme: colorScheme) }
        .onChange(of: colorScheme) { _, value in AdaptiveAppIcon.apply(mode: appearanceMode.wrappedValue, colorScheme: value) }
        .onChange(of: appearanceModeRaw) { _, _ in AdaptiveAppIcon.apply(mode: appearanceMode.wrappedValue, colorScheme: colorScheme) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in
            AdaptiveAppIcon.apply(mode: appearanceMode.wrappedValue, colorScheme: colorScheme)
        }
        .confirmationDialog("Confirm cleanup", isPresented: $model.showConfirmation, titleVisibility: .visible) {
            Button(model.mode == .generic ? "Confirm Permanent Cleanup" : "Confirm Move to Trash", role: .destructive) {
                model.confirmAndExecute()
            }
            Button("Cancel", role: .cancel) { model.cancelConfirmation() }
        } message: {
            Text("\(model.selectedCandidates.count) item(s), \(ByteFormatting.string(model.selectedBytes)). \(model.dangerText)")
        }
    }

    private var appBar: some View {
        HStack(spacing: MTheme.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: MTheme.Radius.medium, style: .continuous)
                    .fill(MTheme.ColorToken.primary).frame(width: 50, height: 50)
                Image(systemName: "sparkles").font(.system(size: 24, weight: .bold)).foregroundStyle(MTheme.ColorToken.onPrimary)
            }
            VStack(alignment: .leading, spacing: MTheme.Spacing.xs) {
                Text("CleanSweep").font(MTheme.Typography.display)
                Text("Review first. Clean with confidence.")
                    .font(MTheme.Typography.body).foregroundStyle(MTheme.ColorToken.onSurfaceVariant)
            }
            Spacer()
            MThemePicker(mode: appearanceMode)
            MChip(text: "Scan-first safety", icon: "checkmark.shield.fill")
        }
        .padding(.horizontal, MTheme.Spacing.xl)
        .padding(.vertical, MTheme.Spacing.lg)
        .background(MTheme.ColorToken.surfaceContainer)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private var genericScanCard: some View {
        MCard(elevation: .raised) {
            HStack(alignment: .center, spacing: MTheme.Spacing.lg) {
                featureIcon("internaldrive.fill")
                MSectionHeader("Conservative cleanup", eyebrow: "Generic scan",
                    detail: "Find regenerable package caches, temporary downloads, known updater residue, stale logs, and superseded VS Code extensions. Projects and arbitrary personal files are excluded.")
                Spacer(minLength: MTheme.Spacing.xl)
                Button { model.scanGeneric() } label: { Label("Scan Mac", systemImage: "magnifyingglass") }
                    .buttonStyle(.material(.filled))
                    .disabled(model.scanState == .scanning || isRunning)
            }
        }
    }

    private var applicationDropCard: some View {
        MCard(elevation: .raised) {
            VStack(spacing: MTheme.Spacing.lg) {
                featureIcon("app.dashed", size: 66)
                MSectionHeader(model.selectedApplication?.lastPathComponent ?? "Drop an application here",
                    eyebrow: "Application removal",
                    detail: "Associated files are matched only by exact bundle identifier or exact application name. Broad fuzzy matching is deliberately disabled.")
                    .multilineTextAlignment(.center).frame(maxWidth: 600)
                Button { model.chooseApplication() } label: { Label("Choose Application…", systemImage: "folder") }
                    .buttonStyle(.material(.tonal)).disabled(isRunning)
                Text(".APP  •  DRAG & DROP")
                    .font(MTheme.Typography.label).foregroundStyle(MTheme.ColorToken.onSurfaceVariant).tracking(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: acceptApplicationDrop)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MTheme.Radius.large, style: .continuous)
                .stroke(MTheme.ColorToken.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .padding(6).allowsHitTesting(false)
        }
    }

    private var dangerBanner: some View {
        MBanner(tone: .warning, title: "Understand the risk before continuing",
            message: model.dangerText + " Review every selected path and never clean while an affected application or package manager is updating.")
    }

    @ViewBuilder private var scanStatus: some View {
        switch model.scanState {
        case .idle: EmptyView()
        case .scanning:
            MCard { HStack { ProgressView().controlSize(.small); Text("Scanning without making changes…") } }
        case .ready where model.candidates.isEmpty:
            MBanner(tone: .success, title: "Everything looks clean", message: "No supported cleanup candidates were found.")
        case .ready:
            HStack {
                MChip(text: "\(model.candidates.count) items · \(ByteFormatting.string(model.candidates.reduce(0) { $0 + $1.size }))", icon: "checklist")
                Spacer()
                Button("Select all") { model.setAll(true) }.buttonStyle(.material(.text))
                Button("Select none") { model.setAll(false) }.buttonStyle(.material(.text))
            }
        case let .failed(message):
            MBanner(tone: .error, title: "Scan failed", message: message)
        }
    }

    @ViewBuilder private var candidateSection: some View {
        if !model.candidates.isEmpty {
            VStack(alignment: .leading, spacing: MTheme.Spacing.md) {
                MSectionHeader("Review selected items", eyebrow: "Nothing runs automatically",
                    detail: "Every checked path will be included in the confirmation dialog.")
                MCard {
                    VStack(spacing: 0) {
                        ForEach(model.candidates) { candidate in
                            CleanupCandidateRow(candidate: candidate, isRunning: isRunning) { model.toggle(candidate) }
                            if candidate.id != model.candidates.last?.id { Divider().padding(.leading, 46) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var executionStatus: some View {
        switch model.executionState {
        case .idle, .confirming: EmptyView()
        case .running:
            MCard(elevation: .raised) {
                VStack(alignment: .leading, spacing: MTheme.Spacing.md) {
                    HStack {
                        MSectionHeader("Cleanup in progress", eyebrow: "Please keep CleanSweep open")
                        Spacer()
                        Text("\(Int(model.progress * 100))%").font(MTheme.Typography.title).monospacedDigit()
                    }
                    MLinearProgress(value: model.progress)
                    Text(model.progressText).font(MTheme.Typography.mono)
                        .foregroundStyle(MTheme.ColorToken.onSurfaceVariant).lineLimit(1).truncationMode(.middle)
                    Button("Cancel remaining items") { model.cancelExecution() }.buttonStyle(.material(.outlined))
                }
            }
        case let .finished(result): MResultCard(result: result)
        }
    }

    private var actionBar: some View {
        HStack(spacing: MTheme.Spacing.md) {
            MChip(text: "Selected \(model.selectedCandidates.count) · \(ByteFormatting.string(model.selectedBytes))", icon: "checkmark.circle")
            Spacer()
            Button("Cancel") { model.cancelConfirmation() }.buttonStyle(.material(.text)).disabled(!model.showConfirmation)
            Button { model.requestConfirmation() } label: { Label("Review and confirm", systemImage: "arrow.right") }
                .buttonStyle(.material(.filled)).disabled(!model.canExecute || isRunning).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, MTheme.Spacing.xl).padding(.vertical, MTheme.Spacing.lg)
        .background(.ultraThinMaterial).overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func featureIcon(_ name: String, size: CGFloat = 54) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MTheme.Radius.medium).fill(MTheme.ColorToken.primaryContainer).frame(width: size, height: size)
            Image(systemName: name).font(.system(size: size * 0.40, weight: .semibold)).foregroundStyle(MTheme.ColorToken.primary)
        }
    }

    private func acceptApplicationDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isRunning, let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
            else if let candidate = item as? URL { url = candidate }
            else { url = nil }
            if let url { Task { @MainActor in model.scan(application: url) } }
        }
        return true
    }

    private var isRunning: Bool {
        if case .running = model.executionState { return true }
        return false
    }
}

private struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    let isRunning: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: MTheme.Spacing.md) {
            Toggle("Select \(candidate.displayName)", isOn: Binding(get: { candidate.isSelected }, set: { _ in toggle() }))
                .labelsHidden().toggleStyle(.checkbox).disabled(isRunning)
            ZStack {
                RoundedRectangle(cornerRadius: MTheme.Radius.small).fill(MTheme.ColorToken.primary.opacity(0.10)).frame(width: 34, height: 34)
                Image(systemName: candidate.category.systemImage).foregroundStyle(MTheme.ColorToken.primary)
            }
            VStack(alignment: .leading, spacing: MTheme.Spacing.xs) {
                HStack {
                    Text(candidate.displayName).font(MTheme.Typography.title)
                    Text(candidate.category.rawValue.uppercased()).font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MTheme.ColorToken.primary).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(MTheme.ColorToken.primary.opacity(0.08)).clipShape(Capsule())
                }
                Text(candidate.url.path).font(MTheme.Typography.mono).foregroundStyle(MTheme.ColorToken.onSurfaceVariant).textSelection(.enabled)
                Text(candidate.explanation).font(MTheme.Typography.caption).foregroundStyle(MTheme.ColorToken.onSurfaceVariant)
            }
            Spacer(minLength: MTheme.Spacing.md)
            Text(ByteFormatting.string(candidate.size)).font(MTheme.Typography.label).monospacedDigit()
        }
        .padding(.vertical, MTheme.Spacing.md).contentShape(Rectangle())
        .onTapGesture { if !isRunning { toggle() } }
    }
}

private struct MResultCard: View {
    let result: CleanupResult
    var body: some View {
        MCard(elevation: .raised) {
            VStack(alignment: .leading, spacing: MTheme.Spacing.lg) {
                MBanner(tone: result.failures.isEmpty ? .success : .warning,
                    title: result.cancelled ? "Cleanup cancelled" : result.failures.isEmpty ? "Cleanup completed" : "Completed with errors",
                    message: "Processed \(result.processedCount) item(s).")
                HStack(spacing: MTheme.Spacing.md) {
                    metric("Freed now", ByteFormatting.string(result.freedBytes), "internaldrive")
                    metric("Moved to Trash", ByteFormatting.string(result.movedToTrashBytes), "trash")
                    metric("Errors", "\(result.failures.count)", "exclamationmark.circle")
                }
                if result.movedToTrashBytes > 0 {
                    Text("Items in Trash still consume disk space. Empty Trash separately only when you are certain they are no longer needed.")
                        .font(MTheme.Typography.caption).foregroundStyle(MTheme.ColorToken.onSurfaceVariant)
                }
                if !result.failures.isEmpty {
                    DisclosureGroup("Error details") {
                        VStack(alignment: .leading, spacing: MTheme.Spacing.md) {
                            ForEach(result.failures) { failure in
                                VStack(alignment: .leading, spacing: MTheme.Spacing.xs) {
                                    Text(failure.path).font(MTheme.Typography.mono).textSelection(.enabled)
                                    Text(failure.message).font(MTheme.Typography.caption).foregroundStyle(MTheme.ColorToken.error)
                                }
                            }
                        }.padding(.top, MTheme.Spacing.sm)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: MTheme.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(MTheme.ColorToken.primary)
            Text(value).font(MTheme.Typography.headline).monospacedDigit()
            Text(title).font(MTheme.Typography.caption).foregroundStyle(MTheme.ColorToken.onSurfaceVariant)
        }
        .padding(MTheme.Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(MTheme.ColorToken.surfaceContainerHigh).clipShape(RoundedRectangle(cornerRadius: MTheme.Radius.medium))
    }
}
