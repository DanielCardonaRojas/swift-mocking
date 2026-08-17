// Generates the tutorial artwork for the SwiftMocking DocC catalog.
//
// Usage: swift Scripts/generate-tutorial-images.swift [output-dir]
// Default output: Sources/SwiftMocking/SwiftMocking.docc/Resources
//
// Produces eight 1600x900 PNG cards: one table-of-contents hero, three
// chapter cards, and four tutorial-page intros. Chapter color coding:
// blue = Getting Started, purple = Argument Matching, orange = Advanced.

import AppKit
import Foundation

// MARK: - Card specifications

struct CardSpec {
    let filename: String
    let eyebrow: String
    let title: String
    let gradient: [NSColor]
    let accent: NSColor
}

let blue = [NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.44, blue: 0.92, alpha: 1)]
let purple = [NSColor(calibratedRed: 0.10, green: 0.06, blue: 0.22, alpha: 1),
              NSColor(calibratedRed: 0.37, green: 0.29, blue: 0.90, alpha: 1)]
let orange = [NSColor(calibratedRed: 0.24, green: 0.08, blue: 0.03, alpha: 1),
              NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.04, alpha: 1)]
let hero = [NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.75, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.52, blue: 0.16, alpha: 1)]

let blueAccent = NSColor(calibratedRed: 0.35, green: 0.78, blue: 0.98, alpha: 1)
let purpleAccent = NSColor(calibratedRed: 0.75, green: 0.35, blue: 0.95, alpha: 1)
let orangeAccent = NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.04, alpha: 1)

let cards: [CardSpec] = [
    CardSpec(filename: "intro", eyebrow: "INTERACTIVE TUTORIALS", title: "SwiftMocking",
             gradient: hero, accent: orangeAccent),
    CardSpec(filename: "chapter-getting-started", eyebrow: "CHAPTER 1", title: "Getting Started",
             gradient: blue, accent: blueAccent),
    CardSpec(filename: "chapter-matching", eyebrow: "CHAPTER 2", title: "Argument Matching",
             gradient: purple, accent: purpleAccent),
    CardSpec(filename: "chapter-advanced", eyebrow: "CHAPTER 3", title: "Advanced Stubbing & Verification",
             gradient: orange, accent: orangeAccent),
    CardSpec(filename: "intro-first-mock", eyebrow: "TUTORIAL", title: "Mock Your First Protocol",
             gradient: blue, accent: blueAccent),
    CardSpec(filename: "intro-matching", eyebrow: "TUTORIAL", title: "Match Arguments Precisely",
             gradient: purple, accent: purpleAccent),
    CardSpec(filename: "intro-dynamic", eyebrow: "TUTORIAL", title: "Stub Dynamically",
             gradient: orange, accent: orangeAccent),
    CardSpec(filename: "intro-verifying", eyebrow: "TUTORIAL", title: "Verify Every Interaction",
             gradient: orange, accent: orangeAccent),
]

// MARK: - Drawing

let canvas = CGSize(width: 1600, height: 900)

func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func titleSize(for title: String) -> CGFloat {
    switch title.count {
    case ..<20: return 132
    case ..<28: return 104
    default: return 84
    }
}

