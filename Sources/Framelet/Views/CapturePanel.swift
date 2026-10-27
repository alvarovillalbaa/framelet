import AppKit
import AVFoundation
import SwiftUI

@MainActor
struct CapturePanel: View {
    @Bindable var capture: CaptureCoordinator
    @State private var showOptions = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        if UIRecordingActions.hasCaptureWork(capture) {
                            Circle().fill(capture.phase == .paused ? Color.orange : Color.red).frame(width: 8, height: 8)
                        }
                        Text(capture.phase.uiTitle).font(.headline)
                        if capture.phase == .countdown {
                            Text(String(capture.countdownRemaining))
                                .font(.title2.monospacedDigit().bold())
                                .accessibilityLabel("Starting in \(capture.countdownRemaining) seconds")
                        } else if UIRecordingActions.hasCaptureWork(capture) {
                            Text(UIFormatters.duration(capture.elapsedSeconds)).monospacedDigit()
                        }
                    }
                    Text(capture.selectedSourceName ?? "No display or window selected")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if UIRecordingActions.hasCaptureWork(capture) {
                    if capture.phase == .recording || capture.phase == .paused {
                        Button(capture.phase == .paused ? "Resume" : "Pause",
                               systemImage: capture.phase == .paused ? "play.fill" : "pause.fill") {
                            UIRecordingActions.togglePause(capture)
                        }
                    }
                    Button(capture.phase == .failed ? "Retry Stop" :
                           [.starting, .countdown].contains(capture.phase) ? "Cancel Start" : "Stop",
                           systemImage: "stop.fill") {
                        Task { await capture.stop() }
                    }
                    .disabled(!UIRecordingActions.canStop(capture))
                } else {
                    Button("Choose Source…", systemImage: "rectangle.dashed") { capture.chooseSource() }
                        .disabled(!UIRecordingActions.canChoose(capture))
                    Button("Start", systemImage: "record.circle") { Task { await capture.start() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(!UIRecordingActions.canStart(capture))
                }
            }
            .controlSize(.large)
            .accessibilityElement(children: .contain)

            DisclosureGroup("Recording options", isExpanded: $showOptions) {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 9) {
                        Toggle("System audio", isOn: $capture.options.capturesSystemAudio)
                        Toggle("Default microphone", isOn: $capture.options.capturesMicrophone)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Toggle("Default camera", isOn: $capture.options.cameraEnabled)
                        Toggle("Show pointer", isOn: $capture.options.showsCursor)
                    }
                    Picker("Countdown", selection: $capture.options.countdownSeconds) {
                        Text("None").tag(0)
                        Text("3 sec").tag(3)
                        Text("5 sec").tag(5)
                        Text("10 sec").tag(10)
                    }
                    .frame(maxWidth: 160)
                }
                .padding(.top, 8)
                .disabled(UIRecordingActions.hasCaptureWork(capture) || capture.phase == .choosing)
            }
            if let session = capture.cameraSession, capture.hasUnfinishedCapture {
                HStack(spacing: 12) {
                    CameraMonitorView(session: session)
                        .frame(width: 112, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel("Live camera monitor")
                    Text("Camera is active for this recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = capture.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { capture.clearError() }
                }
                .font(.callout)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .contain)
            }
            Text(UIRecordingActions.hasCaptureWork(capture)
                 ? "Keep Framelet open while recording finishes. Closing this window leaves controls in the menu bar."
                 : "Choose Source opens the native picker. It never starts recording on its own.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CameraMonitorView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let layer = view.layer as? AVCaptureVideoPreviewLayer else { return }
        if layer.session !== session { layer.session = session }
    }

    static func dismantleNSView(_ view: NSView, coordinator: ()) {
        (view.layer as? AVCaptureVideoPreviewLayer)?.session = nil
    }
}
