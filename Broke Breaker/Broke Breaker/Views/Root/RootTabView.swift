import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                ListOverviewView()
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
            }

            NavigationStack {
                AddItemView()
            }
            .tabItem {
                Label("Add", systemImage: "plus")
            }
        }
    }
}

#Preview {
    RootTabView()
}
