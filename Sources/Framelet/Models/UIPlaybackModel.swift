import AVFoundation
import Foundation
import FrameletCore
import Observation

@MainActor @Observable
final class UIPlaybackModel {
    let screenPlayer = AVPlayer()
    let cameraPlayer = AVPlayer()
    private(set) var isLoading = false
    private(set) var isPlaying = false
    private(set) var positionSeconds: Double = 0
    private(set) var durationSeconds: Double = 0
    private(set) var cameraVisible = false
    private(set) var errorMessage: String?
    private(set) var cameraMessage: String?
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sourceStart: Double = 0
    @ObservationIgnored private var cameraOrigin: Double = 0
    @ObservationIgnored private var cameraOverlapStart: Double = 0
    @ObservationIgnored private var overlap: CameraOverlap?
    @ObservationIgnored private var suspended = false

    func load(project: RecordingProject, clip: RecordingClip, library: RecordingLibrary) async {
        clear()
        let token = generation
        isLoading = true
        defer { if generation == token { isLoading = false } }
        do {
            guard let slice = try recordingTimeline(project).first(where: { $0.clipID == clip.id }) else {
                throw UIEditError.missingClip
            }
            let url = try library.mediaURL(projectID: project.id, path: slice.segment.screenPath)
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw RecordingValidationError.invalidTiming
            }
            let videoRange = try await videoTrack.load(.timeRange)
            let actualDuration = CMTimeGetSeconds(videoRange.duration)
            let screenOrigin = CMTimeGetSeconds(videoRange.start)
            guard playable, actualDuration.isFinite, actualDuration > 0, screenOrigin.isFinite,
                  clip.trimEndSeconds <= actualDuration + 1.0 / 600.0 else {
                throw RecordingValidationError.invalidTiming
            }
            guard generation == token, !Task.isCancelled else { return }
            sourceStart = screenOrigin + clip.trimStartSeconds
            durationSeconds = clip.durationSeconds
            let item = AVPlayerItem(asset: asset)
            item.forwardPlaybackEndTime = CMTime(seconds: screenOrigin + min(actualDuration, clip.trimEndSeconds),
                                                preferredTimescale: 600)
            screenPlayer.replaceCurrentItem(with: item)
            screenPlayer.actionAtItemEnd = .pause
            screenPlayer.seek(to: CMTime(seconds: sourceStart, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
            observer = screenPlayer.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main
            ) { [weak self] time in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    let sourceTime = CMTimeGetSeconds(time)
                    guard sourceTime.isFinite else { return }
                    self.positionSeconds = min(self.durationSeconds, max(0, sourceTime - self.sourceStart))
                    if self.positionSeconds >= self.durationSeconds - 0.02 {
                        self.isPlaying = false
                        self.cameraPlayer.pause()
                    }
                    self.synchronizeCamera(force: false)
                }
            }
            failureObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    self.pause()
                    self.errorMessage = "This clip could not be played. Its original files have been retained."
                }
            }
            if let path = slice.segment.cameraPath {
                do {
                    let cameraURL = try library.mediaURL(projectID: project.id, path: path)
                    let asset = AVURLAsset(url: cameraURL)
                    let cameraPlayable = try await asset.load(.isPlayable)
                    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                        throw RecordingValidationError.invalidTiming
                    }
                    let cameraRange = try await videoTrack.load(.timeRange)
                    let cameraDuration = CMTimeGetSeconds(cameraRange.duration)
                    let origin = CMTimeGetSeconds(cameraRange.start)
                    guard cameraPlayable, origin.isFinite else { throw RecordingValidationError.invalidTiming }
                    let visible = try cameraOverlap(slice: slice, cameraDurationSeconds: cameraDuration)
                    guard generation == token, !Task.isCancelled else { return }
                    cameraPlayer.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                    cameraPlayer.isMuted = true
                    cameraOrigin = origin
                    overlap = visible
                    cameraOverlapStart = (visible?.timelineStartSeconds ?? 0) - slice.timelineStartSeconds
                    synchronizeCamera(force: true)
                } catch {
                    guard generation == token, !Task.isCancelled else { return }
                    cameraMessage = "Camera playback is unavailable for this clip. Original files are retained."
                }
            }
        } catch {
            if generation == token, !Task.isCancelled {
                errorMessage = "This clip could not be opened: " + error.localizedDescription
            }
        }
    }

    func togglePlayback() {
        if isPlaying { pause(); return }
        guard !suspended, !isLoading, errorMessage == nil, screenPlayer.currentItem != nil else { return }
        if positionSeconds >= durationSeconds - 0.02 {
            seek(to: 0)
        }
        isPlaying = true
        screenPlayer.play()
        synchronizeCamera(force: true)
    }

    func pause() {
        isPlaying = false
        screenPlayer.pause()
        cameraPlayer.pause()
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        if value { pause() }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite, screenPlayer.currentItem != nil else { return }
        positionSeconds = min(durationSeconds, max(0, seconds))
        screenPlayer.seek(to: CMTime(seconds: sourceStart + positionSeconds, preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero)
        synchronizeCamera(force: true)
    }

    func clear() {
        generation += 1
        pause()
        if let observer { screenPlayer.removeTimeObserver(observer) }
        observer = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        screenPlayer.replaceCurrentItem(with: nil)
        cameraPlayer.replaceCurrentItem(with: nil)
        overlap = nil
        cameraOrigin = 0
        cameraVisible = false
        isLoading = false
        durationSeconds = 0
        positionSeconds = 0
        errorMessage = nil
        cameraMessage = nil
    }

    private func synchronizeCamera(force: Bool) {
        guard let overlap, cameraPlayer.currentItem != nil,
              positionSeconds >= cameraOverlapStart,
              positionSeconds < cameraOverlapStart + overlap.durationSeconds else {
            cameraVisible = false
            cameraPlayer.pause()
            return
        }
        let wasVisible = cameraVisible
        cameraVisible = true
        let desired = cameraOrigin + overlap.sourceStartSeconds + positionSeconds - cameraOverlapStart
        let current = CMTimeGetSeconds(cameraPlayer.currentTime())
        if force || !wasVisible || !current.isFinite || abs(current - desired) > 0.15 {
            cameraPlayer.seek(to: CMTime(seconds: desired, preferredTimescale: 600),
                              toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if isPlaying && !suspended { cameraPlayer.play() }
        else { cameraPlayer.pause() }
    }
}
