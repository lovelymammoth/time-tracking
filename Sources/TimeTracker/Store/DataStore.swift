import Foundation
import Combine
import AppKit

final class DataStore: ObservableObject {
    enum ExistingDatabaseChoice {
        case useExisting
        case replaceWithCurrent
    }

    static let syncedDatabaseFilename = "TimeTracker-data.json"

    @Published var clients: [Client] = []
    @Published var projects: [Project] = []
    @Published var entries: [TimeEntry] = []

    @Published var isRunning: Bool = false
    @Published var runningClientId: UUID?
    @Published var runningProjectId: UUID?
    @Published var runningStart: Date?

    @Published private(set) var databaseURL: URL
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var storageErrorMessage: String?

    private struct PersistedData: Codable {
        var clients: [Client]
        var projects: [Project]
        var entries: [TimeEntry]
    }

    private static let storageBookmarkKey = "storage.directoryBookmark"

    private let localDatabaseURL: URL
    private let defaults: UserDefaults
    private var securityScopedDirectoryURL: URL?
    private var activationCancellable: AnyCancellable?

    var isUsingCustomStorage: Bool {
        databaseURL.standardizedFileURL != localDatabaseURL.standardizedFileURL
    }

    var storageDirectoryURL: URL {
        databaseURL.deletingLastPathComponent()
    }

    init(defaults: UserDefaults = .standard, applicationSupportDirectory: URL? = nil) {
        self.defaults = defaults

        let supportDir = (applicationSupportDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("TimeTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let localURL = supportDir.appendingPathComponent("data.json")
        localDatabaseURL = localURL
        databaseURL = localURL

        restoreStorageLocation()
        load()
        restoreRunningTimer()

        activationCancellable = NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )
        .sink { [weak self] _ in
            self?.reloadFromDisk()
        }
    }

    deinit {
        securityScopedDirectoryURL?.stopAccessingSecurityScopedResource()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }

        do {
            let decoded = try readPersistedData(from: databaseURL)
            apply(decoded)
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = "Could not read the database: \(error.localizedDescription)"
        }
    }

    func reloadFromDisk() {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return }
        load()
    }

    func save() {
        do {
            try writeCurrentData(to: databaseURL)
            lastSavedAt = Date()
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = "Could not save the database: \(error.localizedDescription)"
        }
    }

    func connectStorage(
        to directoryURL: URL,
        existingDatabaseChoice: ExistingDatabaseChoice
    ) throws {
        let destinationURL = directoryURL.appendingPathComponent(Self.syncedDatabaseFilename)
        let bookmark = try directoryURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let startedAccessing = directoryURL.startAccessingSecurityScopedResource()
        var shouldStopNewAccess = startedAccessing

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path),
               existingDatabaseChoice == .useExisting {
                let existingData = try readPersistedData(from: destinationURL)
                apply(existingData)
            } else {
                try writeCurrentData(to: destinationURL)
            }

            securityScopedDirectoryURL?.stopAccessingSecurityScopedResource()
            securityScopedDirectoryURL = startedAccessing ? directoryURL : nil
            shouldStopNewAccess = false

            databaseURL = destinationURL
            defaults.set(bookmark, forKey: Self.storageBookmarkKey)
            lastSavedAt = Date()
            storageErrorMessage = nil
        } catch {
            if shouldStopNewAccess {
                directoryURL.stopAccessingSecurityScopedResource()
            }
            storageErrorMessage = "Could not use the selected folder: \(error.localizedDescription)"
            throw error
        }
    }

    func returnToLocalStorage() throws {
        do {
            try writeCurrentData(to: localDatabaseURL)
            securityScopedDirectoryURL?.stopAccessingSecurityScopedResource()
            securityScopedDirectoryURL = nil
            databaseURL = localDatabaseURL
            defaults.removeObject(forKey: Self.storageBookmarkKey)
            lastSavedAt = Date()
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = "Could not return to local storage: \(error.localizedDescription)"
            throw error
        }
    }

    func clearStorageError() {
        storageErrorMessage = nil
    }

    private func restoreStorageLocation() {
        guard let bookmark = defaults.data(forKey: Self.storageBookmarkKey) else { return }

        do {
            var isStale = false
            let directoryURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            let startedAccessing = directoryURL.startAccessingSecurityScopedResource()
            securityScopedDirectoryURL = startedAccessing ? directoryURL : nil
            databaseURL = directoryURL.appendingPathComponent(Self.syncedDatabaseFilename)

            if isStale {
                let refreshedBookmark = try directoryURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                defaults.set(refreshedBookmark, forKey: Self.storageBookmarkKey)
            }
        } catch {
            defaults.removeObject(forKey: Self.storageBookmarkKey)
            databaseURL = localDatabaseURL
            storageErrorMessage = "The saved storage folder is no longer available. Using local storage."
        }
    }

    private func readPersistedData(from url: URL) throws -> PersistedData {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PersistedData.self, from: data)
    }

    private func writeCurrentData(to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let persistedData = PersistedData(clients: clients, projects: projects, entries: entries)
        let encoded = try JSONEncoder().encode(persistedData)
        try encoded.write(to: url, options: .atomic)
    }

    private func apply(_ data: PersistedData) {
        clients = data.clients
        projects = data.projects
        entries = data.entries
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
