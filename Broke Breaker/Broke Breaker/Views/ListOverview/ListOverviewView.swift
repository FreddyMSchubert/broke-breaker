import SwiftUI
import SwiftData

struct ListOverviewView: View {
    
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
    @State private var weeklyOverview: [Date: DayOverview] = [:]
    @State private var selectedItem: DayLineItem?
    @State private var dragOffset: CGFloat = 0
    @State private var pendingDeleteSource: DayLineItem.Source?

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
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            // Week Calendar
            weekCalendar
                .padding(.horizontal)
            Divider()
            
            // input reader
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    ForEach(visibleDates, id: \.self) { day in
                        dayView(for: day)
                            .frame(width: width)
                    }
                }
                .frame(width: width * 3, alignment: .leading)
                .offset(x: -width + dragOffset)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: dragOffset)
                .contentShape(Rectangle()) // capture gestures even on empty space
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 60

                            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                                if value.translation.width < -threshold || value.predictedEndTranslation.width < -threshold {
                                    // Snap left by exactly one page width
                                    dragOffset = -width
                                } else if value.translation.width > threshold || value.predictedEndTranslation.width > threshold {
                                    // Snap right by exactly one page width
                                    dragOffset = width
                                } else {
                                    // Cancel, snap back
                                    dragOffset = 0
                                }
                            }

                            // After the snap finishes, update the date and reset offset
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if dragOffset == -width {
                                    changeDay(by: 1)
                                } else if dragOffset == width {
                                    changeDay(by: -1)
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .frame(maxHeight: .infinity)
        }
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

// MARK: - Want to do:
    // 1. fix the calander so that the circles colour is based on runningBalanceEndOfDay not netTotal
    // 2. make it re sorts the items when a new one is added otherwise it just wacks at bottom of relevant page
    // 3. make swiping easier, it wants to scroll not swipe to go to the next day
    // 4. animate calander swiping

// views / calander, day and oerview bar
extension ListOverviewView {
    
    // calander
    private var weekCalendar: some View {
        let days = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
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
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Circle()
                                .foregroundStyle(
                                    Calendar.current.isDate(day, inSameDayAs: date)
                                    ? .orange
                                    : ((weeklyOverview[day]?.netTotal ?? 0) >= 0
                                       ? .blue
                                       : .red
                                      )
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
                        changeDay(by: 7)
                    } else if value.translation.width > threshold {
                        changeDay(by: -7)
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
        let ledger = LedgerService(context: modelContext)
        weeklyOverview.removeAll()
        
        for i in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart),
               let overview = try? ledger.dayOverview(for: day) {
                weeklyOverview[day] = overview
            }
        }
    }
    
    // day view
    private func dayView(for day: Date) -> some View {
        let ledger = LedgerService(context: modelContext)
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
            Divider()
            overviewBar(for: day)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .sheet(item: $selectedItem, onDismiss: handleSheetDismiss) { item in
            ItemDetailSheet(item: item, requestDelete: requestDeleteFromSheet)
                .presentationDetents([.medium, .large])
        }
    }
    
    // overview bar
    private func overviewBar(for day: Date) -> some View {
        let ledger = LedgerService(context: modelContext)
        
        let overview = (try? ledger.dayOverview(for: day))
        let items = overview?.items ?? []
        
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let previousTotals = try? ledger.dayTotals(for: previousDay)
        let rollover = previousTotals?.runningBalanceEndOfDay ?? 0
        
        let incomingTotal: Double = items
            .map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            .filter { $0 > 0 }
            .reduce(0, +)
        
        let outgoingTotal: Double = items
            .map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            .filter { $0 < 0 }
            .reduce(0, +)
        
        let dayTotals = try? ledger.dayTotals(for: day)
        let dayNetTotal: Decimal = dayTotals?.runningBalanceEndOfDay ?? 0
        
        return HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(rollover, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(rollover >= 0
                                     ? .blue
                                     : .red)
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
            Spacer()
        }
        .fontWeight(.semibold)
    }
}

// fucntions
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
    
    private func requestDeleteFromSheet(_ source: DayLineItem.Source) {
        pendingDeleteSource = source
        selectedItem = nil
    }
    
    private func handleSheetDismiss() {
        guard let source = pendingDeleteSource else { return }
        pendingDeleteSource = nil
        let ledger = LedgerService(context: modelContext)
        do {
            switch source {
            case .oneTime(let id):
                if let tx = modelContext.model(for: id) as? OneTimeTransaction {
                    try ledger.deleteOneTime(tx)
                }
            case .recurring(let id):
                if let rule = modelContext.model(for: id) as? RecurringRule {
                    try ledger.deleteRecurring(rule)
                }
            }
            loadWeeklyOverview()
        } catch {
            print("Delete failed:", error)
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
}
