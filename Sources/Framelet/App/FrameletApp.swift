import AppKit
import SwiftUI

@main
@MainActor
struct FrameletApp: App {
    @NSApplicationDelegateAdaptor(FrameletAppDelegate.self) private var appDelegate
    @State private var library: RecordingLibrary
    @State private var capture: CaptureCoordinator
    @State private var exporter: ExportCoordinator
    @State private var windows = UIWindowRegistry()

    init() {
        let library = RecordingLibrary()
        let capture = CaptureCoordinator(library: library)
        capture.options = UICapturePreferences.load()
        let exporter = ExportCoordinator()
        _library = State(initialValue: library)
        _capture = State(initialValue: capture)
        _exporter = State(initialValue: exporter)
        appDelegate.capture = capture
        appDelegate.exporter = exporter
    }

    var body: some Scene {
        WindowGroup("Framelet", id: "library") {
            LibraryView(library: library, capture: capture, exporter: exporter)
                .frame(minWidth: 900, minHeight: 640)
                .background(WindowRegistrationView(registry: windows).frame(width: 0, height: 0))
                .onAppear {
                    appDelegate.capture = capture
                    appDelegate.exporter = exporter
                }
                .onChange(of: capture.options) { _, options in
                    UICapturePreferences.save(options)
                }
                .onChange(of: capture.phase) { _, phase in
                    if phase == .recording && UICapturePreferences.hidesWindowWhileRecording {
                        windows.minimizeForRecording()
                    }
                }
                .onChange(of: UIRecordingActions.hasCaptureWork(capture)) { _, hasWork in
                    if !hasWork { windows.restore() }
                }
        }
        .defaultSize(width: 1180, height: 820)
        .commands { RecordingCommands(capture: capture) }

        MenuBarExtra {
            RecordingMenuView(capture: capture, windows: windows)
        } label: {
            Image(systemName: UIRecordingActions.hasCaptureWork(capture) ? "record.circle.fill" : "rectangle.inset.filled.and.person.filled")
                .accessibilityLabel(UIRecordingActions.hasCaptureWork(capture) ? "Framelet recording controls" : "Framelet")
        }

        Settings {
            RecordingSettingsView(capture: capture)
        }
    }
}

@MainActor
final class FrameletAppDelegate: NSObject, NSApplicationDelegate {
    weak var capture: CaptureCoordinator?
    weak var exporter: ExportCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let capture, UIRecordingActions.hasCaptureWork(capture) {
            let alert = NSAlert()
            alert.messageText = "Finish this recording before quitting."
            alert.informativeText = UIRecordingActions.canStop(capture)
                ? "Stop and stay in Framelet while the recording finishes. Original files remain in your local library."
                : "Framelet is finishing a recording operation. Keep the app open until it completes."
            if UIRecordingActions.canStop(capture) { alert.addButton(withTitle: "Stop and Stay") }
            alert.addButton(withTitle: "Keep Framelet Open")
            if alert.runModal() == .alertFirstButtonReturn, UIRecordingActions.canStop(capture) {
                Task { await capture.stop() }
            }
            return .terminateCancel
        }
        if let exporter, exporter.isExporting {
            let alert = NSAlert()
            alert.messageText = "An export is still in progress."
            alert.informativeText = "Cancel the export and stay in Framelet, or keep waiting. Your recording originals are retained."
            alert.addButton(withTitle: "Cancel Export and Stay")
            alert.addButton(withTitle: "Keep Exporting")
            if alert.runModal() == .alertFirstButtonReturn { exporter.cancel() }
            return .terminateCancel
        }
        return .terminateNow
    }
}
