import AVFoundation
import Darwin
import Foundation
import FrameletCore
import Observation

@MainActor @Observable
final class ExportCoordinator {
    private(set) var isExporting = false
    private(set) var progress = 0.0
    private(set) var errorMessage: String?
    private(set) var outputURL: URL?
    @ObservationIgnored private var operation: Task<URL, Error>?

    func export(project: RecordingProject, packageURL: URL, destinationURL: URL) async {
        guard !isExporting else { return }
        isExporting = true
        progress = 0
        errorMessage = nil
        outputURL = nil
        let task = Task { @MainActor in
            try await self.performExport(project: project, packageURL: packageURL, destinationURL: destinationURL)
        }
        operation = task
        defer { operation = nil; isExporting = false }
        do {
            outputURL = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            progress = 1
        } catch is CancellationError {
            progress = 0
            errorMessage = "Export cancelled. Your source recordings have been retained."
        } catch {
            progress = 0
            errorMessage = error.localizedDescription
        }
    }

    func cancel() { operation?.cancel() }

    private func performExport(project: RecordingProject, packageURL: URL, destinationURL: URL) async throws -> URL {
        guard project.status != .recording, project.status != .paused else { throw ExportFailure.activeRecording }
        let slices = try recordingTimeline(project)
        let duration = CMTime(seconds: project.durationSeconds, preferredTimescale: 600_000)
        guard project.durationSeconds.isFinite, duration.isNumeric, CMTimeCompare(duration, .zero) > 0,
              slices.allSatisfy({ $0.timelineStartSeconds.isFinite }) else { throw RecordingValidationError.invalidTiming }
        let package = try ExportPaths.directory(packageURL)
        guard package.pathExtension == "framelet" else { throw RecordingValidationError.unsafePath }
        let destination = destinationURL.standardizedFileURL
        guard destination.isFileURL, destination.pathExtension.lowercased() == "mp4",
              !ExportPaths.contains(destination, in: package) else { throw ExportFailure.unsafeDestination }
        try Task.checkCancellation()
        let staging = try ExportStaging(destination: destination)
        defer { staging.cleanUp() }

        let recording = try await RecordingCompositionBuilder.build(project: project, packageURL: package) { value in
            progress = value * 0.1
        }
        defer { withExtendedLifetime(recording) {} }
        guard let exporter = AVAssetExportSession(asset: recording.asset, presetName: AVAssetExportPresetHighestQuality),
              exporter.supportedFileTypes.contains(.mp4) else { throw ExportFailure.unsupportedExport }
        exporter.videoComposition = recording.videoComposition
        exporter.timeRange = CMTimeRange(start: .zero, duration: recording.duration)
        exporter.shouldOptimizeForNetworkUse = false
        if let mix = recording.audioMix { exporter.audioMix = mix }
        try staging.validateIdentity()
        let monitor = Task { @MainActor [weak self] in
            for await state in exporter.states(updateInterval: 0.2) {
                if Task.isCancelled { break }
                if case .exporting(let value) = state {
                    self?.progress = 0.1 + 0.89 * min(1, max(0, value.fractionCompleted))
                }
            }
        }
        defer { monitor.cancel() }
        try Task.checkCancellation()
        try await exporter.export(to: staging.output, as: .mp4)
        try Task.checkCancellation()
        try staging.commit()
        return destination
    }

}

enum ExportFailure: LocalizedError {
    case activeRecording, invalidMedia, invalidTrim, unsupportedOrientation, composition
    case unsafeDestination, destinationExists, unsupportedExport, changedPath
    var errorDescription: String? {
        switch self {
        case .activeRecording: "Stop recording before exporting this project."
        case .invalidMedia: "A recording file is missing a readable video or has invalid media timing. Originals have been retained."
        case .invalidTrim: "A clip extends beyond its actual media. Adjust its trim before exporting."
        case .unsupportedOrientation: "A source has an unsupported video orientation. Its original file has been retained."
        case .composition: "The recording tracks could not be assembled for export."
        case .unsafeDestination: "Choose a new MP4 outside the recording package in a folder without symbolic links."
        case .destinationExists: "A file already exists at this destination. Choose a new export name."
        case .unsupportedExport: "This recording cannot be exported as MP4 with the available media encoder."
        case .changedPath: "An export folder or source path changed. Choose the destination again."
        }
    }
}

