import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var navigation: AppNavigation
    @Environment(\.openWindow) var openWindow

    @State private var selectedClientId: UUID?
    @State private var selectedProjectId: UUID?

    @State private var manualDate = Date()
    @State private var manualHours = ""
    @State private var manualMinutes = ""
    @State private var manualNotes = ""

    private var availableProjects: [Project] {
        guard let clientId = selectedClientId else { return [] }
        return store.projects(for: clientId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Tracker")
                .font(.headline)

            if store.clients.isEmpty {
                emptyState
            } else {
                Divider()
                timerSection
                Divider()
                manualEntrySection
                Divider()
                recentEntriesSection
            }

            Divider()
            footerButtons
        }
        .padding(14)
        .frame(width: 320)
        .onAppear(perform: setDefaultSelection)
        .onChange(of: store.clients) { _ in setDefaultSelection() }
        .onChange(of: selectedClientId) { _ in
            selectedProjectId = store.isRunning
                ? store.runningProjectId
                : availableProjects.first?.id
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No clients yet.")
                .foregroundStyle(.secondary)
            Button("Add a Client…") {
                showMainWindow(tab: .clients)
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Client", selection: $selectedClientId) {
                Text("Select client").tag(UUID?.none)
                ForEach(store.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }
            .disabled(store.isRunning)

            Picker("Project", selection: $selectedProjectId) {
                Text("Select project").tag(UUID?.none)
                ForEach(availableProjects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
            .disabled(store.isRunning || selectedClientId == nil)

            TextField("Task notes (optional)", text: runningNotesBinding, axis: .vertical)
                .lineLimit(2...4)

            if store.isRunning {
                HStack {
                    Button {
                        if store.isPaused {
                            store.resumeTimer()
                        } else {
                            store.pauseTimer()
                        }
                    } label: {
                        Label(
                            store.isPaused ? "Resume" : "Pause",
                            systemImage: store.isPaused ? "play.circle.fill" : "pause.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        store.stopTimer()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Button {
                    if let clientId = selectedClientId, let projectId = selectedProjectId {
                        store.startTimer(clientId: clientId, projectId: projectId)
                    }
                } label: {
                    Label("Start Timer", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedClientId == nil || selectedProjectId == nil)
            }
        }
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Entry").font(.subheadline).bold()
            DatePicker("Date", selection: $manualDate, displayedComponents: .date)
            HStack {
                TextField("Hours", text: $manualHours)
                    .frame(width: 50)
                Text("h")
                TextField("Minutes", text: $manualMinutes)
                    .frame(width: 50)
                Text("m")
                Spacer()
            }
            TextField("Notes (optional)", text: $manualNotes)
            Button {
                addManualEntry()
            } label: {
                Label("Add Entry", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedClientId == nil || selectedProjectId == nil || (manualHours.isEmpty && manualMinutes.isEmpty))
        }
    }

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent").font(.subheadline).bold()
            if store.entries.isEmpty {
                Text("No entries yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(store.entries.sorted(by: { $0.startTime > $1.startTime }).prefix(4)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(clientName(entry.clientId))
                                .font(.caption)
                                .lineLimit(1)
                            Text(projectName(entry.projectId))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formatDuration(entry.durationSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var footerButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showMainWindow(tab: .clients)
            } label: {
                Label("Clients & Projects…", systemImage: "person.2.fill")
            }
            Button {
                showMainWindow(tab: .log)
            } label: {
                Label("Time Log & Export…", systemImage: "clock.arrow.circlepath")
            }
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Time Tracker", systemImage: "power")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    private func showMainWindow(tab: MainTab) {
        navigation.selectedTab = tab
        openWindow(id: "main")
        MainWindowPresenter.bringToFront()
    }

    private func setDefaultSelection() {
        if store.isRunning {
            selectedClientId = store.runningClientId
            selectedProjectId = store.runningProjectId
            return
        }
        if selectedClientId == nil { selectedClientId = store.clients.first?.id }
        if selectedProjectId == nil { selectedProjectId = availableProjects.first?.id }
    }

    private var runningNotesBinding: Binding<String> {
        Binding(
            get: { store.runningNotes },
            set: { store.updateRunningNotes($0) }
        )
    }

    private func addManualEntry() {
        guard let clientId = selectedClientId, let projectId = selectedProjectId else { return }
        let h = Double(manualHours) ?? 0
        let m = Double(manualMinutes) ?? 0
        let duration = h * 3600 + m * 60
        guard duration > 0 else { return }
        let entry = TimeEntry(clientId: clientId, projectId: projectId, date: manualDate, startTime: manualDate, durationSeconds: duration, notes: manualNotes)
        store.addEntry(entry)
        manualHours = ""
        manualMinutes = ""
        manualNotes = ""
    }

    private func clientName(_ id: UUID) -> String {
        store.clients.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    private func projectName(_ id: UUID) -> String {
        store.projects.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}
