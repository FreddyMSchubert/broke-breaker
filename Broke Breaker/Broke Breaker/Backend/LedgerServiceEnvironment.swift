import SwiftUI
import SharedLedger

private struct LedgerServiceKey: EnvironmentKey {
    static let defaultValue: LedgerService = {
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        let proc = ProcessInfo.processInfo.processName
        fatalError("LedgerService not injected. process=\(proc)\n\nCall stack:\n\(stack)")
    }()
}

extension EnvironmentValues {
    var ledgerService: LedgerService {
        get { self[LedgerServiceKey.self] }
        set { self[LedgerServiceKey.self] = newValue }
    }
}

enum Ledger {
    static let shared: LedgerService = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbURL = docs.appendingPathComponent("ledger.sqlite")
        do {
            return try LedgerService(databasePath: dbURL.path)
        } catch {
            fatalError("Could not open ledger DB: \(error)")
        }
    }()
}
