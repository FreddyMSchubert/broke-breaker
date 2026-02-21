import SwiftUI
import SharedLedger

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
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("preview-ledger.sqlite")
    try? FileManager.default.removeItem(at: tmp)

    let ledger = Ledger.shared

    return RootTabView()
}
