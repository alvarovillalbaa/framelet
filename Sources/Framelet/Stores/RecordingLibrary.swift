import Foundation
import Darwin
import Observation
import FrameletCore

@MainActor @Observable
final class RecordingLibrary {
    private(set) var projects: [RecordingProject] = []
    var errorMessage: String?
    private(set) var unreadableCount = 0
    let baseURL: URL
    private let fileManager = FileManager.default
    private var activeIDs = Set<UUID>()

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Framelet/Recordings", isDirectory: true)
        refresh()
    }

    func packageURL(for id: UUID) -> URL {
        baseURL.appendingPathComponent(id.uuidString + ".framelet", isDirectory: true)
    }

    func project(id: UUID) -> RecordingProject? { projects.first { $0.id == id } }

    func refresh() {
        do {
            try ensureBase()
            let children = try fileManager.contentsOfDirectory(at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            var loaded: [RecordingProject] = []
            var unreadable = 0
            for folder in children where folder.pathExtension == "framelet" {
                do {
                    guard let id = UUID(uuidString: folder.deletingPathExtension().lastPathComponent),
                          folder.lastPathComponent == id.uuidString + ".framelet" else { throw RecordingValidationError.invalidManifest }
                    try ensurePackage(id)
                    let manifest = folder.appendingPathComponent("manifest.json")
                    try requireRegularFile(manifest)
                    let attributes = try fileManager.attributesOfItem(atPath: manifest.path)
                    guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 4_000_000 else { throw RecordingValidationError.invalidManifest }
                    var recording = try decoder().decode(RecordingProject.self, from: Data(contentsOf: manifest))
                    guard recording.id == id else { throw RecordingValidationError.invalidManifest }
                    try validateRecording(recording)
                    if !activeIDs.contains(id) && (recording.status == .recording || recording.status == .paused) {
                        recording.status = .interrupted
                        recording.lastError = "Recording was interrupted. Finished clips and original files have been retained."
                    }
                    loaded.append(recording)
                } catch { unreadable += 1 }
            }
            projects = loaded.sorted { $0.createdAt > $1.createdAt }
            unreadableCount = unreadable
            errorMessage = unreadable > 0 ? "\(unreadable) recording package(s) could not be read safely. Their original files remain in the library folder." : nil
        } catch { errorMessage = "The local library could not be opened: \(error.localizedDescription)" }
    }

    func create(options: CaptureOptions) throws -> RecordingProject {
        try ensureBase()
        guard (0...10).contains(options.countdownSeconds) else { throw RecordingValidationError.invalidManifest }
        let title = "Recording " + Date.now.formatted(date: .abbreviated, time: .shortened)
        let recording = RecordingProject(title: title, options: options)
        let folder = packageURL(for: recording.id)
        guard !fileManager.fileExists(atPath: folder.path) else { throw RecordingValidationError.invalidManifest }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: folder.appendingPathComponent("segments"), withIntermediateDirectories: false)
        try save(recording)
        return recording
    }

    func save(_ recording: RecordingProject) throws {
        try validateRecording(recording)
        try ensurePackage(recording.id)
        let manifest = packageURL(for: recording.id).appendingPathComponent("manifest.json")
        if fileManager.fileExists(atPath: manifest.path) { try requireRegularFile(manifest) }
        var updated = recording
        updated.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: manifest, options: .atomic)
        if updated.status == .recording || updated.status == .paused { activeIDs.insert(updated.id) }
        else { activeIDs.remove(updated.id) }
        if let index = projects.firstIndex(where: { $0.id == updated.id }) { projects[index] = updated }
        else { projects.insert(updated, at: 0) }
    }

    func mediaURL(projectID: UUID, path: String) throws -> URL {
        guard isSafeRecordingPath(path) else { throw RecordingValidationError.unsafePath }
        try ensurePackage(projectID)
        let folder = packageURL(for: projectID).appendingPathComponent("segments", isDirectory: true)
        try requireDirectory(folder)
        let result = packageURL(for: projectID).appendingPathComponent(path)
        try requireRegularFile(result)
        guard result.resolvingSymlinksInPath().deletingLastPathComponent() == folder.resolvingSymlinksInPath() else {
            throw RecordingValidationError.unsafePath
        }
        return result
    }

    func newMediaURL(projectID: UUID, path: String) throws -> URL {
        guard isSafeRecordingPath(path) else { throw RecordingValidationError.unsafePath }
        try ensurePackage(projectID)
        let folder = packageURL(for: projectID).appendingPathComponent("segments", isDirectory: true)
        let result = packageURL(for: projectID).appendingPathComponent(path)
        guard result.deletingLastPathComponent().resolvingSymlinksInPath() == folder.resolvingSymlinksInPath() else {
            throw RecordingValidationError.unsafePath
        }
        var info = stat()
        guard lstat(result.path, &info) != 0 else { throw CocoaError(.fileWriteFileExists) }
        guard errno == ENOENT else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return result
    }

    func rename(id: UUID, title: String) throws {
        guard !activeIDs.contains(id), var recording = project(id: id) else { throw RecordingValidationError.invalidManifest }
        recording.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try save(recording)
    }

    func moveToTrash(id: UUID) throws {
        guard !activeIDs.contains(id), project(id: id) != nil else { throw RecordingValidationError.invalidManifest }
        try ensurePackage(id)
        try fileManager.trashItem(at: packageURL(for: id), resultingItemURL: nil)
        projects.removeAll { $0.id == id }
    }

    private func ensureBase() throws {
        guard baseURL.isFileURL,
              baseURL.standardizedFileURL.path == baseURL.resolvingSymlinksInPath().path else {
            throw RecordingValidationError.unsafePath
        }
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
        try requireDirectory(baseURL)
    }

    private func ensurePackage(_ id: UUID) throws {
        try ensureBase()
        let folder = packageURL(for: id)
        try requireDirectory(folder)
        guard folder.resolvingSymlinksInPath().deletingLastPathComponent() == baseURL.resolvingSymlinksInPath() else {
            throw RecordingValidationError.unsafePath
        }
        try requireDirectory(folder.appendingPathComponent("segments", isDirectory: true))
    }

    private func requireDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw RecordingValidationError.unsafePath }
    }

    private func requireRegularFile(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw RecordingValidationError.unsafePath }
    }

    private func decoder() -> JSONDecoder {
        let result = JSONDecoder()
        result.dateDecodingStrategy = .iso8601
        return result
    }
}