func drawWindow(_ ctx: CGContext, accent: NSColor, rect: CGRect) {
    // Editor window shell.
    let shell = CGPath(roundedRect: rect, cornerWidth: 26, cornerHeight: 26, transform: nil)
    ctx.addPath(shell)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.fillPath()
    ctx.addPath(shell)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.setLineWidth(3)
    ctx.strokePath()

    // Traffic lights.
    let dotRadius: CGFloat = 11
    let dotY = rect.maxY - 42
    let dotColors: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.85, blue: 0.39, alpha: 1),
    ]
    for (index, color) in dotColors.enumerated() {
        let x = rect.minX + 38 + CGFloat(index) * (dotRadius * 2 + 16)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: dotY - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
    }

    // Code lines: muted gray, with one accent line standing in for a stub.
    let lineHeight: CGFloat = 26
    let gap: CGFloat = 38
    let widths: [CGFloat] = [190, 320, 250, 380, 150]
    let accentIndex = 3
    for (index, width) in widths.enumerated() {
        let y = rect.maxY - 110 - CGFloat(index) * gap
        if y < rect.minY + lineHeight { break }
        let lineRect = CGRect(x: rect.minX + 44, y: y, width: width, height: lineHeight)
        let line = CGPath(roundedRect: lineRect, cornerWidth: lineHeight / 2,
                          cornerHeight: lineHeight / 2, transform: nil)
        ctx.addPath(line)
        ctx.setFillColor(index == accentIndex
            ? accent.withAlphaComponent(0.85).cgColor
            : NSColor.white.withAlphaComponent(0.28).cgColor)
        ctx.fillPath()
    }
}

func render(_ spec: CardSpec) -> NSImage {
    let image = NSImage(size: canvas)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no graphics context") }

    // Vertical gradient background.
    let cgColors = spec.gradient.map(\.cgColor) as CFArray
    let locations: [CGFloat] = spec.gradient.count == 3 ? [0.0, 0.55, 1.0] : [0.0, 1.0]
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: cgColors, locations: locations) else {
        fatalError("bad gradient")
    }
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: canvas.height),
                           end: CGPoint(x: 0, y: 0),
                           options: [])

    // Soft diagonal glow for depth.
    ctx.saveGState()
    let glow = CGPath(ellipseIn: CGRect(x: 900, y: 500, width: 900, height: 900), transform: nil)
    ctx.addPath(glow)
    ctx.clip()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
    ctx.fill(CGRect(origin: .zero, size: canvas))
    ctx.restoreGState()

    // Editor window on the right.
    drawWindow(ctx, accent: spec.accent,
               rect: CGRect(x: 880, y: 300, width: 560, height: 460))

    // Eyebrow label.
    let eyebrow = NSAttributedString(string: spec.eyebrow, attributes: [
        .font: roundedFont(size: 30, weight: .semibold),
        .foregroundColor: spec.accent,
        .kern: 6.0,
    ])
    eyebrow.draw(at: CGPoint(x: 92, y: 420))

    // Title, wrapped if it would overflow the canvas.
    let titleFont = roundedFont(size: titleSize(for: spec.title), weight: .bold)
    let title = NSAttributedString(string: spec.title, attributes: [
        .font: titleFont,
        .foregroundColor: NSColor.white,
    ])
    let maxWidth: CGFloat = 720
    if title.size().width <= maxWidth {
        title.draw(at: CGPoint(x: 90, y: 300))
    } else {
        let words = spec.title.split(separator: " ").map(String.init)
        var line = ""
        var lines: [String] = []
        for word in words {
            let candidate = line.isEmpty ? word : "\(line) \(word)"
            let size = NSAttributedString(string: candidate, attributes: [
                .font: titleFont, .foregroundColor: NSColor.white,
            ]).size()
            if size.width > maxWidth, !line.isEmpty {
                lines.append(line)
                line = word
            } else {
                line = candidate
            }
        }
        lines.append(line)
        let lineHeight = titleFont.boundingRectForFont.height + 8
        for (index, text) in lines.enumerated() {
            NSAttributedString(string: text, attributes: [
                .font: titleFont, .foregroundColor: NSColor.white,
            ]).draw(at: CGPoint(x: 90, y: 300 - CGFloat(index) * lineHeight))
        }
    }

    image.unlockFocus()
    return image
}

// MARK: - Main

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/SwiftMocking/SwiftMocking.docc/Resources", isDirectory: true)

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for spec in cards {
    let image = render(spec)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("failed to encode \(spec.filename)")
    }
    let url = outputDir.appendingPathComponent("\(spec.filename).png")
    try png.write(to: url)
    print("wrote \(url.path)")
}
