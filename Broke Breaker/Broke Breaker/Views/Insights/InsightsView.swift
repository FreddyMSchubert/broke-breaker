import SwiftUI
import SharedLedger

enum Period: String, CaseIterable { case weekly = "Weekly", monthly = "Monthly", biannual = "Biannual" }
enum ChartMode: String, CaseIterable { case line = "Line", bars = "Bars" }

struct InsightsView: View {
    let ledger = Ledger.shared

    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    ) ?? .now
    @State private var weeklyTotals: [Date: DayTotals] = [:]

    @State private var period: Period = .weekly
    @State private var navigateToList = false
    @State private var selectedDateForNavigation: Date? = nil
    @State private var chartMode: ChartMode = .line

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Insights")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    // Week selector
                    weekHeader

                    HStack(spacing: 12) {
                        // Period menu
                        Menu {
                            ForEach(Period.allCases, id: \.self) { p in
                                Button(action: { period = p }) { Label(p.rawValue, systemImage: period == p ? "checkmark" : "") }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(period.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .tint(.primary)

                        // Chart mode menu
                        Menu {
                            Button(action: { chartMode = .line }) { Label("Line", systemImage: chartMode == .line ? "checkmark" : "") }
                            Button(action: { chartMode = .bars }) { Label("Bars", systemImage: chartMode == .bars ? "checkmark" : "") }
                        } label: {
                            HStack(spacing: 8) {
                                Text(chartMode.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .tint(.primary)

                        Spacer()
                    }
                    .onChange(of: period) { _, _ in
                        // Recompute data for selected period
                        // Weekly uses cached weeklyTotals; others fetch on demand
                    }

                    // Summary and chart card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            let summary = periodSummary()
                            insightBadge(title: "Income", value: summary.income, color: .blue)
                            insightBadge(title: "Expense", value: summary.expense, color: .red, isExpense: true)
                            Spacer()
                        }

                        Group {
                            switch chartMode {
                            case .line:
                                if period == .monthly {
                                    let dayCount = currentMonthDaysCount()
                                    let perDayWidth: CGFloat = 36
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        InsightsLineChart(points: chartPointsLine(), formatter: chartLabelFormatter(), tapEnabledDates: interactiveDates()) { date in
                                            NotificationCenter.default.post(name: .showListForDate, object: date)
                                        }
                                        .frame(width: CGFloat(dayCount) * perDayWidth, height: 180)
                                    }
                                    .padding(.top, 6)
                                } else {
                                    InsightsLineChart(points: chartPointsLine(), formatter: chartLabelFormatter(), tapEnabledDates: interactiveDates()) { date in
                                        NotificationCenter.default.post(name: .showListForDate, object: date)
                                    }
                                    .frame(height: 180)
                                    .padding(.top, 6)
                                }
                            case .bars:
                                if period == .monthly {
                                    let dayCount = currentMonthDaysCount()
                                    let perDayWidth: CGFloat = 36
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        SpendingBarChart(bins: spendingBins(), formatter: chartLabelFormatter()) { date in
                                            NotificationCenter.default.post(name: .showListForDate, object: date)
                                        }
                                        .frame(width: CGFloat(dayCount) * perDayWidth, height: 180)
                                    }
                                    .padding(.top, 6)
                                } else {
                                    SpendingBarChart(bins: spendingBins(), formatter: chartLabelFormatter()) { date in
                                        NotificationCenter.default.post(name: .showListForDate, object: date)
                                    }
                                    .frame(height: 180)
                                    .padding(.top, 6)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 16))

                    // Savings card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Savings")
                            .font(.title3).bold()

                        HStack(spacing: 12) {
                            let s = periodSavingsSummary()
                            insightBadge(title: "Saved", value: s.saved, color: .blue)
                            insightBadge(title: "Withdrawn", value: s.withdrawn, color: .red, isExpense: true)
                            Spacer()
                        }

                        Group {
                            switch chartMode {
                            case .line:
                                if period == .monthly {
                                    let dayCount = currentMonthDaysCount()
                                    let perDayWidth: CGFloat = 36
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        InsightsLineChart(points: chartPointsSavingsLine(), formatter: chartLabelFormatter(), tapEnabledDates: interactiveSavingsDates()) { date in
                                            NotificationCenter.default.post(name: .showListForDate, object: date)
                                        }
                                        .frame(width: CGFloat(dayCount) * perDayWidth, height: 180)
                                    }
                                    .padding(.top, 6)
                                } else {
                                    InsightsLineChart(points: chartPointsSavingsLine(), formatter: chartLabelFormatter(), tapEnabledDates: interactiveSavingsDates()) { date in
                                        NotificationCenter.default.post(name: .showListForDate, object: date)
                                    }
                                    .frame(height: 180)
                                    .padding(.top, 6)
                                }
                            case .bars:
                                if period == .monthly {
                                    let dayCount = currentMonthDaysCount()
                                    let perDayWidth: CGFloat = 36
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        SpendingBarChart(bins: savingsBins(), formatter: chartLabelFormatter()) { date in
                                            NotificationCenter.default.post(name: .showListForDate, object: date)
                                        }
                                        .frame(width: CGFloat(dayCount) * perDayWidth, height: 180)
                                    }
                                    .padding(.top, 6)
                                } else {
                                    SpendingBarChart(bins: savingsBins(), formatter: chartLabelFormatter()) { date in
                                        NotificationCenter.default.post(name: .showListForDate, object: date)
                                    }
                                    .frame(height: 180)
                                    .padding(.top, 6)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 16))

                    // Additional space for future insights (monthly, categories, etc.)
                }
                .padding(.horizontal)
            }
            .onAppear { loadWeeklyTotals() }
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftPeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Text(periodTitle())
                .font(.headline)
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            Button {
                shiftPeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }
}

