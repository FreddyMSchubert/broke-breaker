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

    var body: some View {
        VStack(spacing: 12) {

            // date and today
            HStack {
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

                    // Gesture overlay
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
        .padding()
        .navigationTitle("List Overview")
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
                                $0.amount == $1.amount
                                ? $0.title < $1.title
                                : $0.amount > $1.amount
                            }
                        ) { item in
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text(item.amount as NSNumber, formatter: currencyFormatter)
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

                    HStack {
                        Text("Net total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(overview.netTotal as NSNumber, formatter: currencyFormatter)
                            .fontWeight(.semibold)
                            .foregroundStyle(overview.netTotal >= 0 ? .blue : .red)
                    }
                    .padding(.horizontal)
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
