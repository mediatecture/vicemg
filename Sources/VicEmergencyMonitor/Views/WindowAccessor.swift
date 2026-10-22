import SwiftUI
import AppKit

/// Lets a SwiftUI view reach into its hosting NSWindow. While `keepOnTop` is set the window
/// floats above other apps on every Space and can be dragged by its background while the
/// content collapses into the compact mini layout; unpinning restores the previous size.
struct WindowAccessor: NSViewRepresentable {
    var keepOnTop: Bool

    final class Coordinator {
        var keepOnTop = false
        var isPinned = false
        var sizeBeforePinning: NSSize?
    }

    /// Reports when the view is actually attached to a window. Without this, a window that
    /// launches already pinned would be styled too early (no window yet) and never again.
    final class AccessorView: NSView {
        var onWindowAttached: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { onWindowAttached?() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let coordinator = context.coordinator
        coordinator.keepOnTop = keepOnTop
        let view = AccessorView(frame: .zero)
        view.onWindowAttached = { [weak view] in
            guard let view else { return }
            DispatchQueue.main.async { Self.apply(to: view, coordinator: coordinator) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.keepOnTop = keepOnTop
        DispatchQueue.main.async { Self.apply(to: nsView, coordinator: coordinator) }
    }

    private static func apply(to view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }
        let keepOnTop = coordinator.keepOnTop
        window.level = keepOnTop ? .floating : .normal
        window.collectionBehavior = keepOnTop ? [.canJoinAllSpaces, .stationary] : []

        if keepOnTop {
            if !coordinator.isPinned {
                coordinator.isPinned = true
                coordinator.sizeBeforePinning = window.contentRect(forFrameRect: window.frame).size
                keepTopLeft(of: window)
            }
            window.isMovableByWindowBackground = true
        } else {
            window.isMovableByWindowBackground = false

            if coordinator.isPinned {
                coordinator.isPinned = false
                if let size = coordinator.sizeBeforePinning {
                    restore(window, to: size)
                }
            }
        }
    }

    /// SwiftUI resizes the window around its own anchor, so after it shrinks put the
    /// top-left corner back where it was instead of letting the window drift.
    private static func keepTopLeft(of window: NSWindow) {
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.setFrameTopLeftPoint(topLeft)
        }
    }

    /// Grows the window back to its pre-pinning size, keeping its top-left corner in place.
    private static func restore(_ window: NSWindow, to size: NSSize) {
        // Wait a beat so SwiftUI has applied the full layout's minimum size first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
            window.setContentSize(size)
            window.setFrameTopLeftPoint(topLeft)
        }
    }
}
