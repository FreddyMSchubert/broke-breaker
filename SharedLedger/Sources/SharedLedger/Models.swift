import Foundation

public typealias PersistentIdentifier = Int64

// ----- BFF structs

/// One line item shown for a day (can affect main and/or savings)
public struct DayLineItem: Identifiable, Sendable {
    public enum Source: Sendable {
        case oneTime(id: PersistentIdentifier)
        case recurring(id: PersistentIdentifier)
        case saving(id: PersistentIdentifier)
    }

    public let id = UUID()
    public let title: String

    /// Main pot delta for this item (what the normal pot sees)
    public let mainAmount: Decimal

    /// Savings pot delta for this item (what the savings pot sees)
    public let savingsAmount: Decimal

    public let source: Source

    public init(title: String, mainAmount: Decimal, savingsAmount: Decimal, source: Source) {
        self.title = title
        self.mainAmount = mainAmount
        self.savingsAmount = savingsAmount
        self.source = source
    }
}

/// Detailed breakdown for one day
public struct DayOverview: Sendable {
    public let dayStart: Date
    public let items: [DayLineItem]
    public let netTotalMain: Decimal
    public let netTotalSavings: Decimal
}

/// Totals + rollover for one day
public struct DayTotals: Sendable {
    public let dayStart: Date
    public let netTotalMain: Decimal
    public let netTotalSavings: Decimal
    public let runningBalanceMainEndOfDay: Decimal
    public let runningBalanceSavingsEndOfDay: Decimal
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
    public var amount: Decimal // main pot delta

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

/// Savings transfer (one-time).
/// `amount` is the MAIN pot delta. Savings pot delta is `-amount`.
public final class SavingsTransaction: @unchecked Sendable {
    public let id: PersistentIdentifier
    public var title: String
    public var date: Date
    public var amount: Decimal // main pot delta

    public init(id: PersistentIdentifier, title: String, date: Date, amount: Decimal) {
        self.id = id
        self.title = title
        self.date = date
        self.amount = amount
    }

    public var savingsDelta: Decimal { -amount }
}

public final class DailyCacheEntry: @unchecked Sendable {
    public var dayStart: Date // unique key

    // Main
    public var netFromOneTimeMain: Decimal
    public var netFromRecurringMain: Decimal
    public var netFromSavingsMain: Decimal
    public var netTotalMain: Decimal
    public var runningMainEndOfDay: Decimal

    // Savings
    public var netFromSavingsSavings: Decimal
    public var netTotalSavings: Decimal
    public var runningSavingsEndOfDay: Decimal

    public init(
        dayStart: Date,

        netFromOneTimeMain: Decimal,
        netFromRecurringMain: Decimal,
        netFromSavingsMain: Decimal,
        netTotalMain: Decimal,
        runningMainEndOfDay: Decimal,

        netFromSavingsSavings: Decimal,
        netTotalSavings: Decimal,
        runningSavingsEndOfDay: Decimal
    ) {
        self.dayStart = dayStart

        self.netFromOneTimeMain = netFromOneTimeMain
        self.netFromRecurringMain = netFromRecurringMain
        self.netFromSavingsMain = netFromSavingsMain
        self.netTotalMain = netTotalMain
        self.runningMainEndOfDay = runningMainEndOfDay

        self.netFromSavingsSavings = netFromSavingsSavings
        self.netTotalSavings = netTotalSavings
        self.runningSavingsEndOfDay = runningSavingsEndOfDay
    }
}

// ----- Errors

public enum LedgerError: Error {
    case cacheMissing
    case savingsWouldGoNegative(dayStart: Date)
}
