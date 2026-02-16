import SwiftUI
import SwiftData

struct ListOverviewView: View {
    
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from:.now))!
    @State private var weeklyOverview: [Date: DayOverview] = [:]
    @State private var selectedItem: DayLineItem?
    @State private var totalIncomings: Double = 0
    @State private var totalOutgoings: Double = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            Text("List Overview")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            HStack (){
                DatePicker("", selection: $date, displayedComponents: .date)
                Button("Today") { date = .now }
                    .buttonStyle(.bordered)
            }

            weekCalendar
            Divider()

            // input reader sheet. Need to redo
            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 0) {
                        ForEach(visibleDates, id: \.self) { day in
                            dayView(for: day)
                                .frame(width: geo.size.width)
                        }
                    }
                    .frame(width: geo.size.width * 3, alignment: .leading)
                    .offset(x: -geo.size.width + dragOffset)
                    .animation(
                        .interactiveSpring(response: 0.25, dampingFraction: 0.85),
                        value: dragOffset
                    )

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    guard abs(value.translation.width) >
                                          abs(value.translation.height) else { return }
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 60
                                    if value.translation.width < -threshold ||
                                       value.predictedEndTranslation.width < -threshold {
                                        changeDay(by: 1)
                                    } else if value.translation.width > threshold ||
                                              value.predictedEndTranslation.width > threshold {
                                        changeDay(by: -1)
                                    }
                                    dragOffset = 0
                                }
                        )
                }
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

// calander
extension ListOverviewView {

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
    }
}

// day view
extension ListOverviewView {

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
                        ForEach(
                            overview.items.sorted {
                                if $0.amount == $1.amount {
                                    return $0.title < $1.title
                                } else {
                                    return $0.amount > $1.amount
                                }
                            }
                        )
                        {
                            item in
                            HStack {
                                Text(item.title)
                                Spacer()
                                let amountDouble = NSDecimalNumber(decimal: item.amount).doubleValue
                                Text("\(amountDouble, format: .number.precision(.fractionLength(2)))")
                                    .foregroundStyle(item.amount >= 0 ? .blue : .red)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                        }
                    }
                    .listStyle(.plain)

                    Divider()

                    // overview bar
                    HStack {
                        HStack {
                            VStack (alignment: .trailing) {

                                // Previous day rollover
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

                                Text("\(rollover, format: .number.precision(.fractionLength(2)))")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(rollover >= 0 ? .blue : .red)

                                Text("+\(incomingTotal, format: .number.precision(.fractionLength(2)))")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)

                                Text("\(outgoingTotal, format: .number.precision(.fractionLength(2)))")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }
                            
                            VStack (alignment: .leading ) {
                                Text("Rollover").fontWeight(.semibold)
                                Text("Income").fontWeight(.semibold)
                                Text("Expense").fontWeight(.semibold)
                            }
                        }

                        Spacer()

                        HStack {
                            Spacer()
                            VStack {
                                let dayTotals = try? ledger.dayTotals(for: day)
                                let dayNetTotal: Decimal = dayTotals?.netTotal ?? 0
                                Text("\(dayNetTotal, format: .number.precision(.fractionLength(2)))")
                                    .fontWeight(.semibold)
                                    .font(.title)
                                    .foregroundStyle(dayNetTotal >= 0 ? .blue : .red)
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                Text("No items for this day.")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemEditorView(item: item)
                .presentationDetents([.medium, .height(200), .large])
        }
    }
}

// functions
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
}
