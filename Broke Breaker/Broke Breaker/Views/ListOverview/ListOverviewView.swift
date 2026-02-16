import SwiftUI
import SwiftData

struct ListOverviewView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = .now
    @State private var weekStart: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
    )!
    @State private var weeklyOverview: [Date: DayOverview] = [:]
    @State private var selectedItem: DayLineItem?
    @State private var dragOffset: CGFloat = 0
    
    // Info set by details popup after its closed (deletion / edits)
    @State private var pendingDeleteSource: DayLineItem.Source?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("List Overview")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            // date picker and today button
            HStack (){
                DatePicker("", selection: $date, displayedComponents: .date)
                Button("Today") { date = .now }
                    .buttonStyle(.bordered)
            }

            // calander
            weekCalendar

            Divider()

            // Pager
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
                        changeDay(by: 7)
                    } else if value.translation.width > threshold ||
                              value.predictedEndTranslation.width > threshold {
                        changeDay(by: -7)
                    }

                    dragOffset = 0
                }
        )
    }
}

// day view
extension ListOverviewView {

    private func dayView(for day: Date) -> some View {
        let ledger = LedgerService(context: modelContext)
        let overview = try? ledger.dayOverview(for: day)

        return VStack(alignment: .leading, spacing: 8) {
            if let overview {
                dayOverviewBody(overview)   // <- extracted
            } else {
                Text("No items for this day.")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $selectedItem, onDismiss: handleSheetDismiss) { item in
            ItemDetailSheet(item: item, requestDelete: requestDeleteFromSheet)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func dayOverviewBody(_ overview: DayOverview) -> some View {
        if overview.items.isEmpty {
            Spacer()
            Label("No Items", systemImage: "tray")
                .font(.title)
                .frame(maxWidth: .infinity)
            Spacer()
        } else {
            itemsList(overview)            // <- extracted again
            Divider()
            netTotalRow(overview)
                .padding(.horizontal)
        }
    }

    private func itemsList(_ overview: DayOverview) -> some View {
        List {
            ForEach(sortedItems(from: overview)) { item in
                row(for: item)
            }
        }
        .listStyle(.plain)
    }

    private func sortedItems(from overview: DayOverview) -> [DayLineItem] {
        overview.items.sorted {
            $0.amount == $1.amount ? $0.title < $1.title : $0.amount > $1.amount
        }
    }

    private func row(for item: DayLineItem) -> some View {
        HStack {
            Text(item.title)
            Spacer()
            Text(item.amount as NSNumber, formatter: currencyFormatter)
                .foregroundStyle(item.amount >= 0 ? .blue : .red)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedItem = item }
    }

    private func netTotalRow(_ overview: DayOverview) -> some View {
        HStack {
            Text("Net total").fontWeight(.semibold)
            Spacer()
            Text(overview.netTotal as NSNumber, formatter: currencyFormatter)
                .fontWeight(.semibold)
                .foregroundStyle(overview.netTotal >= 0 ? .blue : .red)
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
}

// function
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

    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }
}

