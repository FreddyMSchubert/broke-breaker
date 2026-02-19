import Foundation
import GRDB

public final class LedgerService: @unchecked Sendable {
	private let db: LedgerDatabase
	private let calendar: Calendar

	// NEW initializer (cross-platform)
	public init(databasePath: String, calendar: Calendar = .current) throws {
		self.db = try LedgerDatabase(path: databasePath)
		self.calendar = calendar
	}

	// ----- Public Write API (same calls)

	@discardableResult
	public func addOneTime(title: String, date: Date, amount: Decimal) throws -> OneTimeTransaction {
		let d = dayStart(date)

        return try db.dbQueue.write { wdb in
            let seconds = LedgerDatabase.dateToSeconds(date)
            let amountStr = LedgerDatabase.decimalToString(amount)

            try wdb.execute(
                sql: """
                INSERT INTO one_time_transactions(title, date_seconds, amount_decimal)
                VALUES (?, ?, ?);
                """,
                arguments: [title, seconds, amountStr]
            )

            let newId = wdb.lastInsertedRowID
            try invalidateCache(from: d, wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)

            return OneTimeTransaction(id: newId, title: title, date: date, amount: amount)
        }
	}

    @discardableResult
    public func addRecurring(
        title: String,
        amountPerCycle: Decimal,
        startDate: Date,
        endDate: Date?,
        recurrence: Recurrence
    ) throws -> RecurringRule {
        try db.dbQueue.write { wdb in
            let startSec = LedgerDatabase.dateToSeconds(startDate)
            let endSec = endDate.map { LedgerDatabase.dateToSeconds($0) }
            let amountStr = LedgerDatabase.decimalToString(amountPerCycle)

            let (unit, interval): (Int, Int) = {
                switch recurrence {
                case .everyDays(let n):   return (0, n)
                case .everyWeeks(let n):  return (1, n)
                case .everyMonths(let n): return (2, n)
                case .everyYears(let n):  return (3, n)
                }
            }()

            try wdb.execute(
                sql: """
                INSERT INTO recurring_rules(
                    title, amount_per_cycle_decimal, start_date_seconds, end_date_seconds,
                    recurrence_unit, recurrence_interval
                ) VALUES (?, ?, ?, ?, ?, ?);
                """,
                arguments: [title, amountStr, startSec, endSec as DatabaseValueConvertible?, unit, interval]
            )

            let newId = wdb.lastInsertedRowID
            try invalidateCache(from: dayStart(startDate), wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)

            return RecurringRule(
                id: newId,
                title: title,
                amountPerCycle: amountPerCycle,
                startDate: startDate,
                endDate: endDate,
                recurrence: recurrence
            )
        }
    }

	public func updateOneTime(
		_ tx: OneTimeTransaction,
		title: String? = nil,
		date: Date? = nil,
		amount: Decimal? = nil
	) throws {
		let oldDay = dayStart(tx.date)

		if let title { tx.title = title }
		if let date  { tx.date = date }
		if let amount { tx.amount = amount }

		let newDay = dayStart(tx.date)
		let earliest = min(oldDay, newDay)

		try db.dbQueue.write { wdb in
            let seconds = LedgerDatabase.dateToSeconds(tx.date)
            let amountStr = LedgerDatabase.decimalToString(tx.amount)

            try wdb.execute(
                sql: """
                UPDATE one_time_transactions
                SET title = ?, date_seconds = ?, amount_decimal = ?
                WHERE id = ?;
                """,
                arguments: [tx.title, seconds, amountStr, tx.id]
            )

            try invalidateCache(from: earliest, wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)
		}
	}

	public enum EndDateUpdate {
		case keep
		case clear
		case set(Date)
	}

