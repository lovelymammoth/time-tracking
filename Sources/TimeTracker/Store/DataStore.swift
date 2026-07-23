import Foundation
import Combine

final class DataStore: ObservableObject {
    @Published var clients: [Client] = []
    @Published var projects: [Project] = []
    @Published var entries: [TimeEntry] = []

    @Published var isRunning: Bool = false
    @Published var runningClientId: UUID?
    @Published var runningProjectId: UUID?
    @Published var runningStart: Date?

    private let fileURL: URL
    private let defaults = UserDefaults.standard

    init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimeTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        fileURL = supportDir.appendingPathComponent("data.json")
        load()
        restoreRunningTimer()
    }

    private struct PersistedData: Codable {
        var clients: [Client]
        var projects: [Project]
        var entries: [TimeEntry]
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else { return }
        clients = decoded.clients
        projects = decoded.projects
        entries = decoded.entries
    }

    func save() {
        let data = PersistedData(clients: clients, projects: projects, entries: entries)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }

    // MARK: Clients

    func addClient(name: String) {
        clients.append(Client(name: name))
        save()
    }

    func deleteClient(_ client: Client) {
        let projectIds = projects.filter { $0.clientId == client.id }.map { $0.id }
        entries.removeAll { projectIds.contains($0.projectId) || $0.clientId == client.id }
        projects.removeAll { $0.clientId == client.id }
        clients.removeAll { $0.id == client.id }
        save()
    }

    // MARK: Projects

    func addProject(name: String, clientId: UUID) {
        projects.append(Project(name: name, clientId: clientId))
        save()
    }

    func deleteProject(_ project: Project) {
        entries.removeAll { $0.projectId == project.id }
        projects.removeAll { $0.id == project.id }
        save()
    }

    func projects(for clientId: UUID) -> [Project] {
        projects.filter { $0.clientId == clientId }
    }

    // MARK: Entries

    func addEntry(_ entry: TimeEntry) {
        entries.append(entry)
        save()
    }

    func deleteEntry(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func updateEntry(_ entry: TimeEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }

    func entries(for clientId: UUID) -> [TimeEntry] {
        entries.filter { $0.clientId == clientId }.sorted { $0.startTime > $1.startTime }
    }

    // MARK: Stopwatch

    func startTimer(clientId: UUID, projectId: UUID) {
        isRunning = true
        runningClientId = clientId
        runningProjectId = projectId
        runningStart = Date()
        persistRunningTimer()
    }

    @discardableResult
    func stopTimer() -> TimeEntry? {
        guard let start = runningStart, let clientId = runningClientId, let projectId = runningProjectId else { return nil }
        let duration = Date().timeIntervalSince(start)
        let entry = TimeEntry(clientId: clientId, projectId: projectId, date: start, startTime: start, durationSeconds: duration)
        addEntry(entry)
        isRunning = false
        runningClientId = nil
        runningProjectId = nil
        runningStart = nil
        clearPersistedRunningTimer()
        return entry
    }

    func cancelTimer() {
        isRunning = false
        runningClientId = nil
        runningProjectId = nil
        runningStart = nil
        clearPersistedRunningTimer()
    }

    private func persistRunningTimer() {
        defaults.set(runningClientId?.uuidString, forKey: "running.clientId")
        defaults.set(runningProjectId?.uuidString, forKey: "running.projectId")
        defaults.set(runningStart, forKey: "running.start")
    }

    private func clearPersistedRunningTimer() {
        defaults.removeObject(forKey: "running.clientId")
        defaults.removeObject(forKey: "running.projectId")
        defaults.removeObject(forKey: "running.start")
    }

    private func restoreRunningTimer() {
        guard let clientIdStr = defaults.string(forKey: "running.clientId"),
              let clientId = UUID(uuidString: clientIdStr),
              let projectIdStr = defaults.string(forKey: "running.projectId"),
              let projectId = UUID(uuidString: projectIdStr),
              let start = defaults.object(forKey: "running.start") as? Date else { return }
        isRunning = true
        runningClientId = clientId
        runningProjectId = projectId
        runningStart = start
    }
}
