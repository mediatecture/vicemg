import AppKit
import MapKit
import CoreLocation

/// Builds the thumbnail attached to a notification: a map centred on the
/// incident, a coloured badge with an icon for the emergency type, and a dot
/// for the user's own location when it falls inside the frame.
@MainActor
enum NotificationImageRenderer {
    static let size = CGSize(width: 320, height: 320)

    /// Returns a file URL for a PNG, or nil if the image couldn't be written.
    /// If the map can't be fetched (offline, timeout) the badge is drawn on a
    /// plain background so the notification still gets its icon.
    static func renderPNG(for incident: Incident, origin: CLLocationCoordinate2D?, distanceKm: Double?) async -> URL? {
        // Centre on the incident, wide enough that the user's location is in frame.
        let spanMeters = min(max((distanceKm ?? 0) * 2_200, 4_000), 500_000)
        let region = MKCoordinateRegion(center: incident.coordinate, latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
        let snapshot = await mapSnapshot(region: region)

        let image = compose(snapshot: snapshot, incident: incident, origin: origin, distanceKm: distanceKm)
        return writePNG(image)
    }

    // MARK: - Map snapshot

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    private static func mapSnapshot(region: MKCoordinateRegion) async -> MKMapSnapshotter.Snapshot? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard
        let snapshotter = MKMapSnapshotter(options: options)

        return await withCheckedContinuation { continuation in
            let once = Once()
            snapshotter.start(with: .global()) { snapshot, _ in
                if once.claim() { continuation.resume(returning: snapshot) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
                if once.claim() {
                    snapshotter.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Drawing

    private static func compose(
        snapshot: MKMapSnapshotter.Snapshot?,
        incident: Incident,
        origin: CLLocationCoordinate2D?,
        distanceKm: Double?
    ) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            if let snapshot {
                snapshot.image.draw(in: rect, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            } else {
                NSColor(white: 0.92, alpha: 1).setFill()
                rect.fill()
            }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            // MapKit's snapshot points have a bottom-left origin on macOS, but this
            // image is drawn top-left, so flip Y.
            func point(_ coordinate: CLLocationCoordinate2D, in snapshot: MKMapSnapshotter.Snapshot) -> CGPoint {
                let p = snapshot.point(for: coordinate)
                return CGPoint(x: p.x, y: snapshot.image.size.height - p.y)
            }
            let incidentPoint = snapshot.map { point(incident.coordinate, in: $0) } ?? center

            if let snapshot, let origin {
                let p = point(origin, in: snapshot)
                if rect.insetBy(dx: 10, dy: 10).contains(p) {
                    drawUserDot(at: p)
                }
            }
            drawBadge(at: incidentPoint, incident: incident)
            if let distanceKm {
                drawPill(String(format: "%.0f km away", distanceKm), in: rect)
            }
            return true
        }
    }

    private static func badgeColor(for incident: Incident) -> NSColor {
        switch incident.severity {
        case .critical: return .systemRed
        case .high: return .systemOrange
        case .medium: return NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.05, alpha: 1)
        case .low: return .systemGray
        }
    }

    private static func drawBadge(at point: CGPoint, incident: Incident) {
        let outer: CGFloat = 30
        let inner: CGFloat = 25

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - outer, y: point.y - outer, width: outer * 2, height: outer * 2)).fill()
        NSGraphicsContext.restoreGraphicsState()

        badgeColor(for: incident).setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - inner, y: point.y - inner, width: inner * 2, height: inner * 2)).fill()

        if let symbol = tintedSymbol(incident.kind.symbolName, pointSize: 28, color: .white) {
            let s = symbol.size
            symbol.draw(
                in: CGRect(x: point.x - s.width / 2, y: point.y - s.height / 2, width: s.width, height: s.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
        }
    }

    private static func drawUserDot(at point: CGPoint) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)).fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)).fill()
    }

    private static func drawPill(_ text: String, in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let pill = CGRect(x: 12, y: rect.maxY - textSize.height - 22, width: textSize.width + 20, height: textSize.height + 10)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        string.draw(at: CGPoint(x: pill.minX + 10, y: pill.minY + 5))
    }

    /// SF Symbols are template images, so tint by filling over the glyph's alpha.
    private static func tintedSymbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                ?? NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        else { return nil }
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        return tinted
    }

    // MARK: - Output

    private static func writePNG(_ image: NSImage) -> URL? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vicemergency-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Couldn't write notification image: \(error.localizedDescription)")
            return nil
        }
    }
}
