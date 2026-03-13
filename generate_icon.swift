#!/usr/bin/env swift
import AppKit

let iconsetPath = "LightEmUp/LightEmUp.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        // Background: rounded rect with gradient
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05),
                                   xRadius: size * 0.2, yRadius: size * 0.2)

        // Orange-yellow gradient background
        let gradient = NSGradient(colors: [
            NSColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0)
        ])!
        gradient.draw(in: bgPath, angle: -90)

        // Draw sun symbol
        if let symbolImage = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: size * 0.45, weight: .bold)
            let configured = symbolImage.withSymbolConfiguration(config)!

            let symbolSize = configured.size
            let x = (size - symbolSize.width) / 2
            let y = (size - symbolSize.height) / 2

            NSColor.white.set()
            configured.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                          from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        return true
    }

    // Render to bitmap
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: Int(size),
                                pixelsHigh: Int(size),
                                bitsPerSample: 8,
                                samplesPerPixel: 4,
                                hasAlpha: true,
                                isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: 0,
                                bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
}

print("Generated iconset at \(iconsetPath)")