// MARK: - Helpers
extension InsightsView {
    private func shiftWeek(by offset: Int) {
        if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) {
            weekStart = newStart
            loadWeeklyTotals()
        }
    }

    private func shiftPeriod(by offset: Int) {
        let cal = Calendar.current
        switch period {
        case .weekly:
            if let newStart = cal.date(byAdding: .weekOfYear, value: offset, to: weekStart) {
                weekStart = newStart
                loadWeeklyTotals()
            }
        case .monthly:
            // Move the anchor month by offset, keep day = 1
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            if let newMonth = cal.date(byAdding: .month, value: offset, to: anchor) {
                weekStart = newMonth
                loadWeeklyTotals()
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            if let newMonth = cal.date(byAdding: .month, value: offset, to: anchor) {
                weekStart = newMonth
                loadWeeklyTotals()
            }
        }
    }

    private func weekTitle(for start: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let startStr = df.string(from: start)
        let endStr = df.string(from: end)
        return "\(startStr) – \(endStr)"
    }

    private func periodTitle() -> String {
        switch period {
        case .weekly:
            return weekTitle(for: weekStart)
        case .monthly:
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let start = cal.date(byAdding: .month, value: -5, to: monthStart) ?? monthStart
            let end = monthStart
            let df = DateFormatter()
            df.dateFormat = "MMM yyyy"
            return "\(df.string(from: start)) – \(df.string(from: end))"
        case .biannual:
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let start = cal.date(byAdding: .month, value: -5, to: anchor) ?? anchor
            let df = DateFormatter()
            df.dateFormat = "MMM yyyy"
            return "\(df.string(from: start)) – \(df.string(from: anchor))"
        }
    }

    private func loadWeeklyTotals() {
        weeklyTotals.removeAll()
        for i in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart),
               let totals = try? ledger.dayTotals(for: day) {
                weeklyTotals[day] = totals
            }
        }
    }

    private func formatMoney(_ value: Double, signed: Bool = true) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let absStr = nf.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
        if signed {
            let sign = value >= 0 ? "+" : "-"
            return value == 0 ? "+0.00" : "\(sign)\(absStr)"
        } else {
            return absStr
        }
    }

    private func formatExpense(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let absStr = nf.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
        return "-\(absStr)"
    }

    private func weeklySummary() -> (income: Double, expense: Double) {
        var income: Double = 0
        var expense: Double = 0
        for i in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart) else { continue }
            if let overview = try? ledger.dayOverview(for: day) {
                for item in overview.items {
                    let val = NSDecimalNumber(decimal: item.mainAmount).doubleValue
                    if val > 0 { income += val } else if val < 0 { expense += val }
                }
            } else if let totals = weeklyTotals[day] {
                let prev = Calendar.current.date(byAdding: .day, value: -1, to: day)
                let prevEnd: Decimal = {
                    guard let p = prev else { return 0 }
                    return (try? ledger.dayTotals(for: p).runningBalanceMainEndOfDay) ?? 0
                }()
                let end: Decimal = totals.runningBalanceMainEndOfDay
                let prevEndDecimal: Decimal = prevEnd
                let diff: Decimal = end - prevEndDecimal
                let delta: Double = NSDecimalNumber(decimal: diff).doubleValue
                if delta >= 0 { income += delta } else { expense += delta }
            }
        }
        return (income, expense)
    }

    private func anchorDayForPeriod() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch period {
        case .weekly:
            // Anchor at today if it's within the displayed week, else first day of week
            let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }.map { cal.startOfDay(for: $0) }
            if weekDays.contains(cal.startOfDay(for: today)) { return today }
            return weekDays.first ?? today
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let start = cal.date(from: comps) ?? weekStart
            let monthDays = (0..<(cal.range(of: .day, in: .month, for: start)?.count ?? 30)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }.map { cal.startOfDay(for: $0) }
            if monthDays.contains(today) { return today }
            return monthDays.first ?? today
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            let monthDays = months.flatMap { month -> [Date] in
                let next = cal.date(byAdding: .month, value: 1, to: month) ?? month
                var days: [Date] = []
                var d = month
                while d < next {
                    days.append(cal.startOfDay(for: d))
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? d
                    if d == month { break }
                }
                return days
            }
            if monthDays.contains(today) { return today }
            return monthDays.first ?? today
        }
    }

    private func chartPoints() -> [(Date, Double)] {
        let cal = Calendar.current
        let anchor = anchorDayForPeriod()
        let anchorEnd: Decimal = (try? ledger.dayTotals(for: anchor).runningBalanceMainEndOfDay) ?? 0
        switch period {
        case .weekly:
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                let end = (try? ledger.dayTotals(for: day).runningBalanceMainEndOfDay) ?? 0
                let val = NSDecimalNumber(decimal: end - anchorEnd).doubleValue
                return (day, val)
            }
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
            let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: monthStart) }
            return days.map { day in
                let end = (try? ledger.dayTotals(for: day).runningBalanceMainEndOfDay) ?? 0
                let val = NSDecimalNumber(decimal: end - anchorEnd).doubleValue
                return (day, val)
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            return months.map { m in
                let end = (try? ledger.dayTotals(for: m).runningBalanceMainEndOfDay) ?? 0
                let val = NSDecimalNumber(decimal: end - anchorEnd).doubleValue
                return (m, val)
            }
        }
    }

    private func chartPointsLine() -> [(Date, Double)] {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let net = overview.items.map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }.reduce(0, +)
                    return (day, net)
                } else { return (day, 0) }
            }
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
            let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: monthStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let net = overview.items.map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }.reduce(0, +)
                    return (day, net)
                } else { return (day, 0) }
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            return months.map { m in
                let next = cal.date(byAdding: .month, value: 1, to: m) ?? m
                var sum: Double = 0
                var d = m
                while d < next {
                    if let overview = try? ledger.dayOverview(for: d) {
                        sum += overview.items.map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }.reduce(0, +)
                    }
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? d
                    if d == m { break }
                }
                return (m, sum)
            }
        }
    }

    private func periodSavingsSummary() -> (saved: Double, withdrawn: Double) {
        let cal = Calendar.current
        let range = periodDateRange()
        var saved: Double = 0
        var withdrawn: Double = 0
        var day = cal.startOfDay(for: range.start)
        let endDay = cal.startOfDay(for: range.end)
        while day <= endDay {
            if let overview = try? ledger.dayOverview(for: day) {
                for item in overview.items {
                    let v = NSDecimalNumber(decimal: item.savingsAmount).doubleValue
                    if v > 0 { saved += v } else if v < 0 { withdrawn += abs(v) }
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (saved, withdrawn)
    }

    private func savingsBins() -> [(Date, Double)] {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let sum = overview.items.map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }.filter { $0 > 0 }.reduce(0, +)
                    return (day, sum)
                } else { return (day, 0) }
            }
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
            let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: monthStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let sum = overview.items
                        .map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }
                        .filter { $0 > 0 }
                        .reduce(0, +)
                    return (day, sum)
                } else { return (day, 0) }
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            return months.map { m in
                let next = cal.date(byAdding: .month, value: 1, to: m) ?? m
                var sum: Double = 0
                var d = m
                while d < next {
                    if let ov = try? ledger.dayOverview(for: d) {
                        sum += ov.items
                            .map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }
                            .filter { $0 > 0 }
                            .reduce(0, +)
                    }
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? d
                    if d == m { break }
                }
                return (m, sum)
            }
        }
    }

    private func chartPointsSavingsLine() -> [(Date, Double)] {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let net = overview.items.map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }.reduce(0, +)
                    return (day, net)
                } else { return (day, 0) }
            }
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
            let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: monthStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let net = overview.items.map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }.reduce(0, +)
                    return (day, net)
                } else { return (day, 0) }
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            return months.map { m in
                let next = cal.date(byAdding: .month, value: 1, to: m) ?? m
                var sum: Double = 0
                var d = m
                while d < next {
                    if let overview = try? ledger.dayOverview(for: d) {
                        sum += overview.items.map { NSDecimalNumber(decimal: $0.savingsAmount).doubleValue }.reduce(0, +)
                    }
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? d
                    if d == m { break }
                }
                return (m, sum)
            }
        }
    }

    private func interactiveDates() -> Set<Date> {
        let cal = Calendar.current
        let pts: [(Date, Double)] = (chartMode == .line) ? chartPointsLine() : spendingBins()
        return Set(pts.filter { abs($0.1) > 0.0001 }.map { cal.startOfDay(for: $0.0) })
    }

    private func interactiveSavingsDates() -> Set<Date> {
        let cal = Calendar.current
        let pts: [(Date, Double)] = (chartMode == .line) ? chartPointsSavingsLine() : savingsBins()
        return Set(pts.filter { abs($0.1) > 0.0001 }.map { cal.startOfDay(for: $0.0) })
    }

    @ViewBuilder
    private func insightBadge(title: String, value: Double, color: Color, isExpense: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isExpense ? formatExpense(value) : formatMoney(value))
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func periodDateRange() -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let start = weekStart
            let end = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return (start, end)
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let start = cal.date(byAdding: .month, value: -5, to: monthStart) ?? monthStart
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
            return (start, end)
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let start = cal.date(byAdding: .month, value: -5, to: anchor) ?? anchor
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: anchor) ?? anchor
            return (start, end)
        }
    }
    
    private func periodSummary() -> (income: Double, expense: Double) {
        let cal = Calendar.current
        let range = periodDateRange()
        var income: Double = 0
        var expense: Double = 0
        var day = cal.startOfDay(for: range.start)
        let endDay = cal.startOfDay(for: range.end)
        while day <= endDay {
            if let overview = try? ledger.dayOverview(for: day) {
                for item in overview.items {
                    let val = NSDecimalNumber(decimal: item.mainAmount).doubleValue
                    if val > 0 { income += val } else if val < 0 { expense += val }
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (income, expense)
    }
    
    private func currentMonthDaysCount() -> Int {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: weekStart)
        comps.day = 1
        let monthStart = cal.date(from: comps) ?? weekStart
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        return range.count
    }
}

// MARK: - Chart
extension InsightsView {
    private struct InsightsLineChart: View {
        let points: [(Date, Double)]
        let formatter: DateFormatter
        let tapEnabledDates: Set<Date>
        let onTap: (Date) -> Void

        private var range: (min: Double, max: Double) {
            let vals = points.map { $0.1 }
            var minV = vals.min() ?? 0
            var maxV = vals.max() ?? 0
            // Ensure zero is visible
            if minV > 0 { minV = 0 }
            if maxV < 0 { maxV = 0 }
            if minV == maxV { minV -= 1; maxV += 1 }
            let pad = max(0.1, (maxV - minV) * 0.2)
            return (minV - pad, maxV + pad)
        }

        var body: some View {
            GeometryReader { geo in
                let size = geo.size
                VStack(spacing: 6) {
                    ChartCanvas(size: size, points: points, range: range, tapEnabledDates: tapEnabledDates, onTap: onTap)
                        .frame(height: size.height - 22)
                        .clipped()
                    XAxisLabels(points: points, formatter: formatter)
                        .padding(.top, 6)
                }
            }
        }
    }

    private struct ChartCanvas: View {
        let size: CGSize
        let points: [(Date, Double)]
        let range: (min: Double, max: Double)
        let tapEnabledDates: Set<Date>
        let onTap: (Date) -> Void

        var body: some View {
            Group {
                let w = size.width
                let h = size.height
                let topInset: CGFloat = 8
                let bottomInset: CGFloat = 12
                let drawableH = max(0, h - topInset - bottomInset)
                let count = max(points.count, 1)
                let xs: [CGFloat] = (0..<count).map { i in
                    if count <= 1 { return 0 }
                    return CGFloat(i) / CGFloat(count - 1) * w
                }
                let minV = range.min
                let maxV = range.max
                let denom = max(maxV - minV, 0.0001)
                let ys: [CGFloat] = points.map { p in
                    let yNorm = (p.1 - minV) / denom
                    return topInset + (drawableH - CGFloat(yNorm) * drawableH)
                }
                let yZero: CGFloat? = (minV...maxV).contains(0) ? (topInset + (drawableH - CGFloat((0 - minV) / denom) * drawableH)) : nil

                ZStack {
                    // Soft glow underlay
                    Path { path in
                        guard !xs.isEmpty, !ys.isEmpty else { return }
                        path.move(to: CGPoint(x: xs[0], y: ys[0]))
                        for i in 1..<xs.count { path.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                    }
                    .stroke(Color.primary.opacity(0.15), lineWidth: 6)

                    // Main line
                    Path { path in
                        guard !xs.isEmpty, !ys.isEmpty else { return }
                        path.move(to: CGPoint(x: xs[0], y: ys[0]))
                        for i in 1..<xs.count { path.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Area gradient fill
                    Path { path in
                        guard !xs.isEmpty, !ys.isEmpty else { return }
                        path.move(to: CGPoint(x: xs[0], y: topInset + drawableH))
                        for i in 0..<xs.count { path.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                        path.addLine(to: CGPoint(x: xs.last ?? 0, y: topInset + drawableH))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                    // Baseline at y = 0
                    if let y0 = yZero {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y0))
                            path.addLine(to: CGPoint(x: w, y: y0))
                        }
                        .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }

                    // Points with subtle shadow
                    ForEach(0..<xs.count, id: \.self) { i in
                        let x = xs[i]
                        let y = ys[i]
                        Circle()
                            .fill(points[i].1 >= 0 ? Color.blue : Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .position(x: x, y: y)
                    }

                    // Invisible larger hit areas for interactive points
                    ForEach(0..<xs.count, id: \.self) { i in
                        let x = xs[i]
                        let y = ys[i]
                        let day = Calendar.current.startOfDay(for: points[i].0)
                        if tapEnabledDates.contains(day) {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .position(x: x, y: y)
                                .onTapGesture { onTap(points[i].0) }
                        }
                    }
                }
            }
        }
    }

    private struct XAxisLabels: View {
        let points: [(Date, Double)]
        let formatter: DateFormatter
        var body: some View {
            let count = points.count
            let labels = points.map { formatter.string(from: $0.0) }
            let unique = Set(labels)
            // If all labels are the same (e.g., one month), show it once centered
            if unique.count == 1, let only = labels.first {
                HStack {
                    Spacer()
                    Text(only)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                let stride = max(1, count / 7)
                HStack {
                    ForEach(0..<count, id: \.self) { i in
                        let label = labels[i]
                        // Show first, last, and every 'stride' index, avoid repeating same consecutive labels
                        let prevIndex = max(0, i - stride)
                        let show = (i == 0) || (i == count - 1) || (i % stride == 0 && labels[prevIndex] != label)
                        if show {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(" ")
                                .font(.caption2)
                                .opacity(0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private struct SpendingBarChart: View {
        let bins: [(Date, Double)]
        let formatter: DateFormatter
        var onTap: ((Date) -> Void)? = nil

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxV = max(bins.map { $0.1 }.max() ?? 1, 1)
                let barW = max(10, w / CGFloat(max(bins.count, 1)) * 0.6)
                let spacing = (w - (barW * CGFloat(max(bins.count, 1)))) / CGFloat(max(bins.count - 1, 1))
                let baseY = h - 22 // leave space for labels underneath

                ZStack(alignment: .bottomLeading) {
                    // Full-column transparent hit areas (above labels)
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(0..<bins.count, id: \.self) { i in
                            // Column frame spans from top down to just above the label row
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: barW, height: max(0, baseY - 4))
                                .contentShape(Rectangle())
                                .onTapGesture { onTap?(bins[i].0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Bars
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(0..<bins.count, id: \.self) { i in
                            let v = bins[i].1
                            let hNorm = CGFloat(v / maxV)
                            let barH = (baseY - 8) * hNorm
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.8))
                                .frame(width: barW, height: max(2, barH))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .onTapGesture { onTap?(bins[i].0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Labels
                    HStack(spacing: spacing) {
                        ForEach(0..<bins.count, id: \.self) { i in
                            Text(formatter.string(from: bins[i].0))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: barW, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .position(x: w/2, y: baseY + 10)
                }
            }
        }
    }
}

// Added extension with missing helpers
extension InsightsView {
    // Formatter for x-axis labels based on current period
    private func chartLabelFormatter() -> DateFormatter {
        let df = DateFormatter()
        switch period {
        case .weekly:
            df.dateFormat = "E"
        case .monthly:
            df.dateFormat = "d"
        case .biannual:
            df.dateFormat = "MMM"
        }
        return df
    }
    // Spending-only bins (negative main amounts summed as positive values)
    private func spendingBins() -> [(Date, Double)] {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let sum = overview.items
                        .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
                        .filter { $0 < 0 }
                        .reduce(0) { $0 + abs($1) }
                    return (day, sum)
                } else {
                    return (day, 0)
                }
            }
        case .monthly:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let monthStart = cal.date(from: comps) ?? weekStart
            let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
            let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: monthStart) }
            return days.map { day in
                if let overview = try? ledger.dayOverview(for: day) {
                    let sum = overview.items
                        .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
                        .filter { $0 < 0 }
                        .reduce(0) { $0 + abs($1) }
                    return (day, sum)
                } else { return (day, 0) }
            }
        case .biannual:
            var comps = cal.dateComponents([.year, .month], from: weekStart)
            comps.day = 1
            let anchor = cal.date(from: comps) ?? weekStart
            let months = (0...5).compactMap { back -> Date? in
                cal.date(byAdding: .month, value: -(5 - back), to: anchor)
            }
            return months.map { m in
                let next = cal.date(byAdding: .month, value: 1, to: m) ?? m
                var sum: Double = 0
                var d = m
                while d < next {
                    if let ov = try? ledger.dayOverview(for: d) {
                        sum += ov.items
                            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
                            .filter { $0 < 0 }
                            .reduce(0) { $0 + abs($1) }
                    }
                    d = cal.date(byAdding: .day, value: 1, to: d) ?? d
                    if d == m { break }
                }
                return (m, sum)
            }
        }
    }
}

extension Notification.Name {
    static let showListForDate = Notification.Name("ShowListForDate")
}

