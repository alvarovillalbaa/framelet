import FrameletCore
import SwiftUI

@MainActor
struct ClipListEditor: View {
    let project: RecordingProject
    @Binding var selection: UUID?
    let disabled: Bool
    let onEdit: ((inout RecordingProject) throws -> Void) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clips").font(.headline)
                Text("\(project.clips.count) · " + UIFormatters.duration(project.durationSeconds))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Menu("Add Original Segment") {
                    ForEach(Array(project.segments.enumerated()), id: \.element.id) { index, segment in
                        Button("Segment \(index + 1) · " + UIFormatters.duration(segment.durationSeconds)) {
                            let clip = RecordingClip(segmentID: segment.id, trimEndSeconds: segment.durationSeconds)
                            if onEdit({ $0.clips.append(clip) }) { selection = clip.id }
                        }
                    }
                }
                .disabled(disabled || project.segments.isEmpty || project.clips.count >= 1000)
            }
            if project.clips.isEmpty {
                Text(project.segments.isEmpty
                     ? "Finished recording segments will appear here after Pause or Stop."
                     : "No clips in this edit. Add an original segment to restore it without changing its source file.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(project.clips.enumerated()), id: \.element.id) { index, clip in
                HStack(spacing: 10) {
                    Button {
                        selection = clip.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selection == clip.id ? "play.rectangle.fill" : "play.rectangle")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Clip \(index + 1)").fontWeight(.medium)
                                Text(UIFormatters.trimTime(clip.trimStartSeconds) + "–" +
                                     UIFormatters.trimTime(clip.trimEndSeconds) + " sec · " +
                                     UIFormatters.duration(clip.durationSeconds))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select clip \(index + 1)")
                    .accessibilityAddTraits(selection == clip.id ? .isSelected : [])
                    Button { move(clip.id, delta: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(disabled || index == 0).help("Move clip earlier")
                        .accessibilityLabel("Move clip \(index + 1) earlier")
                    Button { move(clip.id, delta: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(disabled || index == project.clips.count - 1).help("Move clip later")
                        .accessibilityLabel("Move clip \(index + 1) later")
                    Button { duplicate(clip) } label: { Image(systemName: "plus.square.on.square") }
                        .disabled(disabled || project.clips.count >= 1000).help("Duplicate clip")
                        .accessibilityLabel("Duplicate clip \(index + 1)")
                    Button {
                        _ = onEdit { $0.clips.removeAll { $0.id == clip.id } }
                    } label: { Image(systemName: "minus.circle") }
                        .disabled(disabled).help("Remove clip from edit; keep original")
                        .accessibilityLabel("Remove clip \(index + 1) from edit")
                }
                .padding(10)
                .background(selection == clip.id ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8))
            }
            if let clip = project.clips.first(where: { $0.id == selection }),
               let segment = project.segments.first(where: { $0.id == clip.segmentID }) {
                ClipTrimEditor(clip: clip, sourceDuration: segment.durationSeconds, disabled: disabled) { start, end in
                    onEdit { latest in
                        guard let index = latest.clips.firstIndex(where: { $0.id == clip.id }) else { throw UIEditError.missingClip }
                        latest.clips[index].trimStartSeconds = start
                        latest.clips[index].trimEndSeconds = end
                    }
                }
                .id(clip.id)
            }
            Text("Clips play and export in this order. Trimming, duplicating and removing clips never delete original media.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func move(_ id: UUID, delta: Int) {
        _ = onEdit { latest in
            guard let index = latest.clips.firstIndex(where: { $0.id == id }) else { throw UIEditError.missingClip }
            let destination = index + delta
            guard latest.clips.indices.contains(destination) else { return }
            latest.clips.swapAt(index, destination)
        }
    }

    private func duplicate(_ clip: RecordingClip) {
        let duplicate = RecordingClip(segmentID: clip.segmentID, trimStartSeconds: clip.trimStartSeconds,
                                      trimEndSeconds: clip.trimEndSeconds)
        if onEdit({ latest in
            guard let index = latest.clips.firstIndex(where: { $0.id == clip.id }) else { throw UIEditError.missingClip }
            latest.clips.insert(duplicate, at: index + 1)
        }) { selection = duplicate.id }
    }
}

@MainActor
private struct ClipTrimEditor: View {
    let clip: RecordingClip
    let sourceDuration: Double
    let disabled: Bool
    let onApply: (Double, Double) -> Bool
    @State private var start: String
    @State private var end: String

    init(clip: RecordingClip, sourceDuration: Double, disabled: Bool,
         onApply: @escaping (Double, Double) -> Bool) {
        self.clip = clip; self.sourceDuration = sourceDuration; self.disabled = disabled; self.onApply = onApply
        _start = State(initialValue: UIFormatters.editableSeconds(clip.trimStartSeconds))
        _end = State(initialValue: UIFormatters.editableSeconds(clip.trimEndSeconds))
    }

    private var validRange: (Double, Double)? {
        guard let start = Double(start), let end = Double(end), start.isFinite, end.isFinite,
              start >= 0, end > start, end <= sourceDuration else { return nil }
        return (start, end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Start (seconds)").font(.caption)
                    TextField("Start (seconds)", text: $start).labelsHidden().frame(width: 100)
                }
                VStack(alignment: .leading) {
                    Text("End (seconds)").font(.caption)
                    TextField("End (seconds)", text: $end).labelsHidden().frame(width: 100)
                }
                Button("Apply Trim") {
                    if let range = validRange { _ = onApply(range.0, range.1) }
                }
                .disabled(disabled || validRange == nil)
                Button("Reset Fields") {
                    start = UIFormatters.editableSeconds(clip.trimStartSeconds)
                    end = UIFormatters.editableSeconds(clip.trimEndSeconds)
                }
            }
            .disabled(disabled)
            Text("Use a decimal point. Choose a start before the end, within 0–" + UIFormatters.trimTime(sourceDuration) + " seconds.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
