import SwiftUI

struct ClientsProjectsView: View {
    @EnvironmentObject var store: DataStore
    @State private var newClientName = ""
    @State private var newProjectName = ""
    @State private var selectedClientId: UUID?

    var body: some View {
        HSplitView {
            clientsColumn
            projectsColumn
        }
        .frame(minWidth: 520, minHeight: 380)
        .onAppear {
            if selectedClientId == nil { selectedClientId = store.clients.first?.id }
        }
    }

    private var clientsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Clients")
                    .font(.title3.bold())
                Text("Everyone you track time for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 8)

            if store.clients.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("Add your first client below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedClientId) {
                    ForEach(store.clients) { client in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(client.name)
                                let count = store.projects(for: client.id).count
                                Text("\(count) project\(count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(client.id))
                        .contextMenu {
                            Button("Delete Client", role: .destructive) {
                                if selectedClientId == client.id { selectedClientId = nil }
                                store.deleteClient(client)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                TextField("New client name", text: $newClientName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addClient)
                Button("Add", action: addClient)
                    .buttonStyle(.borderedProminent)
                    .disabled(newClientName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
        }
        .frame(minWidth: 240)
    }

    private var projectsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let clientId = selectedClientId, let client = store.clients.first(where: { $0.id == clientId }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projects")
                        .font(.title3.bold())
                    Text("for \(client.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .top], 14)
                .padding(.bottom, 8)

                let projects = store.projects(for: clientId)
                if projects.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("Add a project below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(projects) { project in
                            Label(project.name, systemImage: "folder.fill")
                                .foregroundStyle(.primary)
                                .contextMenu {
                                    Button("Delete Project", role: .destructive) {
                                        store.deleteProject(project)
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }

                Divider()

                HStack {
                    TextField("New project name", text: $newProjectName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addProject(clientId: clientId) }
                    Button("Add") { addProject(clientId: clientId) }
                        .buttonStyle(.borderedProminent)
                        .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(14)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("Select or add a client to manage its projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 280)
    }

    private func addClient() {
        let name = newClientName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addClient(name: name)
        newClientName = ""
    }

    private func addProject(clientId: UUID) {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addProject(name: name, clientId: clientId)
        newProjectName = ""
    }
}
