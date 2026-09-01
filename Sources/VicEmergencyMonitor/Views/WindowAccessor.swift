import SwiftUI
import AppKit

/// Lets a SwiftUI view reach into its hosting NSWindow to toggle "always on top".
struct WindowAccessor: NSViewRepresentable {
    var keepOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        window.level = keepOnTop ? .floating : .normal
        window.collectionBehavior = keepOnTop ? [.canJoinAllSpaces, .stationary] : []
    }
}
