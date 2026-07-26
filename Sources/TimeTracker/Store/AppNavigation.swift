import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case clients
    case log
    case storage

    var id: String { rawValue }
}

final class AppNavigation: ObservableObject {
    @Published var selectedTab: MainTab = .clients
}
