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
    @State private var previewScope: PreviewScope = .recording
    @State private var previewRetry = 0

    private enum PreviewScope: Hashable {
        case recording, selectedClip
    }

    private struct PlaybackRequest: Equatable {
        let project: RecordingProject
        let scope: PreviewScope
        let selectedClip: RecordingClip?
        let packageURL: URL
        let captureActive: Bool
        let retry: Int
    }

    private var captureActive: Bool { UIRecordingActions.hasCaptureWork(capture) }

    private var request: PlaybackRequest {
        PlaybackRequest(project: project, scope: previewScope,
                        selectedClip: previewScope == .selectedClip ? clip : nil,
                        packageURL: library.packageURL(for: project.id), captureActive: captureActive,
                        retry: previewRetry)
    }

    private var hasPreviewMedia: Bool {
        previewScope == .recording ? !project.clips.isEmpty : clip != nil
    }

    private var controlsDisabled: Bool {
        captureActive || !hasPreviewMedia || playback.isLoading ||
            playback.errorMessage != nil || playback.durationSeconds <= 0
    }

    var body: some View {
        let snapshot = request
        VStack(alignment: .leading, spacing: 10) {
            Picker("Preview", selection: $previewScope) {
                Text("Recording").tag(PreviewScope.recording)
                Text("Selected Clip").tag(PreviewScope.selectedClip)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Preview scope")
            .disabled(captureActive)

            GeometryReader { geometry in
                let aspect = CGFloat(project.presentation.preset.width) / CGFloat(project.presentation.preset.height)
                let width = min(geometry.size.width, geometry.size.height * aspect)
                let height = width / aspect
                let rgb = project.presentation.background.rgb
                ZStack(alignment: .topLeading) {
                    Color(red: rgb.0, green: rgb.1, blue: rgb.2)
                    if hasPreviewMedia, !captureActive, playback.errorMessage == nil {
                        if previewScope == .recording, playback.previewsRecording {
                            VideoSurface(player: playback.screenPlayer, fills: false)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                                .frame(width: width, height: height)
                        } else if previewScope == .selectedClip, !playback.previewsRecording, clip != nil {
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
                    }
                    if captureActive {
                        ContentUnavailableView("Playback paused", systemImage: "record.circle",
                                               description: Text("Finish recording to preview this edit."))
                    } else if playback.isLoading {
                        ProgressView(previewScope == .recording ? "Opening recording…" : "Opening clip…")
                            .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = playback.errorMessage {
                        ContentUnavailableView(previewScope == .recording ? "Recording unavailable" : "Clip unavailable", systemImage: "exclamationmark.triangle",
                                               description: Text(error))
                    } else if previewScope == .recording, project.clips.isEmpty {
                        ContentUnavailableView("No clips in this edit", systemImage: "play.rectangle",
                                               description: Text("Finished clips will play here in timeline order. Originals stay in the recording package."))
                    } else if previewScope == .selectedClip, clip == nil {
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
                Button(playback.isPlaying ? "Pause Playback" : previewScope == .recording ? "Play Recording" : "Play Clip",
                       systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                    guard !captureActive else { return }
                    playback.togglePlayback()
                }
                .disabled(controlsDisabled)
                Slider(value: Binding(get: { playback.positionSeconds }, set: {
                    guard !captureActive else { return }
                    playback.seek(to: $0)
                }),
                       in: 0...max(0.001, playback.durationSeconds))
                    .accessibilityLabel(previewScope == .recording ? "Recording playback position" : "Clip playback position")
                    .disabled(controlsDisabled)
                Text(UIFormatters.duration(playback.positionSeconds) + " / " + UIFormatters.duration(playback.durationSeconds))
                    .monospacedDigit().font(.caption)
            }
            if playback.errorMessage != nil {
                Button("Reload Preview", systemImage: "arrow.clockwise") {
                    guard !captureActive else { return }
                    previewRetry += 1
                }
                .disabled(captureActive)
            }
            if captureActive {
                Text("Playback is paused while a recording is active.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message = playback.cameraMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            } else if previewScope == .selectedClip, project.presentation.layout != .screenOnly,
                      let clip, project.segments.first(where: { $0.id == clip.segmentID })?.cameraPath == nil {
                Text("This clip has no camera track. Its screen content is still available.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(previewScope == .recording
                 ? "Previewing the recording in timeline order, without pauses between takes."
                 : "Previewing the selected clip. Choose Recording to play the ordered edit.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: snapshot) {
            guard !Task.isCancelled else { return }
            let suspended = snapshot.captureActive || captureActive
            playback.setSuspended(suspended)
            guard !suspended else { return }
            if snapshot.scope == .recording {
                if snapshot.project.clips.isEmpty { playback.clear() }
                else { await playback.loadRecording(project: snapshot.project, library: library) }
            } else if let selectedClip = snapshot.selectedClip {
                await playback.load(project: snapshot.project, clip: selectedClip, library: library)
            } else {
                playback.clear()
            }
        }
        .onChange(of: captureActive, initial: true) { _, value in playback.setSuspended(value) }
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
