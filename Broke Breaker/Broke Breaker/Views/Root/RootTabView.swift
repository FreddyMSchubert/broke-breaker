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
                    .labelStyle(.iconOnly)
            }

            NavigationStack {
                ListOverviewView()
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
            }

            NavigationStack {
                AddItemView()
            }
            .tabItem {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
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

