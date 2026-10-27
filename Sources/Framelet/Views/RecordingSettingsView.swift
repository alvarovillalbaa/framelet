import SwiftUI

@MainActor
struct RecordingSettingsView: View {
    @Bindable var capture: CaptureCoordinator
    @AppStorage(UICapturePreferences.hideWindowKey) private var hideWindow = true

    var body: some View {
        Form {
            Section("Recording defaults") {
                Toggle("Include system audio", isOn: $capture.options.capturesSystemAudio)
                Toggle("Include default microphone", isOn: $capture.options.capturesMicrophone)
                Toggle("Include default camera", isOn: $capture.options.cameraEnabled)
                Toggle("Show pointer", isOn: $capture.options.showsCursor)
                Picker("Countdown", selection: $capture.options.countdownSeconds) {
                    Text("None").tag(0)
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
            }
            .disabled(UIRecordingActions.hasCaptureWork(capture) || capture.phase == .choosing)
            Section("Window") {
                Toggle("Minimize library while recording", isOn: $hideWindow)
                Text("Use the menu bar to pause, resume or stop. The library returns when the recording finishes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Camera and microphone are off until you enable them. Their device permissions are requested only after you explicitly start a recording with those options.")
                Text("Recordings and edits stay on this Mac. Closing the library window leaves recording controls in the menu bar.")
                if UIRecordingActions.hasCaptureWork(capture) {
                    Text("Finish the current recording before changing its options.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: capture.options) { _, options in UICapturePreferences.save(options) }
    }
}
