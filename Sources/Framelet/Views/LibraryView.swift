import AppKit
import FrameletCore
import SwiftUI

@MainActor
struct LibraryView: View {
    let library: RecordingLibrary
    let capture: CaptureCoordinator
    let exporter: ExportCoordinator
    @State private var selection: UUID?
    @State private var search = ""

    private var visibleProjects: [RecordingProject] {
        library.projects.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(visibleProjects) { project in
                    HStack(spacing: 10) {
                        Image(systemName: project.status == .ready ? "film" : "record.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title).lineLimit(1)
                            Text(UIFormatters.duration(project.durationSeconds) + " · " + UIFormatters.status(project.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(project.id)
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $search, prompt: "Find a recording")
            .navigationTitle("Framelet")
            .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 340)
            .overlay {
                if visibleProjects.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "Your local library" : "No matching recordings",
                        systemImage: search.isEmpty ? "film.stack" : "magnifyingglass",
                        description: Text(search.isEmpty ? "Choose a source and start your first recording." : "Try a different recording title.")
                    )
                    .padding()
                    .allowsHitTesting(false)
                }
            }
        } detail: {
            VStack(spacing: 0) {
                CapturePanel(capture: capture)
                    .padding()
                Divider()
                if let id = selection, let project = library.project(id: id) {
                    RecordingDetailView(project: project, library: library, capture: capture, exporter: exporter)
                        .id(project.id)
                } else {
                    ContentUnavailableView(
                        "Make room for your next idea.",
                        systemImage: "rectangle.inset.filled.and.person.filled",
                        description: Text("Choose a display or window above. Recording begins only when you press Start.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let error = library.errorMessage {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error).textSelection(.enabled)
                        Spacer()
                        Button("Show Library Folder") { NSWorkspace.shared.open(library.baseURL) }
                    }
                    .font(.callout)
                    .padding()
                    .background(.quaternary)
                }
            }
            .navigationTitle(selection.flatMap { library.project(id: $0)?.title } ?? "Library")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        library.refresh()
                    } label: { Label("Refresh Library", systemImage: "arrow.clockwise") }
                    .help("Read the local recording library again")
                    Button {
                        NSWorkspace.shared.open(library.baseURL)
                    } label: { Label("Show Library Folder", systemImage: "folder") }
                }
            }
        }
        .onAppear {
            if selection == nil { selection = library.projects.first?.id }
        }
        .onChange(of: capture.projectID) { _, id in
            if let id { selection = id }
        }
        .onChange(of: library.projects.map(\.id)) { _, ids in
            if let selected = selection, !ids.contains(selected) { selection = ids.first }
        }
    }
}
