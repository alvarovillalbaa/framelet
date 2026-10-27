import FrameletCore
import SwiftUI

@MainActor
struct CanvasSettingsView: View {
    let presentation: PresentationSettings
    let disabled: Bool
    let hasCamera: Bool
    let onApply: (PresentationSettings) -> Bool
    @State private var draft: PresentationSettings

    init(presentation: PresentationSettings, disabled: Bool, hasCamera: Bool,
         onApply: @escaping (PresentationSettings) -> Bool) {
        self.presentation = presentation; self.disabled = disabled
        self.hasCamera = hasCamera; self.onApply = onApply
        _draft = State(initialValue: presentation)
    }

    var body: some View {
        DisclosureGroup("Canvas and camera layout") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 20) {
                    Picker("Canvas", selection: $draft.preset) {
                        ForEach(OutputPreset.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Layout", selection: $draft.layout) {
                        ForEach(CanvasLayout.allCases) { Text($0.title).tag($0) }
                    }
                }
                Picker("Background", selection: $draft.background) {
                    ForEach(CanvasBackground.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("Inset")
                    Slider(value: $draft.inset, in: 0...0.1, step: 0.01).accessibilityLabel("Canvas inset")
                    Text("\(Int(draft.inset * 100))%").monospacedDigit().frame(width: 40)
                }
                if draft.layout == .pictureInPicture {
                    Picker("Camera corner", selection: $draft.cameraCorner) {
                        ForEach(CameraCorner.allCases) { Text($0.title).tag($0) }
                    }
                    HStack {
                        Text("Camera size")
                        Slider(value: $draft.cameraScale, in: 0.12...0.4, step: 0.01).accessibilityLabel("Camera size")
                        Text("\(Int(draft.cameraScale * 100))%").monospacedDigit().frame(width: 40)
                    }
                }
                if draft.layout != .screenOnly {
                    Toggle("Mirror camera", isOn: $draft.cameraMirrored)
                    if !hasCamera { Text("This recording has no camera media. These layouts leave that camera area empty.").font(.caption).foregroundStyle(.secondary) }
                }
                HStack {
                    Button("Apply Canvas") { _ = onApply(draft) }
                        .disabled(draft == presentation)
                    Button("Reset Fields") { draft = presentation }
                    Text("Apply to update the preview and the next export.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)
            .disabled(disabled)
        }
    }
}
