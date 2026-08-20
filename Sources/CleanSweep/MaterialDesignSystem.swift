import SwiftUI

enum MThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case tinted = "Tinted"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system, .tinted: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .tinted: "paintpalette.fill"
        }
    }
}

enum MTheme {
    enum ColorToken {
        // The palette is deliberately semantic and monochrome. Color.primary and
        // AppKit system surfaces adapt automatically to Light and Dark appearances.
        // The user's macOS accent is reserved for focus, controls, and Tint mode.
        static let primary = Color.primary
        static let onPrimary = Color(nsColor: .windowBackgroundColor)
        static let primaryContainer = Color.primary.opacity(0.08)
        static let onPrimaryContainer = Color.primary
        static let surface = Color(nsColor: .windowBackgroundColor)
        static let surfaceContainer = Color(nsColor: .controlBackgroundColor)
        static let surfaceContainerHigh = Color(nsColor: .underPageBackgroundColor)
        static let onSurfaceVariant = Color.secondary
        static let outline = Color.secondary.opacity(0.48)
        static let outlineVariant = Color.secondary.opacity(0.20)
        static let error = Color.primary
        static let errorContainer = Color.primary.opacity(0.12)
        static let onErrorContainer = Color.primary
        static let warning = Color.primary
        static let warningContainer = Color.primary.opacity(0.09)
        static let success = Color.primary
        static let successContainer = Color.primary.opacity(0.07)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    enum Typography {
        static let display = Font.system(size: 32, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 19, weight: .semibold, design: .rounded)
        static let title = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13)
        static let label = Font.system(size: 12, weight: .semibold)
        static let caption = Font.system(size: 11)
        static let mono = Font.system(size: 11, design: .monospaced)
    }
}

struct MThemePicker: View {
    @Binding var mode: MThemeMode

    var body: some View {
        Picker("Appearance", selection: $mode) {
            ForEach(MThemeMode.allCases) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 118)
        .accessibilityHint("Choose System, Light, Dark, or system-accent Tinted appearance")
    }
}

struct MCard<Content: View>: View {
    enum Elevation { case flat, raised }
    let elevation: Elevation
    @ViewBuilder let content: Content

    init(elevation: Elevation = .flat, @ViewBuilder content: () -> Content) {
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        content
            .padding(MTheme.Spacing.lg)
            .background(MTheme.ColorToken.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: MTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTheme.Radius.large, style: .continuous)
                    .stroke(MTheme.ColorToken.outlineVariant, lineWidth: elevation == .flat ? 1 : 0)
            }
            .shadow(color: .black.opacity(elevation == .raised ? 0.13 : 0), radius: 8, y: 3)
    }
}

struct MSectionHeader: View {
    let eyebrow: String?
    let title: String
    let detail: String?

    init(_ title: String, eyebrow: String? = nil, detail: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MTheme.Spacing.xs) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(MTheme.Typography.label)
                    .foregroundStyle(MTheme.ColorToken.primary)
                    .tracking(0.7)
            }
            Text(title).font(MTheme.Typography.headline)
            if let detail {
                Text(detail)
                    .font(MTheme.Typography.body)
                    .foregroundStyle(MTheme.ColorToken.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum MButtonKind { case filled, tonal, outlined, text, danger }

struct MButtonStyle: ButtonStyle {
    let kind: MButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MTheme.Typography.label)
            .padding(.horizontal, kind == .text ? MTheme.Spacing.sm : MTheme.Spacing.lg)
            .frame(minHeight: 38)
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.76 : 1))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(border, lineWidth: kind == .outlined ? 1 : 0) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var background: Color {
        switch kind {
        case .filled: MTheme.ColorToken.primary
        case .tonal: MTheme.ColorToken.primaryContainer
        case .danger: MTheme.ColorToken.error
        case .outlined, .text: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .filled, .danger: MTheme.ColorToken.onPrimary
        case .tonal: MTheme.ColorToken.onPrimaryContainer
        case .outlined, .text: MTheme.ColorToken.primary
        }
    }

    private var border: Color { kind == .outlined ? MTheme.ColorToken.outline : .clear }
}

extension ButtonStyle where Self == MButtonStyle {
    static func material(_ kind: MButtonKind) -> MButtonStyle { MButtonStyle(kind: kind) }
}

struct MChip: View {
    let text: String
    let icon: String?
    var color = MTheme.ColorToken.primary

    var body: some View {
        HStack(spacing: MTheme.Spacing.xs) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(MTheme.Typography.label)
        .foregroundStyle(color)
        .padding(.horizontal, MTheme.Spacing.md)
        .frame(height: 30)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(color.opacity(0.24), lineWidth: 1) }
    }
}

struct MBanner: View {
    enum Tone { case info, warning, error, success }
    let tone: Tone
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: MTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: MTheme.Spacing.xs) {
                Text(title).font(MTheme.Typography.title).foregroundStyle(foreground)
                Text(message).font(MTheme.Typography.body).foregroundStyle(foreground.opacity(0.82))
            }
            Spacer(minLength: 0)
        }
        .padding(MTheme.Spacing.lg)
        .background(container)
        .clipShape(RoundedRectangle(cornerRadius: MTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch tone {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    private var accent: Color {
        switch tone {
        case .info: MTheme.ColorToken.primary
        case .warning: MTheme.ColorToken.warning
        case .error: MTheme.ColorToken.error
        case .success: MTheme.ColorToken.success
        }
    }

    private var container: Color {
        switch tone {
        case .info: MTheme.ColorToken.primaryContainer
        case .warning: MTheme.ColorToken.warningContainer
        case .error: MTheme.ColorToken.errorContainer
        case .success: MTheme.ColorToken.successContainer
        }
    }

    private var foreground: Color {
        switch tone {
        case .info: MTheme.ColorToken.onPrimaryContainer
        case .warning: MTheme.ColorToken.warning
        case .error: MTheme.ColorToken.onErrorContainer
        case .success: MTheme.ColorToken.success
        }
    }
}

struct MLinearProgress: View {
    let value: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MTheme.ColorToken.primary.opacity(0.15))
                Capsule().fill(MTheme.ColorToken.primary)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.22), value: value)
        .accessibilityLabel("Cleanup progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct MModeSelector: View {
    @Binding var selection: CleanupMode
    var body: some View {
        HStack(spacing: MTheme.Spacing.sm) {
            ForEach(CleanupMode.allCases) { mode in
                Button { selection = mode } label: {
                    Label(mode.rawValue, systemImage: mode == .generic ? "sparkles" : "app.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.material(selection == mode ? .filled : .tonal))
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(MTheme.Spacing.xs)
        .background(MTheme.ColorToken.surfaceContainerHigh)
        .clipShape(Capsule())
    }
}
