import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedClientId: UUID?
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var useDateFilter = false
    @State private var exportErrorMessage: String?
    @State private var editingEntry: TimeEntry?

    private var filteredEntries: [TimeEntry] {
        var result = store.entries
        if let clientId = selectedClientId {
            result = result.filter { $0.clientId == clientId }
        }
        if useDateFilter {
            let start = Calendar.current.startOfDay(for: startDate)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            result = result.filter { $0.date >= start && $0.date < end }
        }
        return result.sorted { $0.startTime > $1.startTime }
    }

    private var totalDuration: Double {
        filteredEntries.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            filtersBar

            if filteredEntries.isEmpty {
                emptyState
            } else {
                table
            }

            summaryBar
        }
        .padding(20)
        .alert("Export Error", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditView(entry: entry) { updated in
                store.updateEntry(updated)
            }
            .environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Time Log")
                .font(.title2.bold())
            Text("Review, edit, and export the time you've tracked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 14) {
            Label("Client", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
            Picker("", selection: $selectedClientId) {
                Text("All Clients").tag(UUID?.none)
                ForEach(store.clients) { client in
                    Text(client.name).tag(Optional(client.id))
                }
            }
            .labelsHidden()
            .frame(width: 200)

            Divider().frame(height: 20)

            Toggle("Filter by date", isOn: $useDateFilter)

            if useDateFilter {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }

            Spacer()

            Button {
                exportExcel()
            } label: {
                Label("Export Excel", systemImage: "tablecells")
            }
            .buttonStyle(.bordered)
            .disabled(selectedClientId == nil)
            .help(selectedClientId == nil ? "Select a single client to export its report" : "Export this client's report as .xlsx")

            Button {
                exportPDF()
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedClientId == nil)
            .help(selectedClientId == nil ? "Select a single client to export its report" : "Export this client's report as PDF")
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No time entries")
                .font(.headline)
            Text(selectedClientId == nil ? "Start a timer or add a manual entry from the menu bar." : "No entries match the current filters.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var table: some View {
        Table(filteredEntries) {
            TableColumn("Date") { entry in
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
            }
            TableColumn("Client") { entry in
                Text(clientName(entry.clientId))
            }
            TableColumn("Project") { entry in
                Text(projectName(entry.projectId))
            }
            TableColumn("Start") { entry in
                Text(entry.startTime.formatted(date: .omitted, time: .shortened))
            }
            TableColumn("Duration") { entry in
                Text(formatDuration(entry.durationSeconds))
            }
            TableColumn("Notes") { entry in
                Text(entry.notes)
            }
            TableColumn("") { entry in
                HStack(spacing: 10) {
                    Button {
                        editingEntry = entry
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        store.deleteEntry(entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .width(56)
        }
    }

    private var summaryBar: some View {
        HStack {
            Text("\(filteredEntries.count) \(filteredEntries.count == 1 ? "entry" : "entries")")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total: \(formatDuration(totalDuration))")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
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

    private func exportExcel() {
        guard let clientId = selectedClientId, let client = store.clients.first(where: { $0.id == clientId }) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(client.name) Time Report.xlsx"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try XLSXExporter.export(client: client, entries: filteredEntries, projects: store.projects, to: url)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    private func exportPDF() {
        guard let clientId = selectedClientId, let client = store.clients.first(where: { $0.id == clientId }) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(client.name) Time Report.pdf"
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PDFExporter.export(client: client, entries: filteredEntries, projects: store.projects, to: url)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}
