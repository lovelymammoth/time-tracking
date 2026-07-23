import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case clients
    case log

    var id: String { rawValue }
}

final class AppNavigation: ObservableObject {
    @Published var selectedTab: MainTab = .clients
}
