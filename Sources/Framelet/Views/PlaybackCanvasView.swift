import AppKit
import AVKit
import FrameletCore
import SwiftUI

@MainActor
struct PlaybackCanvasView: View {
    let project: RecordingProject
    let clip: RecordingClip?
    let library: RecordingLibrary
    let capture: CaptureCoordinator
    @State private var playback = UIPlaybackModel()

    private var loadKey: String {
        guard let clip else { return "empty" }
        return "\(project.id)-\(clip.id)-\(clip.trimStartSeconds)-\(clip.trimEndSeconds)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let aspect = CGFloat(project.presentation.preset.width) / CGFloat(project.presentation.preset.height)
                let width = min(geometry.size.width, geometry.size.height * aspect)
                let height = width / aspect
                let rgb = project.presentation.background.rgb
                ZStack(alignment: .topLeading) {
                    Color(red: rgb.0, green: rgb.1, blue: rgb.2)
                    if clip != nil, playback.errorMessage == nil {
                        VideoSurface(player: playback.screenPlayer, fills: false)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .frame(width: width * CGFloat(project.presentation.screenRect.width),
                                   height: height * CGFloat(project.presentation.screenRect.height))
                            .offset(x: width * CGFloat(project.presentation.screenRect.x),
                                    y: height * CGFloat(project.presentation.screenRect.y))
                        if let rect = project.presentation.cameraRect, playback.cameraVisible {
                            VideoSurface(player: playback.cameraPlayer, fills: true)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                                .scaleEffect(x: project.presentation.cameraMirrored ? -1 : 1, y: 1)
                                .frame(width: width * CGFloat(rect.width), height: height * CGFloat(rect.height))
                                .clipped()
                                .offset(x: width * CGFloat(rect.x), y: height * CGFloat(rect.y))
                        }
                    }
                    if playback.isLoading {
                        ProgressView("Opening clip…").padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = playback.errorMessage {
                        ContentUnavailableView("Clip unavailable", systemImage: "exclamationmark.triangle",
                                               description: Text(error))
                    } else if clip == nil {
                        ContentUnavailableView("Select a clip", systemImage: "play.rectangle",
                                               description: Text("Finished clips are available below. Originals stay in the recording package."))
                    }
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 200, idealHeight: 320, maxHeight: 410)
            HStack(spacing: 12) {
                Button(playback.isPlaying ? "Pause Playback" : "Play Clip",
                       systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                    playback.togglePlayback()
                }
                .disabled(clip == nil || playback.isLoading || playback.errorMessage != nil || UIRecordingActions.hasCaptureWork(capture))
                Slider(value: Binding(get: { playback.positionSeconds }, set: { playback.seek(to: $0) }),
                       in: 0...max(0.001, playback.durationSeconds))
                    .accessibilityLabel("Clip playback position")
                    .disabled(clip == nil || playback.isLoading || playback.errorMessage != nil || UIRecordingActions.hasCaptureWork(capture))
                Text(UIFormatters.duration(playback.positionSeconds) + " / " + UIFormatters.duration(playback.durationSeconds))
                    .monospacedDigit().font(.caption)
            }
            if UIRecordingActions.hasCaptureWork(capture) {
                Text("Playback is paused while a recording is active.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message = playback.cameraMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            } else if project.presentation.layout != .screenOnly,
                      let clip, project.segments.first(where: { $0.id == clip.segmentID })?.cameraPath == nil {
                Text("This clip has no camera track. Its screen content is still available.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Previewing the selected clip. Export joins the ordered clips below.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: loadKey) {
            if let clip { await playback.load(project: project, clip: clip, library: library) }
            else { playback.clear() }
        }
        .onChange(of: UIRecordingActions.hasCaptureWork(capture), initial: true) { _, value in playback.setSuspended(value) }
        .onDisappear { playback.clear() }
    }
}

@MainActor
private struct VideoSurface: NSViewRepresentable {
    let player: AVPlayer
    let fills: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let view = PassivePlayerView()
        view.controlsStyle = .none
        view.player = player
        view.videoGravity = fills ? .resizeAspectFill : .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
        view.videoGravity = fills ? .resizeAspectFill : .resizeAspect
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player = nil
    }

    final class PassivePlayerView: AVPlayerView {
        override var acceptsFirstResponder: Bool { false }
    }
}
