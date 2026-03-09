import Foundation
import GRDB

public final class LedgerDatabase: @unchecked Sendable {
    public let dbQueue: DatabaseQueue

    public init(path: String) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
            try db.execute(sql: "PRAGMA journal_mode = WAL;")
        }

        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        try createSchema()
    }

    private func createSchema() throws {
        try dbQueue.write { db in
            // --- One-time (main pot)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS one_time_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                date_seconds INTEGER NOT NULL,
                amount_decimal TEXT NOT NULL
            );
            """)

            // --- Recurring rules (main pot, prorated daily)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS recurring_rules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                amount_per_cycle_decimal TEXT NOT NULL,
                start_date_seconds INTEGER NOT NULL,
                end_date_seconds INTEGER,
                recurrence_unit INTEGER NOT NULL,
                recurrence_interval INTEGER NOT NULL
            );
            """)

            // --- Savings transfers (one-time, affects BOTH pots)
            // amount_decimal is MAIN pot delta; SAVINGS pot delta is (-amount_decimal)
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS savings_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                date_seconds INTEGER NOT NULL,
                amount_decimal TEXT NOT NULL
            );
            """)

            // --- Daily cache: duplicated totals + running balances for main + savings
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS daily_cache (
                day_start_seconds INTEGER PRIMARY KEY,

                -- Main pot breakdown
                net_from_one_time_main_decimal TEXT NOT NULL,
                net_from_recurring_main_decimal TEXT NOT NULL,
                net_from_savings_main_decimal TEXT NOT NULL,
                net_total_main_decimal TEXT NOT NULL,
                running_main_eod_decimal TEXT NOT NULL,

                -- Savings pot breakdown
                net_from_savings_savings_decimal TEXT NOT NULL,
                net_total_savings_decimal TEXT NOT NULL,
                running_savings_eod_decimal TEXT NOT NULL
            );
            """)

            // Helpful indexes
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_one_time_date ON one_time_transactions(date_seconds);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_rules_start ON recurring_rules(start_date_seconds);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_savings_date ON savings_transactions(date_seconds);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_cache_day ON daily_cache(day_start_seconds);")
        }
    }
}

// MARK: - Helpers (Decimal <-> TEXT, Date <-> seconds)

extension LedgerDatabase {
    static func dateToSeconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded(.towardZero))
    }

    static func secondsToDate(_ seconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    static func decimalToString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func stringToDecimal(_ s: String) -> Decimal {
        Decimal(string: s) ?? 0
    }
}
