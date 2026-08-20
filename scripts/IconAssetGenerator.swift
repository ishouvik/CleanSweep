import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: IconAssetGenerator <template.png> <output-directory>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let manager = FileManager.default
try manager.createDirectory(at: output, withIntermediateDirectories: true)
let iconset = output.appendingPathComponent("CleanSweep.iconset", isDirectory: true)
try? manager.removeItem(at: iconset)
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let source = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to read template icon\n", stderr)
    exit(3)
}

enum Variant: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case tinted = "Tinted"

    var background: NSColor {
        switch self {
        case .light: NSColor(calibratedWhite: 0.97, alpha: 1)
        case .dark: NSColor(calibratedWhite: 0.06, alpha: 1)
        case .tinted: .controlAccentColor
        }
    }

    var foreground: NSColor {
        switch self {
        case .light: NSColor(calibratedWhite: 0.04, alpha: 1)
        case .dark, .tinted: .white
        }
    }
}

func render(size: Int, variant: Variant) -> NSImage {
    let dimensions = NSSize(width: size, height: size)
    let glyph = NSImage(size: dimensions)
    glyph.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    variant.foreground.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: dimensions)).fill()
    source.draw(in: NSRect(origin: .zero, size: dimensions), from: .zero, operation: .destinationIn, fraction: 1)
    glyph.unlockFocus()

    let image = NSImage(size: dimensions)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let inset = CGFloat(size) * 0.03
    let tile = NSRect(origin: NSPoint(x: inset, y: inset), size: NSSize(width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2))
    variant.background.setFill()
    NSBezierPath(roundedRect: tile, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22).fill()
    glyph.draw(in: NSRect(origin: .zero, size: dimensions))
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CleanSweep.IconGenerator", code: 1)
    }
    try data.write(to: url)
}

func pngData(_ image: NSImage) throws -> Data {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CleanSweep.IconGenerator", code: 2)
    }
    return data
}

func bigEndian(_ value: UInt32) -> Data {
    var encoded = value.bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

func writeICNS(to url: URL) throws {
    let representations: [(type: String, pixels: Int)] = [
        ("ic10", 1024), ("ic09", 512), ("ic08", 256), ("ic07", 128),
        ("icp6", 64), ("icp5", 32), ("icp4", 16)
    ]
    var body = Data()
    for representation in representations {
        let payload = try pngData(render(size: representation.pixels, variant: .light))
        body.append(representation.type.data(using: .ascii)!)
        body.append(bigEndian(UInt32(payload.count + 8)))
        body.append(payload)
    }
    var file = Data("icns".utf8)
    file.append(bigEndian(UInt32(body.count + 8)))
    file.append(body)
    try file.write(to: url)
}

for variant in Variant.allCases {
    try writePNG(render(size: 1024, variant: variant), to: output.appendingPathComponent("CleanSweep\(variant.rawValue).png"))
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for item in sizes {
    try writePNG(render(size: item.pixels, variant: .light), to: iconset.appendingPathComponent(item.name))
}
try writeICNS(to: output.appendingPathComponent("CleanSweep.icns"))

print("Generated adaptive icon assets in \(output.path)")
