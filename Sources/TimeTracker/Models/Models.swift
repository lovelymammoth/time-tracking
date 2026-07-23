import Foundation

struct Client: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var clientId: UUID
}

struct TimeEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientId: UUID
    var projectId: UUID
    var date: Date
    var startTime: Date
    var durationSeconds: Double
    var notes: String = ""
}