	public func updateRecurring(
		_ rule: RecurringRule,
		title: String? = nil,
		amountPerCycle: Decimal? = nil,
		startDate: Date? = nil,
		endDate: EndDateUpdate = .keep,
		recurrence: Recurrence? = nil
	) throws {
		let oldStart = dayStart(rule.startDate)

		if let title { rule.title = title }
		if let amountPerCycle { rule.amountPerCycle = amountPerCycle }
		if let startDate { rule.startDate = startDate }
		if let recurrence { rule.recurrence = recurrence }

		switch endDate {
		case .keep: break
		case .clear: rule.endDate = nil
		case .set(let d): rule.endDate = d
		}

		let newStart = dayStart(rule.startDate)
		let earliest = min(oldStart, newStart)

		try db.dbQueue.write { wdb in
            let startSec = LedgerDatabase.dateToSeconds(rule.startDate)
            let endSec = rule.endDate.map { LedgerDatabase.dateToSeconds($0) }
            let amountStr = LedgerDatabase.decimalToString(rule.amountPerCycle)

            try wdb.execute(
                sql: """
                UPDATE recurring_rules
                SET title = ?,
                    amount_per_cycle_decimal = ?,
                    start_date_seconds = ?,
                    end_date_seconds = ?,
                    recurrence_unit = ?,
                    recurrence_interval = ?
                WHERE id = ?;
                """,
                arguments: [
                    rule.title,
                    amountStr,
                    startSec,
                    endSec as DatabaseValueConvertible?,
                    rule.recurrenceUnit,
                    rule.recurrenceInterval,
                    rule.id
                ]
            )

            try invalidateCache(from: earliest, wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)
		}
	}

	public func deleteOneTime(_ tx: OneTimeTransaction) throws {
		let d = dayStart(tx.date)

		try db.dbQueue.write { wdb in
            try wdb.execute(
                sql: "DELETE FROM one_time_transactions WHERE id = ?;",
                arguments: [tx.id]
            )
            try invalidateCache(from: d, wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)
		}
	}

	public func deleteRecurring(_ rule: RecurringRule) throws {
		let d = dayStart(rule.startDate)

		try db.dbQueue.write { wdb in
            try wdb.execute(
                sql: "DELETE FROM recurring_rules WHERE id = ?;",
                arguments: [rule.id]
            )
            try invalidateCache(from: d, wdb: wdb)
            try ensureCachedThrough(day: today(), wdb: wdb)
		}
	}

	// ----- Public Read API (same calls)

	public func dayOverview(for date: Date) throws -> DayOverview {
		let day = dayStart(date)

		return try db.dbQueue.read { wdb in
			// if no entries yet or before first entry, return empty day
			guard let ledgerStart = try earliestLedgerDay(wdb: wdb) else {
				return DayOverview(dayStart: day, items: [], netTotal: 0)
			}
			if day < ledgerStart {
				return DayOverview(dayStart: day, items: [], netTotal: 0)
			}

			try ensureCachedThrough(day: max(day, today()), wdb: wdb)

			let oneTimes = try fetchOneTimes(on: day, wdb: wdb)
			let rules = try fetchAllRecurringRules(wdb: wdb)

			var items: [DayLineItem] = []

			for rule in rules {
				let amt = contribution(for: rule, on: day)
				if amt != 0 {
					items.append(DayLineItem(
						title: rule.title,
						amount: amt,
						source: .recurring(id: rule.id)
					))
				}
			}
			for tx in oneTimes {
				items.append(DayLineItem(
					title: tx.title,
					amount: tx.amount,
					source: .oneTime(id: tx.id)
				))
			}

			let net = items.reduce(Decimal(0)) { $0 + $1.amount }
			return DayOverview(dayStart: day, items: items, netTotal: net)
		}
	}

	public func dayTotals(for date: Date) throws -> DayTotals {
		let day = dayStart(date)

		return try db.dbQueue.read { wdb in
			guard let ledgerStart = try earliestLedgerDay(wdb: wdb) else {
				return DayTotals(dayStart: day, netTotal: 0, runningBalanceEndOfDay: 0)
			}
			if day < ledgerStart {
				return DayTotals(dayStart: day, netTotal: 0, runningBalanceEndOfDay: 0)
			}

			try ensureCachedThrough(day: max(day, today()), wdb: wdb)

			guard let entry = try fetchCacheEntry(for: day, wdb: wdb) else {
				throw LedgerError.cacheMissing
			}

			return DayTotals(
				dayStart: entry.dayStart,
				netTotal: entry.netTotal,
				runningBalanceEndOfDay: entry.runningBalanceEndOfDay
			)
		}
	}

	public func balanceEndOfDay(on date: Date) throws -> Decimal {
		try dayTotals(for: date).runningBalanceEndOfDay
	}

