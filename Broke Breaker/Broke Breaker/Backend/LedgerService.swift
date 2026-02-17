import Foundation
import SwiftData
import Vapor
import Fluent

// ----- BFF structs

/// One line item shown for a day
struct DayLineItem: Identifiable {
    enum Source {
        case oneTime(id: PersistentIdentifier)
        case recurring(id: PersistentIdentifier)
    }

    let id = UUID()
    let title: String
    let amount: Decimal
    let source: Source
}

/// Detailed breakdown for one day
struct DayOverview {
    let dayStart: Date
    let items: [DayLineItem]
    let netTotal: Decimal
}

/// Totals + rollover for one day
struct DayTotals {
    let dayStart: Date
    let netTotal: Decimal
    let runningBalanceEndOfDay: Decimal
}

// ----- Recurrence Definition (repeating only)

enum Recurrence: Hashable, Sendable {
    case everyDays(Int)
    case everyWeeks(Int)
    case everyMonths(Int)
    case everyYears(Int)
}

// ----- stored structs

@Model
final class OneTimeTransaction {
    var title: String
    var date: Date
    var amount: Decimal

    init(title: String, date: Date, amount: Decimal) {
        self.title = title
        self.date = date
        self.amount = amount
    }
}

@Model
final class RecurringRule {
    var title: String
    var amountPerCycle: Decimal
    var startDate: Date
    var endDate: Date?

    // SwiftData cant store enums with values directly, so data must be encoded
    var recurrenceUnit: Int // 0=days, 1=weeks, 2=months, 3=years
    var recurrenceInterval: Int

