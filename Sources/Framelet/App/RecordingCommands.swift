import SwiftUI

@MainActor
struct RecordingCommands: Commands {
    let capture: CaptureCoordinator

    var body: some Commands {
        CommandMenu("Recording") {
            Button("Choose Display or Window…") { capture.chooseSource() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!UIRecordingActions.canChoose(capture))
            Button("Start Recording") { Task { await capture.start() } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!UIRecordingActions.canStart(capture))
            Button(capture.phase == .paused ? "Resume Recording" : "Pause Recording") {
                UIRecordingActions.togglePause(capture)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(capture.phase != .recording && capture.phase != .paused)
            Button("Stop Recording") { Task { await capture.stop() } }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!UIRecordingActions.canStop(capture))
            Divider()
            Text("Shortcuts work while Framelet is active.")
        }
    }
}
