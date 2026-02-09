import SwiftUI
import SwiftData

struct ListOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var color: Color = .blue
    @State private var date = Date.now
    @State private var weekStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    @State private var dayOverview: DayOverview?
    @State private var loadError: String?
    @State private var weeklyOverview: [Date: DayOverview] = [:]

    
    let colums = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("List Overview")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            // date picker and today button
            HStack (){
                DatePicker("", selection: $date, displayedComponents: .date)
                Button(action: today) {
                    Text("Today")
                        .foregroundColor(.black)
                } .buttonStyle(.bordered)
            }
            
            // The calander
            HStack{
                let days: [Date] = (0..<7).compactMap {
                    Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
                }
                let daysLetters = ["M", "T", "W", "T", "F", "S", "S"]
                ForEach(days.indices, id: \.self) { index in
                    let day = days[index]
                    VStack(spacing: 6) {
                        // The week letter
                        Text(daysLetters[index])
                            .foregroundStyle(.secondary)
                            .font(.caption.bold())
                        // The day number
                        Text(day.formatted(.dateTime.day()))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                Circle()
                                    .foregroundStyle(
                                        Calendar.current.isDate(day, inSameDayAs: date)
                                        ? Color.orange
                                        : (weeklyOverview[day]?.netTotal ?? 0) >= 0
                                            ? Color.blue
                                            : Color.red
                                    )
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        date = day
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            // Swiped left → next week
                            changeWeek(by: 1)
                        } else if value.translation.width > 50 {
                            // Swiped right → previous week
                            changeWeek(by: -1)
                        }
                    }
            )
            
            // Items for selected day
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Divider()

                if let overview = dayOverview {
                    if overview.items.isEmpty {
                        Spacer()
                        Label("No Items", systemImage: "tray")
                            .font(.title)
                            .imageScale(.large)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        List{}
                    }
                    else {
                        Text("Transactions:")
                            .font(.title2)
                        Divider()
                        
                        let sortedItems = overview.items.sorted { lhs, rhs in
                            if lhs.amount == rhs.amount { return lhs.title < rhs.title }
                            return lhs.amount > rhs.amount
                        }
                        List {
                            ForEach(sortedItems) { item in
                                HStack {
                                    Text(item.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(item.amount as NSNumber, formatter: currencyFormatter)
                                        .foregroundStyle(item.amount >= 0 ? .blue : .red)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(item: item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(minHeight: 0, maxHeight: .infinity)


                        Divider()
                        HStack {
                            Text("Net total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(overview.netTotal as NSNumber, formatter: currencyFormatter)
                                .fontWeight(.semibold)
                                .foregroundStyle(overview.netTotal >= 0 ? .blue : .red)
                        }
                    }
                }
                else {
                    Text("No items for this day.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        

        .onAppear {
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            ) ?? weekStart
            loadOverview()
        }
        
        .onChange(of: date) { _, newValue in
            weekStart = Calendar.current.date(from:
                Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newValue)
            ) ?? weekStart
            loadOverview()
        }
    }

    
    // functions
    private func today() {
        date = Date.now
    }

    private func loadOverview() {
        let ledger = LedgerService(context: modelContext)
        do {
            dayOverview = try ledger.dayOverview(for: date)
        } catch {
            loadError = error.localizedDescription
            dayOverview = nil
        }
        
        weeklyOverview.removeAll()
        for i in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: i, to: weekStart) {
                if let overview = try? ledger.dayOverview(for: day) {
                    weeklyOverview[day] = overview
                }
            }
        }
    }

    private func delete(item: DayLineItem) {
        let ledger = LedgerService(context: modelContext)
        do {
            switch item.source {
            case .oneTime(let id):
                if let tx = modelContext.model(for: id) as? OneTimeTransaction {
                    try ledger.deleteOneTime(tx)
                }
            case .recurring(let id):
                if let rule = modelContext.model(for: id) as? RecurringRule {
                    try ledger.deleteRecurring(rule)
                }
            }
            loadOverview()
        } catch {
            loadError = error.localizedDescription
        }
    }
    
    private func changeWeek(by offset: Int) {
        if let newWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) {
            weekStart = newWeekStart
            date = newWeekStart
            loadOverview()
        }
    }

    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }
}

