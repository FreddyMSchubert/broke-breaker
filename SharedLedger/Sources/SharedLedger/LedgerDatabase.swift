import Foundation
import GRDB

public final class LedgerDatabase: @unchecked Sendable {
	public let dbQueue: DatabaseQueue

	public init(path: String) throws {
		var config = Configuration()
		config.prepareDatabase { db in
			// Foreign keys on, WAL for concurrency
			try db.execute(sql: "PRAGMA foreign_keys = ON;")
			try db.execute(sql: "PRAGMA journal_mode = WAL;")
		}

		self.dbQueue = try DatabaseQueue(path: path, configuration: config)
		try migratesIfNeeded()
	}

	private func migratesIfNeeded() throws {
		try dbQueue.write { db in
			try db.execute(sql: """
			CREATE TABLE IF NOT EXISTS schema_info(
				version INTEGER NOT NULL
			);
			""")

			let existing = try Row.fetchOne(db, sql: "SELECT version FROM schema_info LIMIT 1;")
			let currentVersion = existing?["version"] as Int? ?? 0

			if currentVersion < 1 {
				try createV1(db)
				try db.execute(sql: "DELETE FROM schema_info;")
				try db.execute(sql: "INSERT INTO schema_info(version) VALUES (1);")
			}
		}
	}

	private func createV1(_ db: Database) throws {
		// Store money as TEXT decimal string to preserve your Decimal behavior exactly.
		// Store dates as INTEGER unix seconds.
		try db.execute(sql: """
		CREATE TABLE IF NOT EXISTS one_time_transactions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL,
			date_seconds INTEGER NOT NULL,
			amount_decimal TEXT NOT NULL
		);
		""")

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

		try db.execute(sql: """
		CREATE TABLE IF NOT EXISTS daily_cache (
			day_start_seconds INTEGER PRIMARY KEY,
			net_from_one_time_decimal TEXT NOT NULL,
			net_from_recurring_decimal TEXT NOT NULL,
			net_total_decimal TEXT NOT NULL,
			running_balance_eod_decimal TEXT NOT NULL
		);
		""")

		// Helpful indexes
		try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_one_time_date ON one_time_transactions(date_seconds);")
		try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_rules_start ON recurring_rules(start_date_seconds);")
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
		// Stable, round-trip friendly
		NSDecimalNumber(decimal: value).stringValue
	}

	static func stringToDecimal(_ s: String) -> Decimal {
		Decimal(string: s) ?? 0
	}
}
