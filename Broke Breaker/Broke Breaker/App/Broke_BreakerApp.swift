import SwiftUI
import SharedLedger

@main
struct Broke_BreakerApp: App {
    let ledgerService: LedgerService
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
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
            ZStack {
                if hasSeenOnboarding {
                    RootTabView()
                } else {
                    OnboardingFlow {
                        hasSeenOnboarding = true
                    }
                }
            }
        }
    }
}