    init(title: String,
         amountPerCycle: Decimal,
         startDate: Date,
         endDate: Date?,
         recurrence: Recurrence)
    {
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

    var recurrence: Recurrence {
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

@Model
final class DailyCacheEntry {
    @Attribute(.unique) var dayStart: Date // unique key

    var netFromOneTime: Decimal
    var netFromRecurring: Decimal
    var netTotal: Decimal
    var runningBalanceEndOfDay: Decimal

    init(dayStart: Date,
         netFromOneTime: Decimal,
         netFromRecurring: Decimal,
         netTotal: Decimal,
         runningBalanceEndOfDay: Decimal)
    {
        self.dayStart = dayStart
        self.netFromOneTime = netFromOneTime
        self.netFromRecurring = netFromRecurring
        self.netTotal = netTotal
        self.runningBalanceEndOfDay = runningBalanceEndOfDay
    }
}

// ----- Main ledger class

final class LedgerService {

    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // ----- Public Write API

    @discardableResult
    func addOneTime(title: String, date: Date, amount: Decimal) throws -> OneTimeTransaction {
        let tx = OneTimeTransaction(title: title, date: date, amount: amount)
        context.insert(tx)

        let d = dayStart(date)
        try invalidateCache(from: d)
        try ensureCachedThrough(day: today())
        try context.save()
        return tx
    }

    @discardableResult
    func addRecurring(title: String,
                      amountPerCycle: Decimal,
                      startDate: Date,
                      endDate: Date?,
                      recurrence: Recurrence) throws -> RecurringRule
    {
        let rule = RecurringRule(title: title,
                                 amountPerCycle: amountPerCycle,
                                 startDate: startDate,
                                 endDate: endDate,
                                 recurrence: recurrence)
        context.insert(rule)

        try invalidateCache(from: dayStart(startDate))
        try ensureCachedThrough(day: today())
        try context.save()
        return rule
    }

    func updateOneTime(_ tx: OneTimeTransaction,
                       title: String? = nil,
                       date: Date? = nil,
                       amount: Decimal? = nil) throws
    {
        let oldDay = dayStart(tx.date)

        if let title { tx.title = title }
        if let date  { tx.date = date }
        if let amount { tx.amount = amount }

        let newDay = dayStart(tx.date)
        let earliest = min(oldDay, newDay)

        try invalidateCache(from: earliest)
        try ensureCachedThrough(day: today())
        try context.save()
    }

    enum EndDateUpdate {
        case keep
        case clear
        case set(Date)
    }
    func updateRecurring(_ rule: RecurringRule,
                         title: String? = nil,
                         amountPerCycle: Decimal? = nil,
                         startDate: Date? = nil,
                         endDate: EndDateUpdate = .keep,
                         recurrence: Recurrence? = nil) throws
    {
        let oldStart = dayStart(rule.startDate)

        if let title { rule.title = title }
        if let amountPerCycle { rule.amountPerCycle = amountPerCycle }
        if let startDate { rule.startDate = startDate }
        if let recurrence { rule.recurrence = recurrence }

        switch endDate {
        case .keep:
            break
        case .clear:
            rule.endDate = nil
        case .set(let d):
            rule.endDate = d
        }

        let newStart = dayStart(rule.startDate)
        let earliest = min(oldStart, newStart)

        try invalidateCache(from: earliest)
        try ensureCachedThrough(day: today())
        try context.save()
    }

    func deleteOneTime(_ tx: OneTimeTransaction) throws {
        let d = dayStart(tx.date)
        context.delete(tx)

        try invalidateCache(from: d)
        try ensureCachedThrough(day: today())
        try context.save()
    }

    func deleteRecurring(_ rule: RecurringRule) throws {
        let d = dayStart(rule.startDate)
        context.delete(rule)

        try invalidateCache(from: d)
        try ensureCachedThrough(day: today())
        try context.save()
    }

    // ----- Public Read API

    func dayOverview(for date: Date) throws -> DayOverview {
        let day = dayStart(date)

        // if no entries yet or before first entry, return empty day
        guard let ledgerStart = try earliestLedgerDay() else {
            return DayOverview(dayStart: day, items: [], netTotal: 0)
        }
        if day < ledgerStart {
            return DayOverview(dayStart: day, items: [], netTotal: 0)
        }

        try ensureCachedThrough(day: max(day, today()))

        let oneTimes = try fetchOneTimes(on: day)
        let rules = try fetchAllRecurringRules()

        var items: [DayLineItem] = []

        // collect recurring & one-time entries
        for rule in rules {
            let amt = contribution(for: rule, on: day)
            if amt != 0 {
                items.append(DayLineItem(
                    title: rule.title,
                    amount: amt,
                    source: .recurring(id: rule.persistentModelID)
                ))
            }
        }
        for tx in oneTimes {
            items.append(DayLineItem(
                title: tx.title,
                amount: tx.amount,
                source: .oneTime(id: tx.persistentModelID)
            ))
        }

        let net = items.reduce(Decimal(0)) { $0 + $1.amount }
        return DayOverview(dayStart: day, items: items, netTotal: net)
    }

    func dayTotals(for date: Date) throws -> DayTotals {
        let day = dayStart(date)

        // if no entries yet or before first entry, return empty day
        guard let ledgerStart = try earliestLedgerDay() else {
            return DayTotals(dayStart: day, netTotal: 0, runningBalanceEndOfDay: 0)
        }
        if day < ledgerStart {
            return DayTotals(dayStart: day, netTotal: 0, runningBalanceEndOfDay: 0)
        }

        try ensureCachedThrough(day: max(day, today()))

        guard let entry = try fetchCacheEntry(for: day) else {
            throw LedgerError.cacheMissing
        }

        return DayTotals(dayStart: entry.dayStart,
                         netTotal: entry.netTotal,
                         runningBalanceEndOfDay: entry.runningBalanceEndOfDay)
    }

    func balanceEndOfDay(on date: Date) throws -> Decimal {
        try dayTotals(for: date).runningBalanceEndOfDay
    }

    // ----- Cache Logic

    // ensure cache reaches as far as "day"
    private func ensureCachedThrough(day requested: Date) throws {
        let target = dayStart(requested)

        // if no entries yet or before first entry, return
        guard let ledgerStart = try earliestLedgerDay() else { return }
        if target < ledgerStart { return }

        if let lastCached = try fetchLastCachedDay() {
            if lastCached >= target { return } // already far enough cached

            // append from day after lastCached up to target
            let start = calendar.date(byAdding: .day, value: 1, to: lastCached)!
            try computeAndAppendCache(from: start, through: target)
        } else {
            // no cache, create new
            try computeAndAppendCache(from: ledgerStart, through: target)
        }
    }
    // delete cache starting from "day" forward
    private func invalidateCache(from day: Date) throws {
        let d = dayStart(day)

        let descriptor = FetchDescriptor<DailyCacheEntry>(
            predicate: #Predicate { $0.dayStart >= d }
        )
        let entries = try context.fetch(descriptor)
        for e in entries { context.delete(e) }
    }
    // Compute & store cache between specified days
    private func computeAndAppendCache(from startDay: Date, through endDay: Date) throws {
        let rules = try fetchAllRecurringRules()

        let runningBeforeStart: Decimal = try {
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: startDay),
               let prev = try fetchCacheEntry(for: dayBefore) {
                return prev.runningBalanceEndOfDay
            }
            return 0
        }()

        var running = runningBeforeStart
        var day = startDay

        while day <= endDay {
            let oneTimeNet = try netOneTimes(on: day)

            var recurringNet: Decimal = 0
            for rule in rules {
                recurringNet += contribution(for: rule, on: day)
            }

            let netTotal = oneTimeNet + recurringNet
            running += netTotal

            let entry = DailyCacheEntry(dayStart: day,
                                        netFromOneTime: oneTimeNet,
                                        netFromRecurring: recurringNet,
                                        netTotal: netTotal,
                                        runningBalanceEndOfDay: running)
            context.insert(entry)

            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        try context.save()
    }

    // ----- Recurring Contribution Utils

    // Returns how much this recurring rule contributes on a given day (start-of-day).
    private func contribution(for rule: RecurringRule, on day: Date) -> Decimal {
        let d = dayStart(day)
        let start = dayStart(rule.startDate)

        // not started yet
        if d < start { return 0 }
        // already passed
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
    // for calendar-based time durations, gotta check calendar first
    private func proratedCalendar(rule: RecurringRule,
                                 on day: Date,
                                 component: Calendar.Component,
                                 step: Int) -> Decimal {
        let anchor = dayStart(rule.startDate)

        var cycleStart = anchor
        while true {
            guard let next = calendar.date(byAdding: component, value: step, to: cycleStart) else { break }
            if next <= day {
                cycleStart = next
            } else {
                break
            }
        }

        let nextCycleStart = calendar.date(byAdding: component, value: step, to: cycleStart)!
        let cycleDays = max(1, calendar.dateComponents([.day], from: cycleStart, to: nextCycleStart).day ?? 1)

        return safeDivide(rule.amountPerCycle, by: cycleDays)
    }

    // ----- Fetch Utils

    // earliest day anything happened
    private func earliestLedgerDay() throws -> Date? {
        let earliestTx = try fetchEarliestTransactionDay()
        let earliestRule = try fetchEarliestRuleDay()

        switch (earliestTx, earliestRule) {
            case (nil, nil): return nil
            case (let a?, nil): return a
            case (nil, let b?): return b
            case (let a?, let b?): return min(a, b)
        }
    }

    // earliest one-time transaction dayStart
    private func fetchEarliestTransactionDay() throws -> Date? {
        var descriptor = FetchDescriptor<OneTimeTransaction>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { dayStart($0.date) }
    }
    // earliest recurring dayStart
    private func fetchEarliestRuleDay() throws -> Date? {
        var descriptor = FetchDescriptor<RecurringRule>()
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { dayStart($0.startDate) }
    }

    private func fetchAllRecurringRules() throws -> [RecurringRule] {
        try context.fetch(FetchDescriptor<RecurringRule>())
    }

    // fetch one-time transactions that happen on 'day'
    private func fetchOneTimes(on day: Date) throws -> [OneTimeTransaction] {
        let start = dayStart(day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let descriptor = FetchDescriptor<OneTimeTransaction>(
            predicate: #Predicate { tx in
                tx.date >= start && tx.date < end
            }
        )
        return try context.fetch(descriptor)
    }

    // one-time transactions on "day" sum
    private func netOneTimes(on day: Date) throws -> Decimal {
        let txs = try fetchOneTimes(on: day)
        return txs.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func fetchCacheEntry(for day: Date) throws -> DailyCacheEntry? {
        let d = dayStart(day)
        let descriptor = FetchDescriptor<DailyCacheEntry>(
            predicate: #Predicate { $0.dayStart == d }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchLastCachedDay() throws -> Date? {
        var descriptor = FetchDescriptor<DailyCacheEntry>()
        descriptor.sortBy = [SortDescriptor(\.dayStart, order: .reverse)]
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.dayStart
    }

    // ----- General utils

    /// Normalize to start-of-day (midnight) so "days" are stable keys.
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

// ----- Errors

enum LedgerError: Error {
    case cacheMissing
}
