import SwiftUI
import SharedLedger

struct ListOverviewView: View {
    
    let ledger = Ledger.shared
    
    @GestureState private var isWeekDragging = false
    
    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    ) ?? .now
    
    @State private var weeklyTotals: [Date: DayTotals] = [:]
    @State private var weekPageIndex = 1
    @State private var dayChanging: Bool = false
    @State private var weekChanging: Bool = false
    @State private var pageIndex = 1
    @State private var selectedItem: DayLineItem?
    @State private var refreshToken = UUID()
    
    @State private var selectedItemDay: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // title
            Text("Transactions")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .padding(.horizontal)
            
            // Date Picker
            HStack {
                DatePicker("", selection: $date, displayedComponents: .date)
                Button("Today") { goToToday() }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .padding(.bottom, 1)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
                    .foregroundStyle(Calendar.current.isDate(.now, inSameDayAs: date) ? Color.primary.opacity(0.5) : Color.primary)
                    .controlSize(.mini)
                    .font(.system(size: 17))
                    .disabled(Calendar.current.isDate(.now, inSameDayAs: date))
            }
            .padding(.horizontal)
            
            weekCalendar
                .padding(8)
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
            .onChange(of: pageIndex) { _, newIndex in
                guard newIndex != 1 else { return }
                guard !dayChanging else { return }
                dayChanging = true
                let delta = newIndex - 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {

                    if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: date) {
                        date = newDate
                    }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        pageIndex = 1
                    }
                    dayChanging = false
                }
            }
        }
        .onAppear {
            refresh()
            loadWeeklyTotals()
        }
        .onChange(of: date) { _, newDate in
            refresh()
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(
                day: selectedItemDay,
                item: item,
                onChanged: {
                    refresh()
                    refreshToken = UUID()
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

// views / calender, day and overview bar
extension ListOverviewView {
    
    // calender
    private var weekCalendar: some View {
        TabView(selection: $weekPageIndex) {
            ForEach(0..<3) { index in
                let offset = index - 1
                let baseWeek = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart)!
                HStack {
                    Divider().opacity(isWeekDragging ? 1 : 0)
                    weekView(for: baseWeek)
                    Divider().opacity(isWeekDragging ? 1 : 0)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 70)
        .simultaneousGesture (
            DragGesture(minimumDistance: 1)
                .updating($isWeekDragging) { _, state, _ in
                    state = true
                }
        )
        .onChange(of: weekPageIndex) { _, newIndex in
            guard newIndex != 1 else { return }
            guard !weekChanging else { return }
            
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
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                        Text("No Transactions")
                    }
                    .font(.title)
                    .foregroundStyle(.secondary)
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
                        let savingItems = overview.items.filter {
                            if case .saving = $0.source { return true }
                            return false
                        }
                        
                        if !oneTimeItems.isEmpty {
                            TransactionSectionView(
                                title: "One-Time Transactions:",
                                items: oneTimeItems,
                                iconName: "\(Calendar.current.component(.day, from: day)).calendar",
                                day: day
                            ) { item in
                                selectedItemDay = day
                                selectedItem = item
                                }
                        }
                        
                        if !savingItems.isEmpty {
                            TransactionSectionView(
                                title: "Savings:",
                                items: savingItems,
                                iconName: "square.and.arrow.down",
                                day: day
                            ) { item in
                                selectedItemDay = day
                                selectedItem = item
                            }
                        }

                        if !recurringItems.isEmpty {
                            TransactionSectionView(
                                title: "Recurring Transactions:",
                                items: recurringItems,
                                iconName: "repeat",
                                day: day
                            ) { item in
                                selectedItemDay = day
                                selectedItem = item
                            }
                        }
                    }
                    .listStyle(.plain)
                    .id(refreshToken)
                }
            } else {
                Spacer()
                Text("Error loading day")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let overview {
                    overviewBar(for: day, overview: overview)
                        .padding(.horizontal, 8)
                }
                Rectangle()
                    .fill(.primary)
                    .colorInvert()
                    .padding(0)
                    .frame(maxWidth: .infinity, maxHeight: 8)
            }
        }
    }

    // overview bar view
    private func overviewBar(for day: Date, overview: DayOverview) -> some View {
        
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let previousTotals = try? ledger.dayTotals(for: previousDay)
        let rollover = previousTotals?.runningBalanceMainEndOfDay ?? 0
        
        let incomingTotal: Double = overview.items
            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
            .filter { $0 > 0 }
            .reduce(0, +)
        
        let outgoingTotal: Double = overview.items
            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
            .filter { $0 < 0 }
            .reduce(0, +)
        
        let dayTotals = try? ledger.dayTotals(for: day)
        let dayNetTotal: Decimal = dayTotals?.runningBalanceMainEndOfDay ?? 0

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
                let sign = outgoingTotal == 0 ? "-" : ""
                Text("\(sign)\(outgoingTotal, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            VStack(alignment: .leading) {
                Text("Rollover")
                Text("Income")
                Text("Expense")
            }
            Spacer()
            VStack(alignment: .center) {
                Text("=")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer(minLength: 70)
            VStack(alignment: .trailing) {
                Text("Disposable Today")
                    .font(.caption)
                let sign = dayNetTotal >= 0 ? "+" : ""
                Text("\(sign)\(dayNetTotal, format: .number.precision(.fractionLength(2)))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(dayNetTotal >= 0
                                     ? .blue
                                     : .red)
                    .lineLimit(1)
            }
            Spacer()
        }
        .fontWeight(.semibold)
        .padding(.vertical, 8)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// functions
extension ListOverviewView {
    
    private func updateWeek() {
        weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? weekStart
    }
    
    private func goToToday() {
        let calendar = Calendar.current
        let today = Date()
        
        let currentWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        )!
        let targetWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        )!
        
        let diff = calendar.dateComponents([.weekOfYear], from: currentWeek, to: targetWeek).weekOfYear ?? 0
        
        if calendar.isDate(currentWeek, inSameDayAs: targetWeek) {
            date = today
            return
        }
        
        guard diff != 0 else {
            withAnimation {
                date = today
            }
            return
        }
        
        weekChanging = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            weekPageIndex = diff > 0 ? 2 : 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            weekStart = targetWeek
            date = today
            
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                weekPageIndex = 1
            }
            
            weekChanging = false
            loadWeeklyTotals()
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
    
    private func weekView(for startOfWeek: Date) -> some View {
        let days = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: startOfWeek)
        }
        let letters = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        return HStack {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
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
                        .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: date) ? Color(UIColor.systemBackground) : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Group {
                                if Calendar.current.isDate(day, inSameDayAs: date) {
                                    Circle()
                                        .fill(circleColour(day: day))
                                }
                            }
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    circleColour(day: day),
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        dash: (Calendar.current.isDate(day, inSameDayAs: .now) && !Calendar.current.isDate(day, inSameDayAs: date)) ? [5] : []
                                    )
                                )
                        )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { date = day }
            }
        }
    }
    
    private func refresh() {
        refreshToken = UUID()
        updateWeek()
        loadWeeklyTotals()
    }
    
    private func circleColour(day: Date) -> Color {
        guard let balance = try? ledger.dayTotals(for: day).runningBalanceMainEndOfDay else {
                return .secondary.opacity(0.3)
            }
        return balance >= 0 ? .blue : .red
    }
    
    private struct TransactionSectionView: View {
        
        let title: String
        let items: [DayLineItem]
        let iconName: String
        let day: Date
        let onTap: (DayLineItem) -> Void
        
        var body: some View {
            VStack {
                Label(title, systemImage: iconName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .labelIconToTitleSpacing(8)
                
                let sortedItems = items.sorted { $0.mainAmount > $1.mainAmount }
                
                ForEach(sortedItems.indices, id: \.self) { index in
                    let item = sortedItems[index]
                    
                    HStack {
                        Text(item.title)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        amountView(for: item)
                    }
                    .contentShape(Rectangle())
                    .padding(8)
                    .onTapGesture {
                        onTap(item)
                    }
                    
                    if index < sortedItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(8)
            .glassEffect(in: .rect(cornerRadius: 16))
            .listRowSeparator(.hidden)
        }
        
        @ViewBuilder
        private func amountView(for item: DayLineItem) -> some View {
            let amountDouble = NSDecimalNumber(decimal: item.mainAmount).doubleValue
            let sign = amountDouble >= 0 ? "+" : ""
            
            if abs(amountDouble) < 0.01 {
                let smallSign = amountDouble <= 0 ? "-" : ""
                Text("\(smallSign)0.01")
                    .foregroundStyle(item.mainAmount >= 0 ? .blue : .red)
            } else {
                Text("\(sign)\(amountDouble, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(item.mainAmount >= 0 ? .blue : .red)
            }
        }
    }
    
}
