import AppKit
import SwiftUI

@MainActor
struct WindowRegistrationView: NSViewRepresentable {
    let registry: UIWindowRegistry

    func makeNSView(context: Context) -> RegistrationView {
        let view = RegistrationView()
        view.registry = registry
        return view
    }

    func updateNSView(_ view: RegistrationView, context: Context) {
        view.registry = registry
        if let window = view.window { registry.register(window) }
    }

    @MainActor
    final class RegistrationView: NSView {
        weak var registry: UIWindowRegistry?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { registry?.register(window) }
        }
    }
}
