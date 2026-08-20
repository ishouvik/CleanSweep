import AppKit
import SwiftUI

enum AdaptiveAppIcon {
    static func apply(mode: MThemeMode, colorScheme: ColorScheme) {
        let image: NSImage?
        switch mode {
        case .light:
            image = bundled("CleanSweepLight")
        case .dark:
            image = bundled("CleanSweepDark")
        case .tinted:
            image = tintedFromTemplate()
        case .system:
            image = bundled(colorScheme == .dark ? "CleanSweepDark" : "CleanSweepLight")
        }
        if let image { NSApplication.shared.applicationIconImage = image }
    }

    private static func bundled(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func tintedFromTemplate() -> NSImage? {
        guard let template = bundled("CleanSweepTemplate") else { return bundled("CleanSweepTinted") }
        let size = NSSize(width: 1024, height: 1024)

        let glyph = NSImage(size: size)
        glyph.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        template.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .destinationIn, fraction: 1)
        glyph.unlockFocus()

        let image = NSImage(size: size)
        image.lockFocus()
        let tile = NSRect(x: 31, y: 31, width: 962, height: 962)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: tile, xRadius: 225, yRadius: 225).fill()
        glyph.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
