import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var navigation: AppNavigation

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            ClientsProjectsView()
                .tabItem {
                    Label("Clients & Projects", systemImage: "person.2.fill")
                }
                .tag(MainTab.clients)

            LogView()
                .tabItem {
                    Label("Time Log & Export", systemImage: "clock.arrow.circlepath")
                }
                .tag(MainTab.log)
        }
        .frame(minWidth: 780, minHeight: 540)
    }
}