	public func fetchOneTime(id: PersistentIdentifier) throws -> OneTimeTransaction? {
		try db.dbQueue.read { rdb in
			guard let row = try Row.fetchOne(
				rdb,
				sql: """
				SELECT id, title, date_seconds, amount_decimal
				FROM one_time_transactions
				WHERE id = ?;
				""",
				arguments: [id]
			) else { return nil }

			let id: Int64 = row["id"]
			let title: String = row["title"]
			let dateSec: Int64 = row["date_seconds"]
			let amountStr: String = row["amount_decimal"]

			return OneTimeTransaction(
				id: id,
				title: title,
				date: LedgerDatabase.secondsToDate(dateSec),
				amount: LedgerDatabase.stringToDecimal(amountStr)
			)
		}
	}

	public func fetchRecurring(id: PersistentIdentifier) throws -> RecurringRule? {
		try db.dbQueue.read { rdb in
			guard let row = try Row.fetchOne(
				rdb,
				sql: """
				SELECT id, title, amount_per_cycle_decimal, start_date_seconds, end_date_seconds,
					recurrence_unit, recurrence_interval
				FROM recurring_rules
				WHERE id = ?;
				""",
				arguments: [id]
			) else { return nil }

			let id: Int64 = row["id"]
			let title: String = row["title"]
			let amountStr: String = row["amount_per_cycle_decimal"]
			let startSec: Int64 = row["start_date_seconds"]
			let endSec: Int64? = row["end_date_seconds"]
			let unit: Int = row["recurrence_unit"]
			let interval: Int = row["recurrence_interval"]

			let rule = RecurringRule(
				id: id,
				title: title,
				amountPerCycle: LedgerDatabase.stringToDecimal(amountStr),
				startDate: LedgerDatabase.secondsToDate(startSec),
				endDate: endSec.map(LedgerDatabase.secondsToDate),
				recurrence: .everyMonths(1)
			)
			rule.recurrenceUnit = unit
			rule.recurrenceInterval = interval
			return rule
		}
	}

	// ----- Cache Logic (same behavior, now SQL)

	private func ensureCachedThrough(day requested: Date, wdb: Database) throws {
		let target = dayStart(requested)

		guard let ledgerStart = try earliestLedgerDay(wdb: wdb) else { return }
		if target < ledgerStart { return }

		if let lastCached = try fetchLastCachedDay(wdb: wdb) {
			if lastCached >= target { return }

			let start = calendar.date(byAdding: .day, value: 1, to: lastCached)!
			try computeAndAppendCache(from: start, through: target, wdb: wdb)
		} else {
			try computeAndAppendCache(from: ledgerStart, through: target, wdb: wdb)
		}
	}

	private func invalidateCache(from day: Date, wdb: Database) throws {
		let d = dayStart(day)
		let sec = LedgerDatabase.dateToSeconds(d)

		try wdb.execute(
			sql: "DELETE FROM daily_cache WHERE day_start_seconds >= ?;",
			arguments: [sec]
		)
	}

	private func computeAndAppendCache(from startDay: Date, through endDay: Date, wdb: Database) throws {
		let rules = try fetchAllRecurringRules(wdb: wdb)

        let runningBeforeStart: Decimal
        if let dayBefore = calendar.date(byAdding: .day, value: -1, to: startDay) {
            runningBeforeStart = try fetchCacheEntry(for: dayBefore, wdb: wdb)?.runningBalanceEndOfDay ?? 0
        } else {
            runningBeforeStart = 0
        }

		var running = runningBeforeStart
		var day = startDay

		while day <= endDay {
			let oneTimeNet = try netOneTimes(on: day, wdb: wdb)

			var recurringNet: Decimal = 0
			for rule in rules {
				recurringNet += contribution(for: rule, on: day)
			}

			let netTotal = oneTimeNet + recurringNet
			running += netTotal

			let daySec = LedgerDatabase.dateToSeconds(dayStart(day))

			try wdb.execute(
				sql: """
				INSERT INTO daily_cache(
					day_start_seconds,
					net_from_one_time_decimal,
					net_from_recurring_decimal,
					net_total_decimal,
					running_balance_eod_decimal
				) VALUES (?, ?, ?, ?, ?)
				ON CONFLICT(day_start_seconds) DO UPDATE SET
					net_from_one_time_decimal = excluded.net_from_one_time_decimal,
					net_from_recurring_decimal = excluded.net_from_recurring_decimal,
					net_total_decimal = excluded.net_total_decimal,
					running_balance_eod_decimal = excluded.running_balance_eod_decimal;
				""",
				arguments: [
					daySec,
					LedgerDatabase.decimalToString(oneTimeNet),
					LedgerDatabase.decimalToString(recurringNet),
					LedgerDatabase.decimalToString(netTotal),
					LedgerDatabase.decimalToString(running)
				]
			)

			day = calendar.date(byAdding: .day, value: 1, to: day)!
		}
	}

