import AppKit
import FrameletCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RecordingDetailView: View {
    let project: RecordingProject
    let library: RecordingLibrary
    let capture: CaptureCoordinator
    let exporter: ExportCoordinator
    @State private var selectedClipID: UUID?
    @State private var editError: String?
    @State private var showRename = false
    @State private var showTrashConfirmation = false

    private var selectedClip: RecordingClip? { project.clips.first { $0.id == selectedClipID } }
    private var isCaptureLocked: Bool {
        UIRecordingActions.hasCaptureWork(capture) &&
            (capture.projectID == nil || capture.projectID == project.id ||
             [.countdown, .starting, .pausing, .stopping].contains(capture.phase))
    }
    private var isLocked: Bool { isCaptureLocked || exporter.isExporting }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.title).font(.title2.bold()).textSelection(.enabled)
                        Text(project.createdAt.formatted(date: .abbreviated, time: .shortened) + " · " +
                             UIFormatters.duration(project.durationSeconds) + " · " + UIFormatters.status(project.status))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Rename…", systemImage: "pencil") { showRename = true }.disabled(isLocked)
                        Button("Reveal in Finder", systemImage: "folder") { revealPackage() }
                        Divider()
                        Button("Move Recording to Trash…", systemImage: "trash", role: .destructive) {
                            showTrashConfirmation = true
                        }
                        .disabled(isLocked)
                    } label: { Label("Recording Actions", systemImage: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                if isCaptureLocked {
                    Label("Finish this recording before editing or exporting it.", systemImage: "record.circle")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let message = project.lastError {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(message).textSelection(.enabled)
                        Spacer()
                        Button("Reveal Originals") { revealPackage() }
                    }
                    .font(.callout).padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                PlaybackCanvasView(project: project, clip: selectedClip, library: library, capture: capture)
                ClipListEditor(project: project, selection: $selectedClipID, disabled: isLocked) { mutation in
                    applyEdit(mutation)
                }
                CanvasSettingsView(presentation: project.presentation, disabled: isLocked,
                                   hasCamera: project.segments.contains { $0.cameraPath != nil }) { presentation in
                    applyEdit { $0.presentation = presentation }
                }
                if let error = editError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export a new MP4").font(.headline)
                        Text("Joins the current ordered clips with the saved canvas settings. Originals are kept.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export…", systemImage: "square.and.arrow.up") { chooseExportDestination() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLocked || project.clips.isEmpty || project.status == .recording || project.status == .paused)
                }
                ExportStatusView(exporter: exporter)
            }
            .padding(24)
        }
        .onAppear { selectedClipID = project.clips.first?.id }
        .onChange(of: project.clips.map(\.id)) { _, ids in
            if selectedClipID == nil || !ids.contains(selectedClipID!) { selectedClipID = ids.first }
        }
        .sheet(isPresented: $showRename) {
            RenameRecordingView(title: project.title) { title in
                guard !isLocked else { throw UIEditError.busy }
                try library.rename(id: project.id, title: title)
            }
        }
        .confirmationDialog("Move this recording to Trash?", isPresented: $showTrashConfirmation, titleVisibility: .visible) {
            Button("Move Recording to Trash", role: .destructive) {
                do {
                    guard !isLocked else { throw UIEditError.busy }
                    try library.moveToTrash(id: project.id)
                } catch { editError = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(project.title)” and all of its original screen and camera media will move to Trash. Removing a clip in the editor only removes it from the edit.")
        }
    }

    @discardableResult
    private func applyEdit(_ mutation: (inout RecordingProject) throws -> Void) -> Bool {
        do {
            guard !isLocked else { throw UIEditError.busy }
            guard var latest = library.project(id: project.id) else { throw UIEditError.changedRecording }
            try mutation(&latest)
            try validateRecording(latest)
            try library.save(latest)
            editError = nil
            return true
        } catch {
            editError = error.localizedDescription
            return false
        }
    }

    private func revealPackage() {
        NSWorkspace.shared.activateFileViewerSelecting([library.packageURL(for: project.id)])
    }

    private func chooseExportDestination() {
        guard !isLocked, !project.clips.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export Recording"
        panel.message = "Choose a new MP4 filename. Existing files are never replaced."
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = UIFormatters.exportName(project.title)
        panel.begin { response in
            Task { @MainActor in
                guard response == .OK, let destination = panel.url else { return }
                do {
                    guard !isLocked else { throw UIEditError.busy }
                    guard let latest = library.project(id: project.id) else { throw UIEditError.changedRecording }
                    guard !FileManager.default.fileExists(atPath: destination.path) else {
                        editError = "Choose a new filename. An existing file will not be replaced."
                        return
                    }
                    try validateRecording(latest)
                    await exporter.export(project: latest, packageURL: library.packageURL(for: latest.id),
                                          destinationURL: destination)
                } catch { editError = error.localizedDescription }
            }
        }
    }
}

@MainActor
private struct RenameRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var error: String?
    let onSave: (String) throws -> Void

    init(title: String, onSave: @escaping (String) throws -> Void) {
        _title = State(initialValue: title)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename recording").font(.headline)
            TextField("Recording title", text: $title)
                .onSubmit { save() }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 200 else {
            error = "Enter a title between 1 and 200 characters."
            return
        }
        do { try onSave(title); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor
private struct ExportStatusView: View {
    let exporter: ExportCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exporter.isExporting {
                HStack {
                    ProgressView(value: exporter.progress.isFinite ? min(1, max(0, exporter.progress)) : 0)
                    Button("Cancel Export") { exporter.cancel() }
                }
                Text("Keep Framelet open while this export finishes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = exporter.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
            if let output = exporter.outputURL, !exporter.isExporting {
                HStack {
                    Label("Most recent export: " + output.lastPathComponent, systemImage: "checkmark.circle")
                        .font(.callout).lineLimit(2)
                    Spacer()
                    Button("Reveal Export") { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                }
            }
        }
    }
}
