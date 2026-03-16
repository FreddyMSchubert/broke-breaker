import SwiftUI
import SharedLedger

struct RootTabView: View {
    @State private var selectedTab: Int = 0
    @State private var listInitialDate: Date = Date()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
                    .labelStyle(.iconOnly)
            }
            .tag(0)
            
            NavigationStack {
                ListOverviewView(initialDate: listInitialDate)
                    .id(listInitialDate)
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
            }
            .tag(1)

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(.iconOnly)
            }
            .tag(2)
            
            NavigationStack {
                AddItemView()
            }
            .tabItem {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .tag(3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showListForDate)) { note in
            if let date = note.object as? Date {
                listInitialDate = date
                selectedTab = 1
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

