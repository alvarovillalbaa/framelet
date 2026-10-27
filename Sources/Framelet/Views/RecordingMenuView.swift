import AppKit
import SwiftUI

@MainActor
struct RecordingMenuView: View {
    let capture: CaptureCoordinator
    let windows: UIWindowRegistry
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(capture.phase.uiTitle)
        if UIRecordingActions.hasCaptureWork(capture) {
            Text(UIFormatters.duration(capture.elapsedSeconds))
                .monospacedDigit()
            if capture.phase == .recording || capture.phase == .paused {
                Button(capture.phase == .paused ? "Resume" : "Pause") {
                    UIRecordingActions.togglePause(capture)
                }
            }
            Button(capture.phase == .failed ? "Retry Stop" :
                   [.starting, .countdown].contains(capture.phase) ? "Cancel Start" : "Stop Recording") {
                Task {
                    await capture.stop()
                    if !UIRecordingActions.hasCaptureWork(capture) { openLibrary() }
                }
            }
            .disabled(!UIRecordingActions.canStop(capture))
        } else {
            Button("Choose Display or Window…") {
                openLibrary()
                capture.chooseSource()
            }
            .disabled(!UIRecordingActions.canChoose(capture))
            Button("Start Recording") { Task { await capture.start() } }
                .disabled(!UIRecordingActions.canStart(capture))
        }
        Divider()
        Button("Open Library") { openLibrary() }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Framelet") { NSApp.terminate(nil) }
    }

    private func openLibrary() {
        if !windows.restore() { openWindow(id: "library") }
        NSApp.activate(ignoringOtherApps: true)
    }
}
