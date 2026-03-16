import SwiftUI
import SharedLedger

struct ListOverviewView: View {
    
    let ledger = Ledger.shared
    
    @AppStorage("selectedCurrencyCode") private var currencySelected = "GBP"
    
    @State private var isWeekDragging = false
    
    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    ) ?? .now
    
    @State private var weeklyTotals: [Date: DayTotals] = [:]
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
            SwipePager(
                onStep: moveDay(by:)
            ) { offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: date) ?? date
                dayView(for: day)
            }
        }
        .onAppear {
            refresh()
            loadWeeklyTotals()
        }
        .onChange(of: date) { _, _ in
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
        SwipePager(
            onStep: moveWeek(by:),
            onDraggingChanged: { dragging in
                isWeekDragging = dragging
            }
        ) { offset in
            let baseWeek = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) ?? weekStart
            let activeDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
            
            HStack {
                Divider().opacity(isWeekDragging ? 1 : 0)
                weekView(for: baseWeek, activeDate: activeDate)
                Divider().opacity(isWeekDragging ? 1 : 0)
            }
        }
        .frame(height: 70)
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
                                currency: currencySelected,
                                day: day,
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
                                currency: currencySelected,
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
                                currency: currencySelected,
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
        
        let oneTimeItems = overview.items.filter {
            if case .oneTime = $0.source { return true }
            return false
        }
        let recurringItems = overview.items.filter {
            if case .recurring = $0.source { return true }
            return false
        }
        let savingsItems = overview.items.filter {
            if case .saving = $0.source { return true }
            return false
        }
        let oneTimeTotal: Double = oneTimeItems
            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
            .reduce(0, +)
        
        let recurringTotal: Double = recurringItems
            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
            .reduce(0, +)
        
        let savingsdayTotal: Double = savingsItems
            .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
            .reduce(0, +)
        
        let dayTotals = try? ledger.dayTotals(for: day)
        let dayNetTotal: Decimal = dayTotals?.runningBalanceMainEndOfDay ?? 0
        let savingsTotal: Decimal = (try? ledger.savingsBalanceEndOfDay(on: day)) ?? 0

        return HStack() {
            Spacer()
            // sub totals
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        HStack (spacing: 8) {
                            Text("Rollover")
                            let rolloverSign = rollover >= 0 ? "+" : ""
                            Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(rolloverSign)\(numberFormatter(number: rollover))")
                                .lineLimit(1)
                                .foregroundStyle(rollover >= 0
                                                 ? .blue
                                                 : .red)
                                .foregroundStyle(.primary)
                        }
                        HStack (spacing: 8) {
                            Text("One Time")
                            let oneTimeTotalSign = oneTimeTotal >= 0 ? "+" : ""
                            Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(oneTimeTotalSign)\(numberFormatter(number: Decimal(oneTimeTotal)))")
                                .lineLimit(1)
                                .foregroundStyle(oneTimeTotal >= 0
                                                 ? .blue
                                                 : .red)
                                .foregroundStyle(.primary)
                        }
                        HStack (spacing: 8) {
                            Text("Recurring")
                            let recurringTotalSign = recurringTotal >= 0 ? "+" : ""
                            Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(recurringTotalSign)\(numberFormatter(number: Decimal(recurringTotal)))")
                                .lineLimit(1)
                                .foregroundStyle(recurringTotal >= 0
                                                 ? .blue
                                                 : .red)
                                .foregroundStyle(.primary)
                        }
                        HStack (spacing: 8) {
                            if (savingsdayTotal != 0)
                            {
                                Text("Savings")
                                    .foregroundStyle(.primary)

                                let savingsTotalSign = savingsdayTotal >= 0 ? "+" : ""
                                Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(savingsTotalSign)\(numberFormatter(number: Decimal(savingsdayTotal)))")
                                    .lineLimit(1)
                                    .foregroundStyle(recurringTotal >= 0
                                                     ? .blue
                                                     : .red)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            // equals sign
            VStack(alignment: .center) {
                Text("=")
                    .font(.title2)
                    .fontWeight(.bold)
            }
                .padding(8)
            // disposable today
            VStack(alignment: .center) {
                Text("Disposable Today")
                    .font(.caption)
                let sign = dayNetTotal >= 0 ? "+" : ""
                Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)\(sign)\(numberFormatter(number: dayNetTotal))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(dayNetTotal >= 0
                                     ? .blue
                                     : .red)
                    .padding(.bottom, 4)
                HStack {
                    Text("Savings")
                        .font(.callout)
                    Text("\(Locale(identifier: "en_GB@currency=\(currencySelected)").currencySymbol ?? currencySelected)+\(numberFormatter(number: savingsTotal))")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
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
    
    private func moveDay(by delta: Int) {
        guard delta != 0 else { return }
        guard let newDate = Calendar.current.date(byAdding: .day, value: delta, to: date) else { return }
        date = newDate
    }
    
    private func moveWeek(by delta: Int) {
        guard delta != 0 else { return }
        guard let newWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: weekStart) else { return }
        
        let weekdayOffset = Calendar.current.dateComponents([.day], from: weekStart, to: date).day ?? 0
        weekStart = newWeekStart
        date = Calendar.current.date(byAdding: .day, value: weekdayOffset, to: newWeekStart) ?? newWeekStart
    }
    
    private func goToToday() {
        let calendar = Calendar.current
        let today = Date()
        let targetWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) ?? today
        
        guard !calendar.isDate(today, inSameDayAs: date) else { return }
        
        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.1)) {
            weekStart = targetWeek
            date = today
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
    
    private func weekView(for startOfWeek: Date, activeDate: Date) -> some View {
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
                        .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: activeDate) ? Color(UIColor.systemBackground) : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Group {
                                if Calendar.current.isDate(day, inSameDayAs: activeDate) {
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
                                        dash: (Calendar.current.isDate(day, inSameDayAs: .now) && !Calendar.current.isDate(day, inSameDayAs: activeDate)) ? [5] : []
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
    
    private func numberFormatter(number: Decimal) -> String {
        let absNumber = number < 0 ? -number : number
        
        let divisor: Decimal
        let suffix: String
        
        if absNumber >= 1_000_000_000 {
            divisor = 1_000_000_000
            suffix = "b"
        } else if absNumber >= 1_000_000 {
            divisor = 1_000_000
            suffix = "m"
        } else if absNumber >= 1_000 {
            divisor = 1_000
            suffix = "k"
        } else {
            divisor = 1
            suffix = ""
        }
        
        let value = number / divisor
        
        var valueString = NSDecimalNumber(decimal: value).stringValue
        
        if let dotIndex = valueString.firstIndex(of: ".") {
            let decimalPart = valueString[valueString.index(after: dotIndex)...]
            
            if decimalPart.count > 2 {
                let endIndex = valueString.index(dotIndex, offsetBy: 3)
                valueString = String(valueString[..<endIndex])
            } else if decimalPart.count == 1 {
                valueString += "0"
            }
            
        } else {
            valueString += ".00"
        }
        
        return valueString + suffix
    }
    
    private struct TransactionSectionView: View {
        
        let title: String
        let items: [DayLineItem]
        let iconName: String
        let currency: String
        let day: Date
        let onTap: (DayLineItem) -> Void
        
        var body: some View {
            VStack {
                let incomingTotal: Double = items
                    .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
                    .filter { $0 > 0 }
                    .reduce(0, +)
                let outgoingTotal: Double = items
                    .map { NSDecimalNumber(decimal: $0.mainAmount).doubleValue }
                    .filter { $0 < 0 }
                    .reduce(0, +)
                
                HStack {
                    Label("\(title)", systemImage: iconName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .labelIconToTitleSpacing(8)
                    Spacer()
                    Text("\(Locale(identifier: "en_GB@currency=\(currency)").currencySymbol ?? currency)\(incomingTotal + outgoingTotal,format: .number.precision(.fractionLength(2)))")
                        .lineLimit(1)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .foregroundStyle(incomingTotal + outgoingTotal >= 0
                                         ? .blue
                                         : .red)
                }
                
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
                Text("\(Locale(identifier: "en_GB@currency=\(currency)").currencySymbol ?? currency)\(sign)\(amountDouble, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(item.mainAmount >= 0 ? .blue : .red)
            }
        }
    }
}

private struct SwipePager<Page: View>: View {
    
    let onStep: (Int) -> Void
    let onDraggingChanged: ((Bool) -> Void)?
    let page: (Int) -> Page
    
    @GestureState private var dragTranslation: CGSize = .zero
    
    @State private var settlingOffset: CGFloat = 0
    @State private var pendingStep: Int = 0
    @State private var isAnimating = false
    @State private var isDragging = false
    
    init(
        onStep: @escaping (Int) -> Void,
        onDraggingChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder page: @escaping (Int) -> Page
    ) {
        self.onStep = onStep
        self.onDraggingChanged = onDraggingChanged
        self.page = page
    }
    
    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            
            HStack(spacing: 0) {
                page(-1)
                    .frame(width: width)
                page(0)
                    .frame(width: width)
                page(1)
                    .frame(width: width)
            }
            .frame(width: width * 3, alignment: .leading)
            .offset(x: -width + liveOffset(for: width))
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragTranslation) { value, state, _ in
                        guard !isAnimating else { return }
                        state = value.translation
                    }
                    .onChanged { value in
                        guard !isAnimating else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        
                        if !isDragging {
                            isDragging = true
                            onDraggingChanged?(true)
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating else { return }
                        
                        if isDragging {
                            isDragging = false
                            onDraggingChanged?(false)
                        }
                        
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        guard abs(horizontal) > abs(vertical) else {
                            snapBack(from: horizontal)
                            return
                        }
                        
                        let capturedOffset = clampedDrag(horizontal, width: width)
                        let threshold = width * 0.24
                        let predicted = value.predictedEndTranslation.width
                        
                        let step: Int
                        if predicted <= -threshold || horizontal <= -threshold {
                            step = 1
                        } else if predicted >= threshold || horizontal >= threshold {
                            step = -1
                        } else {
                            step = 0
                        }
                        
                        settlingOffset = capturedOffset
                        pendingStep = step
                        isAnimating = true
                        
                        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.12)) {
                            settlingOffset = CGFloat(-step) * width
                        }
                    }
            )
            .modifier(OffsetAnimationCompletionModifier(observedOffset: settlingOffset) {
                guard isAnimating else { return }
                
                let step = pendingStep
                
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    onStep(step)
                    settlingOffset = 0
                }
                
                pendingStep = 0
                isAnimating = false
            })
        }
    }
    
    private func liveOffset(for width: CGFloat) -> CGFloat {
        guard !isAnimating else { return settlingOffset }
        
        let horizontal = dragTranslation.width
        let vertical = dragTranslation.height
        
        guard abs(horizontal) > abs(vertical) else { return settlingOffset }
        return settlingOffset + clampedDrag(horizontal, width: width)
    }
    
    private func clampedDrag(_ value: CGFloat, width: CGFloat) -> CGFloat {
        let limit = width * 1.05
        return min(max(value, -limit), limit)
    }
    
    private func snapBack(from currentOffset: CGFloat) {
        settlingOffset = currentOffset
        pendingStep = 0
        isAnimating = true
        
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9, blendDuration: 0.12)) {
            settlingOffset = 0
        }
    }
}

private struct OffsetAnimationCompletionModifier: AnimatableModifier {
    
    var targetOffset: CGFloat
    var completion: () -> Void
    
    var animatableData: CGFloat {
        didSet { notifyCompletionIfFinished() }
    }
    
    init(observedOffset: CGFloat, completion: @escaping () -> Void) {
        self.targetOffset = observedOffset
        self.animatableData = observedOffset
        self.completion = completion
    }
    
    func body(content: Content) -> some View {
        content
    }
    
    private func notifyCompletionIfFinished() {
        guard abs(animatableData - targetOffset) < 0.5 else { return }
        
        DispatchQueue.main.async {
            completion()
        }
    }
}
