import SwiftUI
import SharedLedger

struct ListOverviewView: View {

    let ledger = Ledger.shared

    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    )!
    @State private var weeklyOverview: [Date: DayOverview] = [:]
    @State private var selectedItem: DayLineItem?
    @State private var dragOffset: CGFloat = 0
    @State private var pendingDeleteSource: DayLineItem.Source?

    @State private var sheetOneTime: OneTimeTransaction?
    @State private var sheetRecurring: RecurringRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("List Overview")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            HStack {
                DatePicker("", selection: $date, displayedComponents: .date)
                Button("Today") { date = .now }
                    .buttonStyle(.bordered)
            }

            weekCalendar
            Divider()

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(visibleDates, id: \.self) { day in
                        dayView(for: day)
                            .frame(width: geo.size.width)
                    }
                }
                .frame(width: geo.size.width * 3, alignment: .leading)
                .offset(x: -geo.size.width + dragOffset)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dragOffset)
                .contentShape(Rectangle())
                .gesture(daySwipeGesture)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal)
        .onAppear {
            updateWeek()
            loadWeeklyOverview()
        }
        .onChange(of: date) { _, _ in
            updateWeek()
            loadWeeklyOverview()
        }
    }
}

// MARK: - Calendar & Swipe Logic
extension ListOverviewView {

    private var visibleDates: [Date] {
        [
            Calendar.current.date(byAdding: .day, value: -1, to: date)!,
            date,
            Calendar.current.date(byAdding: .day, value: 1, to: date)!
        ]
    }

    private func changeDay(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: date) {
            date = newDate
        }
    }

    private func changeWeek(by offset: Int) {
        if let newWeek = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) {
            weekStart = newWeek
            date = newWeek
            loadWeeklyOverview()
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 60
                if value.translation.width < -threshold || value.predictedEndTranslation.width < -threshold {
                    changeDay(by: 1)
                } else if value.translation.width > threshold || value.predictedEndTranslation.width > threshold {
                    changeDay(by: -1)
                }
                dragOffset = 0
            }
    }

    private var weekCalendar: some View {
        let days = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
        }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]

        return HStack {
            ForEach(days.indices, id: \.self) { index in
                let day = days[index]

                VStack(spacing: 6) {
                    Text(letters[index])
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(day.formatted(.dateTime.day()))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Circle()
                                .foregroundStyle(
                                    Calendar.current.isDate(day, inSameDayAs: date)
                                    ? .orange
                                    : (weeklyOverview[day]?.netTotal ?? 0) >= 0
                                        ? .blue
                                        : .red
                                )
                        )
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { date = day }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width < -threshold {
                        changeWeek(by: 1)
                    } else if value.translation.width > threshold {
                        changeWeek(by: -1)
                    }
                }
        )
    }

    private func updateWeek() {
        weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? weekStart
    }

    private func loadWeeklyOverview() {
        weeklyOverview.removeAll()

        for i in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart),
               let overview = try? ledger.dayOverview(for: day) {
                weeklyOverview[day] = overview
            }
        }
    }
}

// MARK: - Day View & Sheet Handling
extension ListOverviewView {

    private func dayView(for day: Date) -> some View {
        let overview = try? ledger.dayOverview(for: day)

        return VStack(alignment: .leading, spacing: 8) {
            if let overview {
                if overview.items.isEmpty {
                    Spacer()
                    Label("No Items", systemImage: "tray")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(overview.items.sorted {
                            $0.amount == $1.amount ? $0.title < $1.title : $0.amount > $1.amount
                        }) { item in
                            HStack {
                                Text(item.title)
                                Spacer()
                                let amountDouble = NSDecimalNumber(decimal: item.amount).doubleValue
                                Text("\(amountDouble, format: .number.precision(.fractionLength(2)))")
                                    .foregroundStyle(item.amount >= 0 ? .blue : .red)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // NEW: resolve backing model for the sheet
                                resolveSheetModels(for: item)
                                selectedItem = item
                            }
                        }
                    }
                    .listStyle(.plain)

                    Divider()
                    overviewBar(for: day, overview: overview)
                }
            } else {
                Spacer()
                Text("No items for this day.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .sheet(item: $selectedItem, onDismiss: handleSheetDismiss) { item in
            ItemDetailSheet(
                item: item,
                requestDelete: requestDeleteFromSheet,
                oneTime: sheetOneTime,
                recurring: sheetRecurring
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func resolveSheetModels(for item: DayLineItem) {
        sheetOneTime = nil
        sheetRecurring = nil

        do {
            switch item.source {
            case .oneTime(let id):
                sheetOneTime = try ledger.fetchOneTime(id: id)
            case .recurring(let id):
                sheetRecurring = try ledger.fetchRecurring(id: id)
            }
        } catch {
            sheetOneTime = nil
            sheetRecurring = nil
        }
    }

    private func overviewBar(for day: Date, overview: DayOverview) -> some View {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let previousTotals = try? ledger.dayTotals(for: previousDay)
        let rollover = previousTotals?.runningBalanceEndOfDay ?? 0

        let incomingTotal: Double = overview.items
            .map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            .filter { $0 > 0 }
            .reduce(0, +)

        let outgoingTotal: Double = overview.items
            .map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            .filter { $0 < 0 }
            .reduce(0, +)

        let dayTotals = try? ledger.dayTotals(for: day)
        let dayNetTotal: Decimal = dayTotals?.runningBalanceEndOfDay ?? 0

        return HStack {
            VStack(alignment: .trailing) {
                Text("\(rollover, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(rollover >= 0 ? .blue : .red)
                Text("+\(incomingTotal, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.blue)
                Text("\(outgoingTotal, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.red)
            }
            VStack(alignment: .leading) {
                Text("Rollover")
                Text("Income")
                Text("Expense")
            }
            Spacer()
            Text("\(dayNetTotal, format: .number.precision(.fractionLength(2)))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(dayNetTotal >= 0 ? .blue : .red)
        }
        .fontWeight(.semibold)
    }

    private func requestDeleteFromSheet(_ source: DayLineItem.Source) {
        pendingDeleteSource = source
        selectedItem = nil
    }

    private func handleSheetDismiss() {
        guard let source = pendingDeleteSource else { return }
        pendingDeleteSource = nil

        do {
            switch source {
            case .oneTime(let id):
                if let tx = try ledger.fetchOneTime(id: id) {
                    try ledger.deleteOneTime(tx)
                }
            case .recurring(let id):
                if let rule = try ledger.fetchRecurring(id: id) {
                    try ledger.deleteRecurring(rule)
                }
            }
            loadWeeklyOverview()
        } catch {
            print("Delete failed:", error)
        }
    }
}

// MARK: - Currency Formatter
extension ListOverviewView {
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
}