enum ExportPaths {
    static func contains(_ child: URL, in parent: URL) -> Bool {
        child.path == parent.path || child.path.hasPrefix(parent.path + "/")
    }

    static func directory(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw RecordingValidationError.unsafePath }
        let clean = url.standardizedFileURL
        guard clean.path == clean.resolvingSymlinksInPath().path else { throw RecordingValidationError.unsafePath }
        let values = try clean.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw RecordingValidationError.unsafePath }
        return clean
    }

    static func media(_ path: String, package: URL) throws -> URL {
        guard isSafeRecordingPath(path) else { throw RecordingValidationError.unsafePath }
        let url = package.appendingPathComponent(path).standardizedFileURL
        guard contains(url, in: package), url.path == url.resolvingSymlinksInPath().path else {
            throw RecordingValidationError.unsafePath
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isReadableKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.isReadable == true else { throw ExportFailure.invalidMedia }
        return url
    }
}

/// Private staging directory on the destination volume; the final rename is
/// atomic and exclusive even if another process creates the destination meanwhile.
private final class ExportStaging {
    private let parent: URL
    private let parentFD: Int32
    private let directoryFD: Int32
    private let directoryName: String
    private let destinationName: String
    private let directory: URL
    let output: URL

    init(destination: URL) throws {
        parent = try ExportPaths.directory(destination.deletingLastPathComponent())
        destinationName = destination.lastPathComponent
        directoryName = ".framelet-export-" + UUID().uuidString
        directory = parent.appendingPathComponent(directoryName, isDirectory: true)
        output = directory.appendingPathComponent("output.mp4")
        let parentDescriptor = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard parentDescriptor >= 0 else { throw Self.posixError() }
        var existing = stat()
        if fstatat(parentDescriptor, destinationName, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
            close(parentDescriptor); throw ExportFailure.destinationExists
        }
        guard errno == ENOENT else { let error = Self.posixError(); close(parentDescriptor); throw error }
        guard mkdirat(parentDescriptor, directoryName, 0o700) == 0 else {
            let error = Self.posixError(); close(parentDescriptor); throw error
        }
        let descriptor = openat(parentDescriptor, directoryName, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            let error = Self.posixError()
            unlinkat(parentDescriptor, directoryName, AT_REMOVEDIR); close(parentDescriptor)
            throw error
        }
        parentFD = parentDescriptor
        directoryFD = descriptor
    }

    deinit { close(directoryFD); close(parentFD) }

    func validateIdentity() throws {
        _ = try ExportPaths.directory(parent)
        _ = try ExportPaths.directory(directory)
        var parentInfo = stat(); var pathInfo = stat()
        guard fstat(parentFD, &parentInfo) == 0, lstat(parent.path, &pathInfo) == 0,
              parentInfo.st_dev == pathInfo.st_dev, parentInfo.st_ino == pathInfo.st_ino,
              fstat(directoryFD, &parentInfo) == 0, lstat(directory.path, &pathInfo) == 0,
              parentInfo.st_dev == pathInfo.st_dev, parentInfo.st_ino == pathInfo.st_ino else { throw ExportFailure.changedPath }
    }

    func commit() throws {
        try validateIdentity()
        var info = stat()
        guard fstatat(directoryFD, "output.mp4", &info, AT_SYMLINK_NOFOLLOW) == 0,
              (info.st_mode & S_IFMT) == S_IFREG, info.st_size > 0 else { throw ExportFailure.invalidMedia }
        if renameatx_np(directoryFD, "output.mp4", parentFD, destinationName, UInt32(RENAME_EXCL)) != 0 {
            if errno == EEXIST { throw ExportFailure.destinationExists }
            throw Self.posixError()
        }
    }

    func cleanUp() {
        // Never recursively remove a folder or touch the final destination.
        unlinkat(directoryFD, "output.mp4", 0)
        unlinkat(parentFD, directoryName, AT_REMOVEDIR)
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey:
            "The export file could not be written (\(String(cString: strerror(errno)))). Your source recordings have been retained."])
    }
}
