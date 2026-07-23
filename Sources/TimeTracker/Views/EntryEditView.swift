import SwiftUI

struct EntryEditView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let original: TimeEntry
    var onSave: (TimeEntry) -> Void

    @State private var clientId: UUID
    @State private var projectId: UUID
    @State private var date: Date
    @State private var startTime: Date
    @State private var hours: String
    @State private var minutes: String
    @State private var notes: String

    init(entry: TimeEntry, onSave: @escaping (TimeEntry) -> Void) {
        self.original = entry
        self.onSave = onSave
        _clientId = State(initialValue: entry.clientId)
        _projectId = State(initialValue: entry.projectId)
        _date = State(initialValue: entry.date)
        _startTime = State(initialValue: entry.startTime)
        let totalMinutes = Int(entry.durationSeconds / 60)
        _hours = State(initialValue: String(totalMinutes / 60))
        _minutes = State(initialValue: String(totalMinutes % 60))
        _notes = State(initialValue: entry.notes)
    }

    private var availableProjects: [Project] {
        store.projects(for: clientId)
    }

    private var isValid: Bool {
        let h = Double(hours) ?? 0
        let m = Double(minutes) ?? 0
        return (h * 3600 + m * 60) > 0 && availableProjects.contains(where: { $0.id == projectId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Edit Entry")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 18) {
                fieldRow("Client") {
                    Picker("", selection: $clientId) {
                        ForEach(store.clients) { client in
                            Text(client.name).tag(client.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: clientId) { newValue in
                        if let first = store.projects(for: newValue).first {
                            projectId = first.id
                        }
                    }
                }

                fieldRow("Project") {
                    Picker("", selection: $projectId) {
                        ForEach(availableProjects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .labelsHidden()
                }

                fieldRow("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                fieldRow("Start Time") {
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }

                fieldRow("Duration") {
                    HStack(spacing: 10) {
                        TextField("0", text: $hours)
                            .frame(width: 70)
                        Text("hours")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $minutes)
                            .frame(width: 70)
                        Text("minutes")
                            .foregroundStyle(.secondary)
                    }
                }

                fieldRow("Notes") {
                    TextField("", text: $notes)
                }
            }
            .font(.system(size: 16))
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .controlSize(.large)
                Button("Save") {
                    let h = Double(hours) ?? 0
                    let m = Double(minutes) ?? 0
                    var updated = original
                    updated.clientId = clientId
                    updated.projectId = projectId
                    updated.date = date
                    updated.startTime = startTime
                    updated.durationSeconds = h * 3600 + m * 60
                    updated.notes = notes
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!isValid)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
