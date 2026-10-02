#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO

// First run scripts/preview-icon.sh to render the actual Icon Composer materials.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let artwork = root.appendingPathComponent("docs/artwork", isDirectory: true)
let iconURL = root.appendingPathComponent("build/IconPreviews/Default.png")
guard let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
      let icon = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let titleFont = NSFont(name: "SignPainter-HouseScriptSemibold", size: 144),
      let subtitleFont = NSFont(name: "AvenirNext-Regular", size: 32) else {
    fatalError("Run scripts/preview-icon.sh first. macOS SignPainter and Avenir Next fonts are required.")
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func writePNG(name: String, size: NSSize, scale: CGFloat, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.clear(CGRect(origin: .zero, size: size))
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: artwork.appendingPathComponent(name), options: .atomic)
}

try FileManager.default.createDirectory(at: artwork, withIntermediateDirectories: true)
for (name, titleColor, subtitleColor) in [
    ("header-light.png", color(0x254D44), color(0x477365)),
    ("header-dark.png", color(0xE6B57C), color(0xAAD0C2))
] {
    try writePNG(name: name, size: NSSize(width: 850, height: 260), scale: 2) {
        NSGraphicsContext.current!.cgContext.draw(icon, in: CGRect(x: 28, y: 28, width: 204, height: 204))
        ("Scratchpad" as NSString).draw(
            at: NSPoint(x: 268, y: 98),
            withAttributes: [.font: titleFont, .foregroundColor: titleColor])
        ("Tiny notes for macOS" as NSString).draw(
            at: NSPoint(x: 275, y: 45),
            withAttributes: [.font: subtitleFont, .foregroundColor: subtitleColor])
    }
}
try writePNG(name: "scratchpad-icon.png", size: NSSize(width: 256, height: 256), scale: 1) {
    NSGraphicsContext.current!.cgContext.draw(icon, in: CGRect(x: 0, y: 0, width: 256, height: 256))
}
print("README artwork: \(artwork.path)")
