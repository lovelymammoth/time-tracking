import SwiftUI
import AppKit

struct StorageView: View {
    @EnvironmentObject var store: DataStore
    @State private var operationErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                locationCard
                cloudHelp
                syncWarning
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .alert("Storage Error", isPresented: Binding(
            get: { operationErrorMessage != nil },
            set: { if !$0 { operationErrorMessage = nil } }
        )) {
            Button("OK") { operationErrorMessage = nil }
        } message: {
            Text(operationErrorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Database Storage")
                .font(.title2.bold())
            Text("Keep your time-tracking data locally or in a folder synced by your cloud service.")
                .foregroundStyle(.secondary)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: store.isUsingCustomStorage ? "externaldrive.badge.icloud" : "internaldrive")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.isUsingCustomStorage ? "Synced folder" : "Local storage")
                        .font(.headline)
                    Text(store.databaseURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }

                Spacer()
            }

            Divider()

            if let error = store.storageErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else if let lastSavedAt = store.lastSavedAt {
                Label(
                    "Saved \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
                Label("Ready", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    chooseSyncedFolder()
                } label: {
                    Label(
                        store.isUsingCustomStorage ? "Change Folder…" : "Choose Synced Folder…",
                        systemImage: "folder.badge.plus"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.reloadFromDisk()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([store.databaseURL])
                } label: {
                    Label("Show in Finder", systemImage: "finder")
                }
                .buttonStyle(.bordered)

                if store.isUsingCustomStorage {
                    Spacer()
                    Button("Use Local Storage") {
                        returnToLocalStorage()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var cloudHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Choosing a cloud folder", systemImage: "icloud")
                .font(.headline)

            Text("For iCloud Drive, choose a folder under iCloud Drive in the Finder sidebar. For Google Drive, choose a folder inside Google Drive after installing and signing in to Google Drive for desktop.")
                .foregroundStyle(.secondary)

            Text("The app creates \(DataStore.syncedDatabaseFilename) in that folder and remembers access to it after relaunching.")
                .foregroundStyle(.secondary)
        }
    }

    private var syncWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
            Text("Let the cloud service finish syncing before opening Time Tracker on another Mac. Avoid editing the database from two Macs at the same time; the cloud provider may create a conflicted copy.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func chooseSyncedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Database Folder"
        panel.message = "Choose an iCloud Drive, Google Drive, or other synced folder."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let directoryURL = panel.url else { return }

        let destinationURL = directoryURL.appendingPathComponent(DataStore.syncedDatabaseFilename)
        var choice: DataStore.ExistingDatabaseChoice = .replaceWithCurrent

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let alert = NSAlert()
            alert.messageText = "A Time Tracker database already exists"
            alert.informativeText = "Use the database already in this folder, or replace it with the data currently open in the app?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Use Existing")
            alert.addButton(withTitle: "Replace with Current")
            alert.addButton(withTitle: "Cancel")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                choice = .useExisting
            case .alertSecondButtonReturn:
                choice = .replaceWithCurrent
            default:
                return
            }
        }

        do {
            try store.connectStorage(to: directoryURL, existingDatabaseChoice: choice)
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }

    private func returnToLocalStorage() {
        let alert = NSAlert()
        alert.messageText = "Return to local storage?"
        alert.informativeText = "The currently open data will be copied back to this Mac. The cloud copy will not be deleted."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Use Local Storage")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try store.returnToLocalStorage()
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }
}
