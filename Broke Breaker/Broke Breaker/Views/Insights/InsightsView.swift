import SwiftUI
import SharedLedger
struct InsightsView: View {
    let ledger = Ledger.shared

    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    ) ?? .now
    @State private var weeklyTotals: [Date: DayTotals] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Insights")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                // Week selector
                weekHeader

                // Summary and chart card
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Week")
                        .font(.title2).bold()

                    HStack(spacing: 12) {
                        let summary = weeklySummary()
                        insightBadge(title: "Income", value: summary.income, color: .blue)
                        insightBadge(title: "Expense", value: summary.expense, color: .red)
                        Spacer()
                    }

                    WeeklyLineChart(weekStart: weekStart, weeklyTotals: weeklyTotals)
                        .frame(height: 160)
                }
                .padding(12)
                .glassEffect(in: .rect(cornerRadius: 16))

                // Additional space for future insights (monthly, categories, etc.)
            }
            .padding(.horizontal)
        }
        .onAppear { loadWeeklyTotals() }
    }

    private var weekHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Text(weekTitle(for: weekStart))
                .font(.headline)
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            Button {
                shiftWeek(by: 1)
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

    private func weekTitle(for start: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let startStr = df.string(from: start)
        let endStr = df.string(from: end)
        return "\(startStr) – \(endStr)"
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

    @ViewBuilder
    private func insightBadge(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            let sign = value >= 0 ? "+" : ""
            Text("\(sign)\(value, format: .number.precision(.fractionLength(2)))")
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chart
extension InsightsView {
    private struct WeeklyLineChart: View {
        let weekStart: Date
        let weeklyTotals: [Date: DayTotals]

        private var points: [(Date, Double)] {
            let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
            return days.map { day in
                let end: Decimal = weeklyTotals[day]?.runningBalanceMainEndOfDay ?? 0
                let val = NSDecimalNumber(decimal: end).doubleValue
                return (day, val)
            }
        }

        private var weekdayFormatter: DateFormatter {
            let df = DateFormatter()
            df.dateFormat = "E"
            return df
        }

        private var range: (min: Double, max: Double) {
            let vals = points.map { $0.1 }
            let minV = vals.min() ?? 0
            let maxV = vals.max() ?? 0
            if minV == maxV { return (minV - 1, maxV + 1) }
            return (minV, maxV)
        }

        var body: some View {
            GeometryReader { geo in
                let size = geo.size
                ChartCanvas(size: size, points: points, range: range)
                    .overlay(alignment: .bottom) {
                        HStack {
                            ForEach(0..<points.count, id: \.self) { i in
                                Text(weekdayFormatter.string(from: points[i].0))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
            }
        }
    }

    // Nested canvas view to simplify ViewBuilder
    private struct ChartCanvas: View {
        let size: CGSize
        let points: [(Date, Double)]
        let range: (min: Double, max: Double)
        
        var body: some View {
            Group {
                let w = size.width
                let h = size.height
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
                    return h - CGFloat(yNorm) * h
                }
                
                ZStack {
                    // Line
                    Path { path in
                        guard !xs.isEmpty, !ys.isEmpty else { return }
                        path.move(to: CGPoint(x: xs[0], y: ys[0]))
                        for i in 1..<xs.count {
                            path.addLine(to: CGPoint(x: xs[i], y: ys[i]))
                        }
                    }
                    .stroke(.primary.opacity(0.25), lineWidth: 2)
                    
                    // Area
                    Path { path in
                        guard !xs.isEmpty, !ys.isEmpty else { return }
                        path.move(to: CGPoint(x: xs[0], y: h))
                        for i in 0..<xs.count {
                            path.addLine(to: CGPoint(x: xs[i], y: ys[i]))
                        }
                        path.addLine(to: CGPoint(x: xs.last ?? 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(.primary.opacity(0.08))
                    
                    // Points
                    ForEach(0..<xs.count, id: \.self) { i in
                        let x = xs[i]
                        let y = ys[i]
                        Circle()
                            .fill(points[i].1 >= 0 ? Color.blue : Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

#Preview {
    InsightsView()
}
