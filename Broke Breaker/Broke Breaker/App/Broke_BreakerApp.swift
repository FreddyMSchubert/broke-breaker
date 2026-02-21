import SwiftUI
import SharedLedger

@main
struct Broke_BreakerApp: App {
    let ledgerService: LedgerService

    init() {
        // db stored in in documents or application support
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbURL = docs.appendingPathComponent("ledger.sqlite")

        do {
            ledgerService = try LedgerService(databasePath: dbURL.path)
        } catch {
            fatalError("Could not open ledger DB: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