	// ----- Recurring Contribution Utils (unchanged logic)

	private func contribution(for rule: RecurringRule, on day: Date) -> Decimal {
		let d = dayStart(day)
		let start = dayStart(rule.startDate)

		if d < start { return 0 }
		if let end = rule.endDate, d > dayStart(end) { return 0 }

		switch rule.recurrence {
		case .everyDays(let n):
			return proratedFixed(rule: rule, on: d, intervalDays: max(1, n))
		case .everyWeeks(let n):
			return proratedFixed(rule: rule, on: d, intervalDays: max(1, n) * 7)
		case .everyMonths(let n):
			return proratedCalendar(rule: rule, on: d, component: .month, step: max(1, n))
		case .everyYears(let n):
			return proratedCalendar(rule: rule, on: d, component: .year, step: max(1, n))
		}
	}

	private func proratedFixed(rule: RecurringRule, on day: Date, intervalDays: Int) -> Decimal {
		let anchor = dayStart(rule.startDate)
		_ = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
		return safeDivide(rule.amountPerCycle, by: intervalDays)
	}

	private func proratedCalendar(rule: RecurringRule, on day: Date, component: Calendar.Component, step: Int) -> Decimal {
		let anchor = dayStart(rule.startDate)

		var cycleStart = anchor
		while true {
			guard let next = calendar.date(byAdding: component, value: step, to: cycleStart) else { break }
			if next <= day { cycleStart = next } else { break }
		}

		let nextCycleStart = calendar.date(byAdding: component, value: step, to: cycleStart)!
		let cycleDays = max(1, calendar.dateComponents([.day], from: cycleStart, to: nextCycleStart).day ?? 1)

		return safeDivide(rule.amountPerCycle, by: cycleDays)
	}

	// ----- Fetch Utils (raw SQL)

	private func earliestLedgerDay(wdb: Database) throws -> Date? {
		let earliestTx = try fetchEarliestTransactionDay(wdb: wdb)
		let earliestRule = try fetchEarliestRuleDay(wdb: wdb)

		switch (earliestTx, earliestRule) {
		case (nil, nil): return nil
		case (let a?, nil): return a
		case (nil, let b?): return b
		case (let a?, let b?): return min(a, b)
		}
	}

	private func fetchEarliestTransactionDay(wdb: Database) throws -> Date? {
		guard let row = try Row.fetchOne(
			wdb,
			sql: "SELECT date_seconds FROM one_time_transactions ORDER BY date_seconds ASC LIMIT 1;"
		) else { return nil }
		let sec: Int64 = row["date_seconds"]
		return dayStart(LedgerDatabase.secondsToDate(sec))
	}

	private func fetchEarliestRuleDay(wdb: Database) throws -> Date? {
		guard let row = try Row.fetchOne(
			wdb,
			sql: "SELECT start_date_seconds FROM recurring_rules ORDER BY start_date_seconds ASC LIMIT 1;"
		) else { return nil }
		let sec: Int64 = row["start_date_seconds"]
		return dayStart(LedgerDatabase.secondsToDate(sec))
	}

