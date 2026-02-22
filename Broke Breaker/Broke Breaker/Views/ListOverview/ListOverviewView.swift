import SwiftUI
import SharedLedger

struct ListOverviewView: View {

    let ledger = Ledger.shared
    
    @Environment(\.colorScheme) var colourScheme: ColorScheme

    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
    @State private var weeklyTotals: [Date: DayTotals] = [:]
    @State private var weekPageIndex = 1
    @State private var pageIndex = 1
    @State private var selectedItem: DayLineItem?
    @State private var pendingDeleteSource: DayLineItem.Source?

    @State private var sheetOneTime: OneTimeTransaction?
    @State private var sheetRecurring: RecurringRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // title
            Text("List Overview")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.horizontal)
            
            // Date Picker
            HStack {
                DatePicker("", selection: $date, displayedComponents: .date)
                Button("Today") { date = .now }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .padding(.bottom, 1)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
                    .foregroundStyle(.primary)
                    .controlSize(.mini)
                    .font(.system(size: 17))
            }
            .padding(.horizontal)
            
            weekCalendar
                .padding(.horizontal)
            Divider()
            
            // day swiper
            TabView(selection: $pageIndex) {
                ForEach(0..<3) { index in
                    let offset = index - 1
                    let day = Calendar.current.date(byAdding: .day, value: offset, to: date)!
                    dayView(for: day)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: pageIndex) { oldIndex, newIndex in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let delta = newIndex - 1
                    if delta != 0 {
                        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: date) {
                            date = newDate
                        }
                        pageIndex = 1
                    }
                }
            }
            
        }
        .onAppear {
            refresh()
        }
        .onChange(of: date) { _, newDate in
            refresh()
        }
    }
}

// views / calander, day and oerview bar
extension ListOverviewView {
    
    // calander
    private var weekCalendar: some View {
        TabView(selection: $weekPageIndex) {
            ForEach(0..<3) { index in
                let offset = index - 1
                let baseWeek = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart)!
                weekView(for: baseWeek)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 70)
        .onChange(of: weekPageIndex) { _, newIndex in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let delta = newIndex - 1
                if delta != 0 {
                    if let newWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: weekStart) {
                        let weekdayOffset = Calendar.current.dateComponents([.day], from: weekStart, to: date).day ?? 0
                        if let newDate = Calendar.current.date(byAdding: .day, value: weekdayOffset, to: newWeekStart) {
                            weekStart = newWeekStart
                            date = newDate
                        } else {
                            weekStart = newWeekStart
                            date = newWeekStart
                        }
                    }
                    weekPageIndex = 1
                }
            }
        }
    }
    
    // day view
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
                        let oneTimeItems = overview.items.filter {
                            if case .oneTime = $0.source { return true }
                            return false
                        }
                        let recurringItems = overview.items.filter {
                            if case .recurring = $0.source { return true }
                            return false
                        }
                        
                        // One-time Section
                        if !oneTimeItems.isEmpty {
                            Section {
                                ForEach(oneTimeItems.sorted { $0.title > $1.title }) { item in
                                    HStack {
                                        Text(item.title)
                                        Spacer()
                                        let amountDouble = NSDecimalNumber(decimal: item.amount).doubleValue
                                        Text("\(amountDouble, format: .number.precision(.fractionLength(2)))")
                                            .foregroundStyle(item.amount >= 0 ? .blue : .red)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedItem = item }
                                }
                            } header: {
                                Text("One-Time Transactions:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .textCase(nil)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Recurring Section
                        if !recurringItems.isEmpty {
                            Section {
                                ForEach(recurringItems.sorted { $0.title > $1.title }) { item in
                                    HStack {
                                        Text(item.title)
                                        Spacer()
                                        let amountDouble = NSDecimalNumber(decimal: item.amount).doubleValue
                                        Text("\(amountDouble, format: .number.precision(.fractionLength(2)))")
                                            .foregroundStyle(item.amount >= 0 ? .blue : .red)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedItem = item }
                                }
                            } header: {
                                Text("Recurring Transactions:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .textCase(nil)
                                    .foregroundStyle(.secondary)
                            }
                            
                        }
                    }
                    .listStyle(.plain)
                    
                }
            } else {
                Spacer()
                Text("No items for this day.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            Spacer()
            Divider()
            if let overview {
                overviewBar(for: day, overview: overview)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .sheet(item: $selectedItem, onDismiss: handleSheetDismiss) { item in
            let resolved = resolveModels(for: item)

            ItemDetailSheet(
                item: item,
                requestDelete: requestDeleteFromSheet,
                oneTime: resolved.oneTime,
                recurring: resolved.recurring
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func resolveModels(for item: DayLineItem) -> (oneTime: OneTimeTransaction?, recurring: RecurringRule?)
    {
        sheetOneTime = nil
        sheetRecurring = nil
        do {
            switch item.source {
            case .oneTime(let id):
                return (try ledger.fetchOneTime(id: id), nil)
            case .recurring(let id):
                return (nil, try ledger.fetchRecurring(id: id))
            }
        } catch {
            return (nil, nil)
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
            Spacer()
            VStack(alignment: .trailing) {
                HStack() {
                    let sign = rollover >= 0 ? "+" : ""
                    Text("\(sign)\(rollover, format: .number.precision(.fractionLength(2)))")
                        .lineLimit(1)
                        .foregroundStyle(rollover >= 0
                                         ? .blue
                                         : .red)
                }
                Text("+\(incomingTotal, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                Text("\(outgoingTotal, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            VStack(alignment: .leading) {
                Text("Rollover")
                Text("Income")
                Text("Expense")
            }
            Spacer()
            Text("=")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Text("\(dayNetTotal, format: .number.precision(.fractionLength(2)))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(dayNetTotal >= 0
                                 ? .blue
                                 : .red)
                .lineLimit(1)
            Spacer()
        }
        .fontWeight(.semibold)
    }
}

// fucntions
extension ListOverviewView {
    
    private func updateWeek() {
        weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? weekStart
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
    
    private func weekView(for startOfWeek: Date) -> some View {
        let days = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: startOfWeek)
        }
        let letters = ["M", "T", "W", "T", "F", "S", "S"]

        return HStack {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let day = days[index]
                VStack(spacing: 6) {
                    Text(letters[index])
                        .foregroundStyle(
                            Calendar.current.isDate(day, inSameDayAs: .now)
                            ? .primary
                            : .secondary
                        )
                        .font(.caption.bold())
                    
                    Text(day.formatted(.dateTime.day()))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            Calendar.current.isDate(day, inSameDayAs: date)
                            ? Color(uiColor: .systemBackground)
                            : .primary
                        )
                        .colorInvert()
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Circle()
                                .foregroundStyle(circleColour(day: day))
                        )
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { date = day }
            }
        }
    }
    
    private func refresh() {
        updateWeek()
        loadWeeklyTotals()
    }

    private func changeDay(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: date) {
            date = newDate
        }
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
            loadWeeklyTotals()
        } catch {
            print("Delete failed:", error)
        }
    }
    
    private func circleColour(day: Date) -> Color {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: date)
        let balance = weeklyTotals[day]?.runningBalanceEndOfDay ?? 0

        let circleColor: Color
        if isSelected {
            circleColor = colourScheme == .light
                ? .purple.opacity(0.6)
                : .purple
        } else {
            circleColor = balance >= 0 ? .blue : .red
        }
        return circleColor
    }
}
