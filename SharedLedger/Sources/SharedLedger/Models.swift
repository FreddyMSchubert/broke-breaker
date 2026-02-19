import Foundation

public typealias PersistentIdentifier = Int64

// ----- BFF structs

/// One line item shown for a day
public struct DayLineItem: Identifiable, Sendable {
	public enum Source: Sendable {
		case oneTime(id: PersistentIdentifier)
		case recurring(id: PersistentIdentifier)
	}

	public let id = UUID()
	public let title: String
	public let amount: Decimal
	public let source: Source

	public init(title: String, amount: Decimal, source: Source) {
		self.title = title
		self.amount = amount
		self.source = source
	}
}

/// Detailed breakdown for one day
public struct DayOverview: Sendable {
	public let dayStart: Date
	public let items: [DayLineItem]
	public let netTotal: Decimal
}

/// Totals + rollover for one day
public struct DayTotals: Sendable {
	public let dayStart: Date
	public let netTotal: Decimal
	public let runningBalanceEndOfDay: Decimal
}

// ----- Recurrence Definition (repeating only)

public enum Recurrence: Hashable, Sendable {
	case everyDays(Int)
	case everyWeeks(Int)
	case everyMonths(Int)
	case everyYears(Int)
}

// ----- Stored "model" equivalents (no SwiftData)

public final class OneTimeTransaction: @unchecked Sendable {
	public let id: PersistentIdentifier
	public var title: String
	public var date: Date
	public var amount: Decimal

	public init(id: PersistentIdentifier, title: String, date: Date, amount: Decimal) {
		self.id = id
		self.title = title
		self.date = date
		self.amount = amount
	}
}

public final class RecurringRule: @unchecked Sendable {
	public let id: PersistentIdentifier
	public var title: String
	public var amountPerCycle: Decimal
	public var startDate: Date
	public var endDate: Date?

	// 0=days, 1=weeks, 2=months, 3=years
	public var recurrenceUnit: Int
	public var recurrenceInterval: Int

	public init(
		id: PersistentIdentifier,
		title: String,
		amountPerCycle: Decimal,
		startDate: Date,
		endDate: Date?,
		recurrence: Recurrence
	) {
		self.id = id
		self.title = title
		self.amountPerCycle = amountPerCycle
		self.startDate = startDate
		self.endDate = endDate

		switch recurrence {
		case .everyDays(let n):
			self.recurrenceUnit = 0
			self.recurrenceInterval = n
		case .everyWeeks(let n):
			self.recurrenceUnit = 1
			self.recurrenceInterval = n
		case .everyMonths(let n):
			self.recurrenceUnit = 2
			self.recurrenceInterval = n
		case .everyYears(let n):
			self.recurrenceUnit = 3
			self.recurrenceInterval = n
		}
	}

	public var recurrence: Recurrence {
		get {
			let n = max(1, recurrenceInterval)
			switch recurrenceUnit {
			case 0: return .everyDays(n)
			case 1: return .everyWeeks(n)
			case 2: return .everyMonths(n)
			case 3: return .everyYears(n)
			default: return .everyMonths(1)
			}
		}
		set {
			switch newValue {
			case .everyDays(let n):
				recurrenceUnit = 0
				recurrenceInterval = n
			case .everyWeeks(let n):
				recurrenceUnit = 1
				recurrenceInterval = n
			case .everyMonths(let n):
				recurrenceUnit = 2
				recurrenceInterval = n
			case .everyYears(let n):
				recurrenceUnit = 3
				recurrenceInterval = n
			}
		}
	}
}

public final class DailyCacheEntry: @unchecked Sendable {
	public var dayStart: Date // unique key
	public var netFromOneTime: Decimal
	public var netFromRecurring: Decimal
	public var netTotal: Decimal
	public var runningBalanceEndOfDay: Decimal

	public init(
		dayStart: Date,
		netFromOneTime: Decimal,
		netFromRecurring: Decimal,
		netTotal: Decimal,
		runningBalanceEndOfDay: Decimal
	) {
		self.dayStart = dayStart
		self.netFromOneTime = netFromOneTime
		self.netFromRecurring = netFromRecurring
		self.netTotal = netTotal
		self.runningBalanceEndOfDay = runningBalanceEndOfDay
	}
}

// ----- Errors

public enum LedgerError: Error {
	case cacheMissing
}
