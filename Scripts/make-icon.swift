// Generates Resources/AppIcon.icns.
//
//   swiftc Scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Resources/AppIcon.iconset \
//     && iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
//
// The flame is a hand-drawn path (SF Symbols can't be used in app icons).
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Flame outline in a 100x100 box, y up.
func flamePath() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 50, y: 5))
    p.curve(to: NSPoint(x: 14, y: 42), controlPoint1: NSPoint(x: 28, y: 5), controlPoint2: NSPoint(x: 14, y: 22))
    p.curve(to: NSPoint(x: 28, y: 74), controlPoint1: NSPoint(x: 14, y: 56), controlPoint2: NSPoint(x: 22, y: 66))
    p.curve(to: NSPoint(x: 38, y: 52), controlPoint1: NSPoint(x: 28, y: 64), controlPoint2: NSPoint(x: 32, y: 58))
    p.curve(to: NSPoint(x: 58, y: 95), controlPoint1: NSPoint(x: 38, y: 68), controlPoint2: NSPoint(x: 46, y: 82))
    p.curve(to: NSPoint(x: 86, y: 44), controlPoint1: NSPoint(x: 70, y: 80), controlPoint2: NSPoint(x: 86, y: 64))
    p.curve(to: NSPoint(x: 50, y: 5), controlPoint1: NSPoint(x: 86, y: 22), controlPoint2: NSPoint(x: 70, y: 5))
    p.close()
    return p
}

/// Inner, brighter flame core.
func corePath() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 50, y: 12))
    p.curve(to: NSPoint(x: 30, y: 36), controlPoint1: NSPoint(x: 36, y: 12), controlPoint2: NSPoint(x: 28, y: 24))
    p.curve(to: NSPoint(x: 49, y: 68), controlPoint1: NSPoint(x: 32, y: 50), controlPoint2: NSPoint(x: 42, y: 56))
    p.curve(to: NSPoint(x: 68, y: 34), controlPoint1: NSPoint(x: 58, y: 58), controlPoint2: NSPoint(x: 70, y: 50))
    p.curve(to: NSPoint(x: 50, y: 12), controlPoint1: NSPoint(x: 66, y: 20), controlPoint2: NSPoint(x: 58, y: 12))
    p.close()
    return p
}

func draw() {
    // Apple's macOS icon grid: an 824pt body centred in the 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 184, yRadius: 184)

    // Soft drop shadow under the body.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x1B3247).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    bodyPath.addClip()

    // Calm dusk gradient: muted slate-teal at the top into deep navy.
    NSGradient(colors: [color(0x35607A), color(0x1B3247), color(0x111F2E)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)?
        .draw(in: body, angle: -90)

    // Warm glow behind the flame.
    NSGradient(colors: [color(0xFFA95A, alpha: 0.34), color(0xFFA95A, alpha: 0)])?
        .draw(fromCenter: NSPoint(x: 512, y: 440), radius: 0, toCenter: NSPoint(x: 512, y: 440), radius: 420, options: [])

    // Faint concentric rings hint at "what's within your radius".
    color(0xFFFFFF, alpha: 0.10).setStroke()
    for radius: CGFloat in [250, 340, 430] {
        let ring = NSBezierPath(ovalIn: NSRect(x: 512 - radius, y: 500 - radius, width: radius * 2, height: radius * 2))
        ring.lineWidth = 7
        ring.stroke()
    }

    // Flame, scaled from its 100-unit box and centred.
    let transform = NSAffineTransform()
    transform.translateX(by: 512, yBy: 505)
    transform.scale(by: 5.1)
    transform.translateX(by: -50, yBy: -50)

    func transformed(_ path: NSBezierPath) -> NSBezierPath {
        let copy = path.copy() as! NSBezierPath
        copy.transform(using: transform as AffineTransform)
        return copy
    }

    let outer = transformed(flamePath())
    NSGraphicsContext.saveGraphicsState()
    let flameShadow = NSShadow()
    flameShadow.shadowColor = color(0x000000, alpha: 0.30)
    flameShadow.shadowBlurRadius = 22
    flameShadow.shadowOffset = NSSize(width: 0, height: -8)
    flameShadow.set()
    color(0xF58A3D).setFill()
    outer.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0xF58A3D), color(0xFFB65C), color(0xFFD27A)], atLocations: [0, 0.6, 1], colorSpace: .sRGB)?
        .draw(in: outer, angle: 90)

    let core = transformed(corePath())
    NSGradient(colors: [color(0xFFD27A), color(0xFFF1CC)], atLocations: [0, 1], colorSpace: .sRGB)?
        .draw(in: core, angle: 90)

    NSGraphicsContext.restoreGraphicsState()

    // Hairline highlight on the body edge.
    color(0xFFFFFF, alpha: 0.12).setStroke()
    let edge = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: 183, yRadius: 183)
    edge.lineWidth = 3
    edge.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / canvas
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count > 1 else {
    print("usage: make-icon <output .iconset directory>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, px) in sizes {
    try render(pixels: px).write(to: outDir.appendingPathComponent("\(name).png"))
}
print("wrote \(sizes.count) images to \(outDir.path)")