	private func fetchAllRecurringRules(wdb: Database) throws -> [RecurringRule] {
		let rows = try Row.fetchAll(wdb, sql: """
			SELECT id, title, amount_per_cycle_decimal, start_date_seconds, end_date_seconds,
				   recurrence_unit, recurrence_interval
			FROM recurring_rules;
		""")

		return rows.map { row in
			let id: Int64 = row["id"]
			let title: String = row["title"]
			let amountStr: String = row["amount_per_cycle_decimal"]
			let startSec: Int64 = row["start_date_seconds"]
			let endSec: Int64? = row["end_date_seconds"]
			let unit: Int = row["recurrence_unit"]
			let interval: Int = row["recurrence_interval"]

			let rule = RecurringRule(
				id: id,
				title: title,
				amountPerCycle: LedgerDatabase.stringToDecimal(amountStr),
				startDate: LedgerDatabase.secondsToDate(startSec),
				endDate: endSec.map(LedgerDatabase.secondsToDate),
				recurrence: .everyMonths(1) // replaced immediately below
			)
			rule.recurrenceUnit = unit
			rule.recurrenceInterval = interval
			return rule
		}
	}

	private func fetchOneTimes(on day: Date, wdb: Database) throws -> [OneTimeTransaction] {
		let start = dayStart(day)
		let end = calendar.date(byAdding: .day, value: 1, to: start)!

		let startSec = LedgerDatabase.dateToSeconds(start)
		let endSec = LedgerDatabase.dateToSeconds(end)

		let rows = try Row.fetchAll(
			wdb,
			sql: """
			SELECT id, title, date_seconds, amount_decimal
			FROM one_time_transactions
			WHERE date_seconds >= ? AND date_seconds < ?
			ORDER BY date_seconds ASC;
			""",
			arguments: [startSec, endSec]
		)

		return rows.map { row in
			let id: Int64 = row["id"]
			let title: String = row["title"]
			let dateSec: Int64 = row["date_seconds"]
			let amountStr: String = row["amount_decimal"]

			return OneTimeTransaction(
				id: id,
				title: title,
				date: LedgerDatabase.secondsToDate(dateSec),
				amount: LedgerDatabase.stringToDecimal(amountStr)
			)
		}
	}

	private func netOneTimes(on day: Date, wdb: Database) throws -> Decimal {
		let txs = try fetchOneTimes(on: day, wdb: wdb)
		return txs.reduce(Decimal(0)) { $0 + $1.amount }
	}

	private func fetchCacheEntry(for day: Date, wdb: Database) throws -> DailyCacheEntry? {
		let d = dayStart(day)
		let sec = LedgerDatabase.dateToSeconds(d)

		guard let row = try Row.fetchOne(
			wdb,
			sql: """
			SELECT day_start_seconds,
				   net_from_one_time_decimal,
				   net_from_recurring_decimal,
				   net_total_decimal,
				   running_balance_eod_decimal
			FROM daily_cache
			WHERE day_start_seconds = ?;
			""",
			arguments: [sec]
		) else { return nil }

		let daySec: Int64 = row["day_start_seconds"]
		let one: String = row["net_from_one_time_decimal"]
		let rec: String = row["net_from_recurring_decimal"]
		let total: String = row["net_total_decimal"]
		let run: String = row["running_balance_eod_decimal"]

		return DailyCacheEntry(
			dayStart: LedgerDatabase.secondsToDate(daySec),
			netFromOneTime: LedgerDatabase.stringToDecimal(one),
			netFromRecurring: LedgerDatabase.stringToDecimal(rec),
			netTotal: LedgerDatabase.stringToDecimal(total),
			runningBalanceEndOfDay: LedgerDatabase.stringToDecimal(run)
		)
	}

	private func fetchLastCachedDay(wdb: Database) throws -> Date? {
		guard let row = try Row.fetchOne(
			wdb,
			sql: "SELECT day_start_seconds FROM daily_cache ORDER BY day_start_seconds DESC LIMIT 1;"
		) else { return nil }

		let sec: Int64 = row["day_start_seconds"]
		return LedgerDatabase.secondsToDate(sec)
	}

	// ----- General utils (unchanged)

	private func dayStart(_ date: Date) -> Date {
		calendar.startOfDay(for: date)
	}

	private func today() -> Date {
		dayStart(Date())
	}

	private func safeDivide(_ value: Decimal, by divisor: Int) -> Decimal {
		guard divisor != 0 else { return 0 }
		var v = value
		var d = Decimal(divisor)
		var result = Decimal()
		NSDecimalDivide(&result, &v, &d, .bankers)
		return result
	}
}
